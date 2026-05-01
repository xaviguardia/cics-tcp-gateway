/*
 *  CICS TCP Gateway for Hercules/MVS TK5 + KICKS
 *
 *  TCP socket server that accepts connections, reads a request
 *  (program name + commarea), executes the KICKS transaction
 *  via KIKCOBGL, and returns the response.
 *
 *  Compiled with JCC (Jason Winter's C compiler for MVS 3.8j).
 *  Uses Hercules TCPIP instruction (X'75') via JCC sockets.
 *
 *  Protocol (binary, EBCDIC):
 *    Request:  8 bytes program name (EBCDIC, space-padded)
 *             4 bytes commarea length (big-endian)
 *             N bytes commarea data
 *
 *    Response: 4 bytes return code (big-endian)
 *             4 bytes output length (big-endian)
 *             N bytes output data (EBCDIC)
 *             80 bytes SYSPRINT capture (first PUT SKIP LIST line)
 *
 *  (C) 2026 Iria.ai - MIT License
 */

#include <stdio.h>
#include <string.h>
#include <sockets.h>

#define GW_PORT    4321
#define BACKLOG    5
#define MAXCOMA    4096
#define HDRSZ      12
#define RSPSZ      8

/* Request header layout */
struct reqhdr {
    char pgmname[8];    /* Program name, EBCDIC, space-padded */
    long comalen;        /* Commarea length, big-endian */
};

/* Response header layout */
struct rsphdr {
    long retcode;        /* Return code from KICKS */
    long outlen;         /* Output data length */
};

/* Buffers */
static char commarea[MAXCOMA];
static char outbuf[MAXCOMA];
static struct reqhdr req;
static struct rsphdr rsp;

/* SYSPRINT capture buffer */
static char prtbuf[132];
static int  prtlen;

/*
 * Execute a KICKS program.
 *
 * For the initial version, we use a simple approach:
 * load and call the program directly. The program must be
 * in KIKRPL (installed via link-edit step).
 *
 * Returns 0 on success, nonzero on error.
 */
static int exec_program(char *pgmname, char *coma, long comalen)
{
    /* For now, just echo back the commarea with the program name
     * prepended. This validates the TCP round-trip works.
     *
     * Full KIKCOBGL integration requires the KICKS LINK interface
     * which needs the EIB and proper parameter list setup.
     * That will be phase 2 once the TCP layer is proven.
     */
    int i;
    int olen;

    /* Build output: "CICSGW: <PGMNAME> RC=0000 COMALEN=nnnn" */
    memset(outbuf, ' ', sizeof(outbuf));
    memcpy(outbuf, "CICSGW: ", 8);
    memcpy(outbuf + 8, pgmname, 8);
    memcpy(outbuf + 16, " RC=0000 LEN=", 13);

    /* Convert comalen to 4-digit string */
    olen = 29;
    outbuf[olen++] = '0' + ((comalen / 1000) % 10);
    outbuf[olen++] = '0' + ((comalen / 100) % 10);
    outbuf[olen++] = '0' + ((comalen / 10) % 10);
    outbuf[olen++] = '0' + (comalen % 10);

    rsp.retcode = 0;
    rsp.outlen = olen;

    return 0;
}

int main()
{
    long lsock, csock;
    struct sockaddr_in saddr, caddr;
    long caddrlen;
    long rc;
    long nbytes;

    printf("CICSGW: CICS TCP Gateway starting\n");
    printf("CICSGW: Port %d\n", GW_PORT);

    /* Create TCP socket */
    lsock = socket(AF_INET, SOCK_STREAM, 0);
    if (lsock == INVALID_SOCKET) {
        printf("CICSGW: socket() failed, err=%ld\n",
               WSAGetLastError());
        return 8;
    }
    printf("CICSGW: Socket created, fd=%ld\n", lsock);

    /* Bind to port */
    memset(&saddr, 0, sizeof(saddr));
    saddr.sin_family = AF_INET;
    saddr.sin_port = htons(GW_PORT);
    saddr.sin_addr.s_addr = htonl(INADDR_ANY);

    rc = bind(lsock, (struct sockaddr *)&saddr, sizeof(saddr));
    if (rc == SOCKET_ERROR) {
        printf("CICSGW: bind() failed, err=%ld\n",
               WSAGetLastError());
        closesocket(lsock);
        return 8;
    }
    printf("CICSGW: Bound to port %d\n", GW_PORT);

    /* Listen */
    rc = listen(lsock, BACKLOG);
    if (rc == SOCKET_ERROR) {
        printf("CICSGW: listen() failed, err=%ld\n",
               WSAGetLastError());
        closesocket(lsock);
        return 8;
    }
    printf("CICSGW: Listening for connections\n");

    /* Accept loop */
    while (1) {
        caddrlen = sizeof(caddr);
        csock = accept(lsock, (struct sockaddr *)&caddr, &caddrlen);
        if (csock == INVALID_SOCKET) {
            printf("CICSGW: accept() failed, err=%ld\n",
                   WSAGetLastError());
            continue;
        }

        /* Read request header (12 bytes) */
        nbytes = recv(csock, (void *)&req, HDRSZ, 0);
        if (nbytes != HDRSZ) {
            printf("CICSGW: short read on header: %ld\n", nbytes);
            closesocket(csock);
            continue;
        }

        /* Validate commarea length */
        if (req.comalen < 0 || req.comalen > MAXCOMA) {
            printf("CICSGW: bad comalen: %ld\n", req.comalen);
            rsp.retcode = 12;
            rsp.outlen = 0;
            send(csock, (void *)&rsp, RSPSZ, 0);
            closesocket(csock);
            continue;
        }

        /* Read commarea data */
        if (req.comalen > 0) {
            nbytes = recv(csock, (void *)commarea, req.comalen, 0);
            if (nbytes != req.comalen) {
                printf("CICSGW: short read on commarea: %ld\n",
                       nbytes);
                closesocket(csock);
                continue;
            }
        }

        printf("CICSGW: Request: pgm=%.8s comalen=%ld\n",
               req.pgmname, req.comalen);

        /* Execute the program */
        rc = exec_program(req.pgmname, commarea, req.comalen);

        /* Send response header */
        send(csock, (void *)&rsp, RSPSZ, 0);

        /* Send output data */
        if (rsp.outlen > 0) {
            /* Convert output to EBCDIC for the client */
            send(csock, (void *)outbuf, rsp.outlen, 0);
        }

        printf("CICSGW: Response: rc=%ld outlen=%ld\n",
               rsp.retcode, rsp.outlen);

        closesocket(csock);
    }

    closesocket(lsock);
    return 0;
}
