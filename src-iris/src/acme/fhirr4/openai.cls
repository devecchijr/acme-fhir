Class acme.fhirr4.openai Extends acme.base.utilsApi
{

/// for safe string hierarchy
ClassMethod safeH(number, digits = 3) As %String
{
    Set number = +number
    Quit $E($E("000",1,digits),1,*-$L(number))_number
}

ClassMethod getMDStruct(patId As %String, secLevNested As %Boolean = 0) As %Library.DynamicObject
{
    Set tStruct = {}
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Set tSummary = {}
    Set tList = ##class(acme.fhirr4.openai).jretrieveList("acme","IAS|"_patId,0,0)
    If ..g(tList,"maxResults")>0 {
        Do tStream.Write(..g(tList,"data."_(..g(tList,"maxResults")-1)_".summaryContent"))
    } Else {
        //if it doesn't find the content, use patient.md file if exists
        Set tPath = "/acme-assets/"_patId_".md"
        If ##class(%Library.File).Exists(tPath)=1 {
            Set tSC=tStream.LinkToFile(tPath)
            If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC)}
        }
    }
    If tStream.SizeGet()>0 {
        Set (tT1,tT2,tT3,tG1,tG2,tL) = 0
        Set tKey = ""
        Set tGroup = 0
        Do tStream.Rewind()
        While (tStream.AtEnd=0) {
            Set tLine = tStream.ReadLine()
            //titles
            Set tContent = []
            Set tResInfo = ""
            If $Find(tLine,"---")>0 {
                Set tLine = "==="
            }
            If $Find(tLine,"```")>0 {
                Set tLine = $Replace(tLine,"```","")
            }
            Set tLine = $Replace(tLine,"**","*")
            Set tLineCont = $Replace($Select($Find($Replace(tLine," ",""),"-")=2:$Piece(tLine,"-",2,*),1:tLine),"#","")
            Set tL = tL+1 
            For i=1:1:$L(tLineCont,"*") {
                Set tCont = $Piece(tLineCont,"*",i)
                If i#2=0 Set tCont = "**"_tCont
                If $Find(tCont,"||")>0,$Find(tCont,"||",$Find(tCont,"||")+1)>0 {
                    Set tResInfo = $Piece(tCont,"||",2)
                    Set tCont = $Piece(tCont,"||",1)
                }
                Do tContent.%Push(tCont)
            }
            If $Find(tLine,"###") {
                Set tLine = $Replace(tLine,"###","")
                Set tT3 = tL
                Set tKey = $S(tT1>0:"."_..safeH(tT1-1,3),1:"")_$S(tT2>0:"."_..safeH(tT2-1,3),1:"")_$S(tT3>0:"."_..safeH(tT3-1,3),1:"")
                Do ..s(tStruct,$E(tKey,2,*),{"type":"###","value":(tContent)},,"^")
                Set tT3 = 0 //no nested
                continue
            }
            If $Find(tLine,"##") {
                Set tLine = $Replace(tLine,"##","")
                Set tT2 = tL
                Set tT3 = 0
                Set tKey = $S(tT1>0:"."_..safeH(tT1-1,3),1:"")_$S(tT2>0:"."_..safeH(tT2-1,3),1:"")_$S(tT3>0:"."_..safeH(tT3-1,3),1:"")
                Do ..s(tStruct,$E(tKey,2,*),{"type":"##","value":(tContent)},,"^")
                Set tT3 = 0 //no nested
                If secLevNested=0 Set tT2 = 0
                continue
            }
            If $Find(tLine,"#") {
                Set tLine = $Replace(tLine,"#","")
                Set tT1 = tL
                Set (tT2,tT3) = 0
                Set tKey = $S(tT1>0:"."_..safeH(tT1-1,3),1:"")_$S(tT2>0:"."_..safeH(tT2-1,3),1:"")_$S(tT3>0:"."_..safeH(tT3-1,3),1:"")
                Do ..s(tStruct,$E(tKey,2,*),{"type":"#","value":(tContent)},,"^")
                Set tT3 = 0 //no nested
                Set tT1 = 0
                continue
            }
            Set tL = tL + 1
            // topics (with identation)
            Set tGroupL = $Select($Find($replace(tLine," ",""),"-")=2:$Find(tLine,"-"),1:0)
            If tGroupL>0 {
                Set tIdent = $Find(tLine,"-")
                If tGroup'=tGroupL,tGroup=0 {
                    // new group
                    Set tLine = $Piece(tLine,"-",2)
                    Set tG1 = tL
                    Set tG2 = 0
                } ElseIf tGroup'=tGroupL,tGroupL>tGroup {
                    // new subgroup
                    Set tLine = $Piece(tLine,"-",2)
                    Set tG2 = tL
                } ElseIf tGroup'=tGroupL,tGroupL<tGroup {
                    // parent group
                    Set tLine = $Piece(tLine,"-",2)
                    Set tG1 = tL
                    Set tG2 = 0
                } Else {
                    //same group
                    Set tLine = $Piece(tLine,"-",2)
                }
                Set tType = "-"
                Set tKey = $S(tT1>0:"."_..safeH(tT1-1,3),1:"")_$S(tT2>0:"."_..safeH(tT2-1,3),1:"")_$S(tT3>0:"."_..safeH(tT3-1,3),1:"")_$S(tG1>0:"."_..safeH(tG1-1,3),1:"")_$S(tG2>0:"."_..safeH(tG2-1,3),1:"")
                Do ..s(tStruct,$E(tKey,2,*)_"^type",tType,,"^")
                If tIdent'="" Do ..s(tStruct,$E(tKey,2,*)_"^ident",tIdent,,"^")
                Set tType = "span"

                Set tGroup = tGroupL
            } Else {
                // simple div
                Set tGroup=0
                Set tIdent = ""
                Set tG1 = tL
                Set tType = "div"
                Set tKey = $S(tT1>0:"."_..safeH(tT1-1,3),1:"")_$S(tT2>0:"."_..safeH(tT2-1,3),1:"")_$S(tT3>0:"."_..safeH(tT3-1,3),1:"")_$S(tG1>0:"."_..safeH(tG1-1,3),1:"")_$S(tG2>0:"."_..safeH(tG2-1,3),1:"")
                Do ..s(tStruct,$E(tKey,2,*)_"^type",tType,,"^")

                Set tType = "span"
            }
            Set tKey = $S(tT1>0:"."_..safeH(tT1-1,3),1:"")_$S(tT2>0:"."_..safeH(tT2-1,3),1:"")_$S(tT3>0:"."_..safeH(tT3-1,3),1:"")_$S(tG1>0:"."_..safeH(tG1-1,3),1:"")_$S(tG2>0:"."_..safeH(tG2-1,3),1:"")_$S(tL>0:"."_..safeH(tL-1,3),1:"")
            Do ..s(tStruct,$E(tKey,2,*)_"^type",tType,,"^")
            Do ..s(tStruct,$E(tKey,2,*)_"^value",tContent,,"^")
            If tIdent'="" Do ..s(tStruct,$E(tKey,2,*)_"^ident",tIdent,,"^")
            If tResInfo'="" {
                Do ..s(tStruct,$E(tKey,2,*)_"^resInfo",tResInfo,,"^")
            } 
        }
    }
    Quit tStruct
}

ClassMethod getSummaryForm(patId As %String, plainForm As %Boolean = 0, origfhirdata, data, dateftr, encid, hlid) As %Library.DynamicObject
{
    Set tSumCard = {
        "order":0,
        "layout": {
            "value":"grid",
            "a":"col-12",
            "a.a":"card"
        }
    }
    Set tRootH = "layout^a.a"
    Set tSumStruct = ..getMDStruct(patId,$S((plainForm):0,1:1))
    If tSumStruct.%Size()=0 Quit {}
    While ..i(tSumStruct,,.key,.value,.it)
    {
        Set tType = "div"
        Set tClass = "m-0 text-600 mb-3"
        If ..g(value,"type")="###" {
            Set tClass = "text-700 font-bold mb-2 mt-2"
        }
        If ..g(value,"type")="##" {
            Set tClass = "text-800 font-bold mb-3 mt-2"
        }
        If ..g(value,"type")="#" {
            Set tClass = "text-900 font-bold text-3xl mb-4 mt-2"
        }
        If ..g(value,"type")="-" {
            Set tType = "ul"
            Set tClass = "py-0 pl-3 m-0 text-600 mb-3"
        } 
        If ..g(value,"type")="span",..g(value,"ident")'="" {
            Set tType = "li"
            Set tClass = "mb-2"
        }
        Set tObj = {"type":(tType),"class":(tClass)}
        If (plainForm) Do ..s(tSumCard,tRootH_"."_key_".value",tObj,,"^")
        If ((..g(value,"type")="##")||(..g(value,"type")="###")),'(plainForm) {
                Do ..s(tSumCard,tRootH_".b","grid",,"^")
                Do ..s(tSumCard,tRootH_".b.a.value",{"type":"div","class":" text-900 font-bold text-2xl ml-3 mt-2 mr-2 mb-1","content":"Summary Card"},,"^")
                Do ..s(tSumCard,tRootH_".b.b.value",{"type":"icon","class":"ml-2 mt-3 mb-2 pi pi-bolt"},,"^")
                Do ..s(tSumCard,tRootH_".b.c.value",{"type":"div","class":" text-400 ml-1 mt-3 mb-1","content":"(IA Generated)"},,"^")
                Do ..s(tSumCard,tRootH_".d.value",{"type":"tabView"},,"^")
                Do ..s(tSumCard,tRootH_".d."_$Piece(key,".",1),"c:components.tabPan"_$Piece(key,".",1),,"^")
                Set tTabPan = {
                        "type":"tabPanel",
                        "header":(..g(value,"value.0"))
                }
                Do ..s(tSumCard,"components^tabPan"_$Piece(key,".",1)_"^layout^value",tTabPan,,"^")
        } ElseIf '(plainForm),..g(tSumCard,"components^tabPan"_$Piece(key,".",1)_"^layout^value","^")'="" {
                Do ..s(tSumCard,"components^tabPan"_$Piece(key,".",1)_"^layout^"_$Piece(key,".",2,*)_".value",tObj,,"^")
        }
        While ..i(..g(value,"value"),,.skey,.svalue,.sit)
        {
            Set tSClass = ""
            Set tType = "span"
            If $E(svalue,1,2)="**" {
                Set tSClass = "font-semibold"
                Set svalue = $P(svalue,"**",2)
            }
            If svalue="===" {
                Set svalue = ""
                Set tType = "div"
                Set tSClass = "pb-5 border-bottom-1 surface-border"
            }
            Set tObj = {
                "type":(tType),
                "content":(svalue)
            }
            If tSClass'="" Do ..s(tObj,"class",tSClass)
            If (plainForm) Do ..s(tSumCard,tRootH_"."_key_"."_..safeH(skey,3)_".value",tObj,,"^")
            If '(plainForm),..g(tSumCard,"components^tabPan"_$Piece(key,".",1)_"^layout^value","^")'="",$Piece(key,".",2,*)'="" {
                Do ..s(tSumCard,"components^tabPan"_$Piece(key,".",1)_"^layout^"_$Piece(key,".",2,*)_"."_..safeH(skey,3)_".value",tObj,,"^")
            } 
        }
        If ..g(value,"resInfo")'="" {
            Do ..s(data,"styles^btnLink^border-radius","var(--border-radius)",,"^")
            Do ..s(data,"styles^btnLink^padding","0.25em 0.5rem",,"^")
            Do ..s(data,"styles^btnLink^text-transform","uppercase",,"^")
            Do ..s(data,"styles^btnLink^font-weight","300",,"^")
            Do ..s(data,"styles^btnLink^font-size","8px",,"^")
            Do ..s(data,"styles^btnLink^letter-spacing","0.3px",,"^")
            Set tResType = $Piece(..g(value,"resInfo"),"|",2)
            Set tResId = tResType_"|"_$Piece(..g(value,"resInfo"),"|",1)
            Set tResInfo = {}
            Do ##class(acme.fhirr4.api).getResData(origfhirdata,$Piece(..g(value,"resInfo"),"|",2),$Piece(..g(value,"resInfo"),"|",1),tResInfo)
            If ..g(tResInfo,"resId")'="" {
                Set tBtnZoom = {
                    "type":"button",
                    "class":"ml-2 p-button-outlined p-button-text p-button-primary",
                    "icon":"pi pi-search-plus",
                    "onClick":($Replace("fn:context.router.navigate(['/acme/fhirr4/patientData/"_patId_"/"_..g(tResInfo,"resPath")_"'],{queryParams: {"_$Select(hlid'="":",'hlid':'"_hlid_"'",1:"")_",'id':'"_..g(tResInfo,"resId")_"'}});","{,","{")),
                    "style":"fn:return data.styles['btnLink']"
                }
                Do ..s(tSumCard,"components^tabPan"_$Piece(key,".",1)_"^layout^"_$Piece(key,".",2,*)_"."_"888"_".value",tBtnZoom,,"^")
            }
        }
    }
    Quit tSumCard
}

ClassMethod getOpenAIConfig() As %Library.DynamicObject
{
    //Create config file if it does'nt exists
    If ##class(%Library.File).Exists("/acme-config/openai.json")=0 {
        Set tConfig = { 
            "Authorization":"Bearer <your openai code>"
            ,"targetBaseURL":"api.openai.com"
            ,"https":1
            ,"ssl":"pm.community.intersystems.com"
        }
        Set tSC = ..saveJSONFile(tConfig,"/acme-config/openai.json")
        If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC) }
    } Else {
        Set tConfig = ..getJSONFromFile("/acme-config/openai.json")
    }
    Quit tConfig
}

ClassMethod getLighterContent(fhircontent As %DynamicObject) As %DynamicObject
{
        Set tLighterContent = {
            "resourceType": "Bundle",
            "entry":[]
        }
        While (..i(fhircontent,"entry",.resourceKey,.resourceValue,.tResourceIt)) {
            If ..g(resourceValue,"resource.resourceType")="Patient" {
                Set tCopy = {}.%FromJSON(..g(resourceValue,"resource").%ToJSON())
                Do ..r(tCopy,"extension")
                Do ..r(tCopy,"identifier")
                Do ..r(tCopy,"name")
                Do ..r(tCopy,"text")
                Do ..r(tCopy,"telecom")
                Do ..r(tCopy,"communication")
                Do ..r(tCopy,"meta.versionId")
                Do ..r(tCopy,"address.0.extension")
                Do ..s(tLighterContent,"entry.+.resource",tCopy)
            }
            If ..g(resourceValue,"resource.resourceType")="Encounter" {
                Set tCopy = {}.%FromJSON(..g(resourceValue,"resource").%ToJSON())
                Do ..r(tCopy,"extension")
                Do ..r(tCopy,"code.extension")
                Do ..r(tCopy,"identifier")
                Do ..r(tCopy,"code.coding.0.extension")
                Do ..r(tCopy,"meta.versionId")
                Do ..r(tCopy,"participant")
                Do ..r(tCopy,"category.0.coding.0.system")
                Do ..r(tCopy,"serviceProvider")
                Do ..r(tCopy,"serviceType")
                Do ..s(tLighterContent,"entry.+.resource",tCopy)
            }
            If ..g(resourceValue,"resource.resourceType")="DocumentReference" {
                Set tCopy = {}.%FromJSON(..g(resourceValue,"resource").%ToJSON())
                Do ..r(tCopy,"extension")
                Do ..r(tCopy,"code.extension")
                Do ..r(tCopy,"identifier")
                Do ..r(tCopy,"code.coding.0.extension")
                Do ..r(tCopy,"meta.versionId")
                Do ..r(tCopy,"participant")
                Do ..r(tCopy,"category.0.coding.0.system")
                Do ..r(tCopy,"serviceProvider")
                Do ..r(tCopy,"serviceType")
                Do ..s(tLighterContent,"entry.+.resource",tCopy)
            }
            If ..g(resourceValue,"resource.resourceType")="Condition" {
                Set tCopy = {}.%FromJSON(..g(resourceValue,"resource").%ToJSON())
                Do ..r(tCopy,"extension")
                Do ..r(tCopy,"code.extension")
                Do ..r(tCopy,"code.coding.0.extension")
                Do ..r(tCopy,"meta.versionId")
                Do ..r(tCopy,"category.0.coding.0.system")
                Do ..s(tLighterContent,"entry.+.resource",tCopy)
            }
            If ..g(resourceValue,"resource.resourceType")="Immunization" {
                Set tCopy = {}.%FromJSON(..g(resourceValue,"resource").%ToJSON())
                Do ..r(tCopy,"extension")
                Do ..r(tCopy,"meta.versionId")
                Do ..s(tLighterContent,"entry.+.resource",tCopy)
            }
            If ..g(resourceValue,"resource.resourceType")="Procedure" {
                Set tCopy = {}.%FromJSON(..g(resourceValue,"resource").%ToJSON())
                Do ..r(tCopy,"extension")
                Do ..r(tCopy,"meta.versionId")
                Do ..s(tLighterContent,"entry.+.resource",tCopy)
            }
            If ..g(resourceValue,"resource.resourceType")="DiagnosticReport" {
                Set tCopy = {}.%FromJSON(..g(resourceValue,"resource").%ToJSON())
                Do ..r(tCopy,"extension")
                Do ..r(tCopy,"code.extension")
                Do ..r(tCopy,"code.coding.0.extension")
                Do ..r(tCopy,"category.0.coding.0.system")
                Do ..r(tCopy,"meta.versionId")
                Do ..r(tCopy,"category.0.coding.0.system")
                If ..g(tCopy,"category.0.coding.0.code")="RAD",..g(tCopy,"presentedForm.0.title")="JPEG" Do ..r(tCopy,"presentedForm.0.data")
                Do ..s(tLighterContent,"entry.+.resource",tCopy)
            }
            If ..g(resourceValue,"resource.resourceType")="MedicationStatement" {
                Set tCopy = {}.%FromJSON(..g(resourceValue,"resource").%ToJSON())
                Do ..r(tCopy,"extension")
                Do ..r(tCopy,"code.extension")
                Do ..r(tCopy,"code.coding.0.extension")
                Do ..r(tCopy,"meta.versionId")
                Do ..r(tCopy,"category.0.coding.0.system")
                Do ..s(tLighterContent,"entry.+.resource",tCopy)
            }
            If ..g(resourceValue,"resource.resourceType")="MedicationRequest" {
                Set tCopy = {}.%FromJSON(..g(resourceValue,"resource").%ToJSON())
                Do ..r(tCopy,"extension")
                Do ..r(tCopy,"code.extension")
                Do ..r(tCopy,"code.coding.0.extension")
                Do ..r(tCopy,"meta.versionId")
                Do ..r(tCopy,"category.0.coding.0.system")
                Do ..s(tLighterContent,"entry.+.resource",tCopy)
            }
            If ..g(resourceValue,"resource.resourceType")="AllergyIntolerance" {
                Set tCopy = {}.%FromJSON(..g(resourceValue,"resource").%ToJSON())
                Do ..r(tCopy,"extension")
                Do ..r(tCopy,"code.extension")
                Do ..r(tCopy,"code.coding.0.extension")
                Do ..r(tCopy,"meta.versionId")
                Do ..r(tCopy,"category.0.coding.0.system")
                Do ..s(tLighterContent,"entry.+.resource",tCopy)
            }
            If ..g(resourceValue,"resource.resourceType")="Observation" {
                Set tCopy = {}.%FromJSON(..g(resourceValue,"resource").%ToJSON())
                Do ..r(tCopy,"extension")
                Do ..r(tCopy,"code.extension")
                Do ..r(tCopy,"code.coding.0.extension")
                Do ..r(tCopy,"meta.versionId")
                Do ..r(tCopy,"category.0.coding.0.system")
                Do ..s(tLighterContent,"entry.+.resource",tCopy)
            }
            /*
            If ..g(resourceValue,"resource.resourceType")="ServiceRequest" {
                Set tCopy = {}.%FromJSON(..g(resourceValue,"resource").%ToJSON())
                Do ..r(tCopy,"extension")
                Do ..r(tCopy,"code.extension")
                Do ..r(tCopy,"code.coding.0.extension")
                Do ..r(tCopy,"meta.versionId")
                Do ..r(tCopy,"category.0.coding.0.system")
                If ..g(tCopy,"category.0.coding.0.code")="RAD",..g(tCopy,"presentedForm.0.title")="JPEG" Do ..r(tCopy,"presentedForm.0.data")
                Do ..s(tLighterContent,"entry.+.resource",tCopy)
            }
            */
        }
        Quit tLighterContent
}

ClassMethod getFromChatGPT(fhircontent As %DynamicObject, subject As %String) As %DynamicObject
{

        Set tLighterContent = ..getLighterContent(fhircontent)
        
        Set tRequest = ##class(apiPub.service.message).%New()
        Set tRequest.HttpVerb = "Post"
        Set tRequest.APIDomain = "ChatGPT"
        Set tRequest.APIOperationId = "getFromChatGPT"
        Set tRequest.APIPath = "/v1/chat/completions"
        Set tModel = "gpt-4-1106-preview"
        //Set tModel = "gpt-4-32k"
        Set tChatRequest = {
            "model": (tModel),
            "messages": [
                {
                "role": "assistant",
                "content": ("you are a very experienced doctor with high knowledge of hl7 fhir standard.")
                },
                {
                "role": "user",
                "content": ("This JSON structure represents a complete FHIR Bundle history of a certain patient:```"_$ZConvert(tLighterContent.%ToJSON(),"O","UTF8")_"```")
                },
                {
                "role": "user",
                "content": ("Now you will use this content to analyse the response i want. The clinical subject is """_subject_""". As a response i want a json content, with 3 columns. The first column represents the resource type, named resourceType. The second the resource id, named id. The third your comment about what this resource is related to my subject, named comment. Show me only the resources that are related to the subject. If there is nothing related, show me a comment using the patient resource type. As a response provide only the json content, nothing more.")
                }
            ],
            "temperature": 1,
            "top_p": 1,
            "frequency_penalty": 0,
            "presence_penalty": 0
        }
        Set tConfig = ..getOpenAIConfig()
        Set tRequest.Headers = {
            "Authorization":(..g(tConfig,"Authorization")),
            "Content-Type":"application/json"
        }.%ToJSON()
        Do tRequest.Body.Write(tChatRequest.%ToJSON())
        Set tApiParams = {
            "targetBaseURL":(..g(tConfig,"targetBaseURL"))
            ,"https":(..g(tConfig,"https"))
            ,"ssl":(..g(tConfig,"ssl"))
        }
        Set tSC = ##class(apiPub.core.service).ToHttpCall(tRequest,tApiParams,.tResponse,720)
        If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC) }
        If tResponse.Body.SizeGet()=0 Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> invalid response"))
        Set tI = $HOROLOG
        Set ^gptResp(tI) = $ZConvert(tResponse.Body.Read(),"I","UTF8")
        If $FIND(^gptResp(tI),"Bundle")=0 {
        Quit {}.%FromJSON(^gptResp(tI))
        }
        Do tResponse.Body.Rewind()
        Set tJSONResponse = {}.%FromJSON($ZConvert(tResponse.Body.Read(),"I","UTF8"))
        Quit tJSONResponse
}

ClassMethod getFromChatGPTSum(fhircontent As %DynamicObject, specialty As %String) As %DynamicObject
{
        Set tLighterContent = ..getLighterContent(fhircontent)

        Set tRequest = ##class(apiPub.service.message).%New()
        Set tRequest.HttpVerb = "Post"
        Set tRequest.APIDomain = "ChatGPT"
        Set tRequest.APIOperationId = "getFromChatGPT"
        Set tRequest.APIPath = "/v1/chat/completions"
        Set tModel = "gpt-4-1106-preview"
        //Set tModel = "gpt-4-turbo-preview"
        //Set tModel = "gpt-4-32k"
        Set tChatRequest = {
            "model": (tModel),
            "messages": [
                {
                "role": "assistant",
                "content": ("you are a very experienced doctor with high knowledge of hl7 fhir standard.")
                },
                {
                "role": "user",
                "content": ("Step 1: This JSON structure represents a complete FHIR Bundle history of a certain patient:```"_$ZConvert(tLighterContent.%ToJSON(),"O","UTF8")_"```")
                },
                {
                "role": "user",
                "content": ("Step 2: Now you will use this content to analyse the response i want. I'm a "_specialty_" physician and as a response I want a friendly and easy summary of this patient in a markdown formatted file, to facilitate my job in an upcoming encounter with the patient. As a response provide only the final file, nothing more.")
                },
                {
                "role": "user",
                "content": ("When you finished the step 2, put the """"""||{resourceId}|{resourceType}||"""""" at the end of each line, except for patient resources. If the line it's related to many resources to the same resourceType, and it's applicable, put at the end of the line the last resource in this format """"""||{resourceId}|{resourceType}||"""""".")
                }
           ],
            "temperature": 1,
            "top_p": 1,
            "frequency_penalty": 0,
            "presence_penalty": 0
        }
        Set tConfig = ..getOpenAIConfig()
        Set tRequest.Headers = {
            "Authorization":(..g(tConfig,"Authorization")),
            "Content-Type":"application/json"
        }.%ToJSON()
        Do tRequest.Body.Write(tChatRequest.%ToJSON())
        Set tApiParams = {
            "targetBaseURL":(..g(tConfig,"targetBaseURL"))
            ,"https":(..g(tConfig,"https"))
            ,"ssl":(..g(tConfig,"ssl"))
        }
        Set tSC = ##class(apiPub.core.service).ToHttpCall(tRequest,tApiParams,.tResponse,720)
        If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC) }
        If tResponse.Body.SizeGet()=0 Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> invalid response"))
        Set tI = $HOROLOG
        Set ^gptRespSum(tI) = $ZConvert(tResponse.Body.Read(),"I","UTF8")
        Do tResponse.Body.Rewind()
        Set tJSONResponse = {}.%FromJSON($ZConvert(tResponse.Body.Read(),"I","UTF8"))
        Quit tJSONResponse
}

ClassMethod filterNodes(pJSON As %Library.DynamicObject, Output pOutJSON As %Library.DynamicObject, pParams As %Library.DynamicObject, pWhereClause As %String, pInternal As %Library.DynamicObject) As %Status
{
	Set tSC = $SYSTEM.Status.OK()
	Try
	{
        //If not Defined The Params Set the Default Values
        If '$DATA(pParams) Set pParams={}
        If '$DATA(pWhereClause) Set pWhereClause=""    
        If pWhereClause="" Set tFilter = 1   
        Set pDelim = $SELECT(pParams.keyDelimiter'="":pParams.keyDelimiter,1:"^") 
        Set pPrintResults = $SELECT(pParams.printResults'="":pParams.printResults,1:0)
        //Internal Params
        If '$DATA(pInternal) Set pInternal={"parentKey":"","parentSchem":"", "parentType":""}
        Set pParentKey = pInternal.parentKey
        Set pParentSchem = pInternal.parentSchem
        Set pParentType = pInternal.parentType
		If pParentType="" {
			Set pOutJSON = {}
			Do ..filterNodes(pJSON,.pOutJSON,pParams,pWhereClause,{"parentKey":"", "parentSchem":"", "parentType":($SELECT($CLASSNAME(pJSON)="%Library.DynamicArray":"array",1:"object"))})
            If pPrintResults {
                Set tFormatter = ##class(%JSON.Formatter).%New(),jsonString=""
                Do tFormatter.FormatToString(pOutJSON.%ToJSON(),.jsonString)
                Write jsonString,!
            }
		} Else {
			Set prop = pJSON.%GetIterator()
			While (prop.%GetNext(.key,.value)) {
				Set tKey = $SELECT(pParentKey'="":pParentKey_pDelim, 1:"")_$SELECT(key'="":key, 1:"")
				Set tSchem = $SELECT(pParentSchem'="":pParentSchem_pDelim, 1:"")_$SELECT(key'="":$SELECT(pInternal.parentType = "array":"[n]",1:key), 1:"")
                If $ISOBJECT(value) {
                    Do ..filterNodes(value,.pOutJSON,pParams,pWhereClause,{"parentKey":(tKey), "parentSchem":(tSchem), "parentType":($SELECT($CLASSNAME(value)="%Library.DynamicArray":"array",1:"object"))})
      			} Else {
                    If pWhereClause'="" {
                        Set tFilterCmd = "(key,value,obj) If ("_pWhereClause_") {Quit 1} Else {Quit 0}"
                        Set tFilter=$XECUTE(tFilterCmd,tKey,value,pJSON)
                    }
                    If tFilter=1 Do ..s(pOutJSON,tKey,value,pJSON.%GetTypeOf(key),"^")
	 			}
			}
		}
	}
	Catch(e)
	{
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
