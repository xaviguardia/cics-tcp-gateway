# CICS TCP Gateway for Hercules/MVS

TCP gateway experiments for Hercules/MVS. The verified path is a host-side
listener that binds a normal TCP socket, following the same host networking
model used by Hercules 3270 listeners. The S/370 assembler X'75' listener is
kept as an experimental guest-side implementation.

The gateway accepts binary requests over TCP and returns binary responses using
the protocol below.

## Architecture

Verified host-side path:

```text
TCP Client  --TCP-->  host-gateway.js  --future bridge-->  Hercules/MVS
  request              port 4321                         KICKS/CICS program
  response             host process
```

Experimental guest-side path:

```text
TCP Client  --TCP-->  CICSGW ASM via X'75'  --future-->  KICKS Program
  request              MVS address space                 CICS commands
  response
```

## Protocol

Fixed-format binary over TCP. All strings in EBCDIC.

### Request

| Offset | Length | Field           | Description                    |
|--------|--------|-----------------|--------------------------------|
| 0      | 8      | Program name    | EBCDIC, space-padded           |
| 8      | 4      | Commarea length | Big-endian unsigned 32-bit     |
| 12     | N      | Commarea data   | EBCDIC, N = commarea length    |

### Response

| Offset | Length | Field           | Description                    |
|--------|--------|-----------------|--------------------------------|
| 0      | 4      | Return code     | Big-endian unsigned 32-bit     |
| 4      | 4      | Output length   | Big-endian unsigned 32-bit     |
| 8      | N      | Output data     | EBCDIC, N = output length      |

## Requirements

- Node.js for the verified host-side gateway and test client.
- Hercules TK5 and Assembler F (IFOX00) only for the experimental ASM/X'75' path.
- KICKS integration is not wired into the verified host-side gateway yet; the
  current verified implementation validates the TCP protocol round trip.

## Build and Run

```bash
# Verified host-side listener, same bind/listen/accept model as Hercules 3270
node src/host-gateway.js --host=0.0.0.0 --port=4321
```

Experimental ASM/X'75' path:

```bash
awk '{gsub(/\r/,""); print}' jcl/ASMCLG.jcl | nc localhost 3505

docker exec hercules-mvs cat /opt/tk5/prt/prt00e.txt | tail -50
```

## Test

```bash
# From the host, with the gateway running:
node test/test-gateway.js --host=localhost --port=4321
```

Verified result against `src/host-gateway.js`:

```text
1. Sending TESTCOB request (empty commarea)...
   RC=0, output=33 bytes
   "CICSGW: TESTCOB  RC=0000 LEN=0000"

2. Sending INQONLN with PORTFOLIO commarea...
   RC=0, output=33 bytes
   "CICSGW: INQONLN  RC=0000 LEN=0153"
```

## Configuration

The verified host-side gateway defaults to port 4321 and can be changed with:

```bash
node src/host-gateway.js --host=0.0.0.0 --port=8080
```

The experimental ASM listener uses port 4321 in the BIND parameter:

```asm
BINDPRM  DC    X'000210E1'       AF_INET=2, port 4321
```

To change the port, convert to hex big-endian:
- Port 4321 = `0x10E1`
- Port 8080 = `0x1F90`
- Port 9090 = `0x2382`

## How It Works

The verified gateway uses the normal host socket sequence:

1. **socket/listen** - Node/libuv creates a TCP listener on the host.
2. **bind** - The process binds to the configured port.
3. **accept** - Each client connection is accepted by the host process.
4. **read** - The gateway reads the 12-byte request header and commarea.
5. **execute** - Current version returns a deterministic protocol response.
6. **write** - The gateway sends the response header and EBCDIC output.
7. **close** - The client socket is closed.

## Limitations

- Max commarea size: 4096 bytes.
- Verified host-side implementation does not yet dispatch into KICKS.
- Experimental ASM/X'75' implementation assembles and links, but BIND currently
  fails on this TK5/Hercules setup with `EINVAL`.
- No TLS/encryption (plaintext TCP)

## Files

```
src/host-gateway.js  Verified host-side TCP listener
src/CICSGW.asm       S/370 assembler source
jcl/ASMCLG.jcl       Assemble, link-edit, and run JCL
test/test-gateway.js  Node.js test client with EBCDIC translation
```

## License

MIT
