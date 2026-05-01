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
***********************************************************************
* STIMWT - callable STIMER WAIT wrapper.                              *
*                                                                     *
* C prototype:                                                        *
*   void stimwt(int centiseconds);                                    *
*                                                                     *
* Sleeps the MVS task for the specified number of 1/100 second units. *
* stimwt(1) = 10 ms.  Properly yields CPU to Hercules host.          *
***********************************************************************
STIMWT   CSECT
         ENTRY STIMWT
         USING STIMWT,12
         STM   14,12,12(13)
         LR    12,15
         LA    10,SVSAVE2
         ST    13,4(10)
         ST    10,8(13)
         LR    13,10
         LR    11,1
         L     2,0(11)
         ST    2,SVINTV
         STIMER WAIT,BINTVL=SVINTV
         L     13,4(13)
         L     14,12(13)
         LM    0,12,20(13)
         BR    14
SVSAVE2  DS    18F
SVINTV   DC    F'1'
         LTORG
         END
