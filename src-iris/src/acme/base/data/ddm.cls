Class acme.base.data.ddm Extends %Persistent
{

Property repository As %String;

Property domain As %String;

Property payloadId As %String;

Property payload As %Stream.GlobalCharacter;

Index repoDomainIdIdx On (repository, domain, payloadId) [ Unique ];

Index repoDomainIdx On (repository, domain);

Storage Default
{
<Data name="ddmDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>repository</Value>
</Value>
<Value name="3">
<Value>domain</Value>
</Value>
<Value name="4">
<Value>payload</Value>
</Value>
<Value name="5">
<Value>payloadId</Value>
</Value>
</Data>
<DataLocation>^acme.base.data.ddmD</DataLocation>
<DefaultData>ddmDefaultData</DefaultData>
<IdLocation>^acme.base.data.ddmD</IdLocation>
<IndexLocation>^acme.base.data.ddmI</IndexLocation>
<StreamLocation>^acme.base.data.ddmS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
