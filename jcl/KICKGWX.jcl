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
#include <stdlib.h>
#include <string.h>

#include "kicks.h"

#define GW_PORT_HEX 0x10E1
#define MAX_REQ 4096
#define RSP_LEN 29

extern int x75call(int func, int aux1, int aux2, char *buf,
                   int len, int mode);
extern vconstb5;
extern kikaica;

static char reqbuf[MAX_REQ + 12];
static char rspbuf[MAX_REQ + 12];
static int kicks_ready = 0;

static void tracewtr(char *tracemsg, int intense)
{
    (void)tracemsg;
    (void)intense;
}

static void init_base_csa(KIKCSA *csa)
{
    memset(csa, 0, sizeof(*csa));
    memcpy(&csa->csastrt, "KIKCSA-----START", 16);
    memcpy(&csa->siteye, "SIT", 3);
    memcpy(&csa->pcpeye, "PCP", 3);
    memcpy(&csa->ppteye, "PPT", 3);
    memcpy(&csa->kcpeye, "KCP", 3);
    memcpy(&csa->pcteye, "PCT", 3);
    memcpy(&csa->fcpeye, "FCP", 3);
    memcpy(&csa->fcteye, "FCT", 3);
    memcpy(&csa->dcpeye, "DCP", 3);
    memcpy(&csa->dcteye, "DCT", 3);
    memcpy(&csa->bmseye, "BMS", 3);
    memcpy(&csa->tcpeye, "TCP", 3);
    memcpy(&csa->scpeye, "SCP", 3);
    memcpy(&csa->tspeye, "TSP", 3);
    memcpy(&csa->csaend, "KIKCSA-------END", 16);

    csa->version = MKVER(V, R, M, E);
    csa->csastdin = stdin;
    csa->csastdout = stdout;
    csa->csastderr = stderr;
    csa->maxdelay = 180;
    csa->AICAmax = 5000;
    csa->AICAinst = (char *)&kikaica;
    csa->vcons = (VCONS *)&vconstb5;
    csa->trc_addr = (char *)&tracewtr;

    memcpy(&csa->pcp_suffix, "00", 2);
    memcpy(&csa->kcp_suffix, "00", 2);
    memcpy(&csa->fcp_suffix, "00", 2);
    memcpy(&csa->dcp_suffix, "00", 2);
    memcpy(&csa->tcp_suffix, "00", 2);
    memcpy(&csa->bms_suffix, "00", 2);
    memcpy(&csa->scp_suffix, "00", 2);
    memcpy(&csa->tsp_suffix, "00", 2);
    memcpy(&csa->sit_table_suffix, "1$", 2);
    memcpy(&csa->pcp_table_suffix, "00", 2);
    memcpy(&csa->kcp_table_suffix, "00", 2);
    memcpy(&csa->fcp_table_suffix, "00", 2);
    memcpy(&csa->dcp_table_suffix, "00", 2);

    memset((char *)&kiktca, 0, sizeof(kiktca));
    csa->tca = &kiktca;
    csa->nexttasknum = 1;

    memset((char *)&kiktctte, 0, sizeof(kiktctte));
    csa->tctte = &kiktctte;
    memset(csa->tctte->usrid, ' ', 8);
    memcpy(csa->tctte->usrid, "KICKGWX ", 8);
    memcpy(csa->tctte->trmid, "TCPGW001", 8);
    memcpy(csa->tctte->trmid4, "GW01", 4);
    memset(csa->tctte->sysid, ' ', 8);
    memcpy(csa->tctte->sysid, "KICKGWX ", 8);
    csa->tctte->PRMlines = 24;
    csa->tctte->PRMcols = 80;
    csa->tctte->ALTlines = 24;
    csa->tctte->ALTcols = 80;
    csa->tctte->flags = tctteflag$crlpinuse;

    csa->tctte->tioa = (char *)&tioabuf;
    csa->tctte->lotioa = (char *)&lotioabuf;
    csa->tctte->tioasize = sizeof(tioabuf);
    memset(csa->tctte->tioa, 0, csa->tctte->tioasize);
    memset(csa->tctte->lotioa, 0, csa->tctte->tioasize);

    csa->loadcb = &loadcb;
    memset(csa->loadcb, 0, sizeof(loadcb));
    csa->loadcb->loader = (char *)&kikload;
    memcpy(&csa->loadcb->loadlib, "SKIKLOAD", 8);
    kikload(csa, 0);

    memset((char *)&commarea, 0, COMASIZE);
    csa->usrcommarea = (char *)&commarea;
    csa->maxcommsize = COMASIZE;
    csa->systype = csasystype$mvs38 + csasystype$batch;
}

static int load_kicks_entry(KIKCSA *csa, char *base, char *suffix,
                            char **entry, int *load, int *size)
{
    memcpy(&csa->loadcb->loadbase, base, 6);
    memcpy(&csa->loadcb->loadsuffix, suffix, 2);
    kikload(csa, 2);
    if (csa->loadcb->loaderr1 != 0) {
        printf("KICKGWX load %.6s%.2s failed %d(%d)\n",
               base, suffix, csa->loadcb->loaderr1,
               csa->loadcb->loaderr15);
        fflush(stdout);
        return 20;
    }
    *entry = csa->loadcb->ep;
    *load = (int)csa->loadcb->loadedwhere;
    *size = csa->loadcb->loadlength;
    return 0;
}

static int load_kicks_table(KIKCSA *csa, char *base, char *suffix,
                            char **addr, int *size)
{
    memcpy(&csa->loadcb->loadbase, base, 6);
    memcpy(&csa->loadcb->loadsuffix, suffix, 2);
    kikload(csa, 2);
    if (csa->loadcb->loaderr1 != 0) {
        printf("KICKGWX load %.6s%.2s failed %d(%d)\n",
               base, suffix, csa->loadcb->loaderr1,
               csa->loadcb->loaderr15);
        fflush(stdout);
        return 20;
    }
    *addr = csa->loadcb->loadedwhere;
    *size = csa->loadcb->loadlength;
    return 0;
}

static int init_kicks(void)
{
    KIKCSA *csa = &kikcsa;
    char firstnl[8];
    char *buf;
    int rc;
    int sit_size;

    if (kicks_ready) {
        return 0;
    }

    init_base_csa(csa);

    rc = load_kicks_table(csa, "KIKSIT", csa->sit_table_suffix,
                          (char **)&csa->sit_table_addr, &sit_size);
    if (rc != 0) {
        return rc;
    }
    if (memcmp((char *)&csa->version, &csa->sit_table_addr->ver, 4)) {
        printf("KICKGWX SIT version mismatch\n");
        fflush(stdout);
        return 20;
    }

    memcpy(&csa->pcp_suffix, &csa->sit_table_addr->pcp_suffix, 2);
    memcpy(&csa->pcp_table_suffix,
           &csa->sit_table_addr->pcp_table_suffix, 2);
    memcpy(&csa->kcp_suffix, &csa->sit_table_addr->kcp_suffix, 2);
    memcpy(&csa->kcp_table_suffix,
           &csa->sit_table_addr->kcp_table_suffix, 2);
    memcpy(&csa->fcp_suffix, &csa->sit_table_addr->fcp_suffix, 2);
    memcpy(&csa->fcp_table_suffix,
           &csa->sit_table_addr->fcp_table_suffix, 2);
    memcpy(&csa->dcp_suffix, &csa->sit_table_addr->dcp_suffix, 2);
    memcpy(&csa->dcp_table_suffix,
           &csa->sit_table_addr->dcp_table_suffix, 2);
    memcpy(&csa->bms_suffix, &csa->sit_table_addr->bms_suffix, 2);
    memcpy(&csa->tcp_suffix, &csa->sit_table_addr->tcp_suffix, 2);
    memcpy(&csa->scp_suffix, &csa->sit_table_addr->scp_suffix, 2);
    memcpy(&csa->tsp_suffix, &csa->sit_table_addr->tsp_suffix, 2);
    memcpy(&csa->opid, &csa->sit_table_addr->opid, 3);
    csa->natlang = csa->sit_table_addr->natlang;
    csa->dmpclass = csa->sit_table_addr->dmpclass;
    csa->AICAmax = csa->sit_table_addr->icvr;
    csa->trcnum = csa->sit_table_addr->trcnum;
    csa->trcflags = csa->sit_table_addr->trcflags;
    memcpy(&csa->pltstrt, &csa->sit_table_addr->pltstrt, 4);
    memcpy(&csa->pltend, &csa->sit_table_addr->pltend, 4);
    csa->cwal = csa->sit_table_addr->cwal;
    csa->tctteual = csa->sit_table_addr->tctteual;
    memcpy(&csa->enqscope, &csa->sit_table_addr->enqscope, 8);
    csa->maxdelay = csa->sit_table_addr->maxdelay;
    csa->ffreekb = csa->sit_table_addr->ffreekb;
    memcpy(&csa->syncpgm, &csa->sit_table_addr->syncpgm, 8);

    rc = load_kicks_entry(csa, "KIKPCP", csa->pcp_suffix,
                          &csa->pcp_addr, &csa->pcp_load,
                          &csa->pcp_size);
    if (rc != 0) return rc;
    rc = load_kicks_entry(csa, "KIKKCP", csa->kcp_suffix,
                          &csa->kcp_addr, &csa->kcp_load,
                          &csa->kcp_size);
    if (rc != 0) return rc;
    rc = load_kicks_entry(csa, "KIKFCP", csa->fcp_suffix,
                          &csa->fcp_addr, &csa->fcp_load,
                          &csa->fcp_size);
    if (rc != 0) return rc;
    rc = load_kicks_entry(csa, "KIKDCP", csa->dcp_suffix,
                          &csa->dcp_addr, &csa->dcp_load,
                          &csa->dcp_size);
    if (rc != 0) return rc;
    rc = load_kicks_entry(csa, "KIKBMS", csa->bms_suffix,
                          &csa->bms_addr, &csa->bms_load,
                          &csa->bms_size);
    if (rc != 0) return rc;
    rc = load_kicks_entry(csa, "KIKTCP", csa->tcp_suffix,
                          &csa->tcp_addr, &csa->tcp_load,
                          &csa->tcp_size);
    if (rc != 0) return rc;
    rc = load_kicks_entry(csa, "KIKSCP", csa->scp_suffix,
                          &csa->scp_addr, &csa->scp_load,
                          &csa->scp_size);
    if (rc != 0) return rc;
    rc = load_kicks_entry(csa, "KIKTSP", csa->tsp_suffix,
                          &csa->tsp_addr, &csa->tsp_load,
                          &csa->tsp_size);
    if (rc != 0) return rc;

    rc = load_kicks_table(csa, "KIKPPT", csa->pcp_table_suffix,
                          &csa->pcp_table_addr, &csa->ppt_size);
    if (rc != 0) return rc;
    rc = load_kicks_table(csa, "KIKPCT", csa->kcp_table_suffix,
                          &csa->kcp_table_addr, &csa->pct_size);
    if (rc != 0) return rc;
    rc = load_kicks_table(csa, "KIKFCT", csa->fcp_table_suffix,
                          &csa->fcp_table_addr, &csa->fct_size);
    if (rc != 0) return rc;
    rc = load_kicks_table(csa, "KIKDCT", csa->dcp_table_suffix,
                          &csa->dcp_table_addr, &csa->dct_size);
    if (rc != 0) return rc;

    kikload(csa, 1);

    if (csa->cwal > 0) {
        buf = (char *)malloc(csa->cwal);
        if (buf == NULL) return 20;
        memset(buf, 0, csa->cwal);
        csa->cwaa = buf;
    }
    if (csa->tctteual > 0) {
        csa->tctte->tctteual = csa->tctteual;
        buf = (char *)malloc(csa->tctteual);
        if (buf == NULL) return 20;
        memset(buf, 0, csa->tctteual);
        csa->tctte->tctteuaa = buf;
    }

    memset(firstnl, 0, sizeof(firstnl));
    firstnl[0] = '\n';
    KIKKCP(csa, kikkcpINIT, firstnl);
    KIKSCP(csa, kikscpINIT, firstnl);
    KIKPCP(csa, kikpcpINIT, firstnl);
    KIKFCP(csa, kikfcpINIT, firstnl);
    KIKDCP(csa, kikdcpINIT, firstnl);
    KIKTSP(csa, kiktspINIT, firstnl);
    KIKFCP(csa, kikfcpTRANEND);
    KIKDCP(csa, kikdcpTRANEND);

    kicks_ready = 1;
    printf("KICKGWX KICKS initialized\n");
    fflush(stdout);
    return 0;
}

static void make_gateway_tca(char *program, char *commarea, int commarea_len)
{
    KIKCSA *csa = &kikcsa;
    KIKTCA *tca = csa->tca;
    KIKTCTTE *tctte = csa->tctte;
    int dp[2];
    int tp[2];

    memset((char *)tca, 0, sizeof(KIKTCA));
    memcpy((char *)tca->tranid, program, 4);
    tca->tasknum = csa->nexttasknum++;
    tctte->calen = commarea_len;
    tca->kikeibp.eibpcsa = (char *)csa;
    tca->kikeibp.eibpca = commarea;
    tca->kikeibp.eibpcalen = commarea_len;
    tca->kikeib.eibtaskn = tca->tasknum;
    tca->kikeib.eibcalen = commarea_len;
    memcpy((char *)tca->kikeib.eibtrmid, (char *)tctte->trmid4, 4);
    memcpy((char *)tca->kikeib.eibnetid, (char *)tctte->trmid, 8);
    memcpy((char *)tca->kikeib.eibtrnid, (char *)tca->tranid, 4);
    memcpy((char *)tca->kikeib.eibusrid, (char *)tctte->usrid, 8);
    memcpy((char *)tca->kikeib.eibsysid, (char *)tctte->sysid, 8);
    memcpy((char *)tca->kikeib.eibopid, &csa->opid, 3);
    dp[0] = 0;
    tp[0] = 0;
    TIMEMAC(dp[1], tp[1]);
    tca->kikeib.eibdate = dp[1];
    tca->kikeib.eibtime = (tp[1] >> 4) + 15;
}

int kickgw(char *program, char *commarea, int commarea_len)
{
    KIKCSA *csa = &kikcsa;
    int len = commarea_len;
    int rc;

    if (len < 0) {
        return 12;
    }
    if (len > MAX_REQ) {
        return 12;
    }
    rc = init_kicks();
    if (rc != 0) {
        return rc;
    }

    make_gateway_tca(program, commarea, len);
    KIKPCP(csa, kikpcpLINK, program, commarea, &len);
    KIKSCP(csa, kikscpTRANEND);
    KIKTSP(csa, kiktspTRANEND);
    KIKDCP(csa, kikdcpTRANEND);
    KIKFCP(csa, kikfcpTRANEND);
    KIKPCP(csa, kikpcpTRANEND);
    memset((char *)csa->tca, 0, sizeof(KIKTCA));
    return 0;
}

static int put_response(int rc, char *commarea, int commarea_len)
{
    int len = RSP_LEN;

    memset(rspbuf, 0, sizeof(rspbuf));
    if (rc == 0 && commarea_len > 0 && commarea_len <= MAX_REQ) {
        len = commarea_len;
        memcpy(rspbuf, &rc, 4);
        memcpy(rspbuf + 4, &len, 4);
        memcpy(rspbuf + 8, commarea, len);
        return len + 8;
    }

    memcpy(rspbuf, &rc, 4);
    memcpy(rspbuf + 4, &len, 4);
    memcpy(rspbuf + 8, "CICSGW  ", 8);
    memcpy(rspbuf + 16, reqbuf, 8);
    memcpy(rspbuf + 24, " CONNECTED OK", 13);
    return 37;
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
            x75call(10, clifd, 0, rspbuf,
                    put_response(rc, reqbuf + 12, comalen), 1);
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
 INCLUDE SKIKLOAD(KIKASRB)
 INCLUDE SKIKLOAD(KIKLOAD)
 INCLUDE SKIKLOAD(VCONSTB5)
 ENTRY @@CRT0
/*
//RUN      EXEC PGM=KICKGWX,REGION=8192K,TIME=1440,
//             COND=((4,LT,X75ASM),(4,LT,KICKGWX.LKED))
//STEPLIB  DD DSN=HERC01.KICKSSYS.V1R5M0.SKIKLOAD,DISP=SHR
//SKIKLOAD DD DSN=HERC01.KICKSSYS.V1R5M0.SKIKLOAD,DISP=SHR
//KIKRPL   DD DSN=HERC01.KICKSSYS.V1R5M0.KIKRPL,DISP=SHR
//SYSIN    DD DUMMY
//SYSPRINT DD SYSOUT=A
//SYSTERM  DD SYSOUT=A
//SYSOUT   DD SYSOUT=A
//
