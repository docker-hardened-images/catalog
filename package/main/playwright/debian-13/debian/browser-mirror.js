#!/usr/bin/env node
'use strict';

const fs = require('fs');
const http = require('http');
const path = require('path');

const [rootArg, portArg, readyFile] = process.argv.slice(2);
if (!rootArg || !portArg || !readyFile) {
  console.error('usage: browser-mirror.js <root> <port> <ready-file>');
  process.exit(1);
}

const root = path.resolve(rootArg);
const port = Number(portArg);

const server = http.createServer((request, response) => {
  let pathname;
  try {
    pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  } catch {
    response.writeHead(400).end();
    return;
  }

  const requestedPath = path.resolve(root, `.${pathname}`);
  if (!requestedPath.startsWith(`${root}${path.sep}`)) {
    response.writeHead(403).end();
    return;
  }

  fs.stat(requestedPath, (statError, stat) => {
    if (statError || !stat.isFile()) {
      response.writeHead(404).end();
      return;
    }

    response.writeHead(200, {
      'Content-Length': stat.size,
      'Content-Type': 'application/zip',
    });
    fs.createReadStream(requestedPath).pipe(response);
  });
});

server.listen(port, '127.0.0.1', () => {
  fs.writeFileSync(readyFile, 'ready\n');
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
