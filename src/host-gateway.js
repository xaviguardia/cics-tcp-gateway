#!/usr/bin/env node
'use strict';

const net = require('net');

const DEFAULT_HOST = '0.0.0.0';
const DEFAULT_PORT = 4321;
const HEADER_SIZE = 12;
const RESPONSE_HEADER_SIZE = 8;
const MAX_COMMAREA = 4096;

const A2E = new Uint8Array(256);
const E2A = new Uint8Array(256);

(function initCodepage037() {
  for (let i = 0; i < 256; i++) {
    A2E[i] = i;
    E2A[i] = i;
  }

  const map = {
    0x20: 0x40,
    0x30: 0xF0, 0x31: 0xF1, 0x32: 0xF2, 0x33: 0xF3, 0x34: 0xF4,
    0x35: 0xF5, 0x36: 0xF6, 0x37: 0xF7, 0x38: 0xF8, 0x39: 0xF9,
    0x41: 0xC1, 0x42: 0xC2, 0x43: 0xC3, 0x44: 0xC4, 0x45: 0xC5,
    0x46: 0xC6, 0x47: 0xC7, 0x48: 0xC8, 0x49: 0xC9,
    0x4A: 0xD1, 0x4B: 0xD2, 0x4C: 0xD3, 0x4D: 0xD4, 0x4E: 0xD5,
    0x4F: 0xD6, 0x50: 0xD7, 0x51: 0xD8, 0x52: 0xD9,
    0x53: 0xE2, 0x54: 0xE3, 0x55: 0xE4, 0x56: 0xE5, 0x57: 0xE6,
    0x58: 0xE7, 0x59: 0xE8, 0x5A: 0xE9,
  };

  for (const [ascii, ebcdic] of Object.entries(map)) {
    A2E[Number(ascii)] = ebcdic;
    E2A[ebcdic] = Number(ascii);
  }
})();

function argValue(name, fallback) {
  const prefix = `--${name}=`;
  const arg = process.argv.find((item) => item.startsWith(prefix));
  return arg ? arg.slice(prefix.length) : fallback;
}

function argValues(name) {
  const prefix = `--${name}=`;
  return process.argv
    .filter((item) => item.startsWith(prefix))
    .map((item) => item.slice(prefix.length));
}

function parseBackends() {
  const values = [...argValues('backend')];
  const backendsValue = argValue('backends', '');
  if (backendsValue) {
    values.push(...backendsValue.split(','));
  }

  return values
    .map((value) => value.trim())
    .filter(Boolean)
    .map((value) => {
      const index = value.lastIndexOf(':');
      const host = index >= 0 ? value.slice(0, index) : '127.0.0.1';
      const portText = index >= 0 ? value.slice(index + 1) : value;
      const port = Number.parseInt(portText, 10);
      if (!host || !Number.isInteger(port) || port < 1 || port > 65535) {
        throw new Error(`Invalid backend: ${value}`);
      }
      return { host, port };
    });
}

function asciiToEbcdic(value) {
  const source = Buffer.from(value, 'ascii');
  const out = Buffer.alloc(source.length);
  for (let i = 0; i < source.length; i++) {
    out[i] = A2E[source[i]];
  }
  return out;
}

function ebcdicToAscii(buffer) {
  let value = '';
  for (let i = 0; i < buffer.length; i++) {
    value += String.fromCharCode(E2A[buffer[i]]);
  }
  return value;
}

function buildResponse(rc, message) {
  const payload = asciiToEbcdic(message);
  const header = Buffer.alloc(RESPONSE_HEADER_SIZE);
  header.writeUInt32BE(rc >>> 0, 0);
  header.writeUInt32BE(payload.length, 4);
  return Buffer.concat([header, payload]);
}

function runProgram(programName, commarea) {
  const len = String(commarea.length).padStart(4, '0');
  return {
    rc: 0,
    output: `CICSGW: ${programName.padEnd(8).slice(0, 8)} RC=0000 LEN=${len}`,
  };
}

function handleMockClient(socket) {
  let buffer = Buffer.alloc(0);
  let expectedLength = null;

  socket.on('data', (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);

    while (true) {
      if (expectedLength === null && buffer.length >= HEADER_SIZE) {
        const commareaLength = buffer.readUInt32BE(8);
        if (commareaLength > MAX_COMMAREA) {
          socket.end(buildResponse(12, 'CICSGW: BAD COMMAREA LENGTH'));
          return;
        }
        expectedLength = HEADER_SIZE + commareaLength;
      }

      if (expectedLength === null || buffer.length < expectedLength) {
        break;
      }

      const request = buffer.slice(0, expectedLength);
      buffer = buffer.slice(expectedLength);
      expectedLength = null;

      const programName = ebcdicToAscii(request.slice(0, 8)).trimEnd();
      const commarea = request.slice(HEADER_SIZE);
      const response = runProgram(programName, commarea);
      socket.write(buildResponse(response.rc, response.output));
    }
  });

  socket.on('error', (err) => {
    console.error(`CICSGW host gateway client error: ${err.message}`);
  });
}

function makeProxyHandler(backends) {
  let nextBackend = 0;

  return function handleProxyClient(socket) {
    const backend = backends[nextBackend % backends.length];
    nextBackend += 1;

    const upstream = net.createConnection({
      host: backend.host,
      port: backend.port,
    });

    socket.pipe(upstream, { end: false });
    upstream.pipe(socket, { end: false });

    socket.on('end', () => {
      upstream.end();
    });
    upstream.on('end', () => {
      socket.end();
    });

    socket.on('error', (err) => {
      console.error(`CICSGW client error: ${err.message}`);
      upstream.destroy();
    });
    upstream.on('error', (err) => {
      console.error(
        `CICSGW backend ${backend.host}:${backend.port} error: ${err.message}`,
      );
      socket.destroy();
    });
  };
}

const host = argValue('host', DEFAULT_HOST);
const port = Number.parseInt(argValue('port', String(DEFAULT_PORT)), 10);
let backends;

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  console.error(`Invalid port: ${port}`);
  process.exit(2);
}

try {
  backends = parseBackends();
} catch (err) {
  console.error(err.message);
  process.exit(2);
}

const handler = backends.length > 0
  ? makeProxyHandler(backends)
  : handleMockClient;
const server = backends.length > 0
  ? net.createServer({ allowHalfOpen: true }, handler)
  : net.createServer(handler);

server.on('error', (err) => {
  console.error(`CICSGW host gateway bind failed on ${host}:${port}: ${err.message}`);
  process.exit(1);
});

server.listen({ host, port }, () => {
  const address = server.address();
  console.log(`CICSGW host gateway listening on ${address.address}:${address.port}`);
  if (backends.length > 0) {
    console.log(
      `CICSGW proxy backends: ${backends
        .map((backend) => `${backend.host}:${backend.port}`)
        .join(', ')}`,
    );
  }
});
