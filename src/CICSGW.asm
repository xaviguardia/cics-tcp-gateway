CICSGW   TITLE 'CICS TCP GATEWAY - SOCKET LISTENER FOR KICKS'
***********************************************************************
*                                                                     *
*  CICSGW  - CICS Transaction Gateway via TCP/IP sockets              *
*                                                                     *
*  Listens on a TCP port, accepts connections, reads a fixed-format   *
*  request (program name + commarea), executes the KICKS transaction  *
*  via KIKCOBGL, and returns the response over the socket.            *
*                                                                     *
*  Protocol (fixed-format, EBCDIC):                                   *
*    Request:  8 bytes program name (padded)                          *
*             4 bytes commarea length (binary)                        *
*             N bytes commarea data                                   *
*                                                                     *
*    Response: 4 bytes return code (binary)                           *
*             4 bytes output length (binary)                          *
*             N bytes output data                                     *
*                                                                     *
*  Requires: MVS TCP/IP (EZASOKET interface)                         *
*            KICKS V1R5M0 (KIKCOBGL linkage)                         *
*                                                                     *
*  Register conventions:                                              *
*    R12 = base register                                              *
*    R11 = save area pointer                                          *
*    R10 = socket descriptor (after ACCEPT)                           *
*    R9  = listen socket descriptor                                   *
*                                                                     *
***********************************************************************
         SPACE 2
CICSGW   CSECT
         ENTRY CICSGW
         USING CICSGW,12
         STM   14,12,12(13)       Save registers
         LR    12,15              Establish base
         LA    11,SAVEAREA        Point to save area
         ST    13,4(11)           Chain save areas
         ST    11,8(13)
         LR    13,11
         SPACE 1
***********************************************************************
*  STEP 1: Initialize TCP/IP via EZASOKET INITAPI                    *
***********************************************************************
         SPACE 1
INITAPI  DS    0H
         MVC   SOCFUNC,=H'1'     INITAPI function code
         LA    1,SOCPLIST         Point to parameter list
         MVC   0(4,1),=A(SOCFUNC)
         MVC   4(4,1),=A(MAXSOC)
         MVC   8(4,1),=A(IDENT)
         MVC   12(4,1),=A(SUBTASK)
         MVC   16(4,1),=A(MAXSOCX)
         LA    2,ERRNO
         O     2,HIGHBIT          Last parameter flag
         ST    2,20(1)
         L     15,=V(EZASOKET)
         BALR  14,15
         LTR   15,15
         BNZ   TCPERR             TCP/IP init failed
         SPACE 1
***********************************************************************
*  STEP 2: Create a stream socket (AF_INET, SOCK_STREAM)             *
***********************************************************************
         SPACE 1
CREATSOC DS    0H
         MVC   SOCFUNC,=H'2'     SOCKET function code
         LA    1,SOCPLIST
         MVC   0(4,1),=A(SOCFUNC)
         MVC   4(4,1),=A(AF)     AF_INET = 2
         MVC   8(4,1),=A(SOCTYPE) SOCK_STREAM = 1
         MVC   12(4,1),=A(PROTO) Protocol = 0
         LA    2,ERRNO
         O     2,HIGHBIT
         ST    2,16(1)
         L     15,=V(EZASOKET)
         BALR  14,15
         LTR   15,15
         BNZ   TCPERR
         ST    0,LISTNSOC         Save listen socket descriptor
         LR    9,0                R9 = listen socket
         SPACE 1
***********************************************************************
*  STEP 3: Bind to port (from GWPORT parameter)                      *
***********************************************************************
         SPACE 1
BINDSOC  DS    0H
         MVC   SOCFUNC,=H'4'     BIND function code
         MVC   SADDR,SOCKADDR    Copy address structure
         LA    1,SOCPLIST
         MVC   0(4,1),=A(SOCFUNC)
         ST    9,SOCKD            Store socket descriptor
         MVC   4(4,1),=A(SOCKD)
         MVC   8(4,1),=A(SADDR)
         MVC   12(4,1),=A(SADDRLN)
         LA    2,ERRNO
         O     2,HIGHBIT
         ST    2,16(1)
         L     15,=V(EZASOKET)
         BALR  14,15
         LTR   15,15
         BNZ   TCPERR
         SPACE 1
***********************************************************************
*  STEP 4: Listen with backlog of 5                                   *
***********************************************************************
         SPACE 1
LISTNSOK DS    0H
         MVC   SOCFUNC,=H'5'     LISTEN function code
         LA    1,SOCPLIST
         MVC   0(4,1),=A(SOCFUNC)
         ST    9,SOCKD
         MVC   4(4,1),=A(SOCKD)
         MVC   8(4,1),=A(BACKLOG)
         LA    2,ERRNO
         O     2,HIGHBIT
         ST    2,12(1)
         L     15,=V(EZASOKET)
         BALR  14,15
         LTR   15,15
         BNZ   TCPERR
         SPACE 1
         WTO   'CICSGW: Listening for connections'
         SPACE 1
***********************************************************************
*  STEP 5: Accept loop - wait for connections                         *
***********************************************************************
         SPACE 1
ACCEPT   DS    0H
         MVC   SOCFUNC,=H'6'     ACCEPT function code
         LA    1,SOCPLIST
         MVC   0(4,1),=A(SOCFUNC)
         ST    9,SOCKD
         MVC   4(4,1),=A(SOCKD)
         MVC   8(4,1),=A(CLADDR)
         MVC   12(4,1),=A(CLADLEN)
         LA    2,ERRNO
         O     2,HIGHBIT
         ST    2,16(1)
         L     15,=V(EZASOKET)
         BALR  14,15
         LTR   15,15
         BNZ   TCPERR
         LR    10,0               R10 = client socket
         SPACE 1
***********************************************************************
*  STEP 6: Read request header (8-byte program + 4-byte length)      *
***********************************************************************
         SPACE 1
READREQ  DS    0H
         MVC   SOCFUNC,=H'10'    READ function code
         LA    1,SOCPLIST
         MVC   0(4,1),=A(SOCFUNC)
         ST    10,SOCKD
         MVC   4(4,1),=A(SOCKD)
         MVC   8(4,1),=A(REQHDR)
         MVC   12(4,1),=A(REQHLEN)
         MVC   16(4,1),=A(NOFLAGS)
         LA    2,ERRNO
         O     2,HIGHBIT
         ST    2,20(1)
         L     15,=V(EZASOKET)
         BALR  14,15
         LTR   15,15
         BNZ   CLOSECL            Read failed, close client
         SPACE 1
*  Read commarea data if length > 0
         L     3,REQCLEN          Commarea length from header
         LTR   3,3
         BZ    EXECTRAN           No commarea, execute directly
         C     3,=F'4096'         Sanity check
         BH    CLOSECL            Too large, reject
         SPACE 1
READCOMA DS    0H
         MVC   SOCFUNC,=H'10'    READ
         LA    1,SOCPLIST
         MVC   0(4,1),=A(SOCFUNC)
         ST    10,SOCKD
         MVC   4(4,1),=A(SOCKD)
         MVC   8(4,1),=A(COMMAREA)
         ST    3,COMALEN
         MVC   12(4,1),=A(COMALEN)
         MVC   16(4,1),=A(NOFLAGS)
         LA    2,ERRNO
         O     2,HIGHBIT
         ST    2,20(1)
         L     15,=V(EZASOKET)
         BALR  14,15
         SPACE 1
***********************************************************************
*  STEP 7: Execute KICKS transaction via KIKCOBGL                    *
***********************************************************************
         SPACE 1
EXECTRAN DS    0H
*  Initialize the EIB (Exec Interface Block) for KICKS
         XC    EIB,EIB            Clear EIB
         MVC   EIBFN,=H'0'       Function = INIT
*  Set up KIKCOBGL parameter list for INIT (function 0)
         LA    3,EIB
         ST    3,KIKPL
         LA    3,KIKVER
         ST    3,KIKPL+4
         LA    3,KIKLEN
         O     3,HIGHBIT
         ST    3,KIKPL+8
         LA    1,KIKPL
         L     15,=V(KIKCOBGL)
         BALR  14,15
         SPACE 1
*  Set up KIKCOBGL for LINK (function H'0E06')
         MVC   EIBFN,=H'3590'    LINK function code
         MVC   EIBPROG,REQPGM    Program name from request
         LA    3,EIB
         ST    3,KIKPL
         LA    3,KIKVER
         ST    3,KIKPL+4
         LA    3,REQPGM           Program name
         ST    3,KIKPL+8
         LA    3,COMMAREA         Commarea data
         ST    3,KIKPL+12
         LA    3,REQCLEN          Commarea length
         O     3,HIGHBIT
         ST    3,KIKPL+16
         LA    1,KIKPL
         L     15,=V(KIKCOBGL)
         BALR  14,15
         ST    15,RESPCODE        Save return code
         SPACE 1
***********************************************************************
*  STEP 8: Build and send response                                    *
***********************************************************************
         SPACE 1
SENDRSP  DS    0H
*  Build response header: 4-byte RC + 4-byte output length
         MVC   RSPHDR(4),RESPCODE Return code
         L     3,REQCLEN          Output = commarea (updated)
         ST    3,RSPHDR+4         Output length
*  Send response header
         MVC   SOCFUNC,=H'11'    WRITE function code
         LA    1,SOCPLIST
         MVC   0(4,1),=A(SOCFUNC)
         ST    10,SOCKD
         MVC   4(4,1),=A(SOCKD)
         MVC   8(4,1),=A(RSPHDR)
         MVC   12(4,1),=A(RSPHLEN)
         MVC   16(4,1),=A(NOFLAGS)
         LA    2,ERRNO
         O     2,HIGHBIT
         ST    2,20(1)
         L     15,=V(EZASOKET)
         BALR  14,15
         SPACE 1
*  Send commarea data as response body (if any)
         L     3,REQCLEN
         LTR   3,3
         BZ    CLOSECL
SENDCOMA DS    0H
         MVC   SOCFUNC,=H'11'    WRITE
         LA    1,SOCPLIST
         MVC   0(4,1),=A(SOCFUNC)
         ST    10,SOCKD
         MVC   4(4,1),=A(SOCKD)
         MVC   8(4,1),=A(COMMAREA)
         ST    3,COMALEN
         MVC   12(4,1),=A(COMALEN)
         MVC   16(4,1),=A(NOFLAGS)
         LA    2,ERRNO
         O     2,HIGHBIT
         ST    2,20(1)
         L     15,=V(EZASOKET)
         BALR  14,15
         SPACE 1
***********************************************************************
*  STEP 9: Close client socket and loop back to ACCEPT                *
***********************************************************************
         SPACE 1
CLOSECL  DS    0H
         MVC   SOCFUNC,=H'14'    CLOSE function code
         LA    1,SOCPLIST
         MVC   0(4,1),=A(SOCFUNC)
         ST    10,SOCKD
         MVC   4(4,1),=A(SOCKD)
         LA    2,ERRNO
         O     2,HIGHBIT
         ST    2,8(1)
         L     15,=V(EZASOKET)
         BALR  14,15
         B     ACCEPT             Loop for next connection
         SPACE 1
***********************************************************************
*  Error handling and cleanup                                         *
***********************************************************************
         SPACE 1
TCPERR   DS    0H
         WTO   'CICSGW: TCP/IP error, shutting down'
         SPACE 1
SHUTDOWN DS    0H
*  Close listen socket
         LTR   9,9
         BZ    EXIT
         MVC   SOCFUNC,=H'14'    CLOSE
         LA    1,SOCPLIST
         MVC   0(4,1),=A(SOCFUNC)
         ST    9,SOCKD
         MVC   4(4,1),=A(SOCKD)
         LA    2,ERRNO
         O     2,HIGHBIT
         ST    2,8(1)
         L     15,=V(EZASOKET)
         BALR  14,15
         SPACE 1
*  Terminate TCP/IP
         MVC   SOCFUNC,=H'99'    TERM function code
         LA    1,SOCPLIST
         MVC   0(4,1),=A(SOCFUNC)
         LA    2,ERRNO
         O     2,HIGHBIT
         ST    2,4(1)
         L     15,=V(EZASOKET)
         BALR  14,15
         SPACE 1
EXIT     DS    0H
         L     13,4(13)           Restore save area
         LM    14,12,12(13)       Restore registers
         SR    15,15              RC=0
         BR    14                 Return
         SPACE 2
***********************************************************************
*  Constants and data areas                                           *
***********************************************************************
         SPACE 1
SAVEAREA DS    18F                Register save area
HIGHBIT  DC    X'80000000'        VL flag
         SPACE 1
*  EZASOKET parameters
SOCFUNC  DC    H'0'              Socket function code
SOCPLIST DS    8F                 Parameter list (max 8 params)
SOCKD    DC    F'0'              Socket descriptor
LISTNSOC DC    F'0'              Listen socket saved
ERRNO    DC    F'0'              Error number
MAXSOC   DC    F'20'             Max sockets
MAXSOCX  DC    F'20'             Max sockets (output)
IDENT    DC    CL8'CICSGW'       Task identifier
SUBTASK  DC    CL8'        '     Subtask name
         SPACE 1
*  Socket address structure (sockaddr_in)
SOCKADDR DS    0CL16
SAFAMILY DC    H'2'              AF_INET
SAPORT   DC    X'10E1'           Port 4321 (network byte order)
SAADDR   DC    X'00000000'       INADDR_ANY
SAFILLER DC    XL8'00'           Padding
SADDRLN  DC    F'16'             Address length
         SPACE 1
*  Client address (filled by ACCEPT)
CLADDR   DS    CL16              Client sockaddr
CLADLEN  DC    F'16'             Client address length
         SPACE 1
*  Socket options
AF       DC    F'2'              AF_INET
SOCTYPE  DC    F'1'              SOCK_STREAM
PROTO    DC    F'0'              Default protocol
BACKLOG  DC    F'5'              Listen backlog
NOFLAGS  DC    F'0'              No flags for read/write
         SPACE 1
*  Request buffer
REQHDR   DS    0CL12             Request header
REQPGM   DS    CL8               Program name (8 bytes)
REQCLEN  DS    F                  Commarea length
REQHLEN  DC    F'12'             Header length
         SPACE 1
*  Response buffer
RSPHDR   DS    CL8               Response header (RC + length)
RSPHLEN  DC    F'8'              Response header length
RESPCODE DC    F'0'              Return code from KICKS
         SPACE 1
*  Commarea buffer
COMMAREA DS    CL4096             Commarea data (max 4K)
COMALEN  DC    F'0'              Actual commarea length
         SPACE 1
*  KICKS interface
         EXTRN KIKCOBGL
KIKPL    DS    6F                 KIKCOBGL parameter list
KIKVER   DC    F'17104896'        KICKS version identifier
KIKLEN   DC    H'-1'             Length sentinel
         SPACE 1
*  EIB (Exec Interface Block) for KICKS
EIB      DS    0CL100
EIBTASKN DC    F'0'              Task number
EIBCALEN DC    H'0'              Commarea length
EIBCPOSN DC    H'0'              Cursor position
EIBDATE  DC    CL4' '            Date
EIBTIME  DC    CL4' '            Time
EIBRESP  DC    F'0'              Response code
EIBRESP2 DC    F'0'              Response code 2
EIBRSRCE DC    CL8' '            Resource name
EIBDS    DC    CL8' '            Dataset name
EIBFN    DC    H'0'              Function code
EIBPROG  DC    CL8' '            Program name
EIBFILL  DS    CL48              Filler to 100 bytes
         SPACE 1
         LTORG
         END   CICSGW
