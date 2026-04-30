//CICSGW   JOB (ACCT),'CICS TCP GW',CLASS=A,MSGCLASS=A,
//             MSGLEVEL=(1,1),REGION=4096K,USER=HERC01,PASSWORD=CUL8TR
//*
//* Assemble + link-edit + run the CICS TCP Gateway
//* Uses Hercules TCPIP X'75' instruction directly (no JCC needed)
//*
//ASM      EXEC PGM=IFOX00,PARM='OBJECT,NODECK',REGION=512K
//SYSPRINT DD  SYSOUT=A
//SYSUT1   DD  UNIT=3390,SPACE=(CYL,(1,1))
//SYSUT2   DD  UNIT=3390,SPACE=(CYL,(1,1))
//SYSUT3   DD  UNIT=3390,SPACE=(CYL,(1,1))
//SYSGO    DD  DSN=&&OBJSET,DISP=(NEW,PASS),UNIT=3390,
//             SPACE=(80,(200,50))
//SYSLIB   DD  DSN=SYS1.MACLIB,DISP=SHR
//SYSIN    DD  *
CICSGW   CSECT
         ENTRY CICSGW
         USING CICSGW,12
          STM   14,12,12(13)
          LR    12,15
          LA    11,SAVEAREA
          ST    13,4(11)
          ST    11,8(13)
          LR    13,11
          WTO   'CICSGW01I TCP GATEWAY STARTING PORT 4321'
          BAL   10,CLEANSOC
* INITAPI
          LA    7,1
          BAL   10,TCPCALL
          LTR   15,15
          BM    TCPERR
          WTO   'CICSGW02I INITAPI OK'
* SOCKET (AF_INET=2 SOCK_STREAM=1)
          LA    7,5
          L     8,AFSTRM
          SR    9,9
          BAL   10,TCPCALL
          LTR   15,15
          BM    TCPERR
          ST    15,LSNFD
          WTO   'CICSGW03I SOCKET CREATED'
* BIND (INADDR_ANY PORT 4321)
          L     4,LSNFD
          SLL   4,16
          LA    7,6
          OR    7,4
          SR    8,8
          L     9,BINDPRM
          BAL   10,TCPCALL
          LTR   15,15
          BM    BINDERR
          WTO   'CICSGW04I BIND OK PORT 4321'
* LISTEN BACKLOG=5
          LA    7,8
          L     8,LSNFD
          LA    9,5
          BAL   10,TCPCALL
          LTR   15,15
          BM    TCPERR
          WTO   'CICSGW05I LISTENING'
* ACCEPT LOOP
ACPTLP   DS    0H
          LA    7,9
          L     8,LSNFD
          SR    9,9
          BAL   10,TCPCALL
          C     15,NEG2
          BE    ACPTLP
          LTR   15,15
          BM    TCPERR
          ST    15,CLIFD
          WTO   'CICSGW06I CLIENT CONNECTED'
* RECV
RECVLP   DS    0H
          LA    7,11
          L     8,CLIFD
          LA    9,80
          MVI   ISRECV,X'01'
          BAL   10,TCPCALL
          MVI   ISRECV,X'00'
          C     15,NEG2
          BE    RECVLP
          LTR   15,15
          BNP   CLOSECL
* BUILD PROTOCOL RESPONSE: RC=0 LEN=29 PAYLOAD
          MVC   RSPBUF(4),ZERO
          MVC   RSPBUF+4(4),RSPLEN
          MVC   RSPBUF+8(8),RSPTXT1
          MVC   RSPBUF+16(8),REQBUF
          MVC   RSPBUF+24(13),RSPTXT2
* SEND
          LA    7,10
          L     8,CLIFD
          SR    9,9
          LA    1,37
          LA    2,RSPBUF
          MVI   ISSEND,X'01'
          BAL   10,TCPCALL
          MVI   ISSEND,X'00'
          LTR   15,15
          BM    CLOSECL
          WTO   'CICSGW07I RESPONSE SENT'
* CLOSE CLIENT
CLOSECL  DS    0H
          LA    7,12
          L     8,CLIFD
          SR    9,9
          BAL   10,TCPCALL
          B     ACPTLP
* ERROR EXIT
TCPERR   DS    0H
          WTO   'CICSGW99E TCP ERROR'
EXIT     DS    0H
          L     13,4(13)
          LM    14,12,12(13)
          SR    15,15
          BR    14
* CLEAN STALE SOCKET SLOTS FROM PRIOR TEST RUNS
CLEANSOC DS    0H
          ST    10,CLEANRET
          LA    4,1
CLEANLP  DS    0H
          ST    4,CLEANFD
          LA    7,12
          LR    8,4
          SR    9,9
          BAL   10,TCPCALL
          L     4,CLEANFD
          LA    4,1(4)
          C     4,MAXCLEAN
          BNH   CLEANLP
          L     10,CLEANRET
          BR    10
* BIND DIAGNOSTICS
BINDERR  DS    0H
          LA    7,2
          L     8,LSNFD
          SR    9,9
          BAL   10,TCPCALL
          C     15,EADDRUSE
          BE    BINDUSE
          C     15,EADDRNA
          BE    BINDNA
          C     15,EAFNOSUP
          BE    BINDAF
          C     15,EINVAL
          BE    BINDINV
          WTO   'CICSGW98E BIND FAILED'
          B     TCPERR
BINDUSE  WTO   'CICSGW98E BIND EADDRINUSE'
          B     TCPERR
BINDNA   WTO   'CICSGW98E BIND EADDRNOTAVAIL'
          B     TCPERR
BINDAF   WTO   'CICSGW98E BIND EAFNOSUPPORT'
          B     TCPERR
BINDINV  WTO   'CICSGW98E BIND EINVAL'
          B     TCPERR
* TCPCALL: 2-INSTRUCTION X75 SUBROUTINE
* IN: R7=FUNC R8=AUX1 R9=AUX2
TCPCALL  DS    0H
          ST    10,TCPRET
          ST    1,TCPINLN
          ST    2,TCPINAD
* CALL 1: ALLOCATE/COPY INPUT/EXECUTE
          SR    0,0
          LA    1,0
          LA    5,BUFFER
          CLI   ISSEND,X'01'
          BNE   TPH0
          L     1,TCPINLN
          L     5,TCPINAD
TPH0     DS    0H
          SR    3,3
          DC    X'75005000'
          LR    6,14
* CALL 2: RETRIEVE OUTPUT/FREE CONVERSATION
          LR    14,6
          SR    0,0
          LA    3,1
          CLI   ISRECV,X'01'
          BE    TRCV2
          LA    5,BUFFER
          B     TPH2
TRCV2    DS    0H
          LA    5,REQBUF
TPH2     DS    0H
          DC    X'75005000'
          LR    0,4
          LR    15,4
          L     10,TCPRET
          BR    10
* DATA
SAVEAREA DS    18F
TCPRET   DC    F'0'
TCPINLN  DC    F'0'
TCPINAD  DC    F'0'
CLEANRET DC    F'0'
CLEANFD  DC    F'0'
MAXCLEAN DC    F'32'
LSNFD    DC    F'0'
CLIFD    DC    F'0'
ISRECV   DC    X'00'
ISSEND   DC    X'00'
NEG2     DC    F'-2'
EADDRUSE DC    F'48'
EADDRNA  DC    F'49'
EAFNOSUP DC    F'47'
EINVAL   DC    F'22'
ZERO     DC    F'0'
RSPLEN   DC    F'29'
          DS    0F
AFSTRM   DC    X'00020001'
BINDPRM  DC    X'000210E1'
RSPTXT1  DC    C'CICSGW  '
RSPTXT2  DC    C' CONNECTED OK'
BUFFER   DS    CL256
REQBUF   DS    CL80
RSPBUF   DS    CL80
          LTORG
          END   CICSGW
/*
//LKED     EXEC PGM=IEWL,PARM='XREF,LIST,LET,MAP',REGION=512K,
//             COND=(9,LT,ASM)
//SYSPRINT DD  SYSOUT=A
//SYSLIB   DD  DSN=SYS1.LINKLIB,DISP=SHR
//SYSLIN   DD  DSN=&&OBJSET,DISP=(OLD,DELETE)
//SYSLMOD  DD  DSN=SYS1.LINKLIB(CICSGW),DISP=SHR
//SYSUT1   DD  UNIT=3390,SPACE=(1024,(200,20))
//*
//* Run the gateway (TIME=1440 = no time limit)
//*
//RUN      EXEC PGM=CICSGW,TIME=1440,REGION=4096K,
//             COND=((4,LT,ASM),(4,LT,LKED))
//SYSPRINT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//
