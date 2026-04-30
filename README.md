# CICS TCP Gateway for Hercules/MVS

TCP gateway experiments for Hercules/MVS. The verified path is now the
guest-side S/370 assembler listener using the Hercules X'75' TCPIP instruction:
MVS creates the socket, binds port 4321, listens, accepts a client, and returns
the binary gateway protocol response.

The gateway accepts binary requests over TCP and returns binary responses using
the protocol below.

## Architecture

Verified guest-side path:

```text
TCP Client  --TCP-->  CICSGW ASM via X'75'  --next-->  KICKS Program
  request              MVS address space                 KIKPCP LINK
  response
```

KICKS dispatch target, from the KICKS source:

```text
KIKSIP1$ initializes CSA/TCA/tables
KIKSIP1$ terminal loop calls KIKTCP(RECV), then KIKKCP(ATTACH)
KIKPCP1$ LINK loads a program and calls it with EIB + commarea
CICSGW will keep the X'75' accept loop and dispatch requests via KIKPCP LINK
```

The KGCC/KICKS build path is now verified on TK5 as well. `jcl/KICKGW.jcl`
uses the installed KICKS `KGCC` PROC through `JOBPROC`, the restored
`HERC01.KICKSTS.H` and `HERC01.KICKSTS.TH` include PDSes, and the same
link-edit convention KICKS uses for C programs (`LOPTS='XREF,MAP'`,
`ENTRY @@CRT0`). The gateway-side KICKS dispatch module compiles, assembles,
links, and runs as `PGM=KICKGW`.

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

- Hercules TK5 and Assembler F (IFOX00) for the ASM/X'75' listener.
- Node.js for the test client.
- KICKS integration is the next dispatch step. The KICKS source convention is
  `KIKPCP(csa, kikpcpLINK, pgm, commarea, &len)`, not a 3270 automation path.

## Build and Run

```bash
awk '{gsub(/\r/,""); print}' jcl/ASMCLG.jcl | nc localhost 3505

docker exec hercules-mvs cat /opt/tk5/prt/prt00e.txt | tail -50
```

Build the KGCC/KICKS dispatch module:

```bash
awk '{gsub(/\r/,""); print}' jcl/KICKGW.jcl | nc localhost 3505
```

## Test

```bash
# If Docker publishes 4321 to the host:
node test/test-gateway.js --host=localhost --port=4321
```

Verified result inside the Hercules container network:

```text
IFOX00 RC=0000
IEWL   RC=0000
CICSGW04I BIND OK PORT 4321
CICSGW05I LISTENING

Request TESTCOB + zero commarea:
response hex = 00000000 0000001d ...
rc=0, output length=29
```

Verified KGCC/KICKS dispatch build:

```text
KICKGW COPY GCC input     RC=0000
KICKGW COMP GCC370        RC=0000
KICKGW ASM  IFOX00        RC=0000
KICKGW LKED IEWL          RC=0000
RUNKICKG PGM=KICKGW       RC=0000
```

## Configuration

The ASM listener uses port 4321 in the BIND parameter:

```asm
BINDPRM  DC    X'000210E1'       AF_INET=2, port 4321
```

To change the port, convert to hex big-endian:
- Port 4321 = `0x10E1`
- Port 8080 = `0x1F90`
- Port 9090 = `0x2382`

## How It Works

The verified gateway uses the Hercules X'75' TCPIP sequence from inside MVS:

1. **INITAPI** - Initialize the Hercules TCPIP API.
2. **SOCKET** - Create an AF_INET stream socket.
3. **BIND** - Bind `0.0.0.0:4321`.
4. **LISTEN** - Listen with backlog 5.
5. **ACCEPT** - Accept each client connection.
6. **RECV** - Read the gateway request bytes.
7. **SEND** - Return `rc + output length + EBCDIC output`.
8. **CLOSE** - Close the client socket and return to accept.

## Limitations

- Max commarea size: 4096 bytes.
- The current ASM response validates the TCP/protocol path; KICKS program
  dispatch is not wired yet.
- The current Docker container publishes 3270/3505/8038 only. Port 4321 is
  reachable inside the container network; publish or proxy it for host access.
- No TLS/encryption (plaintext TCP)

## Files

```
src/CICSGW.asm        S/370 assembler X'75' listener
src/KICKGW.c          KGCC/KICKS dispatch side using KIKPCP LINK
jcl/ASMCLG.jcl        Assemble, link-edit, and run JCL
jcl/KICKGW.jcl        KGCC/KICKS compile/link JCL for KICKGW
test/test-gateway.js  Node.js test client with EBCDIC translation
src/host-gateway.js   Host-side protocol harness
```

## License

MIT
