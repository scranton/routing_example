## Spring SOAP

This module contains articles about SOAP APIs with Spring

## Building

```shell
./mvnw clean package
```

## Running

Start SOAP Server

```shell
java -jar target/gs-producing-web-service-0.1.0.jar --version=V2
```

Make client request

```shell
curl --silent --header "content-type: text/xml" -d @request.xml http://localhost:8080/ws | xmllint --format -
```

Should produce following result. Not the getCountryResponse/version entity value should match `--version` setting in SOAP Server.

```shell
<?xml version="1.0"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
  <SOAP-ENV:Header/>
  <SOAP-ENV:Body>
    <ns2:getCountryResponse xmlns:ns2="http://spring.io/guides/gs-producing-web-service">
      <ns2:version>V2</ns2:version>
      <ns2:country>
        <ns2:name>Spain</ns2:name>
        <ns2:population>46704314</ns2:population>
        <ns2:capital>Madrid</ns2:capital>
        <ns2:currency>EUR</ns2:currency>
      </ns2:country>
    </ns2:getCountryResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
```

### Relevant articles

* <https://spring.io/guides/gs/producing-web-service>
