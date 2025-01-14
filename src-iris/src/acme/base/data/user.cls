Class acme.base.data.user Extends (%Persistent, %XML.Adaptor)
{

Property userId As %String(MAXLEN = "");

Property userName As %String(MAXLEN = "");

Property email As %String(MAXLEN = "");

Property password As %String(MAXLEN = "");

Property authToken As %String(MAXLEN = "");

Property photoUrl As %String(MAXLEN = "", XMLIO = "CALC");

Property prefLanguage As %String;

Property pwdAttempts As %Integer;

Property confirmEmail As %Boolean;

Property devMode As %Boolean;

Index emailIndex On email;

Index userIdIndex On userId [ Unique ];

Storage Default
{
<Data name="userDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>userName</Value>
</Value>
<Value name="3">
<Value>email</Value>
</Value>
<Value name="4">
<Value>password</Value>
</Value>
<Value name="5">
<Value>authToken</Value>
</Value>
<Value name="6">
<Value>photoUrl</Value>
</Value>
<Value name="7">
<Value>prefLanguage</Value>
</Value>
<Value name="8">
<Value>pwdAttempts</Value>
</Value>
<Value name="9">
<Value>confirmEmail</Value>
</Value>
<Value name="10">
<Value>userId</Value>
</Value>
<Value name="11">
<Value>devMode</Value>
</Value>
</Data>
<DataLocation>^acme.base.data.userD</DataLocation>
<DefaultData>userDefaultData</DefaultData>
<IdLocation>^acme.base.data.userD</IdLocation>
<IndexLocation>^acme.base.data.userI</IndexLocation>
<StreamLocation>^acme.base.data.userS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
