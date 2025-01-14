Class acme.fhirai.api Extends acme.base.utilsApi [ ProcedureBlock ]
{

/// @apiPub[path="getAuthToken"]
/// @apiPub[protected="false"]
/// @apiPub[tag="fhirAI"]
ClassMethod getAuthToken(domain As %String = "", clientId As %String = "", clientSecret As %String = "", audience As %String, scope As %String, Output accessToken As %String, Output remainingSec As %Integer = 0) As %Status [ WebMethod ]
{
    Set tSC = $SYSTEM.Status.OK()
    Set tConfig = ..getFhirAIConfig()
    If (clientId="")||(domain="") {
        Set domain = ..g(tConfig,"fhirOAuth.domain")
        Set clientId = ..g(tConfig,"fhirOAuth.auth.client_id")
        Set clientSecret = ..g(tConfig,"fhirOAuth.auth.client_secret")
        Set audience = ..g(tConfig,"fhirOAuth.auth.audience")
        Set scope = ..g(tConfig,"fhirOAuth.auth.scope")
    }
    Set accessToken = ""
    Set remainingSec = 0
    Set remainingSec = +$Piece($Get(^oktaToken(clientId,audience),"")," ",1)-($H*86400+$P($H,",",2))
    If remainingSec'="",remainingSec>5 {
        Set accessToken = $Piece($Get(^oktaToken(clientId,audience),"")," ",2)
        Quit tSC
    }
    Try
    {
        Set tRequest = ##class(apiPub.service.message).%New()
        Set tRequest.HttpVerb = "Post"
        Set tRequest.APIDomain = "FHIR"
        Set tRequest.APIOperationId = "getAuthToken"
        Set tRequest.APIPath = "/oauth/token"
        Set tHeader = {
            "Content-Type":"application/json"
        }
        Set tBody = {
            "client_id":(clientId),
            "client_secret":(clientSecret),
            "audience":(audience),
            "scope":(scope),
            "grant_type":"client_credentials"
        }
        Do tRequest.Body.Write(tBody.%ToJSON())
        Set tRequest.Headers = tHeader.%ToJSON()
        Set tApiParams = {
            "targetBaseURL":(domain_".us.auth0.com")
            ,"https":1
            ,"ssl":"pm.community.intersystems.com"
        }
        Set tSC = ##class(apiPub.core.service).ToHttpCall(tRequest,tApiParams,.tResponse)
        If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC) }
        If tResponse.ResponseStatusCode'="200" {
            Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"getAuthToken <"_tResponse.ResponseStatusCode_"> "_tResponse.ResponseStatusLine))
        }
        Set tResult = {}.%FromJSON(tResponse.Body)
        Set accessToken=..g(tResult,"access_token")
        Set ^oktaToken(clientId,audience)=+($H*86400+$P($H,",",2))+..g(tResult,"expires_in")_" "_..g(tResult,"access_token")
        }
        Catch(e)
        {
            Set tSC = e.AsStatus()
        }
    Quit tSC
}

/// @apiPub[tag="fhirAI"]
/// @apiPub[charset="UTF-8"]
/// @apiPub[protected="true"]
/// @apiPub[path="smartQuery"]
ClassMethod smartQuery(question As %String, userid As %String) As %Library.DynamicObject [ WebMethod ]
{
    Set tUser = ##class(acme.base.data.user).%OpenId(userid)
    If '$ISOBJECT(tUser) Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"userid does'nt exist"))
    Set tResult = {}
    Try
    {
        Set tNewQuestion = {}
        Do ..s(tNewQuestion,"question",question)
        Do ..s(tNewQuestion,"userId",userid)
        Do ..s(tNewQuestion,"userName",tUser.userName)
        Do ..s(tNewQuestion,"date",$TR($ZDT($H,3)," ","T"))
        Set tFHIRResult = {}
        Set tResp = ..getFromFhirAI(question)
        If ..g(tResp,"question")'="" {
            Do ..s(tNewQuestion,"response",tResp)
            Set tObj = ..jsave("acme","fhirAI|"_userid,tNewQuestion)
            Set tResult = {"data":(tObj)}
        } Else {
            Do ..s(tResult,"data",tResp)
        }
    }
    Catch(e)
    {
        Throw ##Class(%Exception.StatusException).CreateFromStatus(e.AsStatus())
    }
    Quit tResult
}

ClassMethod getFromFhirAI(question As %String) As %DynamicObject
{

        Set tLighterContent = {}
        Set tRequest = ##class(apiPub.service.message).%New()
        Set tRequest.HttpVerb = "Post"
        Set tRequest.APIDomain = "FhirIA"
        Set tRequest.APIOperationId = "getFromFhirAI"
        Set tRequest.APIPath = "/ai"
        Set tChatRequest = {"question": (question)}
        Set tConfig = ..getFhirAIConfig()
        Set tHeaders = {
            "Content-Type":"application/json",
            "accept": "application/json"
        }
        If ..g(tConfig,"fhirAIAuth")'="" Do ..s(tHeaders,"Authorization",..g(tConfig,"fhirAIAuth"))
        Set tRequest.Headers = tHeaders.%ToJSON() 

        If ..g(tConfig,"fhirAIOAuth")'="" {
            Set tSC = ..getAuthToken(..g(tConfig,"fhirAIOAuth.domain"),..g(tConfig,"fhirAIOAuth.auth.client_id"),..g(tConfig,"fhirAIOAuth.auth.client_secret"),..g(tConfig,"fhirAIOAuth.auth.audience"),..g(tConfig,"fhirAIOAuth.auth.scope"),.tAccessToken)
            If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC) }
            Do ..s(tHeaders,"Authorization","Bearer "_tAccessToken)
        }
        Do tRequest.Body.Write(tChatRequest.%ToJSON())
        Set tApiParams = {
            "targetBaseURL":(..g(tConfig,"fhirAIBaseURL"))
            ,"https":($S(..g(tConfig,"fhirAIhttps")'="":..g(tConfig,"fhirAIhttps"),1:0))
            ,"ssl":(..g(tConfig,"fhirAISSL")),
            "sslCheckServerIdentity":0
        }        
        Set tSC = ##class(apiPub.core.service).ToHttpCall(tRequest,tApiParams,.tResponse,720)
        If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC) }
        If tResponse.ResponseStatusCode'="200" {
            Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"error <"_tResponse.ResponseStatusCode_"> "_tResponse.ResponseStatusLine))
        }
        If tResponse.Body.SizeGet()=0 Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> invalid response"))
        Set tI = $HOROLOG
        Set ^fhirIAResp(tI) = $ZConvert(tResponse.Body.Read(),"I","UTF8")
        Do tResponse.Body.Rewind()
        Set tJSONResponse = {}.%FromJSON($ZConvert(tResponse.Body.Read(),"I","UTF8"))
        Quit tJSONResponse
}

/// @apiPub[path="fhirQuery"]
/// @apiPub[protected="false"]
/// @apiPub[tag="fhirAI"]
/// @apiPub[charset="UTF-8"]
ClassMethod FHIRQuery(query As %String) As %Library.DynamicObject [ WebMethod ]
{
    Set query = $Replace(query,"%25","%")
    Set query = $ZConvert(query,"I","URL")
    Set tConfig = ..getFhirAIConfig()
    Set tSC = $SYSTEM.Status.OK()
    Set tResult = {"status":(tSC)}
    Try
    {
        Set tRequest = ##class(apiPub.service.message).%New()
        Set tRequest.HttpVerb = "Get"
        Set tRequest.APIDomain = "FHIR"
        Set tRequest.APIOperationId = "FHIRR4"
        Set tFhirPath = ..g(tConfig,"fhirPath")
        If $E(tFhirPath,*)'="/" Set tFhirPath = tFhirPath_"/"
        Set tRequest.APIPath = tFhirPath_query
        Set tHeader = {
            "Accept":"*/*",
            "Access-Control-Allow-Origin": "*",
            "Content-Type":"application/fhir+json",
            "Authorization":(..g(tConfig,"fhirAuth"))
        }
        If ..g(tConfig,"fhirOAuth")'="" {
            Set tSC = ..getAuthToken(..g(tConfig,"fhirOAuth.domain"),..g(tConfig,"fhirOAuth.auth.client_id"),..g(tConfig,"fhirOAuth.auth.client_secret"),..g(tConfig,"fhirOAuth.auth.audience"),..g(tConfig,"fhirOAuth.auth.scope"),.tAccessToken)
            If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC) }
            Do ..s(tHeader,"Authorization","Bearer "_tAccessToken)
        }
        Set tRequest.Headers = tHeader.%ToJSON()
        Set tApiParams = {
            "targetBaseURL":(..g(tConfig,"fhirBaseURL"))
            ,"https":(..g(tConfig,"fhirHTTPS"))
            ,"ssl":(..g(tConfig,"fhirSSL")),
            "sslCheckServerIdentity":0
        }
        Set tSC = ##class(apiPub.core.service).ToHttpCall(tRequest,tApiParams,.tResponse)
        If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC) }
        If tResponse.ResponseStatusCode'="200" {
            Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError,"<"_tResponse.ResponseStatusCode_"> "_tResponse.ResponseStatusLine))
        }
        Set tFormatter = ##class(%JSON.Formatter).%New(),jsonString=""
        Do tFormatter.FormatToString(tResponse.Body,.jsonString)
        Set tResult = {"data":(jsonString)}
        }
        Catch(e)
        {
            Throw ##Class(%Exception.StatusException).CreateFromStatus(e.AsStatus())
        }
    Quit tResult
}

/// Gets backend dynamic menu content
/// @apiPub[path="/menu/{userid}"]
/// @apiPub[tag="menu"]
ClassMethod getMenu(userid As %String, browserTimezone As %String = "") As %Library.DynamicObject [ WebMethod ]
{
    return ..getJSONContent("fhirAIMenu")
}

/// Gets fhir backend dynamic content
/// @apiPub[path="/form/{formid}/{userid}"]
/// @apiPub[tag="forms"]
/// @apiPub[protected="true"]
/// @apiPub[charset="UTF-8"]
ClassMethod getForms(userid As %String, formid As %String, objid As %String, subid As %String, httpReq As apiPub.service.message) As %Library.DynamicObject [ WebMethod ]
{
      If formid="smartQuery" {
          Return ..smartQueryForm(userid, objid, subid, httpReq)
      }
    Return {}
}

ClassMethod smartQueryForm(userid, objid, subid, request) As %Library.DynamicObject
{
    Set tHeaders = {}
    If request.Headers'="" Set tHeaders = {}.%FromJSON(request.Headers)
    Set tContainers = {}
    Set tSource = {}
    Set tForms = {}
    Set tModel = {}
    Set tFunctions = {}
    Set tBreadCrumbs = [{"label":"AI Smart Query"}]
    Do ..getSmartQueryForm(userid, tModel, tContainers, tForms, tSource, tFunctions, ..getTranslations(userid))
    Set tData = {
            "data":(tSource),
            "forms":(tForms),
            "containers": (tContainers),
            "functions": (tFunctions),
            "menu":[
                {"label": "Summary", "parentLabel":"FHIR", "delete":true},
                {"label": "Demographics", "parentLabel":"FHIR", "delete":true},
                {"label": "Allergies", "parentLabel":"FHIR", "delete":true},
                {"label": "Encounters", "parentLabel":"FHIR", "delete":true},
                {"label": "Conditions", "parentLabel":"FHIR", "delete":true},
                {"label": "Immunizations", "parentLabel":"FHIR", "delete":true},
                {"label": "Procedures", "parentLabel":"FHIR", "delete":true},
                {"label": "Clinical Documents", "parentLabel":"FHIR", "delete":true},
                {"label": "Image Results", "parentLabel":"FHIR", "delete":true},
                {"label": "Vital Signs", "parentLabel":"FHIR", "delete":true},
                {"label": "Survey", "parentLabel":"FHIR", "delete":true},
                {"label": "Lab. Results", "parentLabel":"FHIR", "delete":true},
                {"label": "Medications", "parentLabel":"FHIR", "delete":true},
                {"label": "Appointments", "parentLabel":"FHIR", "delete":true},
                {"label": "Apply Filters", "parentLabel":"FHIR", "delete":true},
                {"label": "IA Highlights", "parentLabel":"FHIR","delete":true}
            ],
            "breadCrumbs":(tBreadCrumbs)
    }
    Do ..addBackEndLinks(..getBackEndLinks(tHeaders),tContainers,"col-12")
    Return tData
}

ClassMethod getBackEndLinks(headers) As %Library.DynamicArray
{
    Set tURLs = ..getJSONContent("backendurls")
    Quit {}.%FromJSON($Replace(..g(tURLs,"links").%ToJSON(),"<backendurl>",..g(headers,"REQUEST_SCHEME")_"://"_..g(headers,"HTTP_HOST")))
}

/// @apiPub[tag="fhirAI"]
/// @apiPub[protected="true"]
/// @apiPub[verb="delete"]
/// @apiPub[path="smartQuery/{id}"]
ClassMethod smartQueryDel(userid, id) As %Status [ WebMethod ]
{
    Set tSC = $SYSTEM.Status.OK()
    Try {
        Set tSC = ..jdelete("acme","FhirAI|"_userid,id)
    }
    Catch(e) {
        Set tSC = e.AsStatus()      
    }
    Quit tSC
}

ClassMethod getFhirAIConfig() As %Library.DynamicObject
{
    //Create config file if it does'nt exists
    If ##class(%Library.File).Exists("/acme-config/openai.json")=0 {
        Set tConfig = { 
            "targetBaseURL":"host.docker.internal:5005",
            "https":0
        }
        Set tSC = ..saveJSONFile(tConfig,"/acme-config/fhirai.json")
        If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC) }
    } Else {
        Set tConfig = ..getJSONFromFile("/acme-config/fhirai.json")
    }
    Quit tConfig
}

ClassMethod getSmartQueryForm(userid, model, containers, forms, data, functions, config) As %Status
{
    Set tSubmitFunc = "if ((control.errors?.pattern) || (control.errors?.required)) return;"_$CHAR(10,13)_
                            "context.backendService.getItems('smartQuery',backendItem,'fhirai').then(beData => {"_$CHAR(10,13)_
                            "context.isLoading=false;"_$CHAR(10,13)_
                            "data['result']=beData;"_$CHAR(10,13)_
                            "if (data['result']) {"_$CHAR(10,13)_
                            "   if (!data['result']['code']) {"_$CHAR(10,13)_
                            "       context.messageService.add({"_
                            "           severity: 'success',"_
                            "           summary: context.translateService.instant('IA Service'),"_
                            "           detail: context.translateService.instant('there is a new response'),"_
                            "           life: 2000,"_
                            "       });"_
                            "       if (!data['IAList']) data['IAList']=[];data['IASList']=[];"_
                            "       data['IAList'].unshift(data['result']);"_
                            "       data['IASList'].push(data['result']['response']);"_
                            "   } else {"_
                            "       context.messageService.add({"_
                            "           severity: 'error',"_
                            "           summary: context.translateService.instant(data['result']['error']['code']),"_
                            "           detail: context.translateService.instant(data['result']['error']['message']),"_
                            "           life: 6000,"_
                            "       });"_
                            "       console.log(data['result']['error']['code'],data['result']['error']['message']);"_
                            "   }"_
                            "}"_
                            ""_
                            "}, err => {context.isLoading=false;});"_
                            "context.messageService.add({"_
                            "    severity: 'info',"_
                            "    summary: context.translateService.instant('IA Service'),"_
                            "    detail: context.translateService.instant('question submitted to IA Service'),"_
                            "    life: 3000,"_
                            "});"_
                            "context.isLoading=true;"_$CHAR(10,13)_
                            "data['SmartQuery']['question']='';"
    Do ..s(functions,"_submitQuestion.0","control")
    Do ..s(functions,"_submitQuestion.1","context")
    Do ..s(functions,"_submitQuestion.2","data")
    Do ..s(functions,"_submitQuestion.3","containerControl")
    Do ..s(functions,"_submitQuestion.4","backendItem")
    Do ..s(functions,"_submitQuestion.5",$Replace(tSubmitFunc,"{,","{"))
    Do ..s(data, "SmartQuery", {"question":"","userid":(userid)})
    Set tAIList = ..jretrieveList("acme","FhirAI|"_userid,"","")
    Set tAISList=[]
    Set tAITopic = ""
    If ..g(tAIList,"data").%Size() > 0 {
        Do ..s(data, "IAList", ..orderBy(..g(tAIList,"data"),["date|-1"])) 
    }
    Set tSQ = {
                "order":0,
                "layout":{
                    "value":"grid",
                    "a":"col-12",
                    "a.a":"c:acc",
                    "a.a.a":"c:accTab",
                    "a.a.a.a":"c:smartQueryForm"
                },
                "acc":{"type":"accordion","active":true},
                "accTab":{"type":"accordionTab","header":"Smart Query","selected":true},
                "smartQueryForm":{
                    "type":"form",
                    "form":"SmartQuery"
                }
            }
    Set tGrid = {
      "active": true,
      "layout": {
        "value": "grid",
        "a": "col-12",
        "a.a": "card",
        "a.a.a": "c:table"
      },
      "table": {
        "type": "formtable",
        "dataKey": "id",
        "target": "IAList",
        "value": "IAList",
        "form": "IAList",
        "rows": 3,
        "paginator": true,
        "rowHover": true,
        "onRowSelect":"fn:data['IASList']=[];data['IASList'].push(data['selectedItem']['response']);",
        "onRowUnselect":"fn:data['IASList']=[];",
        "selectionTarget":"selectedItem",
        "selectionMode":"single",
        "showEditButton": false,
        "showCurrentPageReport": false,
        "apiTarget": "smartQuery",
        "caption": {
          "label": "Smart Query Results"
        },
        "currentPageReportTemplate": "Showing {first} to {last} of {totalRecords} entries",
        "summary": false,
        "responsiveLayout": "scroll",
        "label": "Hightlight List",
        "columns": [
          {
            "header": "Question",
            "type": "field",
            "value": "question"
          },
          { 
            "header": "Date",
            "dateFormat": "global_datetimeFormat2",
            "type": "field",
            "value": "date"
          },
          {
            "header": "",
            "icon": "pi pi-trash",
            "type": "button",
            "buttonType": "button",
            "class": "p-button-rounded p-button-danger p-button-outlined mb-2",
            "coupled": false,
            "onClick": ("fn:context.deleteItem(containerControl.apiTarget,'id',item,containerControl.target,'Item Deleted',{'userid':'"_userid_"'});data['selectedItem']=null;data['IASList']=[];"),
            "value": "DelBtn"
          }
        ]
      },
      "order": 1
    }
    Do ..s(containers, "SmartQueryC", tSQ)
    Do ..s(containers, "SmartQueryG", tGrid)
    Set tSGrid = {
      "active": true,
      "layout": {
        "value": "grid",
        "a": "col-12",
        "a.a": "card",
        "a.a.a": "c:table"
      },
      "table": {
        "type": "formtable",
        "dataKey": "id",
        "target": "IASList",
        "value": "IASList",
        "form": "IASList",
        "rows": 100,
        "paginator": true,
        "rowHover": true,
        "showEditButton": false,
        "showCurrentPageReport": false,
        "caption": {
          "label": ((..translate(config,"FHIR Queries")))
        },
        "currentPageReportTemplate": "Showing {first} to {last} of {totalRecords} entries",
        "summary": false,
        "responsiveLayout": "scroll",
        "label": "Findings",
        "columns": [
          {
            "header": "",
            "icon": "pi pi-play",
            "type": "button",
            "buttonType": "button",
            "class": "p-button-rounded p-button-primary p-button-outlined mb-2",
            "coupled": false,
            "onClick": ("fn:context.setFormItem('fhirQuery', item);containerData['fhirQueryDial']['dialog']['visible']=true;"),
            "disabled":"fn:return ((!item['query'])|(!item['explanation']));",
            "value": "PlayBtn"
          },
          { 
            "header": "FHIR Query",
            "type": "field",
            "value": "query"
          },
          { 
            "header": "IA Explanation",
            "colStyle":"max-width:35rem;",
            "type": "field",
            "value": "explanation"
          }
        ]
      },
      "order": 1
    }
    Do ..s(containers, "SmartQueryS", tSGrid)
    Set tSQForm = {
                "type":"form",
                "id":"SmartQuery",
                "dataTarget":"SmartQuery",
                "onKeydown":("fn:if (event.key === 'Enter') context._submitQuestion(control,context,data,containerControl,{'userid':'"_userid_"','question':(backendItem['question'])});"),
                "groups": [
                    {
                        "class":"p-fluid",
                        "controlItems": [
                            {
                                "name": "question",
                                "label": "Question",
                                "value": null,
                                "containerClass": "col-12",
                                "type": "text",
                                "showErrors": true
                            }
                        ]
                    },
                    {
                    "class": "div",
                    "containerClass": "p-fluid formgrid grid justify-content-center",
                    "controlItems": [                        
                        {
                            "type":"divider"
                        },
                        {
                            "type": "button",
                            "name": "btn1",
                            "label": "submit to AI",
                            "buttonType": "button",
                            "class":"p-button-outlined",
                            "containerClass": "align-self-start col-12 md:col-4 ",
                            "disabled": "fn:return !form.valid;",
                             "onClick":("fn:context._submitQuestion(control,context,data,containerControl,{'userid':'"_userid_"','question':(backendItem['question'])});")
                        }
                        ]
                    }                    
                ]
            }
        Do ..s(forms, "SmartQuery", tSQForm)
        Do ..addFormDialog(userid, containers, forms,"fhirQuery","Execute FHIR query in the FHIR repository", functions)
    Quit $$$OK
}

ClassMethod addFormDialog(userid, containers, forms, grpName As %String, header As %String, functions) As %Status
{
    Set tDevMode = 0
    Set tDialog = {
        "layout":{
            "value":"c:dialog",
            "a.value":{"type":"form","form":(grpName)},
            "footer":"c:btclose"
        },
        "dialog":{
            "type":"dialog",
            "header":(header),
            "ngStyle":{ "width": "900px"},
            "visible":false
        },
        "btclose":{
            "type":"button",
            "icon":"pi pi-times",
            "class":"p-button-text",
            "label":"Close",
            "onClick":("fn:containerData['"_grpName_"Dial']['dialog']['visible']=false;")
        }            
    }
    Set tSubmitFHIR = "if ((control.errors?.pattern) || (control.errors?.required)) return;"_$CHAR(10,13)_
                            "context.backendService.getItems('fhirQuery',backendItem,'fhirai').then(beData => {"_$CHAR(10,13)_
                            "context.isLoading=false;"_$CHAR(10,13)_
                            "data['fhirResult']=beData;"_$CHAR(10,13)_
                            "if (data['fhirResult']) {"_$CHAR(10,13)_
                            "       context.messageService.add({"_
                            "           severity: 'success',"_
                            "           summary: context.translateService.instant('FHIR Service'),"_
                            "           detail: context.translateService.instant('there is a new response'),"_
                            "           life: 2000,"_
                            "       });"_
                            "      data['item']['result']=data['fhirResult'];"_
                            "}"_
                            ""_
                            "}, err => {"_$CHAR(10,13)_
                            "    context.isLoading=false;"_$CHAR(10,13)_
                            "    context.messageService.add({"_$CHAR(10,13)_
                            "           severity: 'error',"_$CHAR(10,13)_
                            "           summary: context.translateService.instant('invalid Query'),"_$CHAR(10,13)_
                            "           detail: context.translateService.instant(err['statusText']),"_$CHAR(10,13)_
                            "           life: 6000,"_
                            "       });"_
                            "      data['item']['result']=null;"_
                            "    });"_
                            "context.messageService.add({"_
                            "    severity: 'info',"_
                            "    summary: context.translateService.instant('FHIR Repository'),"_
                            "    detail: context.translateService.instant('query submitted to FHIR Repository'),"_
                            "    life: 3000,"_
                            "});"_
                            "context.isLoading=true;"_$CHAR(10,13)
    Do ..s(functions,"_submitFHIRQuery.0","control")
    Do ..s(functions,"_submitFHIRQuery.1","context")
    Do ..s(functions,"_submitFHIRQuery.2","data")
    Do ..s(functions,"_submitFHIRQuery.3","containerControl")
    Do ..s(functions,"_submitFHIRQuery.4","backendItem")
    Do ..s(functions,"_submitFHIRQuery.5",$Replace(tSubmitFHIR,"{,","{"))

    Set form = {
      "groups":[
        {
          "controlItems":[
                {
                    "showNull":false,
                    "containerClass":"align-self-start col-12 md:col-12",
                    "label":"FHIR Query",
                    "type":"text",
                    "readonly":false,
                    "name":"query"
                },
                {
                    "type": "button",
                    "name": "btn1",
                    "label": "submit to FHIR Repository",
                    "buttonType": "button",
                    "class":"p-button-outlined",
                    "containerClass": "align-self-start col-12 md:col-4 ",
                    "disabled": "fn:return !form.valid;",
                        "onClick":("fn:_query=encodeURIComponent(backendItem['query']);if (_query.startsWith('%20',0)) {_query = _query.substr(3)};_query=_query.replace('%25','%');context._submitFHIRQuery(control,context,data,containerControl,{'query':(_query)});")
                },
                {
                    "showNull":false,
                    "containerClass":"align-self-start col-12 md:col-12",
                    "rows":20,
                    "type":"textarea",
                    "label":"FHIR Result",
                    "readonly":true,
                    "style":{
                        "background":"rgba(0,0,0,.15)"
                    },
                    "name":"result"
                }
            ]
        }
      ]
    }
    Do ..s(forms,grpName,form,,"^")
    Do ..s(containers,grpName_"Dial",tDialog)
}

}
