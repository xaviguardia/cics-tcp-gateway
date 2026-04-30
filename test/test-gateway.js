#!/usr/bin/env node
'use strict';

/**
 * Test client for the CICS TCP Gateway running on Hercules/MVS.
 *
 * Protocol (binary, network byte order):
 *   Request:  8 bytes program name (EBCDIC, space-padded)
 *            4 bytes commarea length (big-endian)
 *            N bytes commarea data (EBCDIC)
 *
 *   Response: 4 bytes return code (big-endian)
 *            4 bytes output length (big-endian)
 *            N bytes output data (EBCDIC)
 *
 * Usage:
 *   node test/test-gateway.js [--host=localhost] [--port=4321]
 */

const net = require('net');

const HOST = process.argv.find(a => a.startsWith('--host='))?.split('=')[1] || 'localhost';
const PORT = parseInt(process.argv.find(a => a.startsWith('--port='))?.split('=')[1] || '4321', 10);

// Minimal ASCII-to-EBCDIC translation table (printable chars only)
const A2E = new Uint8Array(256);
const E2A = new Uint8Array(256);
(function initCodepage() {
  // Initialize with identity
  for (let i = 0; i < 256; i++) { A2E[i] = i; E2A[i] = i; }
  // Key mappings (codepage 037)
  const map = {
    0x20: 0x40, // space
    0x30: 0xF0, 0x31: 0xF1, 0x32: 0xF2, 0x33: 0xF3, 0x34: 0xF4,
    0x35: 0xF5, 0x36: 0xF6, 0x37: 0xF7, 0x38: 0xF8, 0x39: 0xF9,
    0x41: 0xC1, 0x42: 0xC2, 0x43: 0xC3, 0x44: 0xC4, 0x45: 0xC5,
    0x46: 0xC6, 0x47: 0xC7, 0x48: 0xC8, 0x49: 0xC9,
    0x4A: 0xD1, 0x4B: 0xD2, 0x4C: 0xD3, 0x4D: 0xD4, 0x4E: 0xD5,
    0x4F: 0xD6, 0x50: 0xD7, 0x51: 0xD8, 0x52: 0xD9,
    0x53: 0xE2, 0x54: 0xE3, 0x55: 0xE4, 0x56: 0xE5, 0x57: 0xE6,
    0x58: 0xE7, 0x59: 0xE8, 0x5A: 0xE9,
  };
  for (const [a, e] of Object.entries(map)) {
    A2E[Number(a)] = e;
    E2A[e] = Number(a);
  }
})();

function asciiToEbcdic(str) {
  const buf = Buffer.alloc(str.length);
  for (let i = 0; i < str.length; i++) buf[i] = A2E[str.charCodeAt(i)];
  return buf;
}

function ebcdicToAscii(buf) {
  let s = '';
  for (let i = 0; i < buf.length; i++) s += String.fromCharCode(E2A[buf[i]]);
  return s;
}

function buildRequest(programName, commareaAscii) {
  const pgm = asciiToEbcdic(programName.padEnd(8).slice(0, 8));
  const commarea = commareaAscii ? asciiToEbcdic(commareaAscii) : Buffer.alloc(0);
  const hdr = Buffer.alloc(12);
  pgm.copy(hdr, 0);
  hdr.writeUInt32BE(commarea.length, 8);
  return Buffer.concat([hdr, commarea]);
}

function parseResponse(data) {
  if (data.length < 8) return { rc: -1, output: '' };
  const rc = data.readUInt32BE(0);
  const len = data.readUInt32BE(4);
  const output = len > 0 ? ebcdicToAscii(data.slice(8, 8 + len)) : '';
  return { rc, output };
}

function sendRequest(program, commarea) {
  return new Promise((resolve, reject) => {
    const req = buildRequest(program, commarea);
    const client = net.createConnection({ host: HOST, port: PORT }, () => {
      client.write(req);
    });
    const chunks = [];
    client.on('data', (chunk) => chunks.push(chunk));
    client.on('end', () => resolve(parseResponse(Buffer.concat(chunks))));
    client.on('error', reject);
    setTimeout(() => { client.destroy(); reject(new Error('timeout')); }, 10000);
  });
}

async function run() {
  console.log(`\nCICS TCP Gateway Test Client`);
  console.log(`Connecting to ${HOST}:${PORT}\n`);

  try {
    console.log('1. Sending TESTCOB request (empty commarea)...');
    const r1 = await sendRequest('TESTCOB', '');
    console.log(`   RC=${r1.rc}, output=${r1.output.length} bytes`);
    if (r1.output) console.log(`   "${r1.output.trim()}"`);

    console.log('\n2. Sending INQONLN with PORTFOLIO commarea...');
    // Build a minimal commarea matching INQ_COMMAREA structure:
    // INQ_FUNCTION(12) + INQ_USER(8) + INQ_PORTFOLIO_ID(12) + INQ_RESPONSE(120)
    const commarea = 'PORTFOLIO   CICSUSER PORT000001  ' + ' '.repeat(120);
    const r2 = await sendRequest('INQONLN', commarea);
    console.log(`   RC=${r2.rc}, output=${r2.output.length} bytes`);
    if (r2.output) console.log(`   "${r2.output.trim()}"`);

    console.log('\nDone.');
  } catch (e) {
    console.error(`Error: ${e.message}`);
    console.error('Is the gateway running? Submit jcl/ASMCLG.jcl to Hercules first.');
    process.exitCode = 1;
  }
}

run();
