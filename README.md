# CICS TCP Gateway for Hercules/MVS

TCP gateway experiments for Hercules/MVS. The verified path is now the
guest-side S/370 assembler listener using the Hercules X'75' TCPIP instruction:
MVS creates the socket, binds port 4321, listens, accepts a client, and returns
the binary gateway protocol response.

The gateway accepts binary requests over TCP and returns binary responses using
the protocol below.

## Architecture

Verified guest-side paths:

```text
TCP Client  --TCP-->  CICSGW ASM via X'75'  --next-->  KICKS Program
  request              MVS address space                 KIKPCP LINK
  response

TCP Client  --TCP-->  KICKGWX KGCC via X75CALL  -->  kickgw()
  request              MVS address space              KIKPCP LINK once
  response                                          KICKS state is ready

TCP Clients --TCP--> host-gateway acceptor/proxy --> KICKGWX worker pool
  many sessions        webserver-style frontend        isolated KICKS state
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

`jcl/KICKGWX.jcl` verifies the combined KGCC-hosted TCP gateway. It assembles
`src/X75CALL.asm`, compiles `src/KICKGWX.c`, links both into `KICKGWX`, binds
`0.0.0.0:4321`, accepts TCP sessions, loops over framed binary requests on the
same socket, and returns gateway responses from the `kickgw()` dispatch guard.

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

Build and run the KGCC-hosted TCP gateway:

```bash
awk '{gsub(/\r/,""); print}' jcl/KICKGWX.jcl | nc localhost 3505
```

Run the host-side acceptor/proxy in front of one or more KICKGWX workers:

```bash
node src/host-gateway.js --host=0.0.0.0 --port=4321 \
  --backend=127.0.0.1:4322 --backend=127.0.0.1:4323
```

Each backend is a full TCP session target. The frontend does not split a user
session across workers; it selects a worker when the client connects and then
proxies the byte stream.

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

Verified KGCC-hosted TCP gateway:

```text
KICKGWX X75ASM IFOX00       RC=0000
KICKGWX COPY   IEBGENER     RC=0000
KICKGWX COMP   GCC370       RC=0000
KICKGWX ASM    IFOX00       RC=0000
KICKGWX LKED   IEWL         RC=0000

Request KLASTCCG + 4-byte commarea:
response hex = 00000000 00000004 00000000
rc=0, output length=4

Same TCP session, two KLASTCCG frames:
response hex = 000000000000000400000000000000000000000400000000
```

This verifies the TCP bind/listen/accept/recv/send path, KICKS-style
CSA/TCA/EIB initialization, and `KIKPCP LINK` dispatch into a real program from
`KIKRPL`.

Verified host acceptor/proxy:

```text
3 concurrent frontend clients -> proxy -> backend:
client-0
client-1
client-2
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
6. **RECV** - Read a full request header and commarea.
7. **SEND** - Return `rc + output length + EBCDIC output`.
8. Repeat RECV/SEND on the same client socket until EOF/error.
9. **CLOSE** - Close the client socket and return to accept.

## Limitations

- Max commarea size: 4096 bytes.
- The current ASM response validates the TCP/protocol path.
- `KICKGWX` requires `KIKASRB`, `KIKLOAD`, and `VCONSTB5` to exist in
  `HERC01.KICKSSYS.V1R5M0.SKIKLOAD`, plus RUN DDs for `SKIKLOAD` and `KIKRPL`.
- The current Docker container publishes 3270/3505/8038 only. Port 4321 is
  reachable inside the container network; publish or proxy it for host access.
- `KICKGWX` is session-persistent but still processes accepted clients serially
  inside one MVS address space. Webserver-style simultaneous multi-user
  operation is provided by running multiple independent `KICKGWX` workers and
  putting `src/host-gateway.js` in proxy mode in front of them.
- `KICKGWX` accepts a decimal port as its first program argument/JCL `PARM`;
  the default JCL uses `PARM='4321'`.
- No TLS/encryption (plaintext TCP)

## Files

```
src/CICSGW.asm        S/370 assembler X'75' listener
src/KICKGW.c          KGCC/KICKS dispatch side using KIKPCP LINK
src/KICKGWX.c         KGCC-hosted X'75' gateway loop
src/X75CALL.asm       KGCC-callable X'75' wrapper
jcl/ASMCLG.jcl        Assemble, link-edit, and run JCL
jcl/KICKGW.jcl        KGCC/KICKS compile/link JCL for KICKGW
jcl/KICKGWX.jcl       KGCC-hosted gateway build/run JCL
test/test-gateway.js  Node.js test client with EBCDIC translation
src/host-gateway.js   Host-side protocol harness
```

## License

MIT
