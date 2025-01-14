Class acme.fhirr4.api Extends acme.base.utilsApi [ ProcedureBlock ]
{

/// @apiPub[path="getAuthToken"]
/// @apiPub[protected="false"]
/// @apiPub[tag="fhir"]
ClassMethod getAuthToken(domain As %String = "", clientId As %String = "", clientSecret As %String = "", audience As %String, scope As %String, Output accessToken As %String, Output remainingSec As %Integer = 0) As %Status [ WebMethod ]
{
    Set tSC = $SYSTEM.Status.OK()
    Set tConfig = ..getFHIRR4Config()
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

/// @apiPub[tag="fhir"]
/// @apiPub[protected="false"]
ClassMethod getMDStruct(patId) As %Library.DynamicObject [ WebMethod ]
{
    Quit ##class(acme.fhirr4.openai).getMDStruct(patId)
}

ClassMethod getFHIRR4Config() As %Library.DynamicObject
{
    //Create config file if it does'nt exists
    If ##class(%Library.File).Exists("/acme-config/fhirr4.json")=0 {
        Set tConfig = {
            "fhirPath": "/csp/healthshare/demo/fhir/r4/",
            "fhirBaseURL": "host.docker.internal:8443",
            "_fhirOAuth": {
                "comments":"remove _ from _fhirOAuth node for Oauth Machine to Machine Authentication",
                "domain":"dev-tz6eol0jyjsyi7g0",
                "auth": {"client_id":"qAQgXRDAC36z2C0LXkUjDRrZ2wdvgAVD","client_secret":"k9N0vBcB6GzTtAsFzPyNyk202OYcLRDcQ3PZOZT1Ph_bw3sBXos_AczGBho70T_F","audience":"https://host.docker.internal:8443/csp/healthshare/demo/fhir/r4","grant_type":"client_credentials","scope":"user/*.*"}
            },
            "fhirAuth": "Basic X3N5c3RlbTpJU0NERU1P",
            "fhirHTTPS":1,
            "fhirSSL": "pm.community.intersystems.com"
        }
        Set tSC = ..saveJSONFile(tConfig,"/acme-config/fhirr4.json")
        If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC) }
    } Else {
        Set tConfig = ..getJSONFromFile("/acme-config/fhirr4.json")
    }
    Quit tConfig
}

/// @apiPub[tag="fhir"]
/// @apiPub[charset="UTF-8"]
/// @apiPub[protected="false"]
/// @apiPub[path="fhirSummary"]
ClassMethod fhirSummary(specialty As %String = "primary care", userid As %String, objid As %String) As %Library.DynamicObject [ WebMethod ]
{
    Set tUser = ##class(acme.base.data.user).%OpenId(userid)
    Set tResult = {}
    Set tSummary = {}
    Do ..s(tSummary,"specialty",specialty)
    Do ..s(tSummary,"userId",userid)
    Do ..s(tSummary,"userName",tUser.userName)
    Do ..s(tSummary,"patientId",objid)
    Do ..s(tSummary,"procDate",$TR($ZDT($H,3)," ","T"))
    Set tFHIRResult = ..FHIRPassThrough("Patient", objid, "$everything")
    Set tResp = ##class(acme.fhirr4.openai).getFromChatGPTSum(tFHIRResult, specialty)
    If ..g(tResp,"error")="" {
        Set tParseResp = ..g(tResp,"choices.0.message.content")
        Do ..s(tSummary,"summaryContent",tParseResp)
        Set tObj = ..jsave("acme","IAS|"_objid,tSummary)
        Set tResult = {"data":(tObj)}
    } Else {
        Do ..s(tResult,"data",tResp)
    }
    Quit tResult
}

/// @apiPub[tag="fhir"]
/// @apiPub[charset="UTF-8"]
/// @apiPub[protected="true"]
/// @apiPub[path="fhirHighlight"]
ClassMethod fhirHighlight(topic As %String, userid As %String, objid As %String) As %Library.DynamicObject [ WebMethod ]
{
    Set tUser = ##class(acme.base.data.user).%OpenId(userid)
    Set tResult = {}
    Set tNewTopic = {}
    Do ..s(tNewTopic,"topic",topic)
    Do ..s(tNewTopic,"userId",userid)
    Do ..s(tNewTopic,"userName",tUser.userName)
    Do ..s(tNewTopic,"patientId",objid)
    Do ..s(tNewTopic,"procDate",$TR($ZDT($H,3)," ","T"))
    Set tFHIRResult = ..FHIRPassThrough("Patient", objid, "$everything")
    Set tResp = ##class(acme.fhirr4.openai).getFromChatGPT(tFHIRResult, topic)
    Set tParseResp = []        
    If ..g(tResp,"error")="" {
        If $Find("[]",..g(tResp,"choices.0.message.content"))=0 {
            Set tParseResp = {}.%FromJSON($Piece("["_$Piece(..g(tResp,"choices.0.message.content"),"[",2,*),"]",1,*-1)_"]")
        }
        Do ..s(tNewTopic,"responseList",tParseResp)
        Set tObj = ..jsave("acme","IA|"_objid,tNewTopic)
        Set tResult = {"data":(tObj)}
    } Else {
        Do ..s(tResult,"data",tResp)
    }
    Quit tResult
}

/// @apiPub[tag="fhir"]
/// @apiPub[charset="UTF-8"]
/// @apiPub[protected="true"]
/// @apiPub[path="lighterFHIRContent"]
ClassMethod lighterFHIRContent(objid As %String) As %Library.DynamicObject [ WebMethod ]
{
    Set tFHIRResult = ..FHIRPassThrough("Patient", objid, "$everything")
    Quit ##class(acme.fhirr4.openai).getLighterContent(tFHIRResult)
}

/// Gets backend dynamic menu content
/// @apiPub[path="/menu/{userid}"]
/// @apiPub[tag="menu"]
ClassMethod getMenu(userid As %String, browserTimezone As %String = "") As %Library.DynamicObject [ WebMethod ]
{
    return ..getJSONContent("fhirMenu")
}

/// Gets fhir backend dynamic content
/// @apiPub[path="/form/{formid}/{userid}"]
/// @apiPub[tag="forms"]
/// @apiPub[protected="true"]
/// @apiPub[charset="UTF-8"]
ClassMethod getForms(userid As %String, formid As %String, objid As %String, subid As %String, reload As %Integer, dateftr As %String, encid As %String, ssn As %String, hlid As %String, id As %String, httpReq As apiPub.service.message) As %Library.DynamicObject [ WebMethod ]
{
      If formid="patientData" {
          Return ..patientDataForm(userid, objid, subid, reload, dateftr, encid, hlid, id, httpReq)
      }
      If formid="patientSearch" {
          Return ..patientSearchForm(userid, objid, subid, ssn, httpReq)
      }
    Return {}
}

/// @apiPub[path="passthrough/{resourceType}/{id}/{queryType}"]
/// @apiPub[params.queryType.required="false"]
/// @apiPub[params.id.required="false"]
/// @apiPub[protected="false"]
/// @apiPub[tag="fhir"]
/// @apiPub[charset="UTF-8"]
ClassMethod FHIRPassThrough(resourceType As %String, id As %String, queryType As %String, given As %String, family As %String, identifier As %String, birthdate As %String, gender As %String, address As %String) As %Library.DynamicObject [ WebMethod ]
{
    Set tConfig = ..getFHIRR4Config()
    If ('$DATA(queryType))||(queryType="*") Set queryType = ""
    If ('$DATA(id))||(id="*") Set id = ""
    If ('$DATA(resourceType))||(resourceType="") Set resourceType = "Patient"
    Set argument = "?"
    If $DATA(family),family'="" Set argument = argument_$SELECT(argument'="?":"&",1:"")_"family="_family
    If $DATA(given),given'="" Set argument = argument_$SELECT(argument'="?":"&",1:"")_"given="_given
    If $DATA(birthdate),birthdate'="" Set argument = argument_$SELECT(argument'="?":"&",1:"")_"birthdate="_birthdate
    If $DATA(identifier),identifier'="" Set argument = argument_$SELECT(argument'="?":"&",1:"")_"identifier="_identifier
    If $DATA(gender),gender'="" Set argument = argument_$SELECT(argument'="?":"&",1:"")_"gender="_gender
    If $DATA(address),address'="" Set argument = argument_$SELECT(argument'="?":"&",1:"")_"address="_address
    Set tSC = $SYSTEM.Status.OK()
    Set tResult = {"status":(tSC)}
    If argument="?",id="",queryType="" Return {"statusCode": 0,"message": "Invalid Arguments","errorCode": 5001}
    Try
    {
        Set tRequest = ##class(apiPub.service.message).%New()
        Set tRequest.HttpVerb = "Get"
        Set tRequest.APIDomain = "FHIR"
        Set tRequest.APIOperationId = "FHIRR4"
        Set tRequest.APIPath = ..g(tConfig,"fhirPath")_resourceType_$SELECT(id'="":"/"_id,1:"")_$SELECT(queryType'="":"/"_queryType,1:"")_$SELECT(argument'="?":argument,1:"")
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
        Set tResult = {}.%FromJSON(tResponse.Body)
        }
        Catch(e)
        {
            Throw ##Class(%Exception.StatusException).CreateFromStatus(e.AsStatus())
        }
    Quit tResult
}

/// show an image
/// @apiPub[tag="fhir"]
/// @apiPub[path="/showimage/{resourceType}/{resourceId}"]
/// @apiPub[response.outputType="text/html"]
/// @apiPub[protected="true"]
/// @apiPub[charset="ISO-8859-1"]
Method showResourceImage(resourceType As %String, resourceId As %String, httpReq As apiPub.service.message) As %Stream.GlobalCharacter [ WebMethod ]
{
    Set tFileStream=..getResourceImage(resourceType, resourceId)
    Set tOutput=##class(%Stream.GlobalCharacter).%New()
    Do tOutput.Write("<img alt="""" src="""_httpReq.GetHeaders("REQUEST_SCHEME")_"://"_httpReq.GetHeaders("HTTP_HOST")_$PIECE(httpReq.GetHeaders("REQUEST_URI"),"/",1,2)_"/image/"_resourceType_"/"_resourceId_"""/>")
    Quit tOutput
}

/// show a document
/// @apiPub[tag="fhir"]
/// @apiPub[path="/showdoc/{resourceType}/{resourceId}"]
/// @apiPub[response.outputType="text/html"]
/// @apiPub[protected="true"]
/// @apiPub[charset="ISO-8859-1"]
Method showResourceDoc(resourceType As %String, resourceId As %String, httpReq As apiPub.service.message) As %Stream.GlobalCharacter [ WebMethod ]
{
    Set resourceId = $REPLACE($ZCONVERT(resourceId,"L"),".pdf","")
    Set tFileStream=..getResourceImage(resourceType, resourceId)
    Set tOutput=##class(%Stream.GlobalCharacter).%New()
    Do tOutput.Write("<a href="""_httpReq.GetHeaders("REQUEST_SCHEME")_"://"_httpReq.GetHeaders("HTTP_HOST")_$PIECE(httpReq.GetHeaders("REQUEST_URI"),"/",1,2)_"/doc/"_resourceType_"/"_resourceId_""">pdf</>")
    Quit tOutput
}

/// get a file or image
/// @apiPub[tag="fhir"]
/// @apiPub[path="/image/{resourceType}/{resourceId}"]
/// @apiPub[response.outputType="application/octet-stream"]
/// @apiPub[charset="ISO-8859-1"]
/// @apiPub[protected="false"]
Method getResourceImage(resourceType As %String, resourceId As %String, httpRequest As apiPub.service.message) As %Stream.GlobalBinary [ WebMethod ]
{
    Set tResource = ..fhirQuery(resourceType,resourceId,"",,,,,,,httpRequest)
    Set tBinary = ##class(%Stream.GlobalBinary).%New()
    Do tBinary.Write($SYSTEM.Encryption.Base64Decode(..g(tResource,"presentedForm_0_data","^")))
    Quit tBinary
}

/// get a file or image
/// @apiPub[tag="fhir"]
/// @apiPub[path="/doc/{resourceType}/{resourceId}"]
/// @apiPub[response.outputType="application/octet-stream"]
/// @apiPub[charset="ISO-8859-1"]
/// @apiPub[protected="false"]
Method getResourceDoc(resourceType As %String, resourceId As %String, httpRequest As apiPub.service.message) As %Stream.GlobalBinary [ WebMethod ]
{
    Set resourceId = $REPLACE($ZCONVERT(resourceId,"L"),".pdf","")
    Set tResource = ..fhirQuery(resourceType,resourceId,"",,,,,,,httpRequest)
    Set tBinary = ##class(%Stream.GlobalBinary).%New()
    Do tBinary.Write($SYSTEM.Encryption.Base64Decode(..g(tResource,"content_0_attachment_data","^")))
    Quit tBinary
}

/// @apiPub[tag="fhir"]
/// @apiPub[charset="UTF-8"]
/// @apiPub[protected="true"]
/// @apiPub[path="fhirPatientSearch"]
ClassMethod fhirPatientSearch(given As %String, family As %String, identifier As %String, birthdate As %String, gender As %String, address As %String, httpReq As apiPub.service.message) As %Library.DynamicObject [ WebMethod ]
{
    If '$DATA(given) Set given = ""
    If '$DATA(family) Set family = ""
    If '$DATA(identifier) Set identifier = ""
    If '$DATA(birthdate) Set birthdate = ""
    If '$DATA(gender) Set gender = ""
    If '$DATA(address) Set address = ""
    Set tResult = {"data":[]}
    If $LENGTH(given_family_identifier_birthdate_gender_address)=0 Quit tResult
    Set tQuery = ..fhirQuery("Patient","*","*",given,family,identifier,birthdate,gender,address,httpReq)
    If ..g(tQuery,"Patient")'="" {
        While (..i(tQuery,"Patient",.resourceKey,.resourceValue,.tResourceIt)) {
            Do ..s(tResult,"data.+",resourceValue)
        }
    }
    Quit tResult
}

/// @apiPub[path="fhirquery/{resourceType}/{id}/{queryType}"]
/// @apiPub[params.id.required="false"]
/// @apiPub[params.queryType.required="false"]
/// @apiPub[protected="false"]
/// @apiPub[tag="fhir"]
/// @apiPub[charset="UTF-8"]
ClassMethod fhirQuery(resourceType As %String, id As %String, queryType As %String, given As %String, family As %String, identifier As %String, birthdate As %String, gender As %String, address As %String, httpRequest As apiPub.service.message) As %Library.DynamicObject [ WebMethod ]
{
    Set tHeaders = {}
    If httpRequest.Headers'="" Set tHeaders = {}.%FromJSON(httpRequest.Headers)
    Set tParams = {}
    If httpRequest.Params'="" Set tParams = {}.%FromJSON(httpRequest.Params)
    Set tDevMode = 0
    If ..g(tParams,"userid")'="" {
        Set tUserData = ##class(acme.base.data.user).%OpenId(..g(tParams,"userid"))
        Set tDevMode = tUserData.devMode
    }
    Set tConfig = ..getFHIRR4Config()
    Set tResult = {}
    Set tQueryConfig = {
            "groupType":"resourceType",
            "*|extension": "0|url",
            "*|identifier":"1|type_coding_0_code",
            "*|participant":"1|type_0_coding_0_display",
            "*|name":"1|use",
            "*|telecom":"1|use",
            "Observation|component":"1|0",
            "DiagnosticReport|result":"1|0"
    }
    If '$DATA(given) Set given = ""
    If '$DATA(family) Set family = ""
    If '$DATA(identifier) Set identifier = ""
    If '$DATA(birthdate) Set birthdate = ""
    If '$DATA(gender) Set gender = ""
    If '$DATA(address) Set address = ""
    Set tFHIRResult = ..FHIRPassThrough(resourceType, id, queryType, given, family, identifier, birthdate, gender, address)
    Set tModProps = {}
    If (..g(tFHIRResult,"resourceType")'="Bundle")||(..g(tFHIRResult,"total")=0)||(..g(tFHIRResult,"total")="")  {
        Set tFlatResource = {}
        Set tFModProps=..flat(tFHIRResult,"_",tQueryConfig)
        Quit tFModProps
    } Else {
        While (..i(tFHIRResult,"entry",.resourceKey,.resourceValue,.tResourceIt)) {
            Set tFlatResource=..flat(..g(resourceValue,"resource"),"_",tQueryConfig)
            Set tResourceURL = ..g(resourceValue,"fullUrl")
            If tResourceURL'="" {
                Set tKey = ..g(resourceValue,"resource.resourceType")_"."_..g(resourceValue,"resource.resourceType")_"/"_..g(resourceValue,"resource.id")
                Do ..s(tResult,tKey,tFlatResource)
                Do ..s(tResult,tKey_".fullURL",tResourceURL)
                Do ..s(tResult,tKey_".searchMode",..g(resourceValue,"search.mode"))
                If tDevMode = 1 {
                    Set tFormatter = ##class(%JSON.Formatter).%New(),jsonString=""
                    Do tFormatter.FormatToString(resourceValue.%ToJSON(),.jsonString)
                    Do ..s(tResult,tKey_".rawdata",jsonString)
                }
            } 
        }
    }
    If tResult.%Get("Patient")'="" {
        While (..i(tResult,"Patient",.resourceKey,.resourceValue,.tResIt)) {
            If ..g(resourceValue,"nameIdx_0_text","^")'="" Do ..s(resourceValue,"nameIdx_official_text",..g(resourceValue,"nameIdx_0_text","^"))
            If ..g(resourceValue,"nameIdx_0_family","^")'="" Do ..s(resourceValue,"nameIdx_official_family",..g(resourceValue,"nameIdx_0_family","^"))
            If ..g(resourceValue,"nameIdx_0_given_0","^")'="" Do ..s(resourceValue,"nameIdx_official_given_0",..g(resourceValue,"nameIdx_0_given_0","^"))
            If ..g(resourceValue,"nameIdx_official_text","^")="" Do ..s(resourceValue,"nameIdx_official_text",..g(resourceValue,"nameIdx_official_given_0")_" "_..g(resourceValue,"nameIdx_official_family","^"))
        }
    }

    If tResult.%Get("Encounter")'="" {
        While (..i(tResult,"Encounter",.resourceKey,.resourceValue,.tResIt)) {
            If ..g(resourceValue,"identifierIdx_0_value","^")="" Do ..s(resourceValue,"identifierIdx_0_value",..g(resourceValue,"id"))
        }
    }

    If tResult.%Get("DiagnosticReport")'="" {
        While (..i(tResult,"DiagnosticReport",.resourceKey,.resourceValue,.tResIt)) {
            If ..g(resourceValue,"presentedForm_0_data","^")'="",..g(resourceValue,"presentedForm_0_extensionIdx_result-result-type_valueString","^")="IM",..g(resourceValue,"presentedForm_0_title","^")'="" {
                Do ..s(resourceValue,"imageURL",..g(tHeaders,"REQUEST_SCHEME")_"://"_..g(tHeaders,"HTTP_HOST")_$Piece(..g(tHeaders,"REQUEST_URI"),"/fhirr4/",1)_"/fhirr4/image/"_..g(resourceValue,"resourceType")_"/"_..g(resourceValue,"id"))
                If resourceType'="DiagnosticReport" Do ..JRem(resourceValue,"presentedForm_0_data","^")
            }
            If ..g(resourceValue,"result")'="" { 
                Set tFT = ""
                While (..i(resourceValue,"result",.resKey,.resValue,.tResultIt)) {
                    Set tResObj = ..GetResourceByRef(..g(resValue,"reference"),tResult)
                    If ..g(tResObj,"effectiveDateTime","^")="" Do ..s(tResObj,"effectiveDateTime",..g(resourceValue,"issued","^"),,"^")
                    Do ..s(tResObj,"parent_id",..g(resourceValue,"id","^"),,"^")
                    Do ..s(tResObj,"lineOrder",$E("00000",1,5-$length(resKey))_resKey,,"^")
                    Do ..s(tResObj,"parent_code_coding_0_code",..g(resourceValue,"code_coding_0_code","^"),,"^")
                    Do ..s(tResObj,"parent_code_coding_0_display",..g(resourceValue,"code_coding_0_display","^"),,"^")
                    If ..g(tResObj,"extensionIdx_lab-result-item-observation-value-type_valueString","^")="FT" {
                        Set tFT = tFT_..g(tResObj,"valueString","^")
                    }
                    Do ..s(tResult,"DiagnosticReport."_resourceKey_".result."_resKey,tResObj)
                    If ..g(tResObj,"extensionIdx_lab-result-item-observation-value-type_valueString","^")="FT",resKey>0 {
                        Do ..JRem(tResult,"DiagnosticReport."_resourceKey_".result."_resKey)
                    }
                }
                // Group pieces of text on first result and anulate others
                If tFT'="" {
                    Do ..s(resourceValue,"resultFT",tFT)
                    Do ..s(tResult,"DiagnosticReport."_resourceKey_".result.0.extensionIdx_lab-result-item-observation-value-type_valueString","ST")
                    Do ..s(tResult,"DiagnosticReport."_resourceKey_".result.0.valueString","Result")
                }
            }
        }
    } 
    If tResult.%Get("DocumentReference")'="" {
        Set resourceKey=""
        While (..i(tResult,"DocumentReference",.resourceKey,.resourceValue,.tResourceIt)) {
            Set tEncValue = ..g(resourceValue,"content_0_attachment_data","^")
            If tEncValue'="" {
                If ..g(resourceValue,"content_0_attachment_contentType","^")="application/pdf" {
                    Do ..s(resourceValue,"docURL",..g(tHeaders,"REQUEST_SCHEME")_"://"_..g(tHeaders,"HTTP_HOST")_"/acme/fhirr4/doc/"_..g(resourceValue,"resourceType")_"/"_..g(resourceValue,"id")_".pdf")
                    If resourceType'="DocumentReference" Do ..r(resourceValue,"content_0_attachment_data","^")
                } Else {
                    Do ..s(tResult,"DocumentReference^"_resourceKey_"^content_0_attachment_data",$SYSTEM.Encryption.Base64Decode(tEncValue),,"^")
                }
            } Else {
                If ..g(resourceValue,"content_0_attachment_url","^")'="" {
                    Do ..s(resourceValue,"docURL",..g(tHeaders,"REQUEST_SCHEME")_"://"_..g(tHeaders,"HTTP_HOST")_"/acme/fhirr4/doc/"_..g(resourceValue,"resourceType")_"/"_..g(resourceValue,"id"))
                }
            }
        }
    }

    If tResult.%Get("Condition")'="" {
        Set resourceKey=""
        While (..i(tResult,"Condition",.resourceKey,.resourceValue,.tResourceIt)) {
            if ..g(resourceValue,"code_coding_0_code")="" { 
                Do ..s(resourceValue,"code_coding_0_display",..g(resourceValue,"note_0_text"))
                Do ..s(resourceValue,"recordedDate",..g(resourceValue,"onsetDateTime"))
            }
        }
    }
    If tResult.%Get("Observation")'="" {
        Set resourceKey=""
        While (..i(tResult,"Observation",.resourceKey,.resourceValue,.tResourceIt)) {
            If ..g(resourceValue,"valueQuantity_value","^")="", ..g(resourceValue,"valueCodeableConcept_text","^")'="" {
                Do ..s(resourceValue,"valueQuantity_value",..g(resourceValue,"valueCodeableConcept_text"))
            }
            If ..g(resourceValue,"component","^")'="" {
                While (..i(resourceValue,"component",.compKey,.compValue,.tCompIt)) {
                    Do ..s(resourceValue,"componentCount",$Select(..g(resourceValue,"componentCount")'="":..g(resourceValue,"componentCount"),1:0)+1)
                    Do ..s(tResult,"Observation^"_resourceKey_"/"_compKey,compValue,,"^")
                   If ..g(resourceValue,"rawdata")'="" {
                        Do ..s(tResult,"Observation^"_resourceKey_"/"_compKey_"^rawdata",..g(resourceValue,"rawdata"),,"^")
                    }
                    Do ..s(tResult,"Observation^"_resourceKey_"/"_compKey_"^id",$PIECE(resourceKey,"/",2)_"/"_compKey,,"^")
                    Do ..s(tResult,"Observation^"_resourceKey_"/"_compKey_"^category_0_coding_0_code",..g(resourceValue,"category_0_coding_0_code","^"),,"^")
                    Do ..s(tResult,"Observation^"_resourceKey_"/"_compKey_"^effectiveDateTime",..g(resourceValue,"effectiveDateTime","^"),,"^")
                }
            }
        }
    }
    //Put colors on organizations
    Set tColors = ..getColors(200,900)
    If tResult.%Get("Organization")'="" {
        Set tIdx = 0
        Set resourceKey=""
        While (..i(tResult,"Organization",.resourceKey,.resourceValue,.tResourceIt)) {
            Do ..s(resourceValue,"color",tColors.%Get(tIdx))
            Set tIdx=tIdx+1
        }
    }    
    Do ..s(tResult,"id",id)
    Do ..s(tResult,"dtt",$HOROLOG)
    Set tResult = ..referenceDrillDown(tResult,"*")
    Quit tResult
}

ClassMethod GetResourceByRef(refId As %String, Obj As %Library.DynamicObject) As %Library.DynamicObject
{
    Quit ..g(Obj,$PIECE(refId,"/",1)_"."_refId)
}

ClassMethod referenceDrillDown(tFhirData As %Library.DynamicObject, resourceType As %String = "*") As %Library.DynamicObject
{
      While (..i(tFhirData,,.resGrpKey,.resGrpValue,.tResGrpIt)) {
        If resourceType'="*",$FIND(resourceType,resGrpKey)=0 Continue
        While (..i(resGrpValue,,.resItemKey,.resItemValue,.tResItemIt)) {
            While (..i(resItemValue,,.resPropKey,.resPropValue,.tResPropIt)) {
                If $PIECE(resPropKey,"_",*)="reference",..g(resItemValue,$PIECE(resPropKey,"_",1,*-1)_"_id","^")="",'($ISOBJECT(resPropValue)),$FIND(resPropValue,"Patient/")=0 {
                    Set tRefObj = ..g(tFhirData,$PIECE(resPropValue,"/",1)_"^"_resPropValue,"^")
                    If $ISOBJECT(tRefObj) {
                        While (..i(tRefObj,,.resRefKey,.resRefValue,.tResRefIt)) {
                           If $FIND(resPropValue,"Encounter/"),$FIND(resRefKey,"encounter-number")=0 Continue
                           If '($ISOBJECT(resRefValue)) Do ..s(resItemValue,$PIECE(resPropKey,"_",1,*-1)_"_"_resRefKey,resRefValue,,"^")
                        }
                    }
                }
            }
        }
      }
      Return tFhirData
}

ClassMethod getDemographicsModel(objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject) As %Status
{
    Set tPatient = ..getJSONContent("demogPatientModel")
    Do ..s(model,"Patient",tPatient,,"^")    
    If ..g(fhirdata,"Patient.Patient/"_objid_".identifier")'="" {
        Set tPatientIdentifier = ..getJSONContent("demogIdentModel")
        Do ..s(model,"PatientIdentifier",tPatientIdentifier,,"^")
    }
    If ..g(fhirdata,"Patient.Patient/"_objid_".telecom")'="" {
        Set tPatientTelecom = ..getJSONContent("demogTelecomModel")
        Do ..s(model,"PatientTelecom",tPatientTelecom,,"^")
    }
    Quit $$$OK
}

ClassMethod getAllergyModel(objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject) As %Status
{

    Set tAllergy = ..getJSONContent("allergyModel")
    Do ..s(model,"Allergy",tAllergy,,"^")
    Quit $$$OK
}

ClassMethod getMedicationModel(objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject) As %Status
{
    Set tMedication = ..getJSONContent("medicationModel")
    Do ..s(model,"Medication",tMedication,,"^")
    Quit $$$OK
}

ClassMethod getMedicationReqModel(objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject) As %Status
{

    Set tMedication = ..getJSONContent("medicationReqModel")
    Do ..s(model,"MedicationRequest",tMedication,,"^")
    Quit $$$OK
}

ClassMethod getLabDiagnosticReportModel(objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject) As %Status
{
    Set tDiagnosticReport = ..getJSONContent("labDiagnosticReportModel")
    Do ..s(model,"DiagnosticReport",tDiagnosticReport,,"^")
    Quit $$$OK
}

ClassMethod getRadDiagnosticReportModel(objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject) As %Status
{
        Set tDiagnosticReport = ..getJSONContent("radDiagnosticReportModel")
    Do ..s(model,"DiagnosticReport",tDiagnosticReport,,"^")
    Quit $$$OK
}

ClassMethod getConditionModel(objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject) As %Status
{
    Set tCondition = ..getJSONContent("conditionModel")
    Do ..s(model,"Condition",tCondition,,"^")
    Quit $$$OK
}

ClassMethod getImmunizationModel(objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject) As %Status
{
    Set tImmunization = ..getJSONContent("immunizationModel")
    Do ..s(model,"Immunization",tImmunization,,"^")
    Quit $$$OK
}

ClassMethod getProcedureModel(objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject) As %Status
{
    Set tCondition = ..getJSONContent("procedureModel")
    Do ..s(model,"Procedure",tCondition,,"^")
    Quit $$$OK
}

ClassMethod getSummaryModel(userid, objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject, containers As %Library.DynamicObject, forms As %Library.DynamicObject, calendarButtons As %Library.DynamicObject, locale As %String, dateftr, encid, hlid, functions As %Library.DynamicObject, origfhirdata As %Library.DynamicObject) As %Status
{
    Set tEncounterFilter = $Replace("fn:context.router.navigate(['/acme/fhirr4/patientData/"_objid_"/summary'],{queryParams: {"_$Select(dateftr'="":",'dateftr':'"_dateftr_"'",1:"")_",'encid':(item['id'])"_$Select(hlid'="":",'hlid':'"_hlid_"'",1:"")_"}});","{,","{")
    Set tSummary = ..getJSONContent("summaryModel")
    Set tSummary = {}.%FromJSON($Replace(tSummary.%ToJSON(),"<encounterFilter>",tEncounterFilter))

    Set tContainers = {}
    Set tForms = {}
    Do ..buildFEFromModel(userid, {"Summary":(tSummary)},fhirdata,tContainers,tForms,data)
    Do ..addFormDialog(userid, containers,forms,"Summary","Encounter Details")
    Do ..s(containers,"IASummary",##class(acme.fhirr4.openai).getSummaryForm(objid,0,origfhirdata,data,dateftr,encid,hlid))
    Do ..s(containers,"Summary",..g(tContainers,"Summary"),,"^")
    Do ..s(forms,"Summary",..g(tForms,"Summary"),,"^")
    Set (tStartDate,tStartDateH) = ""
    Set tEvents = []
    While (..i(data,"Encounter",.encKey,.encValue,.tEncIt)) {
        Set tEvent = {
            "id": (..g(encValue,"id")),
    		"encounterNumber": (..g(encValue,"identifierIdx_0_value")),
    		"title": (..g(encValue,"serviceProvider_name")),
    		"start": (..g(encValue,"period_start")),
			  "end": (..g(encValue,"period_end")),
            "location": (..g(encValue,"serviceProvider_name")_$SELECT(..g(encValue,"hospitalization_admitSource_coding_0_display")'="":" - "_..g(encValue,"hospitalization_admitSource_coding_0_display"),1:"")),
			  "description": (..g(encValue,"class_code")_" "_..g(encValue,"hospitalization_admitSource_coding_0_display")),
            "backgroundColor": ("var("_..g(encValue,"serviceProvider_color")_")"),
            "borderColor":  ("var("_..g(encValue,"serviceProvider_color")_")"),
            "textColor": "#212121"
        }
        If (tStartDate="") Set tStartDate = ..g(encValue,"period_start")
        Do tEvents.%Push(tEvent)
    }
    Set tEncounterDrillDown = "fn:"_
        "let encId = item['id'];"_
        "editItem = data['Encounter'].filter(itm => {return (itm['id']===String(encId));})[0];"_$CHAR(10,13)_
        "context.setFormItem('Summary', editItem);context.setFormItem('SummaryJSON', editItem);context.containerData['SummaryDial']['dialog']['visible']=true;"

    //cards
    Do ..s(containers,"Summary^layout^value","grid",,"^")
    Do ..s(containers,"Summary^layout^a","col-12 md:col-6 xl:col-3",,"^")
    Do ..s(containers,"Summary^layout^a.a","c:card1",,"^")
    Do ..s(containers,"Summary^layout^b","col-12 md:col-6 xl:col-3",,"^")
    Do ..s(containers,"Summary^layout^b.a","c:card2",,"^")
    Do ..s(containers,"Summary^layout^c","col-12 md:col-6 xl:col-3",,"^")
    Do ..s(containers,"Summary^layout^c.a","c:card3",,"^")
    Do ..s(containers,"Summary^layout^d","col-12 md:col-6 xl:col-3",,"^")
    Do ..s(containers,"Summary^layout^d.a","c:card4",,"^")

    Set tConditions = ..g(fhirdata,"@Count.Resource.Condition")
    Set tConditionsDate=""
    If tConditions="" Set tConditions = 0  
    If tConditions>0 Set tConditionsDate = ..g(..top(..g(fhirdata,"Condition"),1),"0.recordedDate")
    Do ..s(containers,"Summary^card1",..getSummaryCard("card1","Conditions",tConditions,"Last ",tConditionsDate,"pi pi-calendar","p-button-raised p-button-secondary",objid,"condition",$SELECT(tConditions=0:1,1:0),dateftr,encid,hlid),,"^")

    Set tAllergies = ..g(fhirdata,"@Count.Resource.AllergyIntolerance")
    Set tAllergiesDate=""
    If tAllergies="" Set tAllergies = 0
    If tAllergies>0 Set tAllergiesDate = ..g(..top(..g(fhirdata,"AllergyIntolerance"),1),"0.extensionIdx_allergy-discovery-time_valueDateTime")
    Do ..s(containers,"Summary^card2",..getSummaryCard("card2","Allergies",tAllergies,"Last ",tAllergiesDate,"pi pi-calendar","p-button-raised p-button-primary",objid,"allergy",$SELECT(tAllergies=0:1,1:0),dateftr,encid,hlid),,"^")

    Set tLabReports = ..g(fhirdata,"@Count.Resource.DiagnosticReport@LAB")
    Set tLabReportsDate=""
    If tLabReports>0 Set tLabReportsDate = ..g(..top(..filter(..g(fhirdata,"DiagnosticReport"),"..g(value,""category_0_coding_0_code"")=""LAB"""),1),"0.issued")
    If tLabReports="" Set tLabReports = 0
    Do ..s(containers,"Summary^card3",..getSummaryCard("card3","Lab. Results",tLabReports,"Last ",tLabReportsDate,"pi pi-calendar","p-button-raised p-button-warning",objid,"labresults",$SELECT(tLabReports=0:1,1:0),dateftr,encid,hlid),,"^")

    Set tRadReports = ..g(fhirdata,"@Count.Resource.DiagnosticReport@RAD")
    Set tRadReportsDate=""
    If tLabReports>0 Set tRadReportsDate = ..g(..top(..filter(..g(fhirdata,"DiagnosticReport"),"..g(value,""category_0_coding_0_code"")=""RAD"""),1),"0.issued")
    If tRadReports="" Set tRadReports = 0
    Do ..s(containers,"Summary^card4",..getSummaryCard("card4","Rad. Results",tRadReports,"Last ",tRadReportsDate,"pi pi-calendar","p-button-raised p-button-success",objid,"radresults",$SELECT(tRadReports=0:1,1:0),dateftr,encid,hlid),,"^")
    Do ..s(containers,"Summary^layout^e","col-12 md:col-12 xl:col-6",,"^")
    Do ..s(containers,"Summary^layout^e.a","card",,"^")
    Do ..s(containers,"Summary^layout^e.a.a","c:table",,"^")
    Set tCalendar = {
            "type":"fullcalendar",
            "onEventClick":(tEncounterDrillDown),
            "onDateSelect":"fn:console.log(item,event);",
            "calendarOptions": {
                "height": 500,
                "initialDate":($SELECT(tStartDate'="":tStartDate,1:$PIECE($ZDATETIME($HOROLOG,3)," ",1))),
                "headerToolbar": {
                    "left": "prev,next today",
                    "center": "title",
                    "right": "dayGridMonth,timeGridWeek,timeGridDay"
                },
                "editable": true,
                "selectable": true,
                "selectMirror": true,
                "dayMaxEvents": true,
                "locales": [ { "code": (locale) }],
                "events":(tEvents)
             }                   
        }
    //calendar
    If calendarButtons'="" Do ..s(tCalendar,"calendarOptions.buttonText",calendarButtons)
    Do ..s(containers,"Summary.calendar",tCalendar)
    Do ..s(containers,"Summary^layout^f","col-12 md:col-12 xl:col-6",,"^")
    Do ..s(containers,"Summary^layout^f.a","card",,"^")
    Do ..s(containers,"Summary^layout^f.a.a","c:calendar",,"^")
    Quit $$$OK
}

ClassMethod getSummaryCard(name, title, contentNumber, subtitleContent, subtitleDate, subtitleIcon, btnClass, patId, navTo, btnEnabled = 1, dateftr, encid, hlid) As %DynamicObject
{
    Set tQueryParams = {"queryParams":{}}
    If dateftr'="" Do ..s(tQueryParams,"queryParams.dateftr",dateftr)
    If encid'="" Do ..s(tQueryParams,"queryParams.encid",encid)
    If hlid'="" Do ..s(tQueryParams,"queryParams.hlid",hlid)
    If '$DATA(onClick) Set onClick=""
    Set tCard = {}
    // card component
    Do ..s(tCard,"layout^value","card h-full",,"^")
    Do ..s(tCard,"layout^a","c:"_name_".title",,"^")
    Do ..s(tCard,"layout^b","flex justify-content-between align-items-start mt-3",,"^")
    Do ..s(tCard,"layout^b.a","w-7",,"^")
    Do ..s(tCard,"layout^b.a.a","c:"_name_".number",,"^")
    Do ..s(tCard,"layout^b.a.b","text-green-500",,"^")
    Do ..s(tCard,"layout^b.a.b.a","c:"_name_".desc1",,"^")
    Do ..s(tCard,"layout^b.a.b.b","c:"_name_".desc2",,"^")
    Do ..s(tCard,"layout^b.a.b.c","c:"_name_".icon",,"^")
    Do ..s(tCard,"layout^b.b","w-5",,"^")
    Do ..s(tCard,"layout^b.b.a","c:"_name_".button",,"^")
    Do ..s(tCard,"button^type","button",,"^")
    Do ..s(tCard,"button^icon","pi pi-search",,"^")
    Do ..s(tCard,"button^class",btnClass,,"^")
    Do ..s(tCard,"button^label","show",,"^")
    Do ..s(tCard,"button^disabled","fn:return "_btnEnabled_";",,"^")
    Do ..s(tCard,"button^onClick","fn:context.router.navigate(['/acme/fhirr4/patientData/"_patId_"/"_navTo_"'],"_$Replace(tQueryParams.%ToJSON(),"""","'")_");",,"^")
    Do ..s(tCard,"title^type","span",,"^")
    Do ..s(tCard,"title^class","font-semibold text-lg",,"^")
    Do ..s(tCard,"title^content",title,,"^")
    Do ..s(tCard,"number^type","span",,"^")
    Do ..s(tCard,"number^class","text-4xl font-bold text-900",,"^")
    Do ..s(tCard,"number^content",contentNumber,,"^")
    Do ..s(tCard,"desc1^type","span",,"^")
    Do ..s(tCard,"desc1^class","font-medium",,"^")
    Do ..s(tCard,"desc1^content",subtitleContent,,"^")
    Do ..s(tCard,"desc2^type","span",,"^")
    Do ..s(tCard,"desc2^class","font-medium",,"^")
    Do ..s(tCard,"desc2^content",subtitleDate,,"^")
    Do ..s(tCard,"desc2^contentDateFormat","global_dateFormat2",,"^")
    Do ..s(tCard,"icon^type","span",,"^")
    Do ..s(tCard,"icon^class",subtitleIcon_" text-xs ml-2",,"^")
    Quit tCard
}

ClassMethod getAppointmentModel(userid, objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject, containers As %Library.DynamicObject, forms As %Library.DynamicObject, calendarButtons As %Library.DynamicObject, locale As %String) As %Status
{
    Set tAppointment = ..getJSONContent("appointmentModel")
    Set tContainers = {}
    Set tForms = {}
    Do ..buildFEFromModel(userid,{"Appointment":(tAppointment)},fhirdata,tContainers,tForms,data)
    Do ..addFormDialog(userid, containers,forms,"Appointment","Appointment Details")
    Do ..s(containers,"Appointment",..g(tContainers,"Appointment"),,"^")
    Do ..s(forms,"Appointment",..g(tForms,"Appointment"),,"^")
    Set (tStartDate,tStartDateH) = ""
    Set tEvents = []
    While (..i(data,"Appointment",.appKey,.appValue,.tAppIt)) {
        Set tEvent = {
            "id": (..g(appValue,"id")),
    		    "appointmentNumber": (..g(appValue,"identifierIdx_0_value")),
    		    "title": (..g(appValue,"serviceType_0_coding_0_display")),
    		    "start": (..g(appValue,"start")),
			      "end": (..g(appValue,"end")),
            "location": (..g(appValue,"serviceType_0_coding_0_display")_$SELECT(..g(appValue,"participantIdx_1_actor_nameIdx_0_text")'="":" - "_..g(appValue,"participantIdx_1_actor_nameIdx_0_text"),1:"")),
			      "description": (..g(appValue,"class_code")_" "_..g(appValue,"hospitalization_admitSource_coding_0_display")),
            "backgroundColor": ("var("_..g(appValue,"participantIdx_2_actor_managingOrganization_color")_")"),
            "borderColor":  ("var("_..g(appValue,"participantIdx_2_actor_managingOrganization_color")_")"),
            "textColor": "#212121"
        }
        If (tStartDateH<+$ZDATETIMEH($TRANSLATE($EXTRACT(..g(appValue,"start"),1,16),"TZ"," "),3)) {
            Set tStartDate = ..g(appValue,"start")
            Set tStartDateH = +$ZDATETIMEH($TRANSLATE($EXTRACT(..g(appValue,"start"),1,16),"TZ"," "),3)
        }
        Do tEvents.%Push(tEvent)
    }
    Set tAppointmentDrillDown = "fn:"_
        "let appId = item['id'];"_
        "editItem = data['Appointment'].filter(itm => {return (itm['id']===String(appId));})[0];"_$CHAR(10,13)_
        "context.setFormItem('Appointment', editItem);context.setFormItem('AppointmentJSON', editItem);context.containerData['AppointmentDial']['dialog']['visible']=true;"

    Set tCalendar = {
        "order":2,
        "layout":{
            "value":"grid",
            "a":"col-12",
            "a.a":"card",
            "a.a.a":"c:calendar"
        },
        "calendar": {
            "type":"fullcalendar",
            "onEventClick":(tAppointmentDrillDown),
            "onDateSelect":"fn:console.log(item,event);",
            "calendarOptions": {
                "height": 450,
                "initialDate":($SELECT(tStartDate'="":tStartDate,1:$PIECE($ZDATETIME($HOROLOG,3)," ",1))),
                "headerToolbar": {
                    "left": "prev,next today",
                    "center": "title",
                    "right": "dayGridMonth,timeGridWeek,timeGridDay"
                },
                "editable": true,
                "selectable": true,
                "selectMirror": true,
                "dayMaxEvents": true,
                "locales": [ { "code": (locale) }],
                "events":(tEvents)
             }                   
        }
    }
    Do ..s(containers,"AppointmentCalendar",tCalendar,,"^")
    If calendarButtons'="" Do ..s(tCalendar,"calendar.calendarOptions.buttonText",calendarButtons)
    Quit $$$OK
}

ClassMethod getEncounterModel(userid, objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject, containers As %Library.DynamicObject, forms As %Library.DynamicObject, calendarButtons As %Library.DynamicObject, locale As %String, dateftr, encid, hlid, id) As %Status
{
    Set tEncounterFilter = $Replace("fn:context.router.navigate(['/acme/fhirr4/patientData/"_objid_"/encounter'],{queryParams: {"_$Select(dateftr'="":",'dateftr':'"_dateftr_"'",1:"")_",'encid':(item['id'])"_$Select(hlid'="":",'hlid':'"_hlid_"'",1:"")_"}});","{,","{")
    Set tEncounter = ..getJSONContent("encounterModel")
    Set tEncounter = {}.%FromJSON($Replace(tEncounter.%ToJSON(),"<encounterFilter>",tEncounterFilter))

    Set tContainers = {}
    Set tForms = {}
    Do ..buildFEFromModel(userid, {"Encounter":(tEncounter)},fhirdata,tContainers,tForms,data,id)
    Do ..addFormDialog(userid, containers,forms,"Encounter","Encounter Details")
    Do ..s(containers,"Encounter",..g(tContainers,"Encounter"),,"^")
    Do ..s(forms,"Encounter",..g(tForms,"Encounter"),,"^")
    Set (tStartDate,tStartDateH) = ""
    Set tEvents = []
    While (..i(data,"Encounter",.encKey,.encValue,.tEncIt)) {
        Set tEvent = {
            "id": (..g(encValue,"id")),
    		"encounterNumber": (..g(encValue,"identifierIdx_0_value")),
    		"title": (..g(encValue,"serviceProvider_name")),
    		"start": (..g(encValue,"period_start")),
			"end": (..g(encValue,"period_end")),
            "location": (..g(encValue,"serviceProvider_name")_$SELECT(..g(encValue,"hospitalization_admitSource_coding_0_display")'="":" - "_..g(encValue,"hospitalization_admitSource_coding_0_display"),1:"")),
			"description": (..g(encValue,"class_code")_" "_..g(encValue,"hospitalization_admitSource_coding_0_display")),
            "backgroundColor": ("var("_..g(encValue,"serviceProvider_color")_")"),
            "borderColor":  ("var("_..g(encValue,"serviceProvider_color")_")"),
            "textColor": "#212121"
        }
        If (tStartDateH<+$ZDATETIMEH($TRANSLATE($EXTRACT(..g(encValue,"period_start"),1,16),"TZ"," "),3)) {
            Set tStartDate = ..g(encValue,"period_start")
            Set tStartDateH = +$ZDATETIMEH($TRANSLATE($EXTRACT(..g(encValue,"period_start"),1,16),"TZ"," "),3)
        }
        Do tEvents.%Push(tEvent)
    }
    Set tEncounterDrillDown = "fn:"_
        "let encId = item['id'];"_
        "editItem = data['Encounter'].filter(itm => {return (itm['id']===String(encId));})[0];"_$CHAR(10,13)_
        "context.setFormItem('Encounter', editItem);context.setFormItem('EncounterJSON', editItem);context.containerData['EncounterDial']['dialog']['visible']=true;"

    Set tCalendar = {
        "order":2,
        "layout":{
            "value":"grid",
            "a":"col-12",
            "a.a":"card",
            "a.a.a":"c:calendar"
        },
        "calendar": {
            "type":"fullcalendar",
            "onEventClick":(tEncounterDrillDown),
            "onDateSelect":"fn:console.log(item,event);",
            "calendarOptions": {
                "height": 450,
                "initialDate":($SELECT(tStartDate'="":tStartDate,1:$PIECE($ZDATETIME($HOROLOG,3)," ",1))),
                "headerToolbar": {
                    "left": "prev,next today",
                    "center": "title",
                    "right": "dayGridMonth,timeGridWeek,timeGridDay"
                },
                "editable": true,
                "selectable": true,
                "selectMirror": true,
                "dayMaxEvents": true,
                "locales": [ { "code": (locale) }],
                "events":(tEvents)
             }                   
        }
    }
    Do ..s(containers,"EncounterCalendar",tCalendar,,"^")
    If calendarButtons'="" Do ..s(tCalendar,"calendar.calendarOptions.buttonText",calendarButtons)
    Quit $$$OK
}

ClassMethod getDocumentReferenceModel(objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject) As %Status
{
    Set tDocumentReference = ..getJSONContent("documentReferenceModel")
    Do ..s(model,"DocumentReference",tDocumentReference,,"^")            
    Quit $$$OK
}

ClassMethod getObservationModel(objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject) As %Status
{
    Set tObservation = ..getJSONContent("observationModel")
    Do ..s(model,"Observation",tObservation,,"^")
    Quit $$$OK
}

ClassMethod buildDocumentReferencePvtForm(userid, containers, forms, objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject, id As %String) As %Status
{
        Set tDocPvt = ..pivotTable(..g(fhirdata,"DocumentReference"),{
            "rows":["type_coding_0_display","category_0_coding_0_code"],
            "rowOrder":1,
            "columns":["content_0_attachment_creation"],
            "colOrder":-1,
            "values":["content_0_attachment_creation","id","ia-hl","filter"]
        },$Select(id'="":"..g(value,""filter"")'=""""",1:"1"),"id")

      If ..g(tDocPvt,"rows").%Size()>0 {
        Set tTarget = "DocumentReferencePvt"
        Set tId = 0
        Set tObj = {}
        Set tDocumentReferencePvt = {}
        Do ..s(tDocumentReferencePvt,"target",tTarget,,"^")
        Do ..s(tDocumentReferencePvt,"tableConfig^showEditButton","false","boolean","^")
        Do ..s(tDocumentReferencePvt,"tableConfig^form","DocumentReference",,"^")
        Do ..s(tDocumentReferencePvt,"tableConfig^caption^label","Clinical Documents",,"^")
        Do ..s(tDocumentReferencePvt,"type_coding_0_display^grid^header","Doc Type",,"^")
        Do ..s(tDocumentReferencePvt,"type_coding_0_display^form^label","Doc Type",,"^")
        Do ..s(tDocumentReferencePvt,"tableConfig^globalFilterFields",["category_0_coding_0_code"],,"^")
        Do ..s(tDocumentReferencePvt,"category_0_coding_0_code^form^label","Category",,"^")
        While (..i(tDocPvt,"rows",.rowKey,.rowValue,.tPvtRowIt)) {
            Set tObj = rowValue
            Set tCount = 1
            While (..i(tDocPvt,"columns",.colKey,.colValue,.tPvtColIt)) {
                If ..g(tObj,colValue,"^")'=""{
                    Set tCol = "Doc "_tCount
                    Do ..s(tDocumentReferencePvt,tCol_"^grid^header",tCol,,"^")
                    Do ..s(tDocumentReferencePvt,tCol_"^grid^dateFormat","global_datetimeFormat2",,"^")
                    Do ..s(tDocumentReferencePvt,tCol_"^grid^type","button",,"^")
                    If ..g(tObj,colValue_"|ia-hl","^")'="" Do ..s(tObj,"ia-hl",1)
                    If ..g(tObj,colValue_"|filter","^")'="" Do ..s(tObj,"filter",1)
                    Set tIcon ="fn:"_
                    "IAHL=item[item['"_tCol_"']+'|ia-hl'];"_
                    "if (IAHL) return 'pi pi-bolt';"_
                    "return '';"
                    Do ..s(tDocumentReferencePvt,tCol_"^grid^icon",tIcon,,"^")
                    Set tbtnStyle ="fn:"_
                    "IAHL=item[item['"_tCol_"']+'|ia-hl'];"_
                    "if (IAHL) return 'p-button-secondary';"_
                    "return 'p-button-outlined p-button-secondary';"
                    Do ..s(tDocumentReferencePvt,tCol_"^grid^class",tbtnStyle,,"^")
                    Set tFunction = "fn:"_
                        "let docId = item[item[control.value]+'|id'];"_
                        "editItem = data['DocumentReference'].filter(itm => {return (itm['id']===String(docId));})[0];"_$CHAR(10,13)_
                        "context.setFormItem('DocumentReference', editItem);context.setFormItem('DocumentReferenceJSON', editItem);context.containerData['DocumentReferenceDial']['dialog']['visible']=true;"
                    Do ..s(tDocumentReferencePvt,tCol_"^grid^onClick",tFunction,,"^")
                    Do ..s(tDocumentReferencePvt,tCol_"^form^label",tCol,,"^")
                    Do ..s(tDocumentReferencePvt,tCol_"^form^type","datetime",,"^")
                    Do ..s(tObj,tCol,..g(tObj,colValue,"^"),,"^")
                    Set tCount = tCount + 1
                }
            }
            Do ..s(fhirdata,tTarget_"^"_tTarget_"/"_..g(tObj,"id"),tObj,,"^")
        }
        Do ..addFormDialog(userid, containers,forms,"DocumentReference","Document Details")
        Do ..s(model,"DocumentReferencePvt",tDocumentReferencePvt,,"^")
      }
    Quit $$$OK
}

ClassMethod buildRadiologyReportPvtForm(userid, containers, forms, objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject, id As %String) As %Status
{
        Set tRadPvt = ..pivotTable(..g(fhirdata,"DiagnosticReport"),{
                "rows":["code_coding_0_display","code_coding_0_code"],
                "rowOrder":1,
                "columns":["issued"],
                "colOrder":-1,
                "values":["issued","id","ia-hl","filter"]
            },"..g(value,""category_0_coding_0_code"")=""RAD"""_$Select(id'="":"&&(..g(value,""filter"")'="""")",1:""),"id")
        If ..g(tRadPvt,"rows").%Size()>0 {
            Set tTarget = "RadiologyReportPvt"
            Set tRadiologyReportPvt = {}
            Set tId = 0
            Set tObj = {}
            Do ..s(tRadiologyReportPvt,"target",tTarget,,"^")
            Do ..s(tRadiologyReportPvt,"tableConfig^showEditButton","false","boolean","^")
            Do ..s(tRadiologyReportPvt,"tableConfig^caption^label","Radiology Results","","^")
            Do ..s(tRadiologyReportPvt,"tableConfig^form","DiagnosticReport","","^")
            Do ..s(tRadiologyReportPvt,"tableConfig^globalFilterFields",["code_coding_0_display"],,"^")
            Do ..s(tRadiologyReportPvt,"code_coding_0_display^grid^header","Test Description",,"^")
            Do ..s(tRadiologyReportPvt,"code_coding_0_display^form^label","Test Description",,"^")
            While (..i(tRadPvt,"rows",.rowKey,.rowValue,.tPvtRowIt)) {
                Set tObj = rowValue
                Set tCount = 1
                While (..i(tRadPvt,"columns",.colKey,.colValue,.tPvtColIt)) {
                    If ..g(tObj,colValue,"^")'=""{
                        Set tCol = "Doc "_tCount
                        Do ..s(tRadiologyReportPvt,tCol_"^grid^header",tCol,,"^")
                        Do ..s(tRadiologyReportPvt,tCol_"^grid^dateFormat","global_datetimeFormat2",,"^")
                        Do ..s(tRadiologyReportPvt,tCol_"^grid^type","button",,"^")
                        If ..g(tObj,colValue_"|ia-hl","^")'="" Do ..s(tObj,"ia-hl",1)
                        If ..g(tObj,colValue_"|filter","^")'="" Do ..s(tObj,"filter",1)
                        Set tIcon ="fn:"_
                        "IAHL=item[item['"_tCol_"']+'|ia-hl'];"_
                        "if (IAHL) return 'pi pi-bolt';"_
                        "return '';"
                        Do ..s(tRadiologyReportPvt,tCol_"^grid^icon",tIcon,,"^")
                        Set tbtnStyle ="fn:"_
                        "IAHL=item[item['"_tCol_"']+'|ia-hl'];"_
                        "if (IAHL) return 'p-button-secondary';"_
                        "return 'p-button-outlined p-button-secondary';"
                        Do ..s(tRadiologyReportPvt,tCol_"^grid^class",tbtnStyle,,"^")
                        Set tFunction = "fn:"_
                            "let radId = item[item[control.value]+'|id'];"_
                            "editItem = data['DiagnosticReport'].filter(itm => {return (itm['id']===String(radId));})[0];"_$CHAR(10,13)_
                            "context.setFormItem('DiagnosticReport', editItem);context.setFormItem('DiagnosticReportJSON', editItem);context.containerData['DiagnosticReportDial']['dialog']['visible']=true;"
                        Do ..s(tRadiologyReportPvt,tCol_"^grid^onClick",tFunction,,"^")
                        Do ..s(tRadiologyReportPvt,tCol_"^form^label",tCol,,"^")
                        Do ..s(tRadiologyReportPvt,tCol_"^form^type","datetime",,"^")
                        Do ..s(tObj,tCol,..g(tObj,colValue,"^"),,"^")
                        Set tCount = tCount + 1
                    }
                }
                Do ..s(fhirdata,tTarget_"^"_tTarget_"/"_..g(tObj,"id"),tObj,,"^")
            }
            Do ..addFormDialog(userid, containers,forms,"DiagnosticReport","Diagnostic Report Details")
            Do ..s(model,"RadiologyReportPvt",tRadiologyReportPvt,,"^")
        }
    Quit $$$OK
}

ClassMethod buildLaboratoryReportPvtModel(userid, containers, forms, objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject, id As %String) As %Status
{
        Set tLabPvt = ..pivotTable(..g(fhirdata,"DiagnosticReport"),{
                "rows":["code_coding_0_display","code_coding_0_code"],
                "rowOrder":1,
                "columns":["issued"],
                "colOrder":-1,
                "values":["issued","id","ia-hl","filter"]
            },"..g(value,""category_0_coding_0_code"")=""LAB"""_$Select(id'="":"&&(..g(value,""filter"")'="""")",1:""),"id")
        If ..g(tLabPvt,"rows").%Size()>0 {
            Set tTarget = "LaboratoryReportPvt"
            Set tLaboratoryReportPvt = {}
            Set tId = 0
            Set tObj = {}
            Do ..s(tLaboratoryReportPvt,"target",tTarget,,"^")
            Do ..s(tLaboratoryReportPvt,"tableConfig^showEditButton","false","boolean","^")
            Do ..s(tLaboratoryReportPvt,"tableConfig^caption.label","Lab. Results",,"^")
            Do ..s(tLaboratoryReportPvt,"tableConfig^form","DiagnosticReport","","^")
            Do ..s(tLaboratoryReportPvt,"tableConfig^onRowSelect",
                                            "fn:data['DiagnosticResultPvtFtr']=data['DiagnosticResultPvt'].filter((itm) => {return (itm['parent_code_coding_0_code']===item['code_coding_0_code'])});"_
                                            "data['LaboratoryReportPvtFtr']=data['LaboratoryReportPvt'].filter((itm) => {return (itm['code_coding_0_code']===item['code_coding_0_code'])});"_
                                            "context.containerData['DiagnosticResultPvt']['table']['value']='DiagnosticResultPvtFtr';"_
                                            "context.containerData['LaboratoryReportPvt']['table']['value']='LaboratoryReportPvtFtr';",,"^")
            Do ..s(tLaboratoryReportPvt,"tableConfig^onRowUnselect",
                                            "fn:context.containerData['DiagnosticResultPvt']['table']['value']='DiagnosticResultPvt';"_
                                            "context.containerData['LaboratoryReportPvt']['table']['value']='LaboratoryReportPvt';",,"^")
            Do ..s(tLaboratoryReportPvt,"tableConfig^selectionTarget","selectedItem",,"^")
            Do ..s(data,"selectedItem",{})
            Do ..s(tLaboratoryReportPvt,"tableConfig^selectionMode","single",,"^")
            Do ..s(tLaboratoryReportPvt,"tableConfig^globalFilterFields",["code_coding_0_display"],,"^")
            Do ..s(tLaboratoryReportPvt,"code_coding_0_display^grid^header","Test Description",,"^")
            Do ..s(tLaboratoryReportPvt,"code_coding_0_display^form^label","Test Description",,"^")
            While (..i(tLabPvt,"rows",.rowKey,.rowValue,.tPvtRowIt)) {
                Set tObj = rowValue
                Set tCount = 1
                While (..i(tLabPvt,"columns",.colKey,.colValue,.tPvtColIt)) {
                    If ..g(tObj,colValue,"^")'=""{
                        Set tCol = "Result "_tCount
                        Do ..s(tLaboratoryReportPvt,tCol_"^grid^header",tCol,,"^")
                        Do ..s(tLaboratoryReportPvt,tCol_"^grid^dateFormat","global_datetimeFormat2",,"^")
                        Do ..s(tLaboratoryReportPvt,tCol_"^grid^type","button",,"^")
                        If ..g(tObj,colValue_"|ia-hl","^")'="" Do ..s(tObj,"ia-hl",1)
                        If ..g(tObj,colValue_"|filter","^")'="" Do ..s(tObj,"filter",1)
                        Set tIcon ="fn:"_
                        "IAHL=item[item['"_tCol_"']+'|ia-hl'];"_
                        "if (IAHL) return 'pi pi-bolt';"_
                        "return '';"
                        Do ..s(tLaboratoryReportPvt,tCol_"^grid^icon",tIcon,,"^")
                        Set tbtnStyle ="fn:"_
                        "IAHL=item[item['"_tCol_"']+'|ia-hl'];"_
                        "if (IAHL) return 'p-button-secondary';"_
                        "return 'p-button-outlined p-button-secondary';"
                        Do ..s(tLaboratoryReportPvt,tCol_"^grid^class",tbtnStyle,,"^")
                        Set tFunction = "fn:"_
                            "let labId = item[item[control.value]+'|id'];"_$CHAR(10,13)_
                            "let parentCode = item['code_coding_0_code'];"_$CHAR(10,13)_
                            "editItem = data['DiagnosticReport'].filter(itm => {return (itm['id']===String(labId));})[0];"_$CHAR(10,13)_
                            "context.setFormItem('DiagnosticReport', editItem);context.setFormItem('DiagnosticReportJSON', editItem);context.containerData['DiagnosticReportDial']['dialog']['visible']=true;"
                        Do ..s(tLaboratoryReportPvt,tCol_"^grid^onClick",tFunction,,"^")
                        Do ..s(tLaboratoryReportPvt,tCol_"^form^label",tCol,,"^")
                        Do ..s(tLaboratoryReportPvt,tCol_"^form^type","datetime",,"^")
                        Do ..s(tObj,tCol,..g(tObj,colValue,"^"),,"^")
                        Set tCount = tCount + 1
                    }
                }
                Do ..s(fhirdata,tTarget_"^"_tTarget_"/"_..g(tObj,"id"),tObj,,"^")
            }
            Do ..addFormDialog(userid, containers,forms,"DiagnosticReport","DiagnosticReport Details")
            Do ..s(model,"LaboratoryReportPvt",tLaboratoryReportPvt,,"^")
        }
    Quit $$$OK
}

ClassMethod buildSurveyPvtForm(userid, containers, forms, objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject, id As %String) As %Status
{
      Set tSurObsPvt = ..pivotTable(..g(fhirdata,"Observation"),{
                "rows":["code_coding_0_display","extensionIdx_observation-observation-value-type_valueString"],
                "rowOrder":1,
                "columns":["effectiveDateTime"],
                "colOrder":-1,
                "values":["valueQuantity_value","id","ia-hl","filter"]
            },"(..g(value,""category_0_coding_0_code"")=""survey"")&&(..g(value,""valueQuantity_value"")'="""")"_$Select(id'="":"&&(..g(value,""filter"")'="""")",1:""),"id")
      If ..g(tSurObsPvt,"rows").%Size()>0 {
        Set tTarget = "SurveyPvt"
        Set tSurveyPvt = {}
        Set tId = 0
        Set tObj = {}
        Do ..s(tSurveyPvt,"target",tTarget,,"^")
        Do ..s(tSurveyPvt,"tableConfig^styleClass","p-datatable-gridlines",,"^")
        Do ..s(tSurveyPvt,"tableConfig^caption.label","Survey",,"^")
        Do ..s(tSurveyPvt,"tableConfig^form","Observation",,"^")
        Do ..s(tSurveyPvt,"tableConfig^showEditButton","false","boolean","^")
        Do ..s(tSurveyPvt,"tableConfig^globalFilterFields",["code_coding_0_display"],,"^")
        Do ..s(data,"styles^item-badge^border-radius","var(--border-radius)",,"^")
        Do ..s(data,"styles^item-badge^padding","0.25em 0.5rem",,"^")
        Do ..s(data,"styles^item-badge^text-transform","uppercase",,"^")
        Do ..s(data,"styles^item-badge^font-weight","700",,"^")
        Do ..s(data,"styles^item-badge^font-size","13px",,"^")
        Do ..s(data,"styles^item-badge^letter-spacing","0.3px",,"^")
        Do ..s(tSurveyPvt,"chartBtn^grid^header","Chart",,"^")
        Do ..s(tSurveyPvt,"chartBtn^grid^type","button",,"^")
        Do ..s(tSurveyPvt,"chartBtn^grid^buttonType","button",,"^")
        Do ..s(tSurveyPvt,"chartBtn^grid^icon","pi pi-chart-bar",,"^")
        Do ..s(tSurveyPvt,"chartBtn^grid^class","p-button-rounded p-button-outlined",,"^")
        Do ..s(tSurveyPvt,"chartBtn^grid^coupled","false","boolean","^")
        Set tFunction = "fn:data['chartOptions']['scales']['y']=item['chartOptions']['scales']['y'];data['chart']=item['chart'];containerData['CumulativeChart']['dialog']['visible']=true;"
        Do ..s(tSurveyPvt,"chartBtn^grid^onClick",tFunction,,"^")
        Do ..s(tSurveyPvt,"chartBtn^grid^disabled","fn:return item.chartDisabled;",,"^")
        Do ..s(tSurveyPvt,"code_coding_0_display^grid^header","Survey Item",,"^")
        Do ..s(tSurveyPvt,"code_coding_0_display^form^label","Survey Item",,"^")
        While (..i(tSurObsPvt,"columns",.colKey,.colValue,.tPvtColIt)) {
            Do ..s(tSurveyPvt,colValue_"^grid^header",colValue,,"^")
            Do ..s(tSurveyPvt,colValue_"^grid^headerDateFormat","global_datetimeFormat2",,"^")
            Do ..s(tSurveyPvt,colValue_"^grid^type","button",,"^")
            Do ..s(tSurveyPvt,colValue_"^grid^ngStyle","fn:return data.styles['item-badge']",,"^")
            Set tIcon ="fn:"_
            "IAHL=item['"_colValue_"|ia-hl'];"_
            "if (IAHL) return 'pi pi-bolt';"_
            "return '';"
            Do ..s(tSurveyPvt,colValue_"^grid^icon",tIcon,,"^")
            Set tbtnStyle ="fn:"_
            "IAHL=item['"_colValue_"|ia-hl'];"_
            "if (IAHL) return 'p-button-secondary';"_
            "return 'p-button-text';"
            Do ..s(tSurveyPvt,colValue_"^grid^class",tbtnStyle,,"^")
            Set tFunction = "fn:"_
                "let obsId = item[control.value+'|id'];"_$CHAR(10,13)_
                "editItem = data['Observation'].filter(itm => {return (itm['id']===String(obsId));})[0];"_$CHAR(10,13)_
                "context.setFormItem('Observation', editItem);context.setFormItem('ObservationJSON', editItem);context.containerData['ObservationDial']['dialog']['visible']=true;"
            Do ..s(tSurveyPvt,colValue_"^grid^onClick",tFunction,,"^")
            Do ..s(tSurveyPvt,colValue_"^form^label",colValue,,"^")
            Do ..s(tSurveyPvt,colValue_"^form^labelDateFormat","global_datetimeFormat2",,"^")
        }
        While (..i(tSurObsPvt,"rows",.rowKey,.rowValue,.tPvtRowIt)) {
            Set tObj = rowValue
            Set (tMin,tMax)=""
            Do ..s(tObj,"chartDisabled","true","boolean","^")
            Set tValueObj = ""
            While (..i(tSurObsPvt,"columns",.colKey,.colValue,.tPvtColIt)) {
                If ..g(tObj,colValue_"|ia-hl")'="" Do ..s(tObj,"ia-hl",1)
                If ..g(tObj,colValue_"|filter")'="" Do ..s(tObj,"filter",1)
                Set tValue = ..g(rowValue,colValue,"^")
                If tValue'="" {
                    Do ..s(tObj,"chart^labels^+",$REPLACE($REPLACE(colValue,"T"," "),"Z",""),,"^")
                    If (..g(rowValue,"extensionIdx_observation-observation-value-type_valueString","^")="NM")||(tValue=+tValue) {
                        If tMin=""||tValue<tMin Set tMin = tValue
                        If tMax=""||tValue>tMax Set tMax = tValue
                        Do ..s(rowValue,colValue,tValue,"number","^")
                        Do ..s(tObj,"chartDisabled","false","boolean","^")
                        If tValueObj="" Set tValueObj = {}
                        Do ..s(tValueObj,"data^+",tValue,"number","^")
                        Do ..s(tValueObj,"fill","true","boolean","^")
                        Do ..s(tValueObj,"borderColor","#6723B3",,"^")
                        Do ..s(tValueObj,"label",..g(tObj,"code_coding_0_display","^"),,"^")
                    }
                }
            }
            If tValueObj'="" Do ..s(tObj,"chart^datasets^+",tValueObj,,"^")
            Do ..s(tObj,"chartOptions^scales^y^ticks^min",$NUMBER(tMin,0)-1,"number","^")
            Do ..s(tObj,"chartOptions^scales^y^ticks^max",$NUMBER(tMax,0)+1,"number","^")
            Do ..s(tObj,"chartOptions^scales^y^ticks^stepSize",$NUMBER((tMax-tMin),0)/10,"number","^")
            Do ..s(fhirdata,tTarget_"^"_tTarget_"/"_..g(tObj,"id"),tObj,,"^")
        }
        Do ..s(model,"SurveyPvt",tSurveyPvt,,"^")
      }
    Quit $$$OK
}

ClassMethod buildVitalsPvtForm(userid, containers, forms, objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject, id As %String) As %Status
{
      Set tVitObsPvt = ..pivotTable(..g(fhirdata,"Observation"),{
                "rows":["code_coding_0_code","code_coding_0_display","extensionIdx_observation-observation-value-type_valueString"],
                "rowOrder":1,
                "columns":["effectiveDateTime"],
                "colOrder":-1,
                "values":["valueQuantity_value","id","ia-hl","filter"]
            },"(..g(value,""category_0_coding_0_code"")=""vital-signs"")&&(..g(value,""valueQuantity_value"")'="""")"_$Select(id'="":"&&(..g(value,""filter"")'="""")",1:""),"id")
      If ..g(tVitObsPvt,"rows").%Size()>0 {
        Set tTarget = "VitalsPvt"
        Set tVitalsPvt = {}
        Set tId = 0
        Set tObj = {}
        Do ..s(tVitalsPvt,"target",tTarget,,"^")
        Do ..s(tVitalsPvt,"tableConfig^styleClass","p-datatable-gridlines",,"^")
        Do ..s(tVitalsPvt,"tableConfig^caption.label","Vital Signs",,"^")
        Do ..s(tVitalsPvt,"tableConfig^form","Observation",,"^")
        Do ..s(tVitalsPvt,"tableConfig^globalFilterFields",["code_coding_0_display"],,"^")
        Do ..s(tVitalsPvt,"tableConfig^showEditButton","false","boolean","^")
        Do ..s(data,"styles^item-badge^border-radius","var(--border-radius)",,"^")
        Do ..s(data,"styles^item-badge^padding","0.25em 0.5rem",,"^")
        Do ..s(data,"styles^item-badge^text-transform","uppercase",,"^")
        Do ..s(data,"styles^item-badge^font-weight","700",,"^")
        Do ..s(data,"styles^item-badge^font-size","13px",,"^")
        Do ..s(data,"styles^item-badge^letter-spacing","0.3px",,"^")
        Do ..s(tVitalsPvt,"chartBtn^grid^header","Chart",,"^")
        Do ..s(tVitalsPvt,"chartBtn^grid^type","button",,"^")
        Do ..s(tVitalsPvt,"chartBtn^grid^buttonType","button",,"^")
        Do ..s(tVitalsPvt,"chartBtn^grid^icon","pi pi-chart-bar",,"^")
        Do ..s(tVitalsPvt,"chartBtn^grid^class","p-button-rounded p-button-outlined",,"^")
        Do ..s(tVitalsPvt,"chartBtn^grid^coupled","false","boolean","^")
        Set tFunction = "fn:data['chartOptions']['scales']['y']=item['chartOptions']['scales']['y'];data['chart']=item['chart'];containerData['CumulativeChart']['dialog']['visible']=true;"
        Do ..s(tVitalsPvt,"chartBtn^grid^onClick",tFunction,,"^")
        Do ..s(tVitalsPvt,"chartBtn^grid^disabled","fn:return item.chartDisabled;",,"^")
        Do ..s(tVitalsPvt,"code_coding_0_display^grid^header","Vital Sign",,"^")
        Do ..s(tVitalsPvt,"code_coding_0_display^form^label","Vital Sign",,"^")
        While (..i(tVitObsPvt,"columns",.colKey,.colValue,.tPvtColIt)) {
            Do ..s(tVitalsPvt,colValue_"^grid^header",colValue,,"^")
            Do ..s(tVitalsPvt,colValue_"^grid^headerDateFormat","global_datetimeFormat2",,"^")
            Do ..s(tVitalsPvt,colValue_"^grid^type","button",,"^")
            Do ..s(tVitalsPvt,colValue_"^grid^ngStyle","fn:return data.styles['item-badge']",,"^")
            Set tIcon ="fn:"_
            "IAHL=item['"_colValue_"|ia-hl'];"_
            "if (IAHL) return 'pi pi-bolt';"_
            "return '';"
            Do ..s(tVitalsPvt,colValue_"^grid^icon",tIcon,,"^")
            Set tbtnStyle ="fn:"_
            "IAHL=item['"_colValue_"|ia-hl'];"_
            "if (IAHL) return 'p-button-secondary';"_
            "return 'p-button-text';"
            Do ..s(tVitalsPvt,colValue_"^grid^class",tbtnStyle,,"^")
            Set tFunction = "fn:"_
                "let obsId = item[control.value+'|id'];"_$CHAR(10,13)_
                "editItem = data['Observation'].filter(itm => {return (itm['id']===String(obsId));})[0];"_$CHAR(10,13)_
                "context.setFormItem('Observation', editItem);context.setFormItem('ObservationJSON', editItem);context.containerData['ObservationDial']['dialog']['visible']=true;"
            Do ..s(tVitalsPvt,colValue_"^grid^onClick",tFunction,,"^")
            Do ..s(tVitalsPvt,colValue_"^form^label",colValue,,"^")
            Do ..s(tVitalsPvt,colValue_"^form^labelDateFormat","global_datetimeFormat2",,"^")
        }
        While (..i(tVitObsPvt,"rows",.rowKey,.rowValue,.tPvtRowIt)) {
            Set tObj = rowValue
            Set (tMin,tMax)=""
            Do ..s(tObj,"chartDisabled","true","boolean","^")
            Set tValueObj = ""
            While (..i(tVitObsPvt,"columns",.colKey,.colValue,.tPvtColIt)) {
                If ..g(tObj,colValue_"|ia-hl")'="" Do ..s(tObj,"ia-hl",1)
                If ..g(tObj,colValue_"|filter")'="" Do ..s(tObj,"filter",1)
                Set tValue = ..g(rowValue,colValue,"^")
                If tValue'="" {
                    Do ..s(tObj,"chart^labels^+",$REPLACE($REPLACE(colValue,"T"," "),"Z",""),,"^")
                    If (..g(rowValue,"extensionIdx_observation-observation-value-type_valueString","^")="NM")||(tValue=+tValue) {
                        If tMin=""||tValue<tMin Set tMin = tValue
                        If tMax=""||tValue>tMax Set tMax = tValue
                        Do ..s(rowValue,colValue,tValue,"number","^")
                        Do ..s(tObj,"chartDisabled","false","boolean","^")
                        If tValueObj="" Set tValueObj = {}
                        Do ..s(tValueObj,"data^+",tValue,"number","^")
                        Do ..s(tValueObj,"fill","true","boolean","^")
                        Do ..s(tValueObj,"borderColor","#6723B3",,"^")
                        Do ..s(tValueObj,"label",..g(tObj,"code_coding_0_display","^"),,"^")
                    }
                }
            }
            If tValueObj'="" Do ..s(tObj,"chart^datasets^+",tValueObj,,"^")
            Do ..s(tObj,"chartOptions^scales^y^ticks^min",$NUMBER(tMin,0)-1,"number","^")
            Do ..s(tObj,"chartOptions^scales^y^ticks^max",$NUMBER(tMax,0)+1,"number","^")
            Do ..s(tObj,"chartOptions^scales^y^ticks^stepSize",$NUMBER((tMax-tMin),0)/10,"number","^")
            Do ..s(fhirdata,tTarget_"^"_tTarget_"/"_..g(tObj,"id"),tObj,,"^")
        }
        Do ..s(model,"VitalsPvt",tVitalsPvt,,"^")
      }
    Quit $$$OK
}

ClassMethod buildDiagnosticResultPvtModel(containers, forms, objid, subid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, data As %Library.DynamicObject, menu As %Library.DynamicObject, id As %String) As %Status
{
      Set tLabObsPvt = ..pivotTable(..g(fhirdata,"Observation"),{
                "rows":["parent_code_coding_0_code","lineOrder","code_coding_0_display","referenceRange_0_text","valueQuantity_unit","parent_code_coding_0_display","referenceRange_0_low_value","referenceRange_0_high_value","extensionIdx_lab-result-item-observation-value-type_valueString"],
                "rowOrder":1,
                "columns":["effectiveDateTime"],
                "colOrder":-1,
                "values":[("_fn:$Select(..g(value,""valueQuantity_value"")'="""":..g(value,""valueQuantity_value""),1:..g(value,""valueString""))"),"parent_id","id","ia-hl","filter"]
            },"(..g(value,""category_0_coding_0_code"")=""laboratory"")&&(..g(value,""parent_code_coding_0_code"")'="""")&&(..g(value,""extensionIdx_lab-result-item-observation-value-type_valueString"")'=""FT"")"_$Select(id'="":"&&(..g(value,""filter"")'="""")",1:""),"id")

      If ..g(tLabObsPvt,"rows").%Size()>0 {
        Set tTarget = "DiagnosticResultPvt"
        Set tDiagnosticResultPvt = {}
        Set tId = 0
        Set tObj = {}
        Do ..s(tDiagnosticResultPvt,"target",tTarget,,"^")
        Do ..s(tDiagnosticResultPvt,"tableConfig^caption^label","Cumulative Item Results",,"^")
        Do ..s(tDiagnosticResultPvt,"tableConfig^styleClass","p-datatable-gridlines",,"^")
        Do ..s(tDiagnosticResultPvt,"tableConfig^showEditButton","false","boolean","^")
        Do ..s(data,"styles^item-badge^border-radius","var(--border-radius)",,"^")
        Do ..s(data,"styles^item-badge^padding","0.25em 0.5rem",,"^")
        Do ..s(data,"styles^item-badge^text-transform","uppercase",,"^")
        Do ..s(data,"styles^item-badge^font-weight","700",,"^")
        Do ..s(data,"styles^item-badge^font-size","13px",,"^")
        Do ..s(data,"styles^item-badge^letter-spacing","0.3px",,"^")
        //Do ..s(data,"styles^item-badge-normalRef^background","#c8e6c9",,"^")
        //Do ..s(data,"styles^item-badge-normalRef^color","#256029",,"^")
        Do ..s(data,"styles^item-badge-abnormalRef^background","#ffcdd2",,"^")
        Do ..s(data,"styles^item-badge-abnormalRef^color","#c63737",,"^")
        Do ..s(data,"styles^item-badge-neutralRef^background","#feedaf",,"^")
        Do ..s(data,"styles^item-badge-neutralRef^color","#8a5340",,"^")
        Do ..s(tDiagnosticResultPvt,"tableConfig^sortField","parent_code_coding_0_display",,"^")
        Do ..s(tDiagnosticResultPvt,"tableConfig^groupRowsBy","parent_code_coding_0_display",,"^")
        Do ..s(tDiagnosticResultPvt,"tableConfig^rowGroupMode","subheader",,"^")
        //Do ..s(tDiagnosticResultPvt,"tableConfig^scrollable","true","boolean","^")
        //Do ..s(tDiagnosticResultPvt,"tableConfig^scrollHeight","400px",,"^")
        Do ..s(tDiagnosticResultPvt,"tableConfig^globalFilterFields",["parent_code_coding_0_display","code_coding_0_display"],,"^")
        Do ..s(tDiagnosticResultPvt,"chartBtn^grid^header","Chart",,"^")
        Do ..s(tDiagnosticResultPvt,"chartBtn^grid^type","button",,"^")
        Do ..s(tDiagnosticResultPvt,"chartBtn^grid^buttonType","button",,"^")
        Do ..s(tDiagnosticResultPvt,"chartBtn^grid^icon","pi pi-chart-bar",,"^")
        Do ..s(tDiagnosticResultPvt,"chartBtn^grid^class","p-button-rounded p-button-outlined",,"^")
        Do ..s(tDiagnosticResultPvt,"chartBtn^grid^coupled","false","boolean","^")
        Set tFunction = "fn:data['chartOptions']['scales']['y']=item['chartOptions']['scales']['y'];data['chart']=item['chart'];containerData['CumulativeChart']['dialog']['visible']=true;"
        Do ..s(tDiagnosticResultPvt,"chartBtn^grid^onClick",tFunction,,"^")
        Do ..s(tDiagnosticResultPvt,"chartBtn^grid^disabled","fn:return item.chartDisabled;",,"^")
        //Do ..s(tDiagnosticResultPvt,"display^grid^header","Test Desc.",,"^")
        //Do ..s(tDiagnosticResultPvt,"display^grid^searchable",1,,"^")
        Do ..s(tDiagnosticResultPvt,"code_coding_0_display^grid^header","Test Item",,"^")
        Do ..s(tDiagnosticResultPvt,"code_coding_0_display^grid^header","Test Item",,"^")
        Do ..s(tDiagnosticResultPvt,"referenceRange_0_text^grid^header","Ref. Range",,"^")
        Do ..s(tDiagnosticResultPvt,"code_coding_0_display^form^label","Test Item",,"^")
        Do ..s(tDiagnosticResultPvt,"referenceRange_0_text^form^label","Ref. Range",,"^")
        While (..i(tLabObsPvt,"columns",.colKey,.colValue,.tPvtColIt)) {
            Do ..s(tDiagnosticResultPvt,colValue_"^grid^header",colValue,,"^")
            Do ..s(tDiagnosticResultPvt,colValue_"^grid^headerDateFormat","global_datetimeFormat2",,"^")
            Set tFuncStyle ="fn:"_
            "resVal=Number(item['"_colValue_"']);"_
            "lowLimit=Number(item['referenceRange_0_low_value']);"_
            "highLimit=Number(item['referenceRange_0_high_value']);"_
            "itemStyle={...data.styles['item-badge']};"_
            "normalStyle = {...data.styles['item-badge'],...data.styles['item-badge-normalRef']};"_
            "abnormalStyle = {...data.styles['item-badge'],...data.styles['item-badge-abnormalRef']};"_
            "if ((resVal)||(resVal===0)) {"_
            "   if (item['"_colValue_"|ia-hl']!==1) {itemStyle=normalStyle};"_
            "   if (((lowLimit)&&(resVal<lowLimit))||((highLimit)&&(resVal>highLimit))) {"_
            "       if (item['"_colValue_"|ia-hl']!==1) {itemStyle=abnormalStyle};"_
            "   };"_
            "};"_
            "return itemStyle;"
            Do ..s(tDiagnosticResultPvt,colValue_"^grid^ngStyle",tFuncStyle,,"^")
            Do ..s(tDiagnosticResultPvt,colValue_"^grid^type","button",,"^")
            Set tIcon ="fn:"_
            "IAHL=item['"_colValue_"'+'|ia-hl'];"_
            "if (IAHL) return 'pi pi-bolt';"_
            "return '';"
            Do ..s(tDiagnosticResultPvt,colValue_"^grid^icon",tIcon,,"^")
            Set tbtnStyle ="fn:"_
            "IAHL=item['"_colValue_"|ia-hl'];"_
            "if (IAHL) return 'p-button-secondary';"_
            "return 'p-button-text';"
            Do ..s(tDiagnosticResultPvt,colValue_"^grid^class",tbtnStyle,,"^")
            //Do ..s(tDiagnosticResultPvt,colValue_"^grid^class","p-button-outlined p-button-secondary",,"^")
            Set tFunction = "fn:"_
                "let repId = item[control.value+'|parent_id'];"_
                "let obsId = item[control.value+'|id'];"_
                "obsItem = data['DiagnosticReport'].filter(itm => {return (itm['id']===String(repId));})[0]['result'].filter(itm => {return (itm['id']===String(obsId));})[0];"_
                "context.setFormItem('DiagnosticReport', obsItem);context.setFormItem('DiagnosticReportJSON', obsItem);context.containerData['DiagnosticReportDial']['dialog']['visible']=true;"
            Do ..s(tDiagnosticResultPvt,colValue_"^grid^onClick",tFunction,,"^")
            Do ..s(tDiagnosticResultPvt,colValue_"^form^label",colValue,,"^")
            Do ..s(tDiagnosticResultPvt,colValue_"^form^labelDateFormat","global_datetimeFormat2",,"^")
        }
        While (..i(tLabObsPvt,"rows",.rowKey,.rowValue,.tPvtRowIt)) {
            Set tObj = rowValue
            // chart data
            Set (tMin,tMax)=""
            Set tMinValue = ..g(rowValue,"referenceRange_0_low_value","^")
            Set tMaxValue = ..g(rowValue,"referenceRange_0_high_value","^")
            Do ..s(tObj,"chartDisabled","true","boolean","^")
            Set (tMinObj,tMaxObj,tValueObj) = ""
            While (..i(tLabObsPvt,"columns",.colKey,.colValue,.tPvtColIt)) {
                If ..g(tObj,colValue_"|ia-hl","^")'="" Do ..s(tObj,"ia-hl",1)
                If ..g(tObj,colValue_"|filter","^")'="" Do ..s(tObj,"filter",1)
                Set tValue = ..g(rowValue,colValue,"^")
                If tValue'="" {
                    If tMinValue'="" {
                            If tMinObj="" Set tMinObj = {}
                            If tMin=""||tMinValue<tMin Set tMin = tMinValue
                            Do ..s(tMinObj,"data^+",tMinValue,"number","^")
                            Do ..s(tMinObj,"fill","true","boolean","^")
                            Do ..s(tMinObj,"label","min ref. range ( "_tMinValue_" )",,"^")
                            Do ..s(tMinObj,"borderDash",[5, 5],,"^")
                            Do ..s(tMinObj,"backgroundColor","rgba(255,167,38,0.2)",,"^")
                    }
                    If tMaxValue'="" {
                            If tMaxObj="" Set tMaxObj = {}
                            If tMax=""||tMaxValue<tMax Set tMax = tMaxValue
                            Do ..s(tMaxObj,"data^+",tMaxValue,"number","^")
                            Do ..s(tMaxObj,"fill","true","boolean","^")
                            Do ..s(tMaxObj,"label","max ref. range( "_tMaxValue_" )",,"^")
                            Do ..s(tMaxObj,"borderDash",[5, 5],,"^")
                            Do ..s(tMaxObj,"backgroundColor","rgba(255,167,38,0.2)",,"^")
                    }
                    Do ..s(tObj,"chart^labels^+",$REPLACE($REPLACE(colValue,"T"," "),"Z",""),,"^")
                    If (..g(rowValue,"extensionIdx_lab-result-item-observation-value-type_valueString","^")="NM")||(tValue=+tValue) {
                        If tMin=""||tValue<tMin Set tMin = tValue
                        If tMax=""||tValue>tMax Set tMax = tValue
                        Do ..s(rowValue,colValue,tValue,"number","^")
                        Do ..s(tObj,"chartDisabled","false","boolean","^")
                        If tValueObj="" Set tValueObj = {}
                        Do ..s(tValueObj,"data^+",tValue,"number","^")
                        Do ..s(tValueObj,"fill","false","boolean","^")
                        Do ..s(tValueObj,"borderColor","#6723B3",,"^")
                        Do ..s(tValueObj,"label",..g(tObj,"code_coding_0_display","^"),,"^")
                    }
                }
            }
            If tMinObj'="" Do ..s(tObj,"chart^datasets^+",tMinObj,,"^")
            If tValueObj'="" Do ..s(tObj,"chart^datasets^+",tValueObj,,"^")
            If tMaxObj'="" Do ..s(tObj,"chart^datasets^+",tMaxObj,,"^")
            Do ..s(tObj,"chartOptions^scales^y^ticks^min",$NUMBER(tMin,0)-1,"number","^")
            Do ..s(tObj,"chartOptions^scales^y^ticks^max",$NUMBER(tMax,0)+1,"number","^")
            Do ..s(tObj,"chartOptions^scales^y^ticks^stepSize",$NUMBER((tMax-tMin),0)/10,"number","^")
            Do ..s(tObj,"referenceRange_0_text",..g(tObj,"referenceRange_0_text","^")_" "_..g(tObj,"valueQuantity_unit","^"),,"^")
            Do ..s(fhirdata,tTarget_"^"_tTarget_"/"_..g(tObj,"id"),tObj,,"^")
        }
        Do ..s(model,"DiagnosticResultPvt",tDiagnosticResultPvt,,"^")
      }
    Quit $$$OK
}

ClassMethod getIAHighlightsForm(userid, model, containers, forms, data, config, objid, dateftr, encid, hlid, fhirdata, functions) As %Status
{
    Set tSubmitFunc = "if ((control.errors?.pattern) || (control.errors?.required)) return;"_$CHAR(10,13)_
                            "context.backendService.getItems('fhirHighlight',backendItem,'fhirr4').then(beData => {"_$CHAR(10,13)_
                            "context.isLoading=false;"_$CHAR(10,13)_
                            "data['result']=beData;"_$CHAR(10,13)_
                            "if (data['result']) {"_$CHAR(10,13)_
                            "   if (data['result']['id']) {"_$CHAR(10,13)_
                            "       context.messageService.add({"_
                            "           severity: 'success',"_
                            "           summary: context.translateService.instant('IA Service'),"_
                            "           detail: context.translateService.instant('there is a new response'),"_
                            "           life: 2000,"_
                            "       });"_
                            "       context.router.navigate(['/acme/fhirr4/patientData/"_objid_"/iahighlights'],{queryParams: {"_$Select(dateftr'="":"'dateftr':'"_dateftr_"'",1:"")_$Select(encid'="":",'encid':'"_encid_"'",1:"")_",hlid: (data['result']['id'])}});"_
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
                            "    detail: context.translateService.instant('topic submitted to IA Service'),"_
                            "    life: 3000,"_
                            "});"_
                            "context.isLoading=true;"_$CHAR(10,13)_
                            "data['Highlight']['topic']='';"
    Do ..s(functions,"_submitTopic.0","control")
    Do ..s(functions,"_submitTopic.1","context")
    Do ..s(functions,"_submitTopic.2","data")
    Do ..s(functions,"_submitTopic.3","containerControl")
    Do ..s(functions,"_submitTopic.4","backendItem")
    Do ..s(functions,"_submitTopic.5",$Replace(tSubmitFunc,"{,","{"))
    Do ..s(data, "Highlight", {"topic":"","userid":(userid),"objid":(objid)})
    Set tIAList = ..jretrieveList("acme","IA|"_objid,"","")
    Set tIASList=[]
    Set tIATopic = ""
    If ..g(tIAList,"data").%Size() > 0 {
        Do ..s(data, "IAList", ..orderBy(..g(tIAList,"data"),["procDate|-1"])) 
        If hlid'="" {
            Set tItem = ..g(..filter(..g(tIAList,"data"),"..g(value,""id"")="""_hlid_""""),0)
            Set tIASList = ..g(tItem,"responseList")
            Set tIATopic = ..g(tItem,"topic")
            If tIASList.%Size() > 0 {
               Set tIASList = ..getResDataFromList(tIASList,fhirdata)
               Do ..s(data, "IASList", tIASList)
            }
        }
    }
    Set tHL = {
                "order":0,
                "layout":{
                    "value":"grid",
                    "a":"col-12",
                    "a.a":"c:acc",
                    "a.a.a":"c:accTab",
                    "a.a.a.a":"c:highlightForm"
                },
                "acc":{"type":"accordion","active":true},
                "accTab":{"type":"accordionTab","header":"Highlight Patient Data","selected":true},
                "highlightForm":{
                    "type":"form",
                    "form":"Highlight"
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
        "rows": 100,
        "paginator": true,
        "rowHover": true,
        "showEditButton": false,
        "showCurrentPageReport": false,
        "caption": {
          "label": "IA Highlight Results"
        },
        "currentPageReportTemplate": "Showing {first} to {last} of {totalRecords} entries",
        "summary": false,
        "responsiveLayout": "scroll",
        "label": "Hightlight List",
        "ngStyle":"fn:if ((context.queryParams['hlid'])&&(context.queryParams['hlid']==item['id'])) {return {'background':'rgba(0,0,0,.15)'}} else {return {}};",        
        "columns": [
          {
            "header": "",
            "icon": "pi pi-bolt",
            "type": "button",
            "buttonType": "button",
            "class": "p-button-rounded p-button-primary",
            "coupled": false,
            "onClick": ($Replace("fn:context.router.navigate(['/acme/fhirr4/patientData/"_objid_"/iahighlights'],{queryParams: {"_$Select(dateftr'="":"'dateftr':'"_dateftr_"'",1:"")_$Select(encid'="":",'encid':'"_encid_"'",1:"")_",hlid: (item['id'])}});","{,","{")),
            "value": "IABtn"
          },
          {
            "header": "Topic",
            "type": "field",
            "value": "topic"
          },
          {
            "header": "User",
            "type": "field",
            "value": "userName"
          },
          { 
            "header": "Proc. Date",
            "dateFormat": "global_datetimeFormat2",
            "type": "field",
            "value": "procDate"
          }
        ]
      },
      "order": 1
    }
    Do ..s(containers, "HighlightC", tHL)
    Do ..s(containers, "HighlightG", tGrid)
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
          "label": ((..translate(config,"IA Findings for"))_" """_tIATopic_"""")
        },
        "currentPageReportTemplate": "Showing {first} to {last} of {totalRecords} entries",
        "summary": false,
        "responsiveLayout": "scroll",
        "label": "Findings",
        "columns": [
          { 
            "header": "IA Comments",
            "type": "field",
            "value": "comment"
          },
          { 
            "header": "Res. Date",
            "dateFormat": "global_datetimeFormat2",
            "type": "field",
            "value": "resDate"
          },
          {
            "header": "Res. Type",
            "type": "button",
            "value": "resourceType",
            "class": "p-button-outlined p-button-text",
            "buttonType": "button",
            "icon":"pi pi-search-plus",
            "ngStylex":{
                "border-radius":"var(--border-radius)",
                "padding":"0.25em 0.5rem",
                "letter-spacing":"0.3px"
            },
            "disabled":"fn:return item['resPath']==='ServiceRequest' ? true : false;",
            "onClick":($Replace("fn:context.router.navigate(['/acme/fhirr4/patientData/"_objid_"/'+item['resPath']],{queryParams: {"_$Select(dateftr'="":"'dateftr':'"_dateftr_"'",1:"")_$Select(encid'="":",'encid':'"_encid_"'",1:"")_",'hlid':'"_hlid_"','id':(item['resId'])}});","{,","{"))
          }
        ]
      },
      "order": 1
    }
    If ..g(data, "IASList", tIASList)'="" Do ..s(containers, "HighlightS", tSGrid)
    Set tHLForm = {
                "type":"form",
                "id":"Highlight",
                "dataTarget":"Highlight",
                "onKeydown":"fn:if (event.key === 'Enter') context._submitTopic(control,context,data,containerControl,backendItem);",
                "groups": [
                    {
                        "class":"p-fluid",
                        "controlItems": [
                            {
                                "name": "topic",
                                "label": "New Topic",
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
                            "label": "submit",
                            "buttonType": "button",
                            "class":"p-button-outlined",
                            "containerClass": "align-self-start col-12 md:col-4 ",
                            "disabled": "fn:return !form.valid;",
                             "onClick":("fn:context._submitTopic(control,context,data,containerControl,backendItem);")
                        }
                        ]
                    }                    
                ]
            }
        Do ..s(forms, "Highlight", tHLForm)
    Quit $$$OK
}

ClassMethod getFilterForm(model, containers, forms, data, config, objid, dateftr, encid, hlid, fhirdata, functions) As %Status
{
    Set tFromDate=""
    If dateftr'="" {
        Set tFromDate=$PIECE(dateftr,"To",1)
    }
    Set tOptionItems=[
            {
                "name": (..translate(config,"All")),
                "value": ""
            },
            {
                "name": ($REPLACE(..translate(config,"last {x} days"),"{x}","30")),
                "value": ($ZDATETIME($HOROLOG-30,3))
            },
            {
                "name": ($REPLACE(..translate(config,"last {x} days"),"{x}","60")),
                "value": ($ZDATETIME($HOROLOG-60,3))
            },
            {
                "name": ($REPLACE(..translate(config,"last {x} days"),"{x}","120")),
                "value": ($ZDATETIME($HOROLOG-120,3))
            },
            {
                "name": ($REPLACE(..translate(config,"last {x} days"),"{x}","180")),
                "value": ($ZDATETIME($HOROLOG-180,3))
            },
            {
                "name": ($REPLACE(..translate(config,"last {x} days"),"{x}","360")),
                "value": ($ZDATETIME($HOROLOG-360,3))
            }
    ]
    Set tIdx = ..find(tOptionItems,"value.value="""_tFromDate_"""")
    If tIdx<0 Set tIdx=0
    Do ..s(data, "Filter", {"days":(tOptionItems.%Get(tIdx))})
    Do ..s(data, "ZoomFilter","")
    Do ..s(functions,"_applyZoomFilter",["axis","this.data.ZoomFilter=((axis.min) ? this.moment(axis.min).format('YYYY-MM-DD') : '')+((axis.max) ? 'To'+this.moment(axis.max).format('YYYY-MM-DD') : '');"])
    Set tFilter = {
                "order":0,
                "layout":{
                    "value":"grid",
                    "a":"col-12",
                    "a.a":"c:acc",
                    "a.a.a":"c:accTab",
                    "a.a.a.a":"card",
                    "a.a.a.a.a":"c:chart",
                    "a.a.a.b":"grid justify-content-center",
                    "a.a.a.b.a":"c:btnZoom",
                    "a.a.a.b.b":"c:clrZoom",
                    "a.a.a.c":"c:filterForm"
                },
                "acc":{"type":"accordion","active":true},
                "accTab":{"type":"accordionTab","header":"Filter Data","selected":true},
                "filterForm":{
                    "type":"form",
                    "form":"Filter"
                },
                "btnZoom":{
                  "type": "button",
                  "class": "col-12 md:col-2 mt-3 ml-3 mr-3 p-button-outlined",
                  "label": "apply zoom",
                  "buttonType": "button",
                  "disabled":"fn:return (data.ZoomFilter==='');",
                  "onClick":($Replace("fn:context.router.navigate(['/acme/fhirr4/patientData/"_objid_"/filterData'],(data.ZoomFilter==='' ? {queryParams: {"_$Select(encid'="":",'encid':'"_encid_"'",1:"")_$Select(hlid'="":",'hlid':'"_hlid_"'",1:"")_"}} : {queryParams: {'dateftr': (data.ZoomFilter)"_$Select(encid'="":",'encid':'"_encid_"'",1:"")_$Select(hlid'="":",'hlid':'"_hlid_"'",1:"")_"}}));","{,","{"))
                },
                "clrZoom":{
                  "type": "button",
                  "class": "col-12 md:col-2 mt-3 ml-3 mr-3 p-button-outlined",
                  "label": "clear zoom",
                  "buttonType": "button",
                  "disabled":("fn:return "_$Select(dateftr'="":"false",1:"true")_";"),
                  "onClick":("fn:context.router.navigate(['/acme/fhirr4/patientData/"_objid_"/filterData'],{queryParams: {"_$Select(hlid'="":"'hlid':'"_hlid_"'",1:"")_"}});")
                }
            }
    Do ..s(tFilter,"chart",..getGanttChart(fhirdata, config, dateftr),,"^")
    If (..g(config,"highcharts.lang")) Do ..s(data, "highchartsTranslation.lang",..g(config,"highcharts.lang"))

    Do ..s(containers, "FilterC", tFilter)
    Set tFilterForm = {
                "type":"form",
                "id":"Filter",
                "dataTarget":"Filter",
                "groups": [
                    {
                        "class":"p-fluid",
                        "controlItems": [
                            {
                                "name": "days",
                                "label": "Period",
                                "value": null,
                                "containerClass": "col-12",
                                "type": "dropdown",
                                "showErrors": true,
                                "pipe":"fn:return item.value ? item.value.value : null",
                                "optionItems": (tOptionItems)
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
                            "label": "apply filter",
                            "buttonType": "button",
                            "class":"p-button-outlined",
                            "containerClass": "align-self-start col-12 md:col-4 ",
                            "disabled": "fn:return !form.valid;",
                             "onClick":("fn:context.router.navigate(['/acme/fhirr4/patientData/"_objid_"/filterData'],(backendItem.days==='' ? {queryParams: {"_$Select(hlid'="":"'hlid':'"_hlid_"'",1:"")_"}} : {queryParams: {'dateftr': (backendItem.days)"_$Select(encid'="":",'encid':'"_encid_"'",1:"")_$Select(hlid'="":",'hlid':'"_hlid_"'",1:"")_"}}));")
                        }
                        ]
                    }                    
                ]
            }
        Do ..s(forms, "Filter", tFilterForm)
    Quit $$$OK
}

ClassMethod getPatientSearchForm(userid, model, containers, forms, data, functions, config, ssn) As %Status
{
    Do ..s(data, "PatientSearch", {"userid":(userid)})
    if $Data(ssn),ssn'="" Do ..s(data,"PatientSearch.identifier",ssn)
    Do ..s(data, "PatientList", [])
    Set tSearchFunc = "if ((control.errors?.pattern) || (control.errors?.required)) return;"_$CHAR(10,13)_
                            "context.isLoading=true;"_$CHAR(10,13)_
                            "context.backendService.getItems('fhirPatientSearch',backendItem,'fhirr4').then(beData => {"_$CHAR(10,13)_
                            "context.isLoading=false;"_$CHAR(10,13)_
                            "data['PatientList']=beData;"_$CHAR(10,13)_
                            "if (data['PatientList'].length>0) containerControl.accTab.selected=false;"_$CHAR(10,13)_
                            "}, err => {context.isLoading=false;});"
    Do ..s(functions,"_searchPatients.0","control")
    Do ..s(functions,"_searchPatients.1","context")
    Do ..s(functions,"_searchPatients.2","data")
    Do ..s(functions,"_searchPatients.3","containerControl")
    Do ..s(functions,"_searchPatients.4","backendItem")
    Do ..s(functions,"_searchPatients.5",tSearchFunc)
    Set tPatientSearchC = {
                "order":0,
                "layout":{
                    "value":"grid",
                    "a":"col-12",
                    "a.a":"c:acc",
                    "a.a.a":"c:accTab",
                    "a.a.a.a":"c:searchForm"
                },
                "acc":{"type":"accordion","active":true},
                "accTab":{"type":"accordionTab","header":"Patient Search Data","selected":true},
                "searchForm":{
                    "type":"form",
                    "form":"PatientSearch"
                }
            }
    Do ..s(containers, "PatientSearchC", tPatientSearchC)
    Set tPatientSearchForm = ..getJSONContent("patientSearchModel")
    While ..i(tPatientSearchForm,"groups",.tGI,.tVG,.tIG) {
        While ..i(tVG,"controlItems",.tICI,.tVCI,.tCI) {
            While ..i(tVCI,"optionItems",.tIOI,.tVOI,.tOI) {
                If ..g(tVOI,"name")'="" Do ..s(tVOI,"name",..translate(config,..g(tVOI,"name")))
            }
        }
    }
    Do ..s(forms, "PatientSearch", tPatientSearchForm)
    Set tPatientList = ..getJSONContent("patientListModel")
    Do ..s(model,"PatientList",tPatientList,,"^")   
    Quit $$$OK
}

ClassMethod addFormDialog(userid, containers, forms, grpName As %String, header As %String) As %Status
{
    Set tDevMode = 0
    If userid'="" {
        Set tUserData = ##class(acme.base.data.user).%OpenId(userid)
        Set tDevMode = tUserData.devMode
    }
    If tDevMode = 0 {
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
    } Else {
        Set tDialog = {
            "layout":{
                "value":"c:dialog",
                "a.value":{"type":"tabView"},
                "a.a":"c:tabPan001",
                "a.b":"c:tabPan002",
                "footer":"c:btclose"
            },
            "dialog":{
                "type":"dialog",
                "header":(header),
                "ngStyle":{ "width": "900px"},
                "visible":false
            },
            "tabPan001":{
                "layout":{
                    "value":{
                        "type":"tabPanel",
                        "header":"Formatted View"
                    },
                    "a.value":{
                        "type":"form",
                        "form":(grpName)
                    }
                }
            },
            "tabPan002":{
                "layout":{
                    "value":{
                        "type":"tabPanel",
                        "header":"Json View"
                    },
                    "a.value":{
                        "type":"form",
                        "form":(grpName_"JSON")
                    }
                }
            },
            "btclose":{
                "type":"button",
                "icon":"pi pi-times",
                "class":"p-button-text",
                "label":"Close",
                "onClick":("fn:containerData['"_grpName_"Dial']['dialog']['visible']=false;")
            }
        }
    }
    Set jsonForm = {
      "groups":[
        {
          "controlItems":[
                {
                "showNull":false,
                "containerClass":"align-self-start col-12 md:col-12",
                "rows":20,
                "type":"textarea",
                "readonly":true,
                "style":{
                    "background":"rgba(0,0,0,.15)"
                },
                "name":"rawdata"
                }
            ]
        }
      ]
    }
    Do ..s(forms,grpName_"JSON",jsonForm,,"^")
    Do ..s(containers,grpName_"Dial",tDialog)
}

ClassMethod buildFEFromModel(userid, model As %Library.DynamicObject, fhirdata As %Library.DynamicObject, containers As %Library.DynamicObject, forms As %Library.DynamicObject, data As %Library.DynamicObject, id As %String) As %Status
{
    If '$Data(id) Set id = ""
    Set tIACount = ..g(fhirdata,"@IACount.Resource")
    Set tResult = $$$OK
    Set tOrder = 1
    While (..i(model,,.resModKey,.resModValue,.tResModIt)) {
        Set resGrpKey = resModKey
        Set tGroup = ..g(model,resGrpKey,"^")
        Set tDataTarget = $SELECT(..g(resModValue,"target","^")'="":..g(resModValue,"target","^"),1:resGrpKey)
        If tGroup'="" {
            Set tTable =  {}
            Do ..s(tTable,"type","formtable")
            Do ..s(tTable,"dataKey","id")
            Do ..s(tTable,"target",tDataTarget)
            Do ..s(tTable,"value",tDataTarget)
            Do ..s(tTable,"form",resGrpKey)
            Do ..s(tTable,"rows",100)
            Do ..s(tTable,"paginator","true","boolean")
            Do ..s(tTable,"rowHover","true","boolean")
            Do ..s(tTable,"ngStyle","fn:if ((item)&&(item['ia-hl']===1)) {return {'background':'rgba(0,0,0,.15)'}} else {return {}};")
            Do ..s(tTable,"showCurrentPageReport","true","boolean")
            Do ..s(tTable,"caption.label","Manage "_resGrpKey)
            Do ..s(tTable,"caption.search","true","boolean")
            Do ..s(tTable,"caption.placeholder","Search...")
            Do ..s(tTable,"currentPageReportTemplate","Showing {first} to {last} of {totalRecords} entries")
            If $find("|DiagnosticReport|DocumentReference|","|"_resGrpKey_"|")=0 Do ..addFormDialog(userid, containers, forms, resGrpKey, resGrpKey_" Details")
            Do ..s(tTable,"editItemButton.onClick",("fn:context.setFormItem(containerControl.form, item);context.setFormItem(containerControl.form+'JSON', item);context.containerData[containerControl.form+'Dial']['dialog']['visible']=true;"))
            //Do ..s(tTable,"editItemButton.onClick","fn:context.editItem(containerControl.form, item)")
            Do ..s(tTable,"summary","false","boolean")
            Do ..s(tTable,"responsiveLayout","scroll")
            While (..i(tGroup,"tableConfig",.cfKey,.cfValue,.tConfigIt,,.tTableConfig)) {
                Do ..s(tTable,cfKey,cfValue,$SELECT($ISOBJECT(cfValue):"",1:tTableConfig.%GetTypeOf(cfKey)))
            }
            While (..i(tGroup,"groupConfig",.cfKey,.cfValue,.tConfigIt,,.tGroupConfig)) {
                Do ..s(forms,resGrpKey_".groups.0."_cfKey,cfValue,$SELECT($ISOBJECT(cfValue):"",1:tGroupConfig.%GetTypeOf(cfKey)))
            }
            If ..g(tIACount,tDataTarget)'="",$find("|Patient|DiagnosticReport|Observation|DocumentReference|","|"_resGrpKey_"|")=0 {
                Do ..s(tTable,"columns.+", {
                    "type":"button",
                    "class":"p-button-rounded p-button-secondary",
                    "onClick":("fn:context.editItem('"_resGrpKey_"', item)"),
                    "icon":"pi pi-bolt",
                    "value":"ia-btn"
                },)
            }
            Do ..s(forms,resGrpKey_".groups.0.controlItems.+",
                {
                "iconClass":"pi pi-bolt",
                "showNull":false,
                "label":"IA Comments",
                "containerClass":"align-self-start col-12 md:col-12",
                "rows":5,
                "type":"textarea",
                "name":"ia-obs",
                "readonly":true,
                "style":{"background":"rgba(0,0,0,.15)"}
                }
            )
            While (..i(tGroup,,.resPropKey,.resPropValue,.tPropIt)) {
                Set tFormProp = ..g(resPropValue,"form")
                If $ISOBJECT(tFormProp) {
                    Set tPropObj = tFormProp
                    Do ..s(tPropObj,"type",$SELECT(..g(tPropObj,"type")'="":..g(tPropObj,"type"),1:"text"),,"^")
                    Do ..s(tPropObj,"name",resPropKey,,"^")
                    Do ..s(tPropObj,"readonly","true","boolean","^")
                    Do ..s(forms,resGrpKey_".groups.0.controlItems.+",tPropObj)
                }
                Set tColumnProp = ..g(resPropValue,"grid")
                If $ISOBJECT(tColumnProp) {
                    Set Column = tColumnProp
                    Do ..s(Column,"type",$SELECT(..g(tColumnProp,"type")'="":..g(tColumnProp,"type"),1:"field"),,"^")
                    Do ..s(Column,"value",$SELECT(..g(tColumnProp,"type")="button":resPropKey,1:resPropKey),,"^")
                    //if ..g(tColumnProp,"searchable")=1 Do ..s(tTable,"globalFilterFields.+",resPropKey)
                    Do ..s(tTable,"columns.+",Column)
                }
            }
            If $FIND("|PatientSearch|PatientList|","|"_resGrpKey_"|")>0 Do ..s(containers,resGrpKey_".active","true","boolean")
            If ..g(tTable,"columns")'="" {
                Do ..s(containers,resGrpKey_"^layout^value","grid",,"^")
                Do ..s(containers,resGrpKey_"^layout^a","col-12",,"^")
                Do ..s(containers,resGrpKey_"^layout^a.a","card",,"^")
                Do ..s(containers,resGrpKey_"^layout^a.a.a","c:table",,"^")
                Do ..s(containers,resGrpKey_".table",tTable)
                If ..g(forms,resGrpKey_".header")="" Do ..s(forms,resGrpKey_".header",resGrpKey_" Details")
            } ElseIf ..g(model,resGrpKey_".dialog")=0 {
                Do ..s(containers,resGrpKey_"^layout^value","grid",,"^")
                Do ..s(containers,resGrpKey_"^layout^a","col-12",,"^")
                Do ..s(containers,resGrpKey_"^layout^a.a","card",,"^")
                Do ..s(containers,resGrpKey_"^layout^a.a.a","c:form",,"^")
                Do ..s(containers,resGrpKey_".form",{"type":"form","form":(resGrpKey)})
            }
            While (..i(tGroup,"containerConfig",.cfKey,.cfValue,,.tContainerConfig)) {
                Do ..s(containers,resGrpKey_"."_cfKey,cfValue,$SELECT($ISOBJECT(cfValue):"",1:tContainerConfig.%GetTypeOf(cfKey)))
            }
        }
        While (..i(tGroup,"formConfig",.cfKey,.cfValue,.tFConfigIt,,.tFormConfig)) {
            Do ..s(forms,resGrpKey_"."_cfKey,cfValue,$SELECT($ISOBJECT(cfValue):"",1:tFormConfig.%GetTypeOf(cfKey)))
        }
        Do ..s(forms,resGrpKey_".style",{ "width": "900px" })
        While (..i(fhirdata,tDataTarget,.resItemKey,.resItemValue,.tItDt)) {
            //filter by id
            If id'="" {
                If ..g(resItemValue,"filter")=1 Do ..s(data,tDataTarget_"^+",resItemValue,,"^")
            } Else {
                Do ..s(data,tDataTarget_"^+",resItemValue,,"^")                
            }
        }
        If ..g(containers,resGrpKey)'="" {
            Do ..s(containers,resGrpKey_".order",tOrder)
            Set tOrder = tOrder + 1
        }
    }
    Quit tResult
}

ClassMethod patientSearchForm(userid, objid, subid, ssn, request) As %Library.DynamicObject
{
    Set tHeaders = {}
    If request.Headers'="" Set tHeaders = {}.%FromJSON(request.Headers)
    Set tContainers = {}
    Set tSource = {}
    Set tForms = {}
    Set tModel = {}
    Set tFunctions = {}
    Set tBreadCrumbs = [{"label":"FHIR - Patient Search"}]
    Do ..getPatientSearchForm(userid, tModel, tContainers, tForms, tSource, tFunctions, ..getTranslations(userid), ssn)
    Do ..buildFEFromModel(userid, tModel,{},tContainers,tForms,tSource)
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

ClassMethod patientDataForm(userid, objid, subid, reload, dateftr, encid, hlid, id, httpRequest) As %Library.DynamicObject
{
    Set tHeaders = {}
    If httpRequest.Headers'="" Set tHeaders = {}.%FromJSON(httpRequest.Headers)
    If objid="" Return {}
    If subid="" Set subid = "$everything"
    If '$DATA(reload) Set reload = 0
    If '$DATA(encid) Set encid = ""
    If '$DATA(dateftr) Set dateftr = ""
    If '$DATA(hlid) Set hlid = ""
    If '$DATA(id) Set id = ""
    Set subid=$ZCONVERT(subid,"L")
    Set tContainers = {}
    Set tSource = {}
    Set tFunctions = {}
    Set tForms = {}
    Set tConfig = {}
    Set tModel = {}
    Set tMenu = []
    Set tFhirData = {}
    Try {
        Set tFhirData = ..jretrieve("acme","fhirquery",objid)
    } Catch (e) {
        Set tFhirData={}
    }
    //same day or < 5 min keep in cache
    //every patient search clear cache
    If (subid="summary" && reload=1)||(..g(tFhirData,"id")="")||($PIECE(..g(tFhirData,"dtt"),",",1)'=$PIECE($HOROLOG,",",1)||($PIECE($HOROLOG,",",2)-$PIECE(..g(tFhirData,"dtt"),",",2)>(60*5))) {
        Set tFhirData = ..fhirQuery("Patient",objid,"$everything",,,,,,,httpRequest)
        //Try {
        Set tNObj = ..jsave("acme","fhirquery",tFhirData,"id")
        //} Catch (ex) {}
        Set reload = 1
    }
    If ..g(tFhirData,"issue_0_severity")="error" {
        Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<500> "_..g(tFhirData,"issue_0_details_text")))
    }
    Set tOrigStream = ##class(%Stream.GlobalCharacter).%New()
    Do tFhirData.%ToJSON(.tOrigStream)
    Set tOrigFhirData = {}.%FromJSON(tOrigStream)

    //filter by date
    If ((dateftr'="")||(encid'="")) {
      Set tFhirData = ..filterResources(tFhirData,dateftr,encid)
    }
    If hlid'="" {
      Set tFhirData = ..applyIAHL(objid, tFhirData,hlid)
    }
    If id'="" {
      Set tFhirData = ..applyFilter(objid, tFhirData,id)
    }
    //count resources
    Do ..countResources(tFhirData)
    //order resources
    Do ..orderResources(tFhirData)
    //Default Chart Options Object for Lab and Vitals and calendars
    Set tConfig = ..getTranslations(userid,.tLocale,.tDateFormat)
    //Calendar Buttons Translation
    Set tCalendarButtons = ..g(tConfig,"calendarButtons")
    Do ..addFilters(dateftr,encid,hlid,tContainers,"col-12",tConfig,objid, subid, id)
    If $FIND("|filterdata|","|"_subid_"|")>0 Do ..getFilterForm(tModel, tContainers, tForms, tSource, tConfig, objid, dateftr, encid, hlid, tFhirData, tFunctions)
    If $FIND("|iahighlights|","|"_subid_"|")>0 Do ..getIAHighlightsForm(userid, tModel, tContainers, tForms, tSource, tConfig, objid, dateftr, encid, hlid, tOrigFhirData, tFunctions)
    If $FIND("|lab|labresults|laboratory|","|"_subid_"|")>0 Do ..buildLaboratoryReportPvtModel(userid, tContainers, tForms, objid, subid, tModel,tFhirData,tSource,tMenu,id)
    If $FIND("|lab|labresults|laboratory|","|"_subid_"|")>0 Do ..buildDiagnosticResultPvtModel(tContainers, tForms, objid, subid, tModel,tFhirData,tSource,tMenu,id)
    If $FIND("|patient|demographics|","|"_subid_"|")>0 Do ..getDemographicsModel(objid, subid, tModel,tFhirData,tSource,tMenu)
    If $FIND("|vitals|vital-signs|survey|observation|","|"_subid_"|")>0 Do ..getObservationModel(objid, subid, tModel,tFhirData,tSource,tMenu)
    If $FIND("|rad|radresults|","|"_subid_"|")>0 Do ..getRadDiagnosticReportModel(objid, subid, tModel,tFhirData,tSource,tMenu)
    If $FIND("|lab|labresults|","|"_subid_"|")>0 Do ..getLabDiagnosticReportModel(objid, subid, tModel,tFhirData,tSource,tMenu)
    If $FIND("|documents|documentreference|","|"_subid_"|")>0 Do ..getDocumentReferenceModel(objid, subid, tModel,tFhirData,tSource,tMenu)
    If $FIND("|documents|documentreference|","|"_subid_"|")>0 Do ..buildDocumentReferencePvtForm(userid, tContainers, tForms, objid, subid, tModel,tFhirData,tSource,tMenu,id)
    If $FIND("|rad|radresults|radiology|","|"_subid_"|")>0 Do ..buildRadiologyReportPvtForm(userid, tContainers, tForms, objid, subid, tModel,tFhirData,tSource,tMenu,id)
    If $FIND("|vitals|observation|vital-signs|","|"_subid_"|")>0 Do ..buildVitalsPvtForm(userid, tContainers, tForms, objid, subid, tModel,tFhirData,tSource,tMenu,id)
    If $FIND("|survey|","|"_subid_"|")>0 Do ..buildSurveyPvtForm(userid, tContainers, tForms, objid, subid, tModel,tFhirData,tSource,tMenu,id)
    If $FIND("|encounter|encounters|","|"_subid_"|")>0 Do ..getEncounterModel(userid, objid, subid, tModel,tFhirData,tSource,tMenu,tContainers,tForms,tCalendarButtons,tLocale,dateftr,encid,hlid,id)
    If $FIND("|appointment|appointments|","|"_subid_"|")>0 Do ..getAppointmentModel(userid, objid, subid, tModel,tFhirData,tSource,tMenu,tContainers,tForms,tCalendarButtons,tLocale)
    If $FIND("|condition|conditions|","|"_subid_"|")>0 Do ..getConditionModel(objid, subid, tModel,tFhirData,tSource,tMenu)
    If $FIND("|immunization|immunizations|","|"_subid_"|")>0 Do ..getImmunizationModel(objid, subid, tModel,tFhirData,tSource,tMenu)
    If $FIND("|procedure|procedures|","|"_subid_"|")>0 Do ..getProcedureModel(objid, subid, tModel,tFhirData,tSource,tMenu)
    If $FIND("|medication|medications|medicationrequest|medicationstatement|","|"_subid_"|")>0 {
        Do ..getMedicationModel(objid, subid, tModel,tFhirData,tSource,tMenu)
        Do ..getMedicationReqModel(objid, subid, tModel,tFhirData,tSource,tMenu)
    }
    If $FIND("|allergy|allergies|allergyintolerance|","|"_subid_"|")>0 Do ..getAllergyModel(objid, subid, tModel,tFhirData,tSource,tMenu)
    If $FIND("|vitals|observation|vital-signs|survey|lab|labresults|","|"_subid_"|")>0 Do ..buildCumulativeChart(tSource,tContainers,tDateFormat)
    If $FIND("|summary|","|"_subid_"|")>0  Do ..getSummaryModel(userid, objid, subid, tModel,tFhirData,tSource,tMenu,tContainers,tForms,tCalendarButtons,tLocale,dateftr,encid,hlid,tFunctions,tOrigFhirData)
    Do ..buildFEFromModel(userid,tModel,tFhirData,tContainers,tForms,tSource,id)
    Set tData = {
            "data":(tSource),
            "forms":(tForms),
            "containers": (tContainers),
            "functions": (tFunctions),
            "execute":[
              ("context.Highcharts.setOptions({});"),
              ("if (data.highchartsTranslation) context.Highcharts.setOptions(data.highchartsTranslation);"),
              ("setTimeout(() => {"_
                "if (context.highchartsGanttComponent) window.dispatchEvent(new Event('resize'));"_
            "},100);")
            ]
    }
    Set tBackEndLinks = ..getBackEndLinks(tHeaders)
    If $IsObject(tBackEndLinks),tBackEndLinks.%Size>0 Do ..addBackEndLinks(tBackEndLinks,tContainers,"col-12")
    Do ..buildMenu(tData,..g(tFhirData,"@Count.Resource"),..g(tFhirData,"@IACount.Resource"),objid,dateftr,encid,hlid)
    Do ..buildBreadCrumbs(tData,tFhirData,objid,tConfig)
    Return tData
}

ClassMethod getBackEndLinks(headers) As %Library.DynamicArray
{
    Set tConfig = ..getFHIRR4Config()
    Set tURLs = ..getJSONContent("backendurls")
    Quit {}.%FromJSON($Replace(..g(tURLs,"links").%ToJSON(),"<backendurl>",..g(headers,"REQUEST_SCHEME")_"://"_..g(headers,"HTTP_HOST")))
}

ClassMethod buildCumulativeChart(data, containers, dateFormat) As %Status
{
        //Create chart modal dialog for Lab and Vitals
        Do ..s(containers,"CumulativeChart^layout^value","c:dialog",,"^")
        Do ..s(containers,"CumulativeChart^layout^a","c:chart",,"^")
        Do ..s(containers,"CumulativeChart^dialog^type","dialog",,"^")
        Do ..s(containers,"CumulativeChart^dialog^header","Cumulative Chart",,"^")
        Do ..s(containers,"CumulativeChart^dialog^style",{ "width": "700px", "height":"500px" },,"^")
        Do ..s(containers,"CumulativeChart^dialog^visible","false","boolean","^")
        Do ..s(containers,"CumulativeChart^chart^type","chart",,"^")

        Do ..s(data,"chartOptions^responsive","true","boolean","^")
        Do ..s(data,"chartOptions^elements^line^tension",0,,"^")
        Do ..s(data,"chartOptions^scales^x^type","time",,"^")
        Do ..s(data,"chartOptions^scales^x^time^displayFormats^day",dateFormat,,"^")
        Do ..s(data,"chartOptions^scales^x^time^displayFormats^hour","DD HH:MM",,"^")
}

ClassMethod getResData(fhirdata, resType, resId, targetObj)
{
        Set tKey = resType_"."_resType_"/"_resId        
        Set tRes = ..g(fhirdata,tKey)
        If tRes'="" {
            Do ..getResPath(tRes,resType,targetObj)
            If (..g(tRes,"componentCount")'="") {
                For i=0:1:..g(tRes,"componentCount")-1 {
                    Set tSRes = ..g(fhirdata,tKey_"/"_i)
                    If tSRes'="" {
                        Do ..getResPath(tSRes,resType,targetObj)
                    }
                }
            }
        }
        If resType="Observation" {
            While (..i(fhirdata,"DiagnosticReport",.tDIdx,.tDVal,.tDIt)) {
                While (..i(tDVal,"result",.tRIdx,.tRVal,.tRIt)) {
                    If ..g(tRVal,"id")=resId {
                        Do ..getResPath(tRVal,resType,targetObj)
                    }
                }        
            }
        }
}

ClassMethod getResDataFromList(hllist, fhirdata) As %Library.DynamicObject
{
    While (..i(hllist,,.tHIdx,.tHVal,.tHIt)) {
        Do ..getResData(fhirdata,..g(tHVal,"resourceType"),..g(tHVal,"id"),tHVal)
    }
    Quit ..orderBy(hllist,["resDate|-1"],1)
}

ClassMethod getResPath(res, resType, obj)
{
    Do ..s(obj, "resPath",resType)
    If ..g(res,"category_0_coding_0_code")'="",$Find("|vital-signs|lab|laboratory|radiology|rad|survey|","|"_$ZConvert(..g(res,"category_0_coding_0_code"),"L")_"|")>0 Do ..s(obj, "resPath",..g(res,"category_0_coding_0_code"))
    Do ..s(obj, "resId",resType_"|"_..g(res,"id"))
    If resType="Encounter" {
        If ..g(res,"period_start")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"period_start"))
        If ..g(res,"period_end")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"period_end"))
    } ElseIf resType="DiagnosticReport" {
        If ..g(res,"issued")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"issued"))
    } ElseIf resType="Observation" {
        If ..g(res,"effectiveDateTime")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"effectiveDateTime"))
    } ElseIf resType="ServiceRequest" {
        If ..g(res,"authoredOn")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"authoredOn"))
    } ElseIf resType="DocumentReference" {
        If ..g(res,"date")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"date"))
    } ElseIf resType="Condition" {
        If ..g(res,"recordedDate")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"recordedDate"))
    } ElseIf resType="MedicationRequest" {
        If ..g(res,"authoredOn")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"authoredOn"))
    } ElseIf resType="Immunization" {
        If ..g(res,"occurrenceDateTime")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"occurrenceDateTime"))
    } ElseIf resType="Procedure" {
        If ..g(res,"performedDateTime")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"performedDateTime"))
        If ..g(res,"performedPeriod_start")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"performedPeriod_start"))
        If ..g(res,"performedPeriod_end")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"performedPeriod_end"))
    } ElseIf resType="MedicationStatement" {
        If ..g(res,"extensionIdx_medication-entered-on_valueDateTime")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"extensionIdx_medication-entered-on_valueDateTime"))
    } ElseIf resType="Appointment" {
        If ..g(res,"start")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"start"))
        If ..g(res,"end")'="",..g(obj,"resDate")="" Do ..s(obj,"resDate",..g(res,"end"))
    }
}

ClassMethod applyIAHL(objid, fhirdata, hlid) As %Library.DynamicObject
{
    Set tHL = ..jretrieve("acme","IA|"_objid,hlid)
    If tHL="" Quit fhirdata
    While (..i(tHL,"responseList",.tHIdx,.tHVal,.tHIt)) {
        Set tResType = ..g(tHVal,"resourceType")
        Set tRes = ..g(fhirdata,tResType_"."_tResType_"/"_..g(tHVal,"id"))
        If tRes'="" {
            Do ..s(tRes,"ia-hl",1)
            Do ..s(tRes,"ia-btn","")
            Do ..s(tRes,"ia-obs",..g(tHVal,"comment"))
            If (..g(tRes,"componentCount")'="") {
                For i=0:1:..g(tRes,"componentCount")-1 {
                    Set tSRes = ..g(fhirdata,tResType_"."_tResType_"/"_..g(tHVal,"id")_"/"_i)
                    If tSRes'="" {
                        Do ..s(tSRes,"ia-hl",1)
                        Do ..s(tSRes,"ia-btn","")
                        Do ..s(tSRes,"ia-obs",..g(tHVal,"comment"))
                    }
                }
            }

        }
        If tResType="Observation" {
            While (..i(fhirdata,"DiagnosticReport",.tDIdx,.tDVal,.tDIt)) {
                While (..i(tDVal,"result",.tRIdx,.tRVal,.tRIt)) {
                    If ..g(tRVal,"id")=..g(tHVal,"id") {
                        Do ..s(tRVal,"ia-hl",1)
                        Do ..s(tRVal,"ia-btn","")
                        Do ..s(tRVal,"ia-obs",..g(tHVal,"comment"))
                        If ..g(tDVal,"ia-obs")="" {
                            Do ..s(tDVal,"ia-hl",1)
                            Do ..s(tDVal,"ia-btn","")
                            Do ..s(tDVal,"ia-obs","")
                        }
                    }
                }        
            }
        }

    }
    Quit fhirdata
}

ClassMethod applyFilter(objid, fhirdata, id) As %Library.DynamicObject
{
    For i=1:1:$L(id,"||") {
        Set tType = $Piece($Piece(id,"||",i),"|",1)
        Set tId = $Piece($Piece(id,"||",i),"|",2)

        Set tResType = tType
        Set tRes = ..g(fhirdata,tResType_"."_tResType_"/"_tId)
        If tRes'="" {
            Do ..s(tRes,"filter",1)
            If (..g(tRes,"componentCount")'="") {
                For i=0:1:..g(tRes,"componentCount")-1 {
                    Set tSRes = ..g(fhirdata,tResType_"."_tResType_"/"_tId_"/"_i)
                    If tSRes'="" {
                        Do ..s(tSRes,"filter",1)
                    }
                }
            }
            If (..g(tRes,"result")'="") {
                While (..i(tRes,"result",.tRIdx,.tRVal,.tRIt)) {
                    Do ..s(tRVal,"filter",1)
                    Set tObs = ..g(fhirdata,"Observation.Observation/"_..g(tRVal,"id"))
                    If tObs'="" {
                        Do ..s(tObs,"filter",1)
                    }
                }
            }
        }
        If tResType="Observation" {
            While (..i(fhirdata,"DiagnosticReport",.tDIdx,.tDVal,.tDIt)) {
                While (..i(tDVal,"result",.tRIdx,.tRVal,.tRIt)) {
                    If ..g(tRVal,"id")=tId {
                        Do ..s(tRVal,"filter",1)
                        If ..g(tDVal,"filter")="" {
                            Do ..s(tDVal,"filter",1)
                        }
                    }
                }        
            }
        }
    }
    Quit fhirdata
}

ClassMethod filterResources(fhirdata, dateftr, encid) As %Library.DynamicObject
{
    Set tFhirData = {}.%FromJSON(fhirdata.%ToJSON())
    Set tFtrFhirData = {}
    If encid'="" {
        While (..i(tFhirData,,.ResGrpIdx,.ResGrpVal,.ResGrpIt)) {
            If $ISOBJECT(ResGrpVal) {
                While (..i(ResGrpVal,,.ResIdx,.ResVal,.ResIt)) {
                    If ResGrpIdx="Encounter" {
                        If encid'="",..g(ResVal,"id")=encid Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                    } ElseIf ResGrpIdx="DiagnosticReport" {
                        If encid'="",$Piece(..g(ResVal,"encounter_reference"),"/",2)=encid Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                    } ElseIf ResGrpIdx="Observation" {
                        If encid'="",$Piece(..g(ResVal,"encounter_reference"),"/",2)=encid Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                    } ElseIf ResGrpIdx="ServiceRequest" {
                        If encid'="",$Piece(..g(ResVal,"encounter_reference"),"/",2)=encid Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                        If ..isDateBetween(..g(ResVal,"authoredOn"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                    } ElseIf ResGrpIdx="DocumentReference" {
                        If encid'="",$Piece(..g(ResVal,"encounter_reference"),"/",2)=encid Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                    } ElseIf ResGrpIdx="Condition" {
                        If encid'="",$Piece(..g(ResVal,"encounter_reference"),"/",2)=encid Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                    } ElseIf ResGrpIdx="MedicationRequest" {
                        If encid'="",$Piece(..g(ResVal,"encounter_reference"),"/",2)=encid Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                    } ElseIf ResGrpIdx="Immunization" {
                        If encid'="",$Piece(..g(ResVal,"encounter_reference"),"/",2)=encid Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                    } ElseIf ResGrpIdx="Procedure" {
                        If encid'="",$Piece(..g(ResVal,"encounter_reference"),"/",2)=encid Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                    } ElseIf ResGrpIdx="MedicationStatement" {
                        If encid'="",$Piece(..g(ResVal,"encounter_reference"),"/",2)=encid Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                    } ElseIf ResGrpIdx="Appointment" {
                    } Else {
                        Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                    }
                }
            } Else {
                Do ..s(tFtrFhirData,ResGrpIdx,ResGrpVal)
            }
        }
        Set tFhirData = tFtrFhirData
    }
    While (..i(tFhirData,,.ResGrpIdx,.ResGrpVal,.ResGrpIt)) {
        If $ISOBJECT(ResGrpVal) {
            While (..i(ResGrpVal,,.ResIdx,.ResVal,.ResIt)) {
                If ResGrpIdx="Encounter" {
                    If ..isDateBetween(..g(ResVal,"period_start"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)  Continue
                    If ..isDateBetween(..g(ResVal,"period_end"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                } ElseIf ResGrpIdx="DiagnosticReport" {
                    If ..isDateBetween(..g(ResVal,"issued"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                } ElseIf ResGrpIdx="Observation" {
                    If ..isDateBetween(..g(ResVal,"effectiveDateTime"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                } ElseIf ResGrpIdx="ServiceRequest" {
                    If ..isDateBetween(..g(ResVal,"authoredOn"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                } ElseIf ResGrpIdx="DocumentReference" {
                    If ..isDateBetween(..g(ResVal,"date"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                } ElseIf ResGrpIdx="Condition" {
                    If ..isDateBetween(..g(ResVal,"recordedDate"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                } ElseIf ResGrpIdx="MedicationRequest" {
                    If ..isDateBetween(..g(ResVal,"authoredOn"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                } ElseIf ResGrpIdx="Immunization" {
                    If ..isDateBetween(..g(ResVal,"occurrenceDateTime"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                } ElseIf ResGrpIdx="Procedure" {
                    If ..isDateBetween(..g(ResVal,"performedDateTime"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)  Continue
                    If ..isDateBetween(..g(ResVal,"performedPeriod_start"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)  Continue
                    If ..isDateBetween(..g(ResVal,"performedPeriod_end"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                } ElseIf ResGrpIdx="MedicationStatement" {
                    If ..isDateBetween(..g(ResVal,"extensionIdx_medication-entered-on_valueDateTime"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                } ElseIf ResGrpIdx="Appointment" {
                    If ..isDateBetween(..g(ResVal,"start"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)  Continue
                    If ..isDateBetween(..g(ResVal,"end"),$PIECE(dateftr,"To",1),$PIECE(dateftr,"To",2)) Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                } Else {
                    Do ..s(tFtrFhirData,ResGrpIdx_"."_ResIdx,ResVal)
                }
            }
        } Else {
            Do ..s(tFtrFhirData,ResGrpIdx,ResGrpVal)
        }
    }
    Quit tFtrFhirData
}

ClassMethod addFilters(dateftr, encid, hlid, containers, gridConfig As %String = "col-12", trConfig, objid, subid, id)
{
    Do ..r(containers,"dataFilters")
    If ((dateftr'="")||(hlid'="")||(encid'="")||(id'="")) {
        Do ..s(containers,"dataFilters^order",-1,,"^")
        Do ..s(containers,"dataFilters^layout^value","grid justify-content-center",,"^")
        Do ..s(containers,"dataFilters^layout^0a",gridConfig,,"^")
    }
    If id'="" {
        Do ..s(containers,"dataFilters^layout^0a.1a.value",{"type":"button","icon":"pi pi-filter-slash","label":("id="_$Piece($Piece(id,"||",1),"|",2)),"class":"p-button-text mr-3","tooltip":"clear filter",
        "onClick":($Replace("fn:context.router.navigate(['/acme/fhirr4/patientData/"_objid_"/"_subid_"'],{'queryParams':{"_$Select(dateftr'="":",'dateftr':'"_dateftr_"'",1:"")_$Select(hlid'="":",'hlid':'"_hlid_"'",1:"")_"}});","{,","{"))},,"^")
    }
    If dateftr'="" {
        Set (tFromDate,tToDate) = ""
        Set tFormat=..nvl(..g(trConfig,"iris_zdatetime_format"),1)
        If $PIECE(dateftr,"To",1)'="" Set tFromDate=..nvl(..g(trConfig,"from date"),"from date")_":"_$PIECE($ZDATETIME($ZDATETIMEH($PIECE(dateftr,"To",1),3),tFormat)," ",1)
        If $PIECE(dateftr,"To",2)'="" Set tToDate=..nvl(..g(trConfig,"to date"),"to date")_":"_$PIECE($ZDATETIME($ZDATETIMEH($PIECE(dateftr,"To",2),3),tFormat)," ",1)
        Do ..s(containers,"dataFilters^layout^0a.0a.value",{"type":"button","icon":"pi pi-filter-slash","label":(tFromDate_" "_tToDate),"class":"p-button-text mr-3","tooltip":"clear filter",
        "onClick":($Replace("fn:context.router.navigate(['/acme/fhirr4/patientData/"_objid_"/"_subid_"'],{'queryParams':{"_$Select(encid'="":",'encid':'"_encid_"'",1:"")_$Select(hlid'="":",'hlid':'"_hlid_"'",1:"")_"}});","{,","{"))},,"^")
    }
    If encid'="" {
        Do ..s(containers,"dataFilters^layout^0a.1a.value",{"type":"button","icon":"pi pi-filter-slash","label":("encounter id="_encid),"class":"p-button-text mr-3","tooltip":"clear filter",
        "onClick":($Replace("fn:context.router.navigate(['/acme/fhirr4/patientData/"_objid_"/"_subid_"'],{'queryParams':{"_$Select(dateftr'="":",'dateftr':'"_dateftr_"'",1:"")_$Select(hlid'="":",'hlid':'"_hlid_"'",1:"")_"}});","{,","{"))},,"^")
    }
    If hlid'="" {
        Set tHLObj = ..jretrieve("acme","IA|"_objid,hlid)
        Do ..s(containers,"dataFilters^layout^0a.2a.value",{"type":"button","icon":"pi pi-bolt","label":("IA highlight For """_..g(tHLObj,"topic")_""""),"class":"p-button-text ml-3 mr-3","tooltip":"clear IA highlights",
        "onClick":($Replace("fn:context.router.navigate(['/acme/fhirr4/patientData/"_objid_"/"_subid_"'],{'queryParams':{"_$Select(encid'="":",'encid':'"_encid_"'",1:"")_$Select(dateftr'="":",'dateftr':'"_dateftr_"'",1:"")_"}});","{,","{"))},,"^")
    }
}

ClassMethod countResources(fhirdata) As %Status
{
    //Count Resource Type Block For Menu
    While (..i(fhirdata,,.ResGrpIdx,.ResGrpVal,.ResGrpIt)) {
        If ResGrpIdx="@Count" Continue
        If ResGrpIdx="@IACount" Continue
        If $ISOBJECT(ResGrpVal) {
            While (..i(ResGrpVal,,.ResIdx,.ResVal,.ResIt)) {
                Set tCategory = ..g(ResVal,"category_0_coding_0_code","^")
                Set tResourceType = ResGrpIdx
                Set tResCount = ..g(fhirdata,"@Count^Resource^"_tResourceType,"^")
                Do ..s(fhirdata,"@Count^Resource^"_tResourceType,$SELECT(tResCount="":1,1:tResCount+1),,"^")
                Set tResCatCount = ..g(fhirdata,"@Count^Resource^"_tResourceType_"@"_tCategory,"^")
                If tCategory'="" Do ..s(fhirdata,"@Count^Resource^"_tResourceType_"@"_tCategory,$SELECT(tResCatCount="":1,1:tResCatCount+1),,"^")

                //ia-hl count
                Set tIACount = ..g(fhirdata,"@IACount^Resource^"_tResourceType,"^")
                If ..g(ResVal,"ia-obs","^")'="" Do ..s(fhirdata,"@IACount^Resource^"_tResourceType,$SELECT(tIACount="":1,1:tIACount+1),,"^")
                Set tIACatCount = ..g(fhirdata,"@IACount^Resource^"_tResourceType_"@"_tCategory,"^")
                If tCategory'="",..g(ResVal,"ia-obs","^")'="" Do ..s(fhirdata,"@IACount^Resource^"_tResourceType_"@"_tCategory,$SELECT(tIACatCount="":1,1:tIACatCount+1),,"^")
            }
        }
    }
}

ClassMethod orderResources(fhirdata) As %Status
{
    If ..g(fhirdata,"Condition")'="" Do ..s(fhirdata,"Condition",..orderBy(..g(fhirdata,"Condition"),["recordedDate|-1"]))
    If ..g(fhirdata,"Encounter")'="" Do ..s(fhirdata,"Encounter",..orderBy(..g(fhirdata,"Encounter"),["period_start|-1"]))
    If ..g(fhirdata,"Appointment")'="" Do ..s(fhirdata,"Appointment",..orderBy(..g(fhirdata,"Appointment"),["start|-1"]))
    If ..g(fhirdata,"AllergyIntolerance")'="" Do ..s(fhirdata,"AllergyIntolerance",..orderBy(..g(fhirdata,"AllergyIntolerance"),["extensionIdx_allergy-discovery-time_valueDateTime|-1"]))
    If ..g(fhirdata,"DiagnosticReport")'="" Do ..s(fhirdata,"DiagnosticReport",..orderBy(..g(fhirdata,"DiagnosticReport"),["issued|-1"]))
}

ClassMethod buildBreadCrumbs(data, fhirdata, objid, config) As %Status
{
    Set tYears = $FNUMBER($HOROLOG-$ZDATETIMEH($PIECE(..g(fhirdata,"Patient.Patient/"_objid_".birthDate"),"T",1),3)/365.25,",",2)
    If $PIECE(tYears,".",1)>0 Set tYears=$PIECE(tYears,".",1)
    Set tName = ..g(fhirdata,"Patient.Patient/"_objid_".nameIdx_official_text")
    Do ..s(data,"breadCrumbs",[{"label":(tName_" - "_tYears_" "_..translate(config,"year(s) old"))}])
}

ClassMethod buildMenu(data, rescount, iacount, objid, dateftr, encid, hlid) As %Status
{
    Set tQueryParams = {}
    Set tIcon = ""
    If dateftr'="" Do ..s(tQueryParams,"dateftr",dateftr)
    //If dateftr'="" Do ..s(tQueryParams,"dateftr",dateftr)  Set tIcon = "pi pi-filter-fill"
    If hlid'="" Do ..s(tQueryParams,"hlid",hlid)
    If encid'="" Do ..s(tQueryParams,"encid",encid)
    Set tIAConfig = ##class(acme.fhirr4.openai).getOpenAIConfig()
    Do ..s(data,"menu",[
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

    ])
    Set tDemMenu = {"label": "Demographics","icon": "pi pi-id-card", "parentLabel":"FHIR", "routerLink": [("/acme/fhirr4/patientData/"_objid_"/patient")],"queryParams":(tQueryParams)}
    If ..g(iacount,"Patient")'="" Do ..s(tDemMenu,"icon",$Select(..g(tDemMenu,"icon")'="":"pi pi-bolt",1:"pi pi-bolt"))
    Do ..s(data,"menu.+",tDemMenu)
    Set tSumMenu = {"label": "Summary","icon": ($SELECT(tIcon'="":tIcon,1:"pi pi-book")), "parentLabel":"FHIR", "routerLink": [("/acme/fhirr4/patientData/"_objid_"/summary")],"queryParams":(tQueryParams)}
    If ..g(iacount,"Encounter")'="" Do ..s(tSumMenu,"icon",$Select(..g(tSumMenu,"icon")'="":"pi pi-bolt",1:"pi pi-bolt"))
    Do ..s(data,"menu.+",tSumMenu)
    Set tAlgMenu = {"label": "Allergies", "parentLabel":"FHIR","icon": "", "badge": (..g(rescount,"AllergyIntolerance")), "badgeSeverity":"warning" , "routerLink": [("/acme/fhirr4/patientData/"_objid_"/allergyintolerance")], "queryParams":(tQueryParams)}
    If ..g(iacount,"AllergyIntolerance")'="" Do ..s(tAlgMenu,"icon",$Select(..g(tAlgMenu,"icon")'="":..g(tAlgMenu,"icon"),1:"pi pi-bolt"))
    If ..g(rescount,"AllergyIntolerance")'="" Do ..s(data,"menu.+",tAlgMenu)
    Set tEncMenu = {"label": "Encounters", "parentLabel":"FHIR","icon": (tIcon), "badge": (..g(rescount,"Encounter")), "routerLink": [("/acme/fhirr4/patientData/"_objid_"/encounter")],"queryParams":(tQueryParams)}
    If ..g(iacount,"Encounter")'="" Do ..s(tEncMenu,"icon",$Select(..g(tEncMenu,"icon")'="":..g(tEncMenu,"icon"),1:"pi pi-bolt"))
    If ..g(rescount,"Encounter")'="" Do ..s(data,"menu.+",tEncMenu)
    Set tCondMenu = {"label": "Conditions", "parentLabel":"FHIR","icon": (tIcon), "badge": (..g(rescount,"Condition")), "routerLink": [("/acme/fhirr4/patientData/"_objid_"/condition")],"queryParams":(tQueryParams)}
    If ..g(iacount,"Condition")'="" Do ..s(tCondMenu,"icon",$Select(..g(tCondMenu,"icon")'="":..g(tCondMenu,"icon"),1:"pi pi-bolt"))
    If ..g(rescount,"Condition")'="" Do ..s(data,"menu.+",tCondMenu)
    Set tImmMenu = {"label": "Immunizations", "parentLabel":"FHIR","icon": (tIcon), "badge": (..g(rescount,"Immunization")), "routerLink": [("/acme/fhirr4/patientData/"_objid_"/immunization")],"queryParams":(tQueryParams)}
    If ..g(iacount,"Immunization")'="" Do ..s(tImmMenu,"icon",$Select(..g(tImmMenu,"icon")'="":..g(tImmMenu,"icon"),1:"pi pi-bolt"))
    If ..g(rescount,"Immunization")'="" Do ..s(data,"menu.+",tImmMenu)
    Set tProcMenu = {"label": "Procedures", "parentLabel":"FHIR","icon": (tIcon), "badge": (..g(rescount,"Procedure")), "routerLink": [("/acme/fhirr4/patientData/"_objid_"/procedure")],"queryParams":(tQueryParams)}
    If ..g(iacount,"Procedure")'="" Do ..s(tProcMenu,"icon",$Select(..g(tProcMenu,"icon")'="":..g(tProcMenu,"icon"),1:"pi pi-bolt"))
    If ..g(rescount,"Procedure")'="" Do ..s(data,"menu.+",tProcMenu)
    Set tDocMenu = {"label": "Clinical Documents", "parentLabel":"FHIR","icon": (tIcon), "badge": (..g(rescount,"DocumentReference")), "routerLink": [("/acme/fhirr4/patientData/"_objid_"/documentreference")],"queryParams":(tQueryParams)}
    If ..g(iacount,"DocumentReference")'="" Do ..s(tDocMenu,"icon",$Select(..g(tDocMenu,"icon")'="":..g(tDocMenu,"icon"),1:"pi pi-bolt"))
    If ..g(rescount,"DocumentReference")'="" Do ..s(data,"menu.+",tDocMenu)
    Set tRADMenu = {"label": "Image Results", "parentLabel":"FHIR","icon": (tIcon), "badge": (..g(rescount,"DiagnosticReport@RAD")), "routerLink": [("/acme/fhirr4/patientData/"_objid_"/rad")],"queryParams":(tQueryParams)}
    If ..g(iacount,"DiagnosticReport@RAD")'="" Do ..s(tRADMenu,"icon",$Select(..g(tRADMenu,"icon")'="":..g(tRADMenu,"icon"),1:"pi pi-bolt"))
    If ..g(rescount,"DiagnosticReport@RAD")'="" Do ..s(data,"menu.+",tRADMenu)
    Set tVitMenu = {"label": "Vital Signs", "parentLabel":"FHIR","icon": (tIcon), "badge": (..g(rescount,"Observation@vital-signs")), "routerLink": [("/acme/fhirr4/patientData/"_objid_"/vital-signs")],"queryParams":(tQueryParams)}
    If ..g(iacount,"Observation@vital-signs")'="" Do ..s(tVitMenu,"icon",$Select(..g(tVitMenu,"icon")'="":..g(tVitMenu,"icon"),1:"pi pi-bolt"))
    If ..g(rescount,"Observation@vital-signs")'="" Do ..s(data,"menu.+",tVitMenu)
    Set tSurMenu = {"label": "Survey", "parentLabel":"FHIR","icon": (tIcon), "badge": (..g(rescount,"Observation@survey")), "routerLink": [("/acme/fhirr4/patientData/"_objid_"/survey")],"queryParams":(tQueryParams)}
    If ..g(iacount,"Observation@survey")'="" Do ..s(tSurMenu,"icon",$Select(..g(tSurMenu,"icon")'="":..g(tSurMenu,"icon"),1:"pi pi-bolt"))
    If ..g(rescount,"Observation@survey")'="" Do ..s(data,"menu.+",tSurMenu)
    Set tLABMenu = {"label": "Lab. Results", "parentLabel":"FHIR","icon": (tIcon), "badge": (..g(rescount,"DiagnosticReport@LAB")), "routerLink": [("/acme/fhirr4/patientData/"_objid_"/lab")],"queryParams":(tQueryParams)}
    If ..g(iacount,"DiagnosticReport@LAB")'="" Do ..s(tLABMenu,"icon",$Select(..g(tLABMenu,"icon")'="":..g(tLABMenu,"icon"),1:"pi pi-bolt"))
    If ..g(rescount,"DiagnosticReport@LAB")'="" Do ..s(data,"menu.+",tLABMenu)
    Set tMedMenu = {"label": "Medications", "parentLabel":"FHIR","icon": (tIcon), "badge": (..g(rescount,"MedicationStatement")+..g(rescount,"MedicationRequest")), "routerLink": [("/acme/fhirr4/patientData/"_objid_"/medicationstatement")],"queryParams":(tQueryParams)}
    If ((..g(iacount,"MedicationStatement")'="")||(..g(iacount,"MedicationRequest")'="")) Do ..s(tMedMenu,"icon",$Select(..g(tMedMenu,"icon")'="":..g(tMedMenu,"icon"),1:"pi pi-bolt"))
    If ((..g(rescount,"MedicationRequest")'="")||(..g(rescount,"MedicationStatement")'="")) {
        Do ..s(data,"menu.+",tMedMenu)
    }
    Set tAppMenu = {"label": "Appointments", "parentLabel":"FHIR","icon": (tIcon), "badge": (..g(rescount,"Appointment")), "routerLink": [("/acme/fhirr4/patientData/"_objid_"/appointment")],"queryParams":(tQueryParams)}
    If ..g(iacount,"Appointment")'="" Do ..s(tAppMenu,"icon",$Select(..g(tAppMenu,"icon")'="":..g(tAppMenu,"icon"),1:"pi pi-bolt"))
    If ..g(rescount,"Appointment")'="" Do ..s(data,"menu.+",tAppMenu)
    Set tFtrMenu = {"label": "Apply Filters", "parentLabel":"FHIR","icon": ($SELECT(dateftr'="":"pi pi-filter-fill",1:"pi pi-filter")), "routerLink": [("/acme/fhirr4/patientData/"_objid_"/filterData")],"queryParams":(tQueryParams)}
    Do ..s(data,"menu.+",tFtrMenu)

    // enable IA Highlights menu if ChatGpt Auth Key is set
    If $Find(..g(tIAConfig,"Authorization"),"<")=0 {
        Set tFtrMenu = {"label": "IA Highlights", "parentLabel":"FHIR","icon": ($SELECT(dateftr'="":"pi pi-bolt",1:"pi pi-bolt")), "routerLink": [("/acme/fhirr4/patientData/"_objid_"/iahighlights")],"queryParams":(tQueryParams)}
        Do ..s(data,"menu.+",tFtrMenu)
    }
}

ClassMethod getGanttChart(fhirdata, config, dateftr)
{
  Set localTimezone = ..g(config,"iris_local_timezone")
  Set today = ..getUTCTime($ZDT($NOW(),3),localTimezone)
  Set (dtIni,dtFin) = 0
  If $PIECE(dateftr,"To",1)'="" Set dtIni = ..getUTCTime($PIECE(dateftr,"To",1),localTimezone)
  If $PIECE(dateftr,"To",2)'="" Set dtFin = ..getUTCTime($PIECE(dateftr,"To",2),localTimezone)
  Set day = 1000 * 60 * 60 * 24
  Set series = []
  Set tEncCt = 0
  Set yAxis = {
        "type": "category",
        "categories": [],
        "accessibility": {
            "description": (..translate(config,"Organization"))
        },
        "min": 0,
        "max": 0
  }
  Set tEncounter=""
  While (..i(fhirdata,,.ResGrpIdx,.ResGrpVal,.ResGrpIt)) {
      If $IsObject(ResGrpVal) {
          While (..i(ResGrpVal,,.ResIdx,.ResVal,.ResIt)) {
              If ResGrpIdx="Encounter" {
                Set start = ..getUTCTime(..g(ResVal,"period_start"))
                Set end = start
                Set category = ..g(ResVal,"serviceProvider_name")
                If ..g(ResVal,"period_end")'="" Set end = ..getUTCTime(..g(ResVal,"period_end"),localTimezone)
                If ..g(ResVal,"period_end")="" Set end = ..getUTCTime($ZDT($NOW(),3),localTimezone)
                Do ..s(series,"0.events.click._fn.0","e")
                Do ..s(series,"0.events.click._fn.1","console.log(e.point.x,e.point.x2,e.point.y,e.start);")
                Do ..s(series,"0.name",..translate(config,"Encounter"))
                Set tEncObj = {}
                If '$Data(tEncounter(category)) {
                  Set tEncounter(category) = tEncCt
                  Do ..s(yAxis,"categories."_tEncCt,category)
                  Do ..s(yAxis,"max",tEncCt)
                  Set tEncCt=tEncCt+1
                } 
                Do ..s(tEncObj,"y",tEncounter(category))
                Do ..s(tEncObj,"name",..translate(config,..g(ResVal,"class_code")))
                Do ..s(tEncObj,"id",..g(ResVal,"id"))
                Do ..s(tEncObj,"start",start)
                Do ..s(tEncObj,"end",end)
                If ((end-start) < day) Do ..s(tEncObj,"milestone","true","boolean")
                if ((start<dtIni)||(dtIni=0)) Set dtIni=start
                if ((end>dtFin)||(dtFin=0)) Set dtFin=end
                Do ..s(series,"0.data.+",tEncObj)
              } ElseIf ResGrpIdx="DiagnosticReport" {
              } ElseIf ResGrpIdx="Observation" {
              } ElseIf ResGrpIdx="ServiceRequest" {
              } ElseIf ResGrpIdx="DocumentReference" {
              } ElseIf ResGrpIdx="Immunization" {
              } ElseIf ResGrpIdx="Condition" {
              } ElseIf ResGrpIdx="MedicationStatement" {
              } ElseIf ResGrpIdx="MedicationRequest" {
              } ElseIf ResGrpIdx="Appointment" {
              }
          }
      }
  }
  if dtIni = 0 Set dtIni = today
  if dtFin = 0 Set dtFin = today
  Set tGanttChartOptions = {
        "title": {
            "text": (..translate(config,"medical history timeline"))
        },
        "xAxis": {
            "min": (dtIni - (day * 10)),
            "max": (dtFin + (day * 10)),
            "dateTimeLabelFormats":  (..nvl(..g(config,"highcharts.dateTimeLabelFormats"),{})),
            "events": {
                "click":{"_fn":["e",("console.log(this.moment(e.point.x).format('YYYY-MM-DD'),this.moment(e.point.x2).format('YYYY-MM-DD'));")]},
                "afterSetExtremes": {
                  "_fn": ["event",("this._applyZoomFilter({'min':(event.min),'max':(event.max)});")]
                }
            }
        },
        "accessibility": {
            "keyboardNavigation": {
                "seriesNavigation": {
                    "mode": "serialize"
                }
            },
            "point": {
                "descriptionFormatter": {"_fn": ["point", 
                    ("var dependency = point.dependency && point.series.chart.get(point.dependency).name,dependsOn = dependency ? ' Depends on ' + dependency + '.' : '';"_
                    "return Highcharts.format("_
                        "'{point.yCategory}. Start {point.x:%Y-%m-%d}, end {point.x2:%Y-%m-%d}.{dependsOn}',"_
                        "{ point, dependsOn }"_
                    ");")]
                  }
            }
        },
        "lang": {
            "accessibility": {
                "axis": {
                    "xAxisDescriptionPlural": "The chart has a two-part X axis showing time in both week numbers and days."
                }
            }
        },
        "scrollbar": {
            "enabled": true
        },
        "rangeSelector": {
            "enabled": true,
            "selected": 4
        },
        "navigator": {
            "enabled": true,
            "liveRedraw": true,
            "series": {
                "type": "gantt",
                "pointPlacement": 0.5,
                "pointPadding": 0.25,
                "accessibility": {
                    "enabled": false
                }
            }
        },
        "yAxis": (yAxis),
        "resizable": {
          "enabled": true
        },      
        "series":(series)
  }
  Quit {
    "type":"highcharts-gantt",
    "options":(tGanttChartOptions)
  }
}

}
