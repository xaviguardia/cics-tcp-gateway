# CICS TCP Gateway for Hercules/MVS

A TCP socket listener written in S/370 assembler that runs on MVS (Hercules TK5) and executes CICS transactions via KICKS. Accepts binary requests over TCP, dispatches to KICKS programs via KIKCOBGL, and returns the response.

This is a miniature CICS Transaction Gateway (CTG) running natively on the mainframe.

## Architecture

```
TCP Client  ──TCP──>  CICSGW (ASM)  ──KIKCOBGL──>  KICKS Program
  request              port 4321                     (PL/I, COBOL)
  response            MVS address space              CICS commands
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

- **Hercules TK5** (MVS 3.8j) with networking enabled
- **KICKS V1R5M0** installed (KIKCOBGL in SKIKLOAD)
- **MVS TCP/IP** with EZASOKET interface
- Assembler F (IFOX00) for compilation

## Build and Run

```bash
# Submit the JCL to Hercules card reader
awk '{gsub(/\r/,""); print}' jcl/ASMCLG.jcl | nc localhost 3505

# Check compilation output
docker exec hercules-mvs cat /opt/tk5/prt/prt00e.txt | tail -50
```

## Test

```bash
# From the host, with the gateway running on MVS:
node test/test-gateway.js --host=localhost --port=4321
```

## Configuration

The listening port is set in `src/CICSGW.asm` at label `SAPORT`:

```asm
SAPORT   DC    X'10E1'           Port 4321 (network byte order)
```

To change the port, convert to hex big-endian:
- Port 4321 = `0x10E1`
- Port 8080 = `0x1F90`
- Port 9090 = `0x2382`

## How It Works

1. **INITAPI** - Initialize the TCP/IP socket interface (EZASOKET)
2. **SOCKET** - Create a TCP stream socket (AF_INET, SOCK_STREAM)
3. **BIND** - Bind to the configured port on all interfaces
4. **LISTEN** - Start listening with a backlog of 5
5. **ACCEPT** - Wait for a client connection (blocking)
6. **READ** - Read the request header (program name + commarea length)
7. **READ** - Read the commarea data
8. **KIKCOBGL** - Initialize KICKS EIB, then LINK to the requested program
9. **WRITE** - Send the response header (return code + output length)
10. **WRITE** - Send the updated commarea as response body
11. **CLOSE** - Close the client socket
12. Loop back to step 5

## Limitations

- Single-threaded: one connection at a time (sequential accept loop)
- Max commarea size: 4096 bytes
- Requires EZASOKET (IBM TCP/IP for MVS). The Greg Price TCP/IP on TK5 may need adaptation
- Programs must be installed in KIKRPL before they can be called
- No TLS/encryption (plaintext TCP)

## Files

```
src/CICSGW.asm       S/370 assembler source
jcl/ASMCLG.jcl       Assemble, link-edit, and run JCL
test/test-gateway.js  Node.js test client with EBCDIC translation
```

## License

MIT
