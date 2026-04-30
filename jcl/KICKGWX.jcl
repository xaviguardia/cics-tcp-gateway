//KICKGWX  JOB (ACCT),'KICKGWX',CLASS=A,MSGCLASS=A,
//             MSGLEVEL=(1,1),REGION=8192K,USER=HERC01,PASSWORD=CUL8TR
//JOBPROC  DD   DSN=HERC01.KICKSSYS.V1R5M0.PROCLIB,DISP=SHR
//X75ASM   EXEC PGM=IFOX00,PARM='OBJECT,NODECK',REGION=512K
//SYSPRINT DD  SYSOUT=A
//SYSUT1   DD  UNIT=3390,SPACE=(CYL,(1,1))
//SYSUT2   DD  UNIT=3390,SPACE=(CYL,(1,1))
//SYSUT3   DD  UNIT=3390,SPACE=(CYL,(1,1))
//SYSGO    DD  DSN=&&X75OBJ,DISP=(NEW,PASS),UNIT=3390,
//             SPACE=(80,(200,50))
//SYSLIB   DD  DSN=SYS1.MACLIB,DISP=SHR
//SYSIN    DD  *
X75CALL  TITLE 'CALLABLE HERCULES X75 TCPIP BRIDGE'
***********************************************************************
* X75CALL - KGCC-callable wrapper for the Hercules TCPIP instruction. *
*                                                                     *
* C prototype:                                                        *
*   int x75call(int func, int aux1, int aux2, char *buf,              *
*               int len, int mode);                                   *
*                                                                     *
* mode 0: no payload                                                  *
* mode 1: SEND payload from buf,len                                   *
* mode 2: RECV payload into buf                                       *
***********************************************************************
X75CALL  CSECT
         ENTRY X75CALL
         USING X75CALL,12
         STM   14,12,12(13)
         LR    12,15
         LA    10,SAVEAREA
         ST    13,4(10)
         ST    10,8(13)
         LR    13,10
         LR    11,1
         L     7,0(11)
         L     8,4(11)
         L     9,8(11)
         L     2,12(11)
         ST    2,BUFPTR
         L     1,16(11)
         ST    1,BUFLEN
         L     2,20(11)
         ST    2,MODE
* PHASE 1: ALLOCATE/COPY INPUT/EXECUTE
         SR    0,0
         LA    1,0
         LA    5,BUFFER
         L     2,MODE
         C     2,ONE
         BNE   PHASE1
         L     1,BUFLEN
         L     5,BUFPTR
PHASE1   DS    0H
         SR    3,3
         DC    X'75005000'
         LR    6,14
* PHASE 2: RETRIEVE OUTPUT/FREE CONVERSATION
         LR    14,6
         SR    0,0
         LA    3,1
         LA    5,BUFFER
         L     2,MODE
         C     2,TWO
         BNE   PHASE2
         L     5,BUFPTR
PHASE2   DS    0H
         DC    X'75005000'
         LR    15,4
         L     13,4(13)
         L     14,12(13)
         LM    0,12,20(13)
         BR    14
SAVEAREA DS    18F
BUFPTR   DC    F'0'
BUFLEN   DC    F'0'
MODE     DC    F'0'
ONE      DC    F'1'
TWO      DC    F'2'
BUFFER   DS    CL256
         LTORG
         END   X75CALL
/*
//KICKGWX  EXEC PROC=KGCC,LOPTS='XREF,MAP',NAME=KICKGWX,
//             GCCPREF=SYS1,PDPPREF=PDPCLIB,
//             COND=(4,LT,X75ASM)
//COPY.SYSUT1 DD DATA,DLM=@@
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
@@
//COMP.INCLUDE DD DSN=HERC01.KICKSTS.H,DISP=SHR
// DD DSN=HERC01.KICKSSYS.V1R5M0.GCCCOPY,DISP=SHR
// DD DSN=HERC01.KICKSTS.TH,DISP=SHR
//ASM.SYSLIB DD DSN=SYS1.MACLIB,DISP=SHR
// DD DSN=PDPCLIB.MACLIB,DISP=SHR
// DD DSN=SYS1.MACLIB,DISP=SHR
//LKED.SYSLIN DD DSN=&&OBJSET,DISP=(OLD,DELETE)
// DD DSN=&&X75OBJ,DISP=(OLD,DELETE)
// DD *
 ENTRY @@CRT0
/*
//RUN      EXEC PGM=KICKGWX,REGION=8192K,TIME=1440,
//             COND=((4,LT,X75ASM),(4,LT,KICKGWX.LKED))
//STEPLIB  DD DSN=HERC01.KICKSSYS.V1R5M0.SKIKLOAD,DISP=SHR
//SYSIN    DD DUMMY
//SYSPRINT DD SYSOUT=A
//SYSTERM  DD SYSOUT=A
//SYSOUT   DD SYSOUT=A
//
