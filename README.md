# InterSystems ACME-FHIR Demo

##  Backend (Apis) and FHIR Server for Acme 4 Health application

1. Clone or download this repostory to your local machine.
2. (optional) Edit the webserver port in `.env`.
3. (optional, default: SYS) Change IRIS password in `./src-iris/irispw.txt`.
4. Build the container images: `docker-compose build`.
5. Create and run containers: `docker-compose up -d`
6. The IRIS management portal: http://localhost:8081/csp/sys/%25CSP.Portal.Home.zen
7. The Acme Application APIs can be seen at http://localhost:8081/swagger-ui/index.html?url=http://localhost:8081/acme/fhirr4/_spec.
8. The FHIR EndPoint is /fhirserver/fhir/r4/. All the patients in the fhirdata folder was loaded
9. (Optional) You can point the application to another fhir r4 endpoint changing the config file at 
 /volumes/iris/config/fhirr4.json

Additonal commands

- Stop Demo: `docker-compose stop`
- Start Demo: `docker-compose start`
- Delete all docker resources of the demo: `docker-compose down`