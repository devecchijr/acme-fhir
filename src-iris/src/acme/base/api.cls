Class acme.base.api Extends acme.base.utilsApi [ ProcedureBlock ]
{

/// Gets base path for modules (moduleId is the first root param)
/// @apiPub[path="/base/modulePaths"]
/// @apiPub[tag="base"]
/// @apiPub[protected="true"]
ClassMethod getModulePaths() As %Library.DynamicObject [ WebMethod ]
{
    // when the module use the same host as the base module, there is no need to inform the server and port ex:"http://server:port/module/path"
    // only the root path
    /*
    Return {
        "fhirai":"fhirai",
        "fhirr4":"fhirr4",
        "config":"config"
    }

    */


    Return {
        "fhirr4":"fhirr4",
        //"fhirai":"fhirai",
        "config":"config"
    }
}

/// Gets backend dynamic menu content
/// @apiPub[path="/base/menu/{userid}"]
/// @apiPub[tag="base"]
/// @apiPub[charset="UTF-8"]    
/// @apiPub[protected="true"]
ClassMethod getMenu(userid As %String, baseUrl As %String) As %Library.DynamicObject [ WebMethod ]
{
    //define groups and their menu order
    return {
            "menu":[
            {
                "label": "FHIR", "icon": "pi pi-copy", "items":[]
            }
    ]}
}

/// get users info after authentication
/// @apiPub[tag="config"]
/// @apiPub[path="/config/userinfo"]
/// @apiPub[protected="true"]
Method userinfo(user As %Library.DynamicObject, pHttpReq As apiPub.service.message) As %Library.DynamicObject [ WebMethod ]
{
    Set tEmail = $ZConvert(..JGet(user,"email"),"L")
    Set tUserId = $ZConvert(..JGet(user,"sub"),"L")
    Set tUser = ##class(acme.base.data.user).userIdIndexOpen(tUserId)
    If '$IsObject(tUser) {
        Set tUser = ##class(acme.base.data.user).%New()
        Set tUser.userId = tUserId
        Set tUser.email = tEmail
        Set tUser.userName = ..JGet(user,"nickname")
        Set tUser.prefLanguage = "en"
        Set tUser.devMode = 0
        Set tSC = tUser.%Save()
        If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC) }        
    }
    If '$IsObject(tUser) Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<401> invalid login"))
    Set tResp = {
        "userId": (tUser.%Id()),
        "lang": ($Select(tUser.prefLanguage'="":tUser.prefLanguage,1:"en"))
    }
    Quit tResp
}

/// Gets fhir backend dynamic content
/// @apiPub[path="/config/form/{formid}/{userid}"]
/// @apiPub[tag="config"]
/// @apiPub[protected="true"]
/// @apiPub[charset="UTF-8"]    
ClassMethod getConfigForm(userid As %String, formid As %String, objid As %String, subid As %String) As %Library.DynamicObject [ WebMethod ]
{
    if formid="userconfig" {
        return ..configform(userid, objid, subid)
    }
    return {}
}

/// Gets backend dynamic menu content
/// @apiPub[path="/config/menu/{userid}"]
/// @apiPub[tag="config"]
ClassMethod getConfigMenu(userid As %String) As %Library.DynamicObject [ WebMethod ]
{
        Return {
        }
}

/// Save config form
/// @apiPub[path="/config/userconfig"]
/// @apiPub[tag="config"]
/// @apiPub[protected="true"]
/// @apiPub[verb="put"]
/// @apiPub[charset="UTF-8"]  
ClassMethod saveConfigForm(configForm As %Library.DynamicObject) As %Library.DynamicObject [ WebMethod ]
{
    Set tUserData = ##class(acme.base.data.user).%OpenId(..JGet(configForm,"userId"))
    If '$IsObject(tUserData) {
        Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "User doesn't Exist"))
    }
    Set tUserData.prefLanguage = ..g(configForm,"lang")
    Set tUserData.devMode = (..g(configForm,"devMode")=1)
    Do tUserData.%Save()
    return configForm
}

ClassMethod configform(userid, objid, subid) As %Library.DynamicObject
{
    Set tUserData = ##class(acme.base.data.user).%OpenId(userid)
    if '$ISOBJECT(tUserData) Return {}
    Set tResponse = {}
    Set tUserConfigC = {
        "layout":{
            "value":"grid justify-content-center",
            "a":"col-8",
            "a.a":"card",
            "a.a.a":"c:configForm"
        },
        "configForm":{
            "type":"form",
            "form":"userConfig"
        }
    }
    Do ..JSet(tResponse,"containers.userConfigC",tUserConfigC)
    Set tUserConfigForm = ..getJSONContent("configPreferencesModel")
    Set tCR = $Char(10,13)
    Set tSaveFunc = "this.userService.setLang(lang);"
    Do ..s(tResponse,"functions._setLang.0","lang")
    Do ..s(tResponse,"functions._setLang.1",tSaveFunc)
    Do ..s(tResponse,"forms.userConfig",tUserConfigForm)
    Do ..s(tResponse,"data.config.userId",userid)
    Do ..s(tResponse,"data.config.lang",$Select(tUserData.prefLanguage'="":tUserData.prefLanguage,1:"en"))
    Do ..s(tResponse,"data.config.devMode",$Select(tUserData.devMode=1:"true",1:"false"),"boolean")
    Quit tResponse
}

/// Gets i18n file for translation (keep protected = false)
/// @apiPub[path="/config/locale/{lang}"]
/// @apiPub[tag="config"]
/// @apiPub[protected="false"]
/// @apiPub[charset="UTF-8"]
ClassMethod getLocale(lang As %String) As %Library.DynamicObject [ WebMethod ]
{
    if '$Data(lang)||lang="" set lang = "en"
    return ..getJSONContent($ZConvert($Replace(lang,"-",""),"L"))
}

}
