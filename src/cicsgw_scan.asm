* Pre-Processed by ASMSCAN, written by Jason Winter.
*
* Compiled by JCC - version 1.50.00
*          on Thu Apr 30 14:52:24 2026
*
* OLD_CSECT: @CICSGW
*
@CICSGW CSECT 
*
        EXTRN ST00002
        EXTRN ST00003
        EXTRN ST00004
        EXTRN ST00005
        EXTRN ST00006
        EXTRN ST00007
        EXTRN ST00008
        EXTRN ST00009
        EXTRN ST00010
        EXTRN ST00012
*
***************
*
* ****
* *****         exec_program
* ****
*
***************
ST00013 DS    0D
R1@1    DS    0H
        STM   14,12,12(13)
        L     2,8(0,13)
        LA    14,120(0,2)
        L     12,0(0,13)
        CL    14,4(0,12)
        BL    @F1-R1@1+4(0,15)
        L     10,0(0,12)
        BALR  11,10
        CNOP  0,4
@F1     DS    0H
        DC    F'120'
        STM   12,14,0(2)
        LR    13,2
        LR    12,15
        USING R1@1,12
*
        LR    11,1
*
        L     10,ST00017
        USING ST00048,10
*
*
* ***          ./cicsgw.c:78 [exec_program]
*
        LA    2,ST00084
        ST    2,108(0,1)
        LA    2,64(0,0)
        ST    2,112(0,1)
        MVC   116(4,13),ST00072
        LM    15,1,108(1)
        LR    2,15
        LR    3,11
        SLR   4,44
        SRA   1,24(0)
        BZ    *+20
        LR    1,00
        SLR   5,55
        DC    X'A8241000'
        BC    1,*-4
        B     *+12
        LR    5,00
        SLL   5,24(0)
        MVCL  2,44
*
* ***          ./cicsgw.c:79 [exec_program]
*
        LA    2,ST00084
        ST    2,108(0,1)
        L     2,ST00018
        LA    2,ST00104-ST00088(0,2)
        ST    2,112(0,1)
        LM    2,3,108(1)
        MVC   0(8,2),0(3)
*
* ***          ./cicsgw.c:80 [exec_program]
*
        LA    2,ST00084
        LA    2,8(0,2)
        ST    2,108(0,1)
        MVC   112(4,13),0(1)
        LM    2,3,108(1)
        MVC   0(8,2),0(3)
*
* ***          ./cicsgw.c:81 [exec_program]
*
        LA    2,ST00084
        LA    2,16(0,2)
        ST    2,108(0,1)
        L     2,ST00018
        LA    2,ST00103-ST00088(0,2)
        ST    2,112(0,1)
        LM    2,3,108(1)
        MVC   0(13,2),0(3)
*
* ***          ./cicsgw.c:84 [exec_program]
*
        LA    6,29(0,0)
*
* ***          ./cicsgw.c:85 [exec_program]
*
        LR    7,66
        A     6,ST00065
        L     2,8(0,1)
        LA    3,1000(0,0)
        LR    0,22
        SRDA  0,32(0)
        DR    0,33
        LR    2,11
        LA    3,10(0,0)
        LR    0,22
        SRDA  0,32(0)
        DR    0,33
        LR    2,00
        A     2,ST00068
        LA    4,ST00084
        STC   2,0(4,))
*
* ***          ./cicsgw.c:86 [exec_program]
*
        LR    8,66
        A     6,ST00065
        L     2,8(0,1)
        LA    3,100(0,0)
        LR    0,22
        SRDA  0,32(0)
        DR    0,33
        LR    2,11
        LA    3,10(0,0)
        LR    0,22
        SRDA  0,32(0)
        DR    0,33
        LR    2,00
        A     2,ST00068
        LA    4,ST00084
        STC   2,0(4,))
*
* ***          ./cicsgw.c:87 [exec_program]
*
        LR    9,66
        A     6,ST00065
        LA    2,10(0,0)
        ST    2,100(0,1)
        L     2,8(0,1)
        L     3,100(0,1)
        LR    0,22
        SRDA  0,32(0)
        DR    0,33
        LR    2,11
        L     3,100(0,1)
        LR    0,22
        SRDA  0,32(0)
        DR    0,33
        LR    2,00
        A     2,ST00068
        LA    4,ST00084
        STC   2,0(4,))
*
* ***          ./cicsgw.c:88 [exec_program]
*
        ST    6,104(0,1)
        A     6,ST00065
        L     2,8(0,1)
        LA    3,10(0,0)
        LR    0,22
        SRDA  0,32(0)
        DR    0,33
        LR    2,00
        A     2,ST00068
        L     3,104(0,1)
        LA    4,ST00084
        STC   2,0(4,))
*
* ***          ./cicsgw.c:90 [exec_program]
*
        XR    2,22
        ST    2,ST00080
*
* ***          ./cicsgw.c:91 [exec_program]
*
        LR    2,66
        LA    3,ST00080
        ST    2,4(0,3)
*
* ***          ./cicsgw.c:93 [exec_program]
*
        XR    15,15
ST00016 DS    0H
        L     13,4(0,13)
        L     14,12(0,13)
        LM    1,12,24(13)
        BR    14
*
        DROP  
*
        DS    0E
ST00017 DC    A(ST00048)
ST00018 DC    A(ST00088)
***************
*
* ****
* *****         main
* ****
*
***************
        ENTRY ST00019
ST00019 DS    0D
R2@1    DS    0H
        STM   14,12,12(13)
        L     2,8(0,13)
        LA    14,176(0,2)
        L     12,0(0,13)
        CL    14,4(0,12)
        BL    @F2-R2@1+4(0,15)
        L     10,0(0,12)
        BALR  11,10
        CNOP  0,4
@F2     DS    0H
        DC    F'176'
        STM   12,14,0(2)
        LR    13,2
        LR    12,15
        USING R2@1,12
*
        L     10,ST00025
        USING ST00048,10
*
*
* ***          ./cicsgw.c:104 [main]
*
        L     2,ST00027
        LA    2,ST00102-ST00088(0,2)
        ST    2,160(0,1)
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:105 [main]
*
        L     2,ST00027
        LA    2,ST00101-ST00088(0,2)
        ST    2,160(0,1)
        MVC   164(4,13),ST00071
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:108 [main]
*
        LA    2,2(0,0)
        ST    2,160(0,1)
        LA    2,1(0,0)
        ST    2,164(0,1)
        XR    2,22
        ST    2,168(0,1)
        L     15,ST00050
        LA    1,160(0,1)
        BALR  14,15
        LR    8,15
*
* ***          ./cicsgw.c:109 [main]
*
        C     8,ST00070
        BNZ   ST00022
*
* ***          ./cicsgw.c:110 [main]
*
        L     15,ST00057
        BALR  14,15
        ST    15,140(0,1)
        L     2,ST00027
        LA    2,ST00100-ST00088(0,2)
        ST    2,160(0,1)
        MVC   164(4,13),140(1)
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:112 [main]
*
        LA    15,8(0,0)
        L     12,ST00026
        B     ST00044-R4@1(0,1)
ST00022 DS    0H
*
* ***          ./cicsgw.c:114 [main]
*
        L     2,ST00027
        LA    2,ST00099-ST00088(0,2)
        ST    2,160(0,1)
        ST    8,164(0,1)
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:117 [main]
*
        LA    2,120(0,1)
        ST    2,160(0,1)
        XR    2,22
        ST    2,164(0,1)
        LA    2,16(0,0)
        ST    2,168(0,1)
        LM    15,1,160(1)
        LR    2,15
        LR    3,11
        SLR   4,44
        SRA   1,24(0)
        BZ    *+20
        LR    1,00
        SLR   5,55
        DC    X'A8241000'
        BC    1,*-4
        B     *+12
        LR    5,00
        SLL   5,24(0)
        MVCL  2,44
*
* ***          ./cicsgw.c:118 [main]
*
        LA    2,2(0,0)
        STH   2,120(0,1)
*
* ***          ./cicsgw.c:119 [main]
*
        L     2,ST00071
        STH   2,122(0,1)
*
* ***          ./cicsgw.c:120 [main]
*
        XR    2,22
        ST    2,124(0,1)
*
* ***          ./cicsgw.c:122 [main]
*
        ST    8,160(0,1)
        LA    2,120(0,1)
        ST    2,164(0,1)
        LA    2,16(0,0)
        ST    2,168(0,1)
        L     15,ST00051
        LA    1,160(0,1)
        BALR  14,15
        LR    9,15
*
* ***          ./cicsgw.c:123 [main]
*
        C     9,ST00070
        BNZ   ST00023
*
* ***          ./cicsgw.c:124 [main]
*
        L     15,ST00057
        BALR  14,15
        ST    15,144(0,1)
        L     2,ST00027
        LA    2,ST00098-ST00088(0,2)
        ST    2,160(0,1)
        MVC   164(4,13),144(1)
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:126 [main]
*
        ST    8,160(0,1)
        L     15,ST00056
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:127 [main]
*
        LA    15,8(0,0)
        L     12,ST00026
        B     ST00044-R4@1(0,1)
ST00023 DS    0H
*
* ***          ./cicsgw.c:129 [main]
*
        L     2,ST00027
        LA    2,ST00097-ST00088(0,2)
        ST    2,160(0,1)
        MVC   164(4,13),ST00071
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:132 [main]
*
        ST    8,160(0,1)
        LA    2,5(0,0)
        ST    2,164(0,1)
        L     15,ST00052
        LA    1,160(0,1)
        BALR  14,15
        LR    9,15
*
* ***          ./cicsgw.c:133 [main]
*
        C     9,ST00070
        BZ    ST00024
        LA    12,R3@1
        B     ST00029-R3@1(0,1)
ST00024 DS    0H
*
* ***          ./cicsgw.c:134 [main]
*
        L     15,ST00057
        BALR  14,15
        ST    15,148(0,1)
        L     2,ST00027
        LA    2,ST00096-ST00088(0,2)
        ST    2,160(0,1)
        MVC   164(4,13),148(1)
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:136 [main]
*
        ST    8,160(0,1)
        L     15,ST00056
        LA    1,160(0,1)
        BALR  14,15
        LA    12,R3@1
        BR    12
*
        DS    0E
ST00025 DC    A(ST00048)
ST00026 DC    A(R4@1)
ST00027 DC    A(ST00088)
*
        DROP  12
*
R3@1    DS    0H
        USING *,12
*
*
* ***          ./cicsgw.c:137 [main]
*
        LA    15,8(0,0)
        LA    12,R4@1
        B     ST00044-R4@1(0,1)
ST00029 DS    0H
*
* ***          ./cicsgw.c:139 [main]
*
        L     2,ST00038
        LA    2,ST00095-ST00088(0,2)
        ST    2,160(0,1)
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
        LA    12,R4@1
        B     ST00043-R4@1(0,1)
ST00030 DS    0H
*
* ***          ./cicsgw.c:143 [main]
*
        LA    2,16(0,0)
        ST    2,108(0,1)
*
* ***          ./cicsgw.c:144 [main]
*
        ST    8,160(0,1)
        LA    2,92(0,1)
        ST    2,164(0,1)
        LA    2,108(0,1)
        ST    2,168(0,1)
        L     15,ST00053
        LA    1,160(0,1)
        BALR  14,15
        LR    6,15
*
* ***          ./cicsgw.c:145 [main]
*
        C     6,ST00070
        BNZ   ST00031
*
* ***          ./cicsgw.c:146 [main]
*
        L     15,ST00057
        BALR  14,15
        ST    15,152(0,1)
        L     2,ST00038
        LA    2,ST00094-ST00088(0,2)
        ST    2,160(0,1)
        MVC   164(4,13),152(1)
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:148 [main]
*
        LA    12,R4@1
        B     ST00043-R4@1(0,1)
ST00031 DS    0H
*
* ***          ./cicsgw.c:152 [main]
*
        ST    6,160(0,1)
        LA    2,ST00082
        ST    2,164(0,1)
        LA    2,12(0,0)
        ST    2,168(0,1)
        XR    2,22
        ST    2,172(0,1)
        L     15,ST00055
        LA    1,160(0,1)
        BALR  14,15
        LR    7,15
*
* ***          ./cicsgw.c:153 [main]
*
        C     7,ST00060
        BZ    ST00032
*
* ***          ./cicsgw.c:154 [main]
*
        L     2,ST00038
        LA    2,ST00093-ST00088(0,2)
        ST    2,160(0,1)
        ST    7,164(0,1)
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:155 [main]
*
        ST    6,160(0,1)
        L     15,ST00056
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:156 [main]
*
        LA    12,R4@1
        B     ST00043-R4@1(0,1)
ST00032 DS    0H
*
* ***          ./cicsgw.c:160 [main]
*
        LA    2,ST00082
        L     2,8(0,2)
        LTR   2,22
        BL    ST00033
        LA    2,ST00082
        L     2,8(0,2)
        C     2,ST00072
        BNH   ST00034
ST00033 DS    0H
*
* ***          ./cicsgw.c:161 [main]
*
        L     2,ST00038
        LA    2,ST00092-ST00088(0,2)
        ST    2,160(0,1)
        LA    2,ST00082
        MVC   164(4,13),8(2)
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:162 [main]
*
        LA    2,12(0,0)
        ST    2,ST00080
*
* ***          ./cicsgw.c:163 [main]
*
        XR    2,22
        LA    3,ST00080
        ST    2,4(0,3)
*
* ***          ./cicsgw.c:164 [main]
*
        ST    6,160(0,1)
        LA    2,ST00080
        ST    2,164(0,1)
        LA    2,8(0,0)
        ST    2,168(0,1)
        XR    2,22
        ST    2,172(0,1)
        L     15,ST00054
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:165 [main]
*
        ST    6,160(0,1)
        L     15,ST00056
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:166 [main]
*
        LA    12,R4@1
        B     ST00043-R4@1(0,1)
ST00034 DS    0H
*
* ***          ./cicsgw.c:170 [main]
*
        LA    2,ST00082
        L     2,8(0,2)
        LTR   2,22
        BH    ST00035
        LA    12,R4@1
        B     ST00041-R4@1(0,1)
ST00035 DS    0H
*
* ***          ./cicsgw.c:171 [main]
*
        ST    6,160(0,1)
        L     2,ST00037
        LA    2,ST00087-ST00085(0,2)
        ST    2,164(0,1)
        LA    2,ST00082
        MVC   168(4,13),8(2)
        XR    2,22
        ST    2,172(0,1)
        L     15,ST00055
        LA    1,160(0,1)
        BALR  14,15
        LR    7,15
*
* ***          ./cicsgw.c:172 [main]
*
        LR    2,77
        LA    3,ST00082
        C     2,8(0,3)
        BNZ   ST00036
        LA    12,R4@1
        B     ST00040-R4@1(0,1)
ST00036 DS    0H
*
* ***          ./cicsgw.c:173 [main]
*
        L     2,ST00038
        LA    2,ST00091-ST00088(0,2)
        ST    2,160(0,1)
        ST    7,164(0,1)
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
        LA    12,R4@1
        BR    12
*
        DS    0E
ST00037 DC    A(ST00085)
ST00038 DC    A(ST00088)
*
        DROP  12
*
R4@1    DS    0H
        USING *,12
*
*
* ***          ./cicsgw.c:175 [main]
*
        ST    6,160(0,1)
        L     15,ST00056
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:176 [main]
*
        B     ST00043
ST00040 DS    0H
*
* ***          ./cicsgw.c:178 [main]
*
ST00041 DS    0H
*
* ***          ./cicsgw.c:180 [main]
*
        L     2,ST00047
        LA    2,ST00090-ST00088(0,2)
        ST    2,160(0,1)
        LA    2,ST00082
        ST    2,164(0,1)
        LA    2,ST00082
        MVC   168(4,13),8(2)
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:184 [main]
*
        LA    2,ST00082
        ST    2,160(0,1)
        L     2,ST00046
        LA    2,ST00087-ST00085(0,2)
        ST    2,164(0,1)
        LA    2,ST00082
        MVC   168(4,13),8(2)
        L     15,ST00058
        LA    1,160(0,1)
        BALR  14,15
        LR    9,15
*
* ***          ./cicsgw.c:187 [main]
*
        ST    6,160(0,1)
        LA    2,ST00080
        ST    2,164(0,1)
        LA    2,8(0,0)
        ST    2,168(0,1)
        XR    2,22
        ST    2,172(0,1)
        L     15,ST00054
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:190 [main]
*
        LA    2,ST00080
        L     2,4(0,2)
        LTR   2,22
        BNH   ST00042
*
* ***          ./cicsgw.c:192 [main]
*
        ST    6,160(0,1)
        LA    2,ST00084
        ST    2,164(0,1)
        LA    2,ST00080
        MVC   168(4,13),4(2)
        XR    2,22
        ST    2,172(0,1)
        L     15,ST00054
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:193 [main]
*
ST00042 DS    0H
*
* ***          ./cicsgw.c:195 [main]
*
        L     2,ST00047
        LA    2,ST00089-ST00088(0,2)
        ST    2,160(0,1)
        MVC   164(4,13),ST00080
        LA    2,ST00080
        MVC   168(4,13),4(2)
        L     15,ST00049
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:198 [main]
*
        ST    6,160(0,1)
        L     15,ST00056
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:199 [main]
*
ST00043 DS    0H
*
* ***          ./cicsgw.c:142 [main]
*
        L     12,ST00045
        B     ST00030-R3@1(0,1)
*
* ***          ./cicsgw.c:201 [main]
*
        ST    8,160(0,1)
        L     15,ST00056
        LA    1,160(0,1)
        BALR  14,15
*
* ***          ./cicsgw.c:202 [main]
*
        XR    15,15
ST00044 DS    0H
        L     13,4(0,13)
        L     14,12(0,13)
        LM    1,12,24(13)
        BR    14
*
        DROP  
*
        DS    0E
ST00045 DC    A(R3@1)
ST00046 DC    A(ST00085)
ST00047 DC    A(ST00088)
ST00048 DS    0E
*
ST00049 DC    V(ST00010)
ST00050 DC    V(ST00009)
ST00051 DC    V(ST00008)
ST00052 DC    V(ST00007)
ST00053 DC    V(ST00006)
ST00054 DC    V(ST00005)
ST00055 DC    V(ST00004)
ST00056 DC    V(ST00003)
ST00057 DC    V(ST00002)
ST00058 DC    A(ST00013)
ST00059 DC    X'00000000'
ST00060 DC    X'0000000C'
ST00061 DC    X'00000010'
ST00062 DC    X'00000064'
ST00063 DC    X'0000000A'
ST00064 DC    X'000003E8'
ST00065 DC    X'00000001'
ST00066 DC    X'0000000D'
ST00067 DC    X'00000002'
ST00068 DC    X'000000F0'
ST00069 DC    X'0000001D'
ST00070 DC    X'FFFFFFFF'
ST00071 DC    X'000010E1'
ST00072 DC    X'00001000'
ST00073 DC    X'00000004'
ST00074 DC    X'00000005'
ST00075 DC    X'00000040'
ST00076 DC    X'00000008'
ST00077 DS    0E
        DC    4X'00'
ST00078 DS    0E
        DC    132X'00'
ST00079 DS    0E
ST00080 DS    0E
        DC    8X'00'
ST00081 DS    0E
ST00082 DS    0E
        DC    12X'00'
ST00083 DS    0E
ST00084 DS    0E
        DC    4096X'00'
*
ST00085 DS    0E
*
ST00086 DS    0E
ST00087 DS    0E
        DC    4096X'00'
*
ST00088 DS    0E
*
ST00089 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'D985A2979695A285'
        DC    X'7A4099837E6C9384'
        DC    X'4096A4A39385957E'
        DC    X'6C93841500'
        DC    3X'00'
ST00090 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'D98598A485A2A37A'
        DC    X'409787947E6C4BF8'
        DC    X'A240839694819385'
        DC    X'957E6C93841500'
        DC    1X'00'
ST00091 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'A2889699A3409985'
        DC    X'8184409695408396'
        DC    X'9494819985817A40'
        DC    X'6C93841500'
        DC    3X'00'
ST00092 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'8281844083969481'
        DC    X'9385957A406C9384'
        DC    X'1500'
        DC    2X'00'
ST00093 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'A2889699A3409985'
        DC    X'8184409695408885'
        DC    X'818485997A406C93'
        DC    X'841500'
        DC    1X'00'
ST00094 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'8183838597A34D5D'
        DC    X'408681899385846B'
        DC    X'408599997E6C9384'
        DC    X'1500'
        DC    2X'00'
ST00095 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'D389A2A385958995'
        DC    X'8740869699408396'
        DC    X'95958583A3899695'
        DC    X'A21500'
        DC    1X'00'
ST00096 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'9389A2A385954D5D'
        DC    X'408681899385846B'
        DC    X'408599997E6C9384'
        DC    X'1500'
        DC    2X'00'
ST00097 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'C296A4958440A396'
        DC    X'40979699A3406C84'
        DC    X'1500'
        DC    2X'00'
ST00098 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'828995844D5D4086'
        DC    X'81899385846B4085'
        DC    X'99997E6C93841500'
ST00099 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'E296839285A34083'
        DC    X'998581A385846B40'
        DC    X'86847E6C93841500'
ST00100 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'A296839285A34D5D'
        DC    X'408681899385846B'
        DC    X'408599997E6C9384'
        DC    X'1500'
        DC    2X'00'
ST00101 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'D79699A3406C8415'
        DC    X'00'
        DC    3X'00'
ST00102 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'C3C9C3E240E3C3D7'
        DC    X'40C781A385A681A8'
        DC    X'40A2A38199A38995'
        DC    X'871500'
        DC    1X'00'
ST00103 DS    0E
        DC    X'40D9C37EF0F0F0F0'
        DC    X'40D3C5D57E00'
        DC    2X'00'
ST00104 DS    0E
        DC    X'C3C9C3E2C7E67A40'
        DC    X'00'
        DC    3X'00'
*
        END   
