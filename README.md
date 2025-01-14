# InterSystems ACME-FHIR Demo

1. Clone or download this repostory to your local machine.
2. (optional) Edit the webserver port in `.env`.
3. (optional, default: SYS) Change IRIS password in `./src-iris/irispw.txt`.
4. Add your OpenAI key to `./src-iris/openaikey.secret`
5. Build the container images: `docker-compose build`.
6. Create and run containers: `docker-compose up -d`
7. Open IRIS management portal: http://localhost:8081/csp/sys/%25CSP.Portal.Home.zen

Additonal commands

- Stop Demo: `docker-compose stop`
- Start Demo: `docker-compose start`
- Delete all docker resources of the demo: `docker-compose down`