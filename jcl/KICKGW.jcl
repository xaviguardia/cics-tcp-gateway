//KICKGW   JOB (ACCT),'KICKS TCP GW',CLASS=A,MSGCLASS=A,
//             MSGLEVEL=(1,1),REGION=7000K,USER=HERC01,PASSWORD=CUL8TR
//JOBPROC  DD   DSN=HERC01.KICKSSYS.V1R5M0.PROCLIB,DISP=SHR
//KICKGW   EXEC PROC=KGCC,LOPTS='XREF,MAP',NAME=KICKGW,
//             GCCPREF=SYS1,PDPPREF=PDPCLIB
//COPY.SYSUT1 DD DATA,DLM=@@
/*
 * KICKS TCP gateway dispatch side.
 *
 * This source deliberately follows the KICKS server convention instead of
 * driving a 3270 terminal. The TCP accept/read/write loop is the verified
 * X'75' listener; this module is the KICKS side that turns a gateway request
 * into a normal KICKS LINK.
 */

#define KIKSIP

#include <stdio.h>
#include <string.h>

#include "kicks.h"

#define KICKGW_MAX_COMMAREA 24576

int kickgw(char *program, char *commarea, int commarea_len)
{
    KIKCSA *csa = &kikcsa;
    int len = commarea_len;

    if (len < 0) {
        return 12;
    }
    if (len > KICKGW_MAX_COMMAREA) {
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

    /*
     * KIKPCP LINK expects KICKS task state to exist already. The gateway
     * startup path must initialize KICKS exactly like KIKSIP1$ and create
     * the TCA/EIB before reaching this point.
     */
    KIKPCP(csa, kikpcpLINK, program, commarea, &len);
    return 0;
}

int main(int argc, char **argv)
{
    char program[8];
    char commarea[16];

    memset(program, ' ', sizeof(program));
    memcpy(program, "TESTCOB", 7);
    memset(commarea, 0, sizeof(commarea));

    /*
     * Do not call kickgw_link from this probe main yet: a real request path
     * must first initialize KICKS and build TCA/EIB state. Keeping the
     * reference here forces KGCC to validate the KIKPCP LINK call signature.
     */
    if (argc > 1000) {
        return kickgw(program, commarea, sizeof(commarea));
    }

    printf("KICKGW KGCC/KICKS dispatch module loaded\n");
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
// DD *
 ENTRY @@CRT0
/*
//
