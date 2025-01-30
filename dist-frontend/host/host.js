'use strict';

const express = require('express');
const path = require('path');
const http = require('http');
const https = require('https');
const cors = require('cors');
const fs = require('fs');
const bodyParser = require('body-parser');
const proxy = require('http-proxy-middleware');

let server = express();

//openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem
var sslOptions = {
  key: fs.readFileSync('key.pem'),
  cert: fs.readFileSync('cert.pem'),
  passphrase: 'iscdemo'
};

let httpServer = http.createServer(server);
//let httpsServer = https.createServer(sslOptions, server);

server.use(cors())
server.use(bodyParser.json());
server.use(bodyParser.urlencoded({ extended: false }));

var port = process.env.PORT || 3000;
console.log(path.join(__dirname, 'dist'));
server.use(express.static(path.join(__dirname, './dist/apollo-ngx')));

// Render your site
const renderIndex = (req, res) => {
  res.sendFile(path.resolve(__dirname, './dist/apollo-ngx/index.html'));
}

server.get('/*', renderIndex);

httpServer.listen(3000, () => {
  console.log('Listening on: http://localhost:3000');
});