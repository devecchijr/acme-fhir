Class acme.base.utilsApi Extends apiPub.core.jsonBuilder [ ProcedureBlock ]
{

ClassMethod getJSONContent(fileName As %String) As %Library.DynamicObject
{
    If ##class(%Library.File).Exists("/acme-config/"_fileName_".json")=1 {
       Quit ..getJSONFromFile("/acme-config/"_fileName_".json")
    }
    Quit {}
}

ClassMethod getBaseConfig() As %Library.DynamicObject
{
    //Create config file if it does'nt exists
    If ##class(%Library.File).Exists("/acme-config/base.json")=0 {
        Set tConfig = { 
            "SMTP2GOApiKey" : "<SMTP2GOKey>",
            "SMTP2GOFrom" : "ACME 4 HEALTH <email@domain.com>",
            "SMTP2GOSSL" : "<SSLName>"
        }
        Set tSC = ..saveJSONFile(tConfig,"/acme-config/base.json")
        If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC) }
    } Else {
        Set tConfig = ..getJSONFromFile("/acme-config/base.json")
    }
    Quit tConfig
}

ClassMethod getTranslations(userid, Output locale, Output dateformat) As %Library.DynamicObject
{
    Set tConfig = {}
    Set dateformat = "MM/DD/YY"
    Set locale = "en"
    Set tUserData = ##class(acme.base.data.user).%OpenId(userid)
    If $IsObject(tUserData),tUserData.prefLanguage'="" {
        Set locale = tUserData.prefLanguage
        Set tConfig = ..getLocale(locale)
        Set dateformat = ..g(tConfig,"global_chartDateFormat")
    }
    Quit tConfig
}

ClassMethod getMimeType(image As %Stream.GlobalBinary) As %String
{
    Do image.Rewind()
    //first characters
    Set tstr = $E(image.ReadLine(),1,16)
    Do image.Rewind()
    Set fc = $SYSTEM.Encryption.Base64Encode(tstr)
    If fc["iVBOR" Quit "png"
    If fc["/9j/4AAQ" Quit "jpeg"
    If fc["R0lGODlh" Quit "gif"
    If fc["SUkq" Quit "tiff"
    If (fc["UklGR")||($E(fc,1,3)["Qk2") Quit "bmp"
    Quit ""
}

ClassMethod getColors(minShade As %Integer = 100, maxShade As %Integer = 900) As %Library.DynamicObject
{
    Set color = "--primary-color"
    Set result=[(color)]
    Set colors = ["blue","green","yellow","cyan","surface","indigo","red","teal"]
    Set shades = [100,200,300,400,500,600,700,800,900]
    Set tShIt = shades.%GetIterator()
    While (tShIt.%GetNext(.shKey,.shValue)) {
        If shValue<minShade continue
        If shValue>maxShade continue
        Set tColIt = colors.%GetIterator()
        While (tColIt.%GetNext(.colKey,.colValue)) {
            Do result.%Push("--"_colValue_"-"_shValue)
        }
    }
    quit result
}

ClassMethod saveFile(image As %Stream.GlobalBinary, fileName As %String) As %Status
{
    Set timg=##class(%Stream.FileBinary).%New()
    Set tSC=timg.LinkToFile(fileName)
    Do timg.CopyFrom(image)
    Do timg.%Save()
    Quit $$$OK
}

/// @apiPub[tag="utils"]
/// @apiPub[protected="true"]
/// @apiPub[trace="false"]
/// @apiPub[path="/jsonfile"]
ClassMethod saveJSONFile(obj As %DynamicObject, path As %String) As %Status [ WebMethod ]
{
    Set tjson=##class(%Stream.FileCharacter).%New()
    Set tSC=tjson.LinkToFile(path)
    Do obj.%ToJSON(tjson)
    Do tjson.%Save()
    Quit $$$OK
}

/// Gets i18n file for translation
/// @apiPub[path="/config/locale/{lang}"]
/// @apiPub[tag="config"]
/// @apiPub[protected="false"]
/// @apiPub[charset="UTF-8"]
ClassMethod getLocale(lang As %String) As %Library.DynamicObject [ WebMethod ]
{
    if '$Data(lang)||lang="" set lang = "en"
    return ..getJSONContent($ZConvert($Replace(lang,"-",""),"L"))
}

/// @apiPub[tag="utils"]
/// @apiPub[protected="true"]
/// @apiPub[trace="false"]
/// @apiPub[path="/jsonfile"]
ClassMethod getJSONFromFile(path As %String) As %DynamicObject [ WebMethod ]
{
    Set tFileStream=##class(%Stream.FileCharacter).%New()
    Set tSC=tFileStream.LinkToFile(path)
    If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC)}
    If tFileStream.SizeGet()=0 Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> file "_path_" doesn't exist"))
    Quit {}.%FromJSON(tFileStream)
}

ClassMethod deleteFile(fileName As %String) As %Status
{
    Set tSC = $$$OK
    Set tFileName = "/acme-assets/"_fileName
    If (##class(%File).Exists(tFileName)) {
        Do ##class(%File).%Delete(tFileName)
    }
    Quit tSC
}

/// get a file or image
/// @apiPub[tag="utils"]
/// @apiPub[path="/file/{fileName}"]
/// @apiPub[response.outputType="application/octet-stream"]
/// @apiPub[charset="ISO-8859-1"]
/// @apiPub[protected="true"]
Method getFile(fileName As %String) As %Stream.FileBinary [ WebMethod ]
{
    Set tFileName = "/acme-assets/"_fileName
    Set tFileStream=##class(%Stream.FileBinary).%New()
    Set tSC=tFileStream.LinkToFile(tFileName)
    If 'tSC { Throw ##Class(%Exception.StatusException).CreateFromStatus(tSC)}
    If tFileStream.SizeGet()=0 Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> file doesn't exist"))
    Quit tFileStream
}

ClassMethod findElement(arr As %Library.DynamicArray, value As %String) As %Numeric
{
    Set l = $listfromstring($e(arr.%ToJSON(),2,*-1),",")
    Quit $listfind(l,value)
}

/// Save a document data model obj (schemaless json) id is required
/// @apiPub[tag="utils"]
/// @apiPub[protected="true"]
/// @apiPub[verb="put"]
/// @apiPub[path="ddm"]
ClassMethod jupdate(repoName As %String, domainKey As %String, payload As %Library.DynamicObject, keyName As %String = "id") As %Library.DynamicObject [ WebMethod ]
{
    If repoName="" Set repoName = "acme"
    If keyName="" Set keyName = "id"
    If ..g(payload,keyName) = "" Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> key is required"))
    If '##class(acme.base.data.ddm).repoDomainIdIdxExists(repoName,domainKey,..g(payload,keyName)) Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> object id doesn't exist"))
    Quit ..jsave(repoName, domainKey, payload, keyName)
}

/// Save a document data model obj (schemaless json)
/// @apiPub[tag="utils"]
/// @apiPub[protected="true"]
/// @apiPub[path="ddm"]
/// @apiPub[charset="UTF-8"]
ClassMethod jsave(repoName As %String, domainKey As %String, payload As %Library.DynamicObject, keyName As %String = "id") As %Library.DynamicObject [ WebMethod ]
{
    If repoName="" Set repoName = "acme"
    If keyName="" Set keyName = "id"
    If domainKey="" Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> domainKey param is required"))
    If '$DATA(payload) Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> payload is required"))
    Set tKey = ..g(payload,keyName)
    If tKey="" Set tKey = $I(^acme.base.data.ddmX(repoName,domainKey))
    Set tObj = ##class(acme.base.data.ddm).repoDomainIdIdxOpen(repoName,domainKey,tKey)
    If '$IsObject(tObj) {
        Set tObj = ##class(acme.base.data.ddm).%New()
        Set tObj.repository = repoName
        Set tObj.domain = domainKey
        Do ..s(payload,keyName,tKey)
        Set tObj.payloadId = tKey
    }
    Do payload.%ToJSON(tObj.payload)
    Do tObj.%Save()
    Quit payload
}

/// Retrieve a document data model obj (schemaless json)
/// @apiPub[protected="true"]
/// @apiPub[tag="utils"]
/// @apiPub[path="ddm"]
/// @apiPub[charset="UTF-8"]
ClassMethod jretrieve(repoName As %String, domainKey As %String, key As %String) As %Library.DynamicObject [ WebMethod ]
{
    If repoName="" Set repoName = "acme"
    Set repoName=repoName
    If domainKey="" Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> domainKey param is required"))
    If key="" Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> key param is required"))
    Set tObj = ##class(acme.base.data.ddm).repoDomainIdIdxOpen(repoName,domainKey,key)
    If '$IsObject(tObj) Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> object id doesn't exist"))
    Return {}.%FromJSON(tObj.payload)
}

/// delete a document data model obj (schemaless json)
/// @apiPub[protected="true"]
/// @apiPub[tag="utils"]
/// @apiPub[verb="delete"]
/// @apiPub[path="ddm"]
ClassMethod jdelete(repoName As %String, domainKey As %String, key As %String) As %Status [ WebMethod ]
{
    If repoName="" Set repoName = "acme"
    Set repoName=repoName
    If domainKey="" Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> domainKey param is required"))
    If key="" Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> key param is required"))
    Set tObj = ##class(acme.base.data.ddm).repoDomainIdIdxOpen(repoName,domainKey,key)
    If '##class(acme.base.data.ddm).repoDomainIdIdxExists(repoName,domainKey,key) Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> object id doesn't exist"))
    Do ##class(acme.base.data.ddm).repoDomainIdIdxDelete(repoName,domainKey,key)
    Return $$$OK
}

/// Retrieve a list of document data model obj (schemaless json)
/// @apiPub[protected="true"]
/// @apiPub[tag="utils"]
/// @apiPub[path="ddm/list"]
/// @apiPub[charset="UTF-8"]
ClassMethod jretrieveList(repoName As %String, domainKey As %String, page As %String, pagesize As %String) As %Library.DynamicObject [ WebMethod ]
{
    Set maxResults = 0
    If repoName="" Set repoName = "acme"
    Set repoName=repoName
    If domainKey="" Throw ##Class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "<404> domainKey param is required"))
    Set tData = []
    Set tPage=1
    Set tIdx=$Order(^acme.base.data.ddmI("repoDomainIdx"," "_$ZCONVERT(repoName,"U")," "_$ZCONVERT(domainKey,"U"),""))
    While tIdx'="" {
        set tPush=1
        Set maxResults=maxResults+1
        If +page'=0,+pagesize'=0 {
            Set tPush=(page=tPage)
            If maxResults#pagesize=0 Set tPage=tPage+1
        }
        If (tPush) {
            Set tObj = ##class(acme.base.data.ddm).%OpenId(tIdx)
            If $IsObject(tObj) Do tData.%Push({}.%FromJSON(tObj.payload)) 
        }
        Set tIdx=$Order(^acme.base.data.ddmI("repoDomainIdx"," "_$ZCONVERT(repoName,"U")," "_$ZCONVERT(domainKey,"U"),tIdx))
    }
    /*
    Set sql = "SELECT ID FROM acme_base_data.ddm where repository='"_repoName_"' and ""domain""='"_domainKey_"' order by 1"
    Set stat = ##class(%SQL.Statement).%New()
	Set Status = stat.%Prepare(sql)
	Set rset = stat.%Execute()
    Set tPage=1
	While rset.%Next() {
        set tPush=1
        Set maxResults=maxResults+1
        If +page'=0,+pagesize'=0 {
            Set tPush=(page=tPage)
            If maxResults#pagesize=0 Set tPage=tPage+1
        }
        If (tPush) {
            Set tObj = ##class(acme.base.data.ddm).%OpenId(rset.ID)
            Do tData.%Push({}.%FromJSON(tObj.payload)) 
        }
	}
    */
    Set tList={"maxResults":(maxResults),"data":(tData)}
    Return tList
}

ClassMethod DTConvertion()
{
    Write "local datetime: ",$ZDATETIME($HOROLOG,3),!
    Set secs=$ZDATETIME($HOROLOG,-2)
    Write "UTC seconds since 1970: ",secs,!
    Set posix=##class(%PosixTime).UnixTimeToLogical(secs)
    Write "PosixTime encoded value: ",posix,!
    Set datetime=##class(%PosixTime).LogicalToOdbc(posix)
    Write "UTC datetime: ",datetime,!
    Set secs2=##class(%PosixTime).LogicalToUnixTime(posix)
    Write "UTC seconds since 1970: ",secs2,!
    Set htime=$ZDATETIMEH(secs2,-2)
    Write "local datetime: ",$ZDATETIME(htime,3)
}

ClassMethod pivotTable(source As %Library.DynamicObject, params As %Library.DynamicObject, filter As %String = "1", rowIdName = "rowId") As %Library.DynamicObject
{
    If ..g(params,"values","^")="" do ..s(params,"values",[])
    Set operations=..g(params,"operations","^")
    If operations="" Set operations=[] 
    Set tValues = {}
    Set tGrp = {"columns":[],"rows":[]}
    If '$IsObject(source) Quit tGrp 
    Set tShowValues = ..g(params,"showValues","^")
    Set (row,col,val)=""
    Set filteredSrc = ..filter(source,filter)
    While (..i(filteredSrc,,.resItemKey,.resItemValue,.resItemIt)) {
        Set tRowProp = ""
        While ..i(params,"rows",.rowKey,.rowValue,.rowIt) {
            Set tCmd = "(value,path) Quit "_$Select($find(rowValue,"_fn:"):$Piece(rowValue,"_fn:",2),1:"..g(value,path,""^"")")
            Set tValue=$XECUTE(tCmd,resItemValue,rowValue)
            Set tRowProp = tRowProp_$Select(tRowProp'="":"|"_tValue,1:tValue)
        }
        Set tColProp = ""
        While ..i(params,"columns",.colKey,.colValue,.colIt) {
            Set tCmd = "(value,path) Quit "_$Select($find(colValue,"_fn:"):$Piece(colValue,"_fn:",2),1:"..g(value,path,""^"")")
            Set tValue=$XECUTE(tCmd,resItemValue,colValue)
            Set tColProp = tColProp_$Select(tColProp'="":"|"_tValue,1:tValue)
        }
        Set tValProp = ""
        If tRowProp'="",'$D(row("order",tRowProp)) {
            Set row("order",tRowProp)=""
        }
        If tColProp'="",'$D(col("order",tColProp)) {
            Set col("order",tColProp)=""
        }
        If tRowProp'="",tColProp'="" {
            Set val(tRowProp,tColProp,resItemKey)=""
        }
}
    Set colOrder = ..g(params,"colOrder")
    If colOrder = ""  Set colOrder = 1
    Set tIdx = $Order(col("order",""),colOrder)
    While tIdx'="" {
        Set col(tIdx)=..g(tGrp,"columns").%Size()
        For i=1:1:$Length(tIdx,"|") {
              Do ..s(tGrp,"columns"_$Select(i=1:"",1:i)_".+",$Piece(tIdx,"|",i))
        }
        Set tIdx = $Order(col("order",tIdx),colOrder)
    }
    Set rowOrder = ..g(params,"rowOrder")
    If rowOrder = ""  Set rowOrder = 1
    Set tId = 1
    Set tIdx = $Order(row("order",""),rowOrder)
    While tIdx'="" {
        Set row(tIdx)=..g(tGrp,"rows").%Size()
        Set tRowObj = {}
        For i=1:1:$Length(tIdx,"|") {
            Do ..s(tRowObj,$Piece(..g(params,"rows."_(i-1)),"_fn:",1),$Piece(tIdx,"|",i),,"^")
        }
        If ..g(tRowObj,rowIdName)="" {
            Do ..s(tRowObj,rowIdName,tId,,"^")
            Set tId = tId+1
        }
        Do ..s(tGrp,"rows.+",tRowObj)                
        Set tIdx = $Order(row("order",tIdx),rowOrder)
    }
    Set tIdxR = $Order(val(""),1)
    While tIdxR'="" {
        Set tIdxC = $Order(val(tIdxR,""),1)
        While tIdxC'="" {
            Set tIdxI = $Order(val(tIdxR,tIdxC,""),1)
            While tIdxI'="" {
                Do ..s(tValues,row(tIdxR)_"|"_col(tIdxC)_".+",tIdxI)
                Set tIdxI = $Order(val(tIdxR,tIdxC,tIdxI),1)
            }
            Set tIdxC = $Order(val(tIdxR,tIdxC),1)
        }
        Set tIdxR = $Order(val(tIdxR),1)
    }
    Set tPropOp=""
    While ..i(tValues,,.valKey,.valValue,.tPvtValIt) {
            Set tRowIdx = $Piece(valKey,"|",1)
            Set tColIdx = $Piece(valKey,"|",2)
            Set tRowObj = ..g(tGrp,"rows."_tRowIdx)
            Set tColVal = $Piece(..g(tGrp,"columns."_tColIdx),"_fn:",1)
            Do ..s(tGrp,"rows^"_tRowIdx_"^"_tColVal_"|count",valValue.%Size(),,"^")
            While ..i(valValue,,.objIdx,.objKey,.objIt)
            {
                Set tObj = filteredSrc.%Get(objKey)
                While ..i(params,"values",.propKey,.propKeyValue,.tPropIt) {
                    Set operation = ..g(operations,propKey,"^")
                    Set prop = $Piece(propKeyValue,"_fn:",1)
                    If prop="" Set prop="value"
                    Set tPropOp(prop)=operation
                    Set tCmd = "(value,path) Quit "_$Select($find(propKeyValue,"_fn:"):$Piece(propKeyValue,"_fn:",2),1:"..g(value,path,""^"")")
                    Set tVal=$XECUTE(tCmd,tObj,propKeyValue)
                    If propKey = 0 {
                        Do ..s(tGrp,"rows^"_tRowIdx_"^"_tColVal,tVal,,"^")
                    } Else {
                        If tVal'="" Do ..s(tGrp,"rows^"_tRowIdx_"^"_tColVal_"|"_$Piece(propKeyValue,"_fn:",1),tVal,,"^")
                    }
                    If tVal=+tVal,prop'="",operation'="" {
                        If '$Data(tOp("avg",prop)) Set tOp("avg",prop) = 0
                        If '$Data(tOp("sum",prop)) Set tOp("sum",prop) = 0
                        If '$Data(tOp("min",prop)) Set tOp("min",prop) = ""
                        If '$Data(tOp("max",prop)) Set tOp("max",prop) = ""
                        Set tOp("sum",prop)=tOp("sum",prop)+tVal
                        Set tOp("avg",prop)=tOp("sum",prop)/valValue.%Size()
                        If tOp("min",prop)="" Set tOp("min",prop)=+tVal
                        If +tVal<tOp("min",prop) Set tOp("min",prop) = tVal
                        If tOp("max",prop)="" Set tOp("max",prop)=+tVal
                        If +tVal>tOp("max",prop) Set tOp("max",prop) = tVal
                    }
                }
            }
            Set tOpIdx=$Order(tOp(""))
            While tOpIdx'="" {
                Set tPropIdx=$Order(tOp(tOpIdx,""))
                While tPropIdx'="" {
                    If $Data(tPropOp(tPropIdx)),tPropOp(tPropIdx)=tOpIdx {
                        Do ..s(tGrp,"rows^"_tRowIdx_"^"_tColVal_$Select(tPropIdx'="value":"|"_tPropIdx,1:"")_"|"_tOpIdx,tOp(tOpIdx,tPropIdx),,"^")
                    }
                    Set tPropIdx=$Order(tOp(tOpIdx,tPropIdx))
                }
                Set tOpIdx=$Order(tOp(tOpIdx))
            }
            K tOp
    }
    K col,row,val
    If tShowValues Do ..s(tGrp,"values",tValues)
    Quit tGrp
}

ClassMethod addBackEndLinks(urlArray, containers, gridConfig As %String = "col-12", path As %String = "Backend")
{
    If urlArray.%Size()<=0 Quit
    Do ..s(containers,path_"^layout^value","grid justify-content-center",,"^")
    Do ..s(containers,path_"^layout^0a",gridConfig,,"^")
    Do ..s(containers,path_"^layout^0a.0a.value",{"type":"inputswitch","class":"","onClick":"fn:containerControl.card.visible=!containerControl.card.visible;"},,"^")
    Do ..s(containers,path_"^layout^0a.0b","c:groupcard",,"^")
    Do ..s(containers,path_"^groupcard^layout^value","c:card",,"^")
    Do ..s(containers,path_"^card",{"type":"div","class":"card","visible":false},,"^")
    while ..i(urlArray,,.idx,.val,.it) {
        Set node=..getNode(idx+1)
        Do ..s(containers,path_"^layout^0a."_..getNode(idx+3),"c:sidebar"_node,,"^")
        Do ..s(containers,path_"^layout^0a."_..getNode(idx+3)_".content.value",{"type":"embedContent","width":1400,"height":800,"src":(..g(val,"url"))},,"^")
        Do ..s(containers,path_"^groupcard^layout^"_node,"c:btn"_node,,"^")
        Do ..s(containers,path_"^btn"_node,{"type":"button","visible":true,"class":"p-button-raised p-button-text p-button-plain mr-3","label":(..g(val,"label")),"onClick":("fn:containerControl.sidebar"_node_".visible=!containerControl.sidebar"_node_".visible;")},,"^")
        Do ..s(containers,path_"^sidebar"_node,{"type":"sidebar","visible":false},,"^")
    }
}

ClassMethod getNode(number As %Integer) As %String
{
    Set tChar="abcdefghijklmnopqrstuvwxyz"
    Set tMod = $Select(number#($L(tChar))=0:$L(tChar),1:number#($L(tChar)))
    Set tDiv=($Number(number/($L(tChar)),2))-.01
    If tDiv<1 Set tDiv="0.00"
    Quit $P(tDiv,".",1)_$Extract(tChar,tMod)
}

ClassMethod isDateBetween(date As %String, fromDate As %String = "", toDate As %String = "") As %Boolean
{
    If date = "" Quit 0
    If fromDate="",toDate="" Quit 0
    If toDate'="",$Piece($Tr(toDate,"TZ"," ")," ",2)="" Set toDate=toDate_" 23:59:59"
    If toDate="" Quit +$Replace($ZDTH($Tr(date,"TZ"," "),3,5),",",".")>=+$Replace($ZDTH($Tr(fromDate,"TZ"," "),3,5),",",".")
    If fromDate="" Quit +$Replace($ZDTH($Tr(date,"TZ"," "),3,5),",",".")<=+$Replace($ZDTH($Tr(toDate,"TZ"," "),3,5),",",".")
    Quit (+$Replace($ZDTH($Tr(date,"TZ"," "),3,5),",",".")>=+$Replace($ZDTH($Tr(fromDate,"TZ"," "),3,5),",","."))&&(+$Replace($ZDTH($Tr(date,"TZ"," "),3,5),",",".")<=+$Replace($ZDTH($Tr(toDate,"TZ"," "),3,5),",","."))
}

ClassMethod getUTCTime(date As %String, localTimeZone As %String = "") As %Numeric
{
  Set date=$TRANSLATE(date,"TZ"," ")
  Set timeZoneCorr=0
  Set timeZone = $E(date,20,25)
  If $L(timeZone)=6,$E(timeZone,4,4)=":",localTimeZone'="" {
     Set hr=+$Piece(timeZone,":",1)
     Set min=+$Piece(timeZone,":",2)
     Set hmls=+($Piece(localTimeZone,":",1))-(hr)*60*60*1000
     Set mmls=+($E(localTimeZone,1,1)_$Piece(localTimeZone,":",2))-(min)*60*1000
     Set timeZoneCorr=hmls+mmls
  }
  Quit 86400000*($P($ZDTH(date,3,6),",",1)-47117)+($P($ZDTH(date,3,6),",",2)*1000)+(timeZoneCorr)
}

ClassMethod translate(config, term As %String)
{
    Quit ..nvl(..g(config,term),term)
}

}
