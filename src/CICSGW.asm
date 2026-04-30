CICSGW   TITLE 'CICS TCP GATEWAY - HERCULES X75 SOCKETS'
***********************************************************************
*  CICSGW  - TCP socket listener using Hercules TCPIP instruction     *
*                                                                     *
*  Uses opcode X'75' (Hercules TCPIP extension) directly.             *
*  No JCC, no EZASOKET - zero external dependencies.                  *
*                                                                     *
*  TCPIP X'75' calling convention (2-instruction per operation):       *
*    Call 1: R0=0, R3=0, alloc/copy guest input and execute op         *
*    Call 2: R0=0, R3=1, retrieve results and free conversation        *
*                                                                     *
*  Register usage:                                                     *
*    R7  = function code (low byte), socket fd (high hw for some)      *
*    R8  = aux param 1 (varies by function)                            *
*    R9  = aux param 2 (varies by function)                            *
*    R0  = phase (0=initial, >0=continue)                              *
*    R1  = byte count for data transfer                                *
*    R2  = host buffer slot returned by Hercules                       *
*    R3  = direction (0=guest-to-host, 1=host-to-guest)                *
*    R5  = guest buffer address used by the RX operand                 *
*    R4  = socket call return code                                     *
*    R14 = conversation ID (returned on phase 0, reuse on 1,2)         *
*    R15 = return code                                                 *
*                                                                     *
*  Functions: 1=INITAPI 5=SOCKET 6=BIND 8=LISTEN 9=ACCEPT             *
*            10=SEND 11=RECV 12=CLOSE 99=TERM                         *
*                                                                     *
*  Port: 4321 (0x10E1).                                                *
*  Request:  8-byte program, 4-byte commarea length, commarea bytes.   *
*  Response: 4-byte rc, 4-byte payload length, EBCDIC payload.         *
***********************************************************************
         SPACE 2
CICSGW   CSECT
         ENTRY CICSGW
         USING CICSGW,12
         STM   14,12,12(13)
         LR    12,15
         LA    11,SAVEAREA
         ST    13,4(11)
         ST    11,8(13)
         LR    13,11
         SPACE 1
         WTO   'CICSGW01I TCP Gateway starting on port 4321'
         BAL   10,CLEANSOC        Clear stale X75 sockets from prior runs
         SPACE 1
***********************************************************************
*  INITAPI - function 1                                                *
***********************************************************************
         LA    7,1                INITAPI
         BAL   10,TCPCALL
         LTR   15,15
         BM    TCPERR
         WTO   'CICSGW02I INITAPI successful'
         SPACE 1
***********************************************************************
*  SOCKET - function 5 (AF_INET=2, SOCK_STREAM=1, proto=0)            *
***********************************************************************
         LA    7,5                SOCKET
         L     8,=X'00020001'     family=2, type=1
         SR    9,9                proto=0
         BAL   10,TCPCALL
         LTR   15,15
         BM    TCPERR
         ST    15,LISTENFD        Save returned socket fd
         WTO   'CICSGW03I Socket created'
         SPACE 1
***********************************************************************
*  BIND - function 6 (INADDR_ANY, port 4321)                          *
***********************************************************************
         L     4,LISTENFD
         SLL   4,16               fd in high halfword of R7
         LA    7,6                BIND
         OR    7,4
         SR    8,8                INADDR_ANY
         L     9,=X'000210E1'     AF_INET=2, port=4321
         BAL   10,TCPCALL
         LTR   15,15
         BM    BINDERR
         WTO   'CICSGW04I Bound to port 4321'
         SPACE 1
***********************************************************************
*  LISTEN - function 8 (backlog=5)                                     *
***********************************************************************
         LA    7,8                LISTEN
         L     8,LISTENFD
         LA    9,5                backlog
         BAL   10,TCPCALL
         LTR   15,15
         BM    TCPERR
         WTO   'CICSGW05I Listening for connections'
         SPACE 1
***********************************************************************
*  ACCEPT loop                                                         *
***********************************************************************
ACCEPTLP DS    0H
         LA    7,9                ACCEPT
         L     8,LISTENFD
         SR    9,9
         BAL   10,TCPCALL
         C     15,NEG2
         BE    ACCEPTLP
         LTR   15,15
         BM    TCPERR
         ST    15,CLIENTFD        Save client fd
         WTO   'CICSGW06I Client connected'
         SPACE 1
***********************************************************************
*  RECV up to 80 bytes                                                 *
***********************************************************************
RECVLP   DS    0H
         LA    7,11               RECV
         L     8,CLIENTFD
         LA    9,80               max bytes
         MVI   ISRECV,X'01'      Flag: this is a RECV
         BAL   10,TCPCALL
         MVI   ISRECV,X'00'      Reset flag
         C     15,NEG2
         BE    RECVLP
         LTR   15,15
         BNP   CLOSECL
         SPACE 1
***********************************************************************
*  Build protocol response: rc=0, len=30, payload                      *
***********************************************************************
         MVC   RSPBUF(4),ZERO     Return code
         MVC   RSPBUF+4(4),RSPLEN Payload length
         MVC   RSPBUF+8(8),=C'CICSGW  '
         MVC   RSPBUF+16(8),REQBUF
         MVC   RSPBUF+24(13),=C' CONNECTED OK'
         LA    5,37               Header + payload length
         SPACE 1
***********************************************************************
*  SEND response                                                       *
***********************************************************************
         LA    7,10               SEND
         L     8,CLIENTFD
         SR    9,9
         LR    1,5                Byte count = response length
         LA    2,RSPBUF
         MVI   ISSEND,X'01'      Flag: caller provided send buffer
         BAL   10,TCPCALL
         MVI   ISSEND,X'00'
         LTR   15,15
         BM    CLOSECL
         WTO   'CICSGW07I Response sent'
         SPACE 1
***********************************************************************
*  CLOSE client socket                                                 *
***********************************************************************
CLOSECL  DS    0H
         LA    7,12               CLOSE
         L     8,CLIENTFD
         SR    9,9
         BAL   10,TCPCALL
         B     ACCEPTLP           Next connection
         SPACE 1
***********************************************************************
*  Error and exit                                                      *
***********************************************************************
TCPERR   DS    0H
         WTO   'CICSGW99E TCP error, shutting down'
EXIT     DS    0H
         L     13,4(13)
         LM    14,12,12(13)
         SR    15,15
         BR    14
         SPACE 2
***********************************************************************
*  CLEANSOC - close stale sockets left by earlier test runs            *
***********************************************************************
CLEANSOC DS    0H
         ST    10,CLEANRET
         LA    4,1
CLEANLP  DS    0H
         ST    4,CLEANFD
         LA    7,12               CLOSE
         LR    8,4
         SR    9,9
         BAL   10,TCPCALL
         L     4,CLEANFD
         LA    4,1(4)
         C     4,MAXCLEAN
         BNH   CLEANLP
         L     10,CLEANRET
         BR    10
         SPACE 2
***********************************************************************
*  BIND diagnostics                                                    *
***********************************************************************
BINDERR  DS    0H
         LA    7,2                GETERRORS
         L     8,LISTENFD
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
         SPACE 2
***********************************************************************
*  TCPCALL - 2-instruction TCPIP X'75' subroutine                      *
*  Input: R7=func, R8=aux1, R9=aux2                                   *
*  For SEND: R1=count, R2=guest buffer already set by caller           *
*  For RECV: uses REQBUF, R9=max bytes                                 *
*  Output: R0/R15=socket call ret_cd from R4                           *
*  Uses: R5 as guest buffer base, R6 conv ID, R10 return address       *
***********************************************************************
TCPCALL  DS    0H
         ST    10,TCPRET          Save return address
         ST    1,TCPINLN          Save optional SEND input length
         ST    2,TCPINAD          Save optional SEND input address
*  Call 1: allocate conversation, optionally copy SEND input, execute
         SR    0,0                R0 = 0 (initial)
         LA    1,0                No data to send for most calls
         LA    5,BUFFER           RX operand base for zero-length calls
         CLI   ISSEND,X'01'      SEND has guest-to-host payload
         BNE   TCPPH0
         L     1,TCPINLN          Byte count from caller
         L     5,TCPINAD          Guest buffer address from caller
TCPPH0   DS    0H
         SR    3,3                R3 = 0 (guest to host)
         DC    X'75005000'        TCPIP 0,0(5)
         LR    6,14               Save conversation ID
*  Call 2: retrieve results and deallocate conversation
         LR    14,6
         SR    0,0                R0 = 0 asks lar_tcpip for output info
         LA    3,1                R3 = 1 (host to guest)
         CLI   ISRECV,X'01'      RECV?
         BE    TCPRECV2
         LA    5,BUFFER           General output buffer
         B     TCPPH2
TCPRECV2 DS    0H
         LA    5,REQBUF           RECV output buffer
TCPPH2   DS    0H
         DC    X'75005000'        TCPIP 0,0(5)
         LR    0,4                Socket API ret_cd
         LR    15,4
         L     10,TCPRET          Restore return address
         BR    10                 Return
         SPACE 2
***********************************************************************
*  Data areas                                                          *
***********************************************************************
SAVEAREA DS    18F
TCPRET   DC    F'0'               Saved return address for TCPCALL
TCPINLN  DC    F'0'               Optional SEND length
TCPINAD  DC    F'0'               Optional SEND guest address
CLEANRET DC    F'0'               Saved return address for cleanup
CLEANFD  DC    F'0'               Current fd cleanup slot
MAXCLEAN DC    F'32'              Last stale socket slot to close
LISTENFD DC    F'0'               Listen socket fd
CLIENTFD DC    F'0'               Client socket fd
ISRECV   DC    X'00'              Flag: 01=RECV call
ISSEND   DC    X'00'              Flag: 01=SEND call has input buffer
NEG2     DC    F'-2'              Would-block retry code
EADDRUSE DC    F'48'
EADDRNA  DC    F'49'
EAFNOSUP DC    F'47'
EINVAL   DC    F'22'
ZERO     DC    F'0'
RSPLEN   DC    F'29'
         DS    0F                 Align
BUFFER   DS    CL256              General purpose buffer
REQBUF   DS    CL80               Request buffer
RSPBUF   DS    CL80               Response buffer
         LTORG
         END   CICSGW
