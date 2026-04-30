# CICS TCP Gateway - Verificar y publicar

## Objetivo
Compilar y ejecutar el gateway TCP en ensamblador S/370 dentro de Hercules TK5, verificar que acepta conexiones TCP y responde, y solo entonces actualizar el repo en GitHub.

## Estado actual
- Source ASM en `src/CICSGW.asm` usa instruccion Hercules TCPIP X'75' directamente (sin JCC, sin EZASOKET)
- JCL en `jcl/ASMCLG.jcl` con ASM inline + IEWL link + RUN step
- Test client Node.js en `test/test-gateway.js` con traduccion EBCDIC
- Source C alternativo en `src/cicsgw.c` (requiere JCC, no instalado en TK5)
- Source KGCC/KICKS en `src/KICKGW.c` usa la convencion real de KICKS:
  `KIKPCP(csa, kikpcpLINK, pgm, commarea, &len)`
- Source KGCC-hosted TCP gateway en `src/KICKGWX.c` usa la misma convencion
  X'75' de `src/CICSGW.asm` para bind/listen/accept/recv/send, entrando por
  runtime KGCC y llamando a `kickgw()`.
- Verificado en MVS: `IFOX00 RC=0000`, `IEWL RC=0000`, `BIND OK PORT 4321`, `LISTENING`
- Verificado con cliente binario desde el contenedor: respuesta `rc=0`, longitud `29`
- Fuente KICKS leido: el dispatch correcto es `KIKPCP(csa, kikpcpLINK, pgm, commarea, &len)` tras inicializacion estilo `KIKSIP1$`; no es 3270/JES.
- Verificado KGCC/KICKS: `jcl/KICKGW.jcl` compila y linka con `COPY/COMP/ASM/LKED RC=0000`; `PGM=KICKGW` ejecuta `RC=0000`.
- Verificado KGCC/X'75': `jcl/KICKGWX.jcl` compila y linka con
  `X75ASM/COPY/COMP/ASM/LKED RC=0000`; `PGM=KICKGWX` escucha en 4321 y
  responde `00000010 0000001d ...` desde `kickgw()` cuando KICKS todavia no
  esta inicializado.

## Lo que falta

### 1. Ensamblar en Hercules
```bash
awk '{gsub(/\r/,""); print}' jcl/ASMCLG.jcl | nc localhost 3505
```
- Verificado RC=0000 en ASM (IFOX00) y LKED (IEWL)
- El JCL ya tiene `SYSLIB DD DSN=SYS1.MACLIB,DISP=SHR` para resolver la macro WTO
- Los labels ASM deben empezar en columna 1 (sin espacio delante)

### 2. Verificar ejecucion
- El step RUN ejecuta CICSGW como programa batch con TIME=1440
- Produce WTO messages en la consola: `CICSGW01I` a `CICSGW05I`
- Si la instruccion X'75' no esta disponible, dara operation exception (S0C1)
- Si X'75' funciona pero INITAPI falla, dara `CICSGW99E TCP ERROR`

### 3. Probar con test client
```bash
node test/test-gateway.js --host=localhost --port=4321
```
- El puerto 4321 debe estar accesible desde el host Docker para esta prueba.
- En el contenedor actual NO esta publicado a macOS; dentro de la red Docker responde.

### 4. Problemas conocidos

**Instruccion X'75' (TCPIP)**: La calling convention correcta en SDL Hyperion para este caso es de 2 instrucciones por operacion: la primera asigna conversacion/copia entrada/ejecuta, la segunda recupera resultado y libera. La implementacion anterior de 3 fases repetia operaciones como BIND y producia errores como `EINVAL`.

**Port forwarding**: El docker-compose actual expone puertos 3270 y 8038. El puerto 4321 del gateway necesita exponerse tambien. Modificar `docker/docker-compose.yml` si es necesario.

**Alternativa JCC**: Si X'75' no funciona, la alternativa es instalar JCC en TK5 y compilar `src/cicsgw.c`. JCC incluye `sockets.h` que wrappea X'75'. Los binarios de JCC estan en `/tmp/jcc/` (clonado de github.com/mvslovers/jcc). Son x86-64 Linux, necesitan Docker `--platform linux/amd64` para ejecutar en ARM. El flujo seria:
1. `jcc cicsgw.c cicsgw.asm -I/jcc/include` (genera ASM)
2. `asmscan cicsgw.asm cicsgw_scan.asm cicsgw.nam` (acorta nombres)
3. `prelink -s /jcc/objs cicsgw.obj cicsgw.asm` (resuelve librerias)
4. Subir el .obj al DASD de TK5 (requiere card reader EBCDIC via rdrprep, o instalar JCC en la imagen Docker)

### 5. Siguiente paso KICKS
- Integrar en `KICKGWX` la inicializacion de `KIKSIP1$`.
- Crear TCA/commarea siguiendo `mak_tca()` de `KIKKCP1$`.
- Invocar programas con `KIKPCP(csa, kikpcpLINK, pgm8, commarea, &len)`.
- La ruta de compilacion KGCC ya esta resuelta: `JOBPROC` debe apuntar a
  `HERC01.KICKSSYS.V1R5M0.PROCLIB`, `GCCPREF=SYS1`, `PDPPREF=PDPCLIB`,
  `COMP.INCLUDE` debe usar `HERC01.KICKSTS.H`,
  `HERC01.KICKSSYS.V1R5M0.GCCCOPY`, `HERC01.KICKSTS.TH`, y
  `ASM.SYSLIB` debe concatenar `SYS1.MACLIB`, `PDPCLIB.MACLIB`,
  `SYS1.MACLIB`.

## Ficheros clave
```
src/CICSGW.asm          ASM con X'75' directo (el que hay que probar)
src/KICKGW.c            KGCC/KICKS dispatch via KIKPCP LINK
src/KICKGWX.c           Gateway TCP X'75' entrando por runtime KGCC
src/X75CALL.asm         Wrapper callable desde KGCC para instruccion X'75'
src/cicsgw.c            Version C (alternativa, requiere JCC)
src/cicsgw_scan.asm     ASM generado por JCC+asmscan (alternativa)
jcl/ASMCLG.jcl          JCL para ensamblar+linkear+ejecutar
jcl/KICKGW.jcl          JCL KGCC probado para compilar/linkar KICKGW
jcl/KICKGWX.jcl         JCL KGCC+X'75' probado para ejecutar KICKGWX
test/test-gateway.js    Test client Node.js
README.md               Documentacion (actualizar con resultados)
```
