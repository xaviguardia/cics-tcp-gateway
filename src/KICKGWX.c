/*
 * KGCC-hosted KICKS TCP gateway.
 *
 * This version enters through the KGCC runtime and calls a tiny assembler
 * wrapper for the Hercules X'75' TCPIP instruction. That avoids calling a
 * KGCC function from a raw assembler main before @@CRT0 has initialized.
 */

#define KIKSIP

#include <stdio.h>
#include <string.h>

#include "kicks.h"

#define GW_PORT_HEX 0x10E1
#define MAX_REQ 4096
#define RSP_LEN 29

extern int x75call(int func, int aux1, int aux2, char *buf,
                   int len, int mode);

static char reqbuf[MAX_REQ + 12];
static char rspbuf[80];

int kickgw(char *program, char *commarea, int commarea_len)
{
    KIKCSA *csa = &kikcsa;
    int len = commarea_len;

    if (len < 0) {
        return 12;
    }
    if (len > MAX_REQ) {
        return 12;
    }
    if (csa->pcp_addr == 0) {
        return 16;
    }
    if (csa->tca == 0) {
        return 16;
    }
    if (csa->tctte == 0) {
        return 16;
    }

    KIKPCP(csa, kikpcpLINK, program, commarea, &len);
    return 0;
}

static void put_response(int rc)
{
    int len = RSP_LEN;

    memset(rspbuf, 0, sizeof(rspbuf));
    memcpy(rspbuf, &rc, 4);
    memcpy(rspbuf + 4, &len, 4);
    memcpy(rspbuf + 8, "CICSGW  ", 8);
    memcpy(rspbuf + 16, reqbuf, 8);
    memcpy(rspbuf + 24, " CONNECTED OK", 13);
}

int main(int argc, char **argv)
{
    int i;
    int lsnfd;
    int clifd;
    int nread;
    int comalen;
    int rc;

    printf("KICKGWX starting port 4321\n");
    fflush(stdout);

    rc = x75call(1, 0, 0, 0, 0, 0);
    printf("KICKGWX init rc %d\n", rc);
    fflush(stdout);
    for (i = 1; i <= 32; i++) {
        x75call(12, i, 0, 0, 0, 0);
    }

    lsnfd = x75call(5, 0x00020001, 0, 0, 0, 0);
    if (lsnfd < 0) {
        printf("KICKGWX socket failed %d\n", lsnfd);
        return 8;
    }

    rc = x75call((lsnfd << 16) + 6, 0, 0x00020000 + GW_PORT_HEX,
                 0, 0, 0);
    if (rc < 0) {
        printf("KICKGWX bind failed %d\n", rc);
        return 8;
    }

    rc = x75call(8, lsnfd, 5, 0, 0, 0);
    if (rc < 0) {
        printf("KICKGWX listen failed %d\n", rc);
        return 8;
    }
    printf("KICKGWX listening\n");
    fflush(stdout);

    while (1) {
        clifd = x75call(9, lsnfd, 0, 0, 0, 0);
        if (clifd < 0) {
            continue;
        }

        memset(reqbuf, 0, sizeof(reqbuf));
        do {
            nread = x75call(11, clifd, sizeof(reqbuf), reqbuf,
                            sizeof(reqbuf), 2);
        } while (nread == -2);
        if (nread >= 12) {
            memcpy(&comalen, reqbuf + 8, 4);
            rc = kickgw(reqbuf, reqbuf + 12, comalen);
            put_response(rc);
            x75call(10, clifd, 0, rspbuf, 37, 1);
            printf("KICKGWX request rc %d bytes %d\n", rc, nread);
            fflush(stdout);
        }

        x75call(12, clifd, 0, 0, 0, 0);
    }

    return 0;
}
