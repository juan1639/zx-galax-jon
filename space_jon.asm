org $8000

ATTR_S:	equ $5c8d	;Variable sistema: atributos (FBPPPIII)
ATTR_T:	equ $5c8f	;Variable sistema: atributos temporales
LOCATE:	equ $0dd9	;Rutina sistema: (Locate), (B = ycoord, C = xcoord)
CLS:	equ $0daf	;Rutina sistema: CLS + atributos
BORDCR:	equ $5c48	;Variable sistema (Borde)
beeper: equ $03b5	;Rutina Beeper (HL = Nota, DE = Duracion)...
			;...( Altera Registros: AF,BC,DE,HL,IX )

nro_iteraciones equ $02	; Iteraciones en las que NO se ejecuta SUB Espacio

s_1:		EQU $0f07		; Nota (Vida menos)0d07
s1_dura:	EQU $0082 / $10		; Duracion

s_2:		EQU $066e		; Nota (Pal)
s2_dura:	EQU $0105 / $10		; Duracion

s_3:		EQU $0326		; Nota (Reb)
s3_dura:	EQU $020B / $10		; Duracion

s_4:		equ $0d0f		; Nota (Pulsa-Menus)
s4_dura:	equ $0184 / $10		; Duracion	

;--------------------------------------------------------------------------
;---		ESTABLECE BORDE & ATRIBUTOS GENERALES                   ---
;--------------------------------------------------------------------------
ld	a,%00000111	; 00BBB000 (B = Borde)
ld	(BORDCR),a

call	CLS		; Llama a rutina sistema CLS
ld	a,$00		; Color del Borde
out	($fe),a		; Puerto FE

comienzo_ymp:
call 	sub_cls
call 	sub_clsattr
call	sub_attr
call	menu_principal	; -------------- Menu Principal -------------------
call	sub_attr
call	score

;==========================================================================
;---                                                                    ---
;---	               B U C L E    P R I N C I P A L                   ---
;---                                                                    ---
;==========================================================================
bucle_principal:
call 	espacio			; SUB espacio estrellado

ld	a,(settings)
bit	3,a
jr	nz,levelup_subs		; Level Up
bit	7,a
jr	z,pausainicial_subs	; Preparado...
bit	0,a
jp	nz,fin			; Final, juego Completado!

call	mover_marcianos		; SUB Mover Marcianos
call 	teclado			; SUB Leer Teclado/JoyStick
call	inicia_marcataque	; SUB Posible inicio Marciano Disparo
call	iteraciones		; SUB Contar Iteraciones

levelup_subs:
call	level_up		; SUB Level Up

pausainicial_subs:
call 	dibuja_navejugador	; SUB Dibuja Nave Jugador
call	disparo			; SUB Disparo
call	explosion		; SUB Explosion
call	marc_ataque		; SUB Ataque Marciano (Cayendo Disparo)
call	pausa_inicial		; SUB Pausa Inicial
call	imprime_cadencia	; SUB Imprimir cadencia de disparo ON/OFF
			
ld	a,(velocidad)
call	ralentiza		; SUB Ralentiza (halt)

jr	bucle_principal		; --------- Fin Bucle Principal -----------

jr $
;==========================================================================
;=================        S U B R U T I N A S        ======================
;==========================================================================
;---		         SUB - DIBUJA NAVE JUGADOR                      ---
;---                                                                    ---
;---  HL---> Coordenadas Nave (fijas)   ...  B---> Bucle Scanlines      ---
;---  DE---> Puntero direcciones Sprite ...  C---> Bucle para Incr DE   ---
;--------------------------------------------------------------------------
dibuja_navejugador:
ld	h,$50				; H = 3er Tercio FIJO
ld	a,(navejugador_x)
ld	l,a				; L = Coordenada X Nave-Jugador

ld	de,sprites_rotanavejugador-48	; Posiciona DE en esa direccion

;----------------------------------------------------------------------
ld	a,(rota_nave)			
call	z,borra_navejugador		; Si cambio de Columna (Borrar Anterior)
ld	a,(rota_nave)		
ld	c,a				; C = Bucle (Dependiendo de la Rotacion)

bucle_incrementarnave:
call 	incrementar_de			; Incrementar DE (2 veces)...
call	incrementar_de			; ...Nave-Jugador = 6 Caracteres
dec	c
jr	nz,bucle_incrementarnave

;----------------------------------------------------------------------
ld	b,$10			; Bucle $10 Scanlines

bucle_dibujanave:
ld	a,(de)			; Carga en A, el Byte correspondiente
ld	(hl),a			; Imprimelo en HL...

inc	l
inc	de
ld	a,(de)			; Siguiente Byte imprimelo a la DCHA...
ld	(hl),a

inc	l
inc	de			; ...Siguiente Byte DCHA
ld	a,(de)
ld	(hl),a

dec	l
dec	l
ld	a,h
and	%00000111
cp	$07			; Cambio de Linea??
jr	z,cambio_scanline

inc	h			; No, entonces solo inc H
jr	no_cambioscanline

cambio_scanline:
ld	a,h
xor	%00000111
ld	h,a

ld	a,l
add	a,$20			; Cambio de Linea
ld	l,a

no_cambioscanline:
inc	de			; Siguiente Byte a dibujar

djnz	bucle_dibujanave
ret		; --------- Retorna ----------

;---------------------------------------------------------------------------
;---            SUB -  B O R R A   N A V E   J U G A D O R               ---
;---------------------------------------------------------------------------
borra_navejugador:
ld	a,l
add	a,$1f
ld	l,a		; 'L' un caracter a la IZDA
ld	b,$08		; Bucle $08 Scanlines

bucle_borranavejugador:
ld	(hl),$00	; Borrado
inc	h
djnz	bucle_borranavejugador

ld	a,h
sub	$08
ld	h,a		; Devuelve 'H' al 1er Scanline

ld	a,l
sub	$1f
ld	l,a		; Devuelve 'L' a su posicion
ret 		; Retorna

;---------------------------------------------------------------------------
;---                  E S P A C I O   E S T R E L L A S                  ---
;---                                                                     ---
;---  HL---> Coordenadas Estrellas  ...  B---> Bucle de $24/36 estrellas ---
;---  DE---> Puntero direcciones de Coordenadas de cada estrella         ---
;---  DE(1)h - DE(2)l - DE(3)Posicion estrella en Byte(ej:%0000 1000)    ---
;---------------------------------------------------------------------------
espacio:
ld	de,estrellas	; Situar DE en direccion 'estrellas'
ld	b,$24		; Bucle $24 estrellas

bucle_estrellas:
ld	a,(de)
ld	h,a
inc	de
ld	a,(de)
ld	l,a
ld	(hl),$00	; Borrar estrella

call 	next_scan	; Sub Next-Scan (calculando tb Linea y Tercio)
call	scroll		; Sub Scroll (estrella ha terminado su recorrido)

inc	de
ld	a,(de)
ld	(hl),a	; Dibuja estrella (direccion DE contiene cual estrella)

dec	de
ld	a,l
ld	(de),a
dec	de
ld	a,h
ld	(de),a		; Actualiza la nueva HL en direcciones DE

inc	de
inc	de
inc 	de
djnz bucle_estrellas	; Bucle $24 estrellas
ret			; retorna

;----------------------------------------------------------------
scroll:
ld	a,h
cp	%01010000	; Hipotetico 4to Tercio? 01011000
ret	nz		; No? retorna y la estrella sigue...

ld	a,l
and	%11100000
cp	%11100000
jr	z,scroll2
ret

scroll2:
ld	h,%01000000	; Reinicia H
res	7,l
res	6,l
res	5,l		; 000C CCCC, Reinicia Linea a 0
ld	a,l
add	a,$0e		; Cambia la C CCCC tb (Simulando un Pseudo-RND)
ld	l,a		
ret			; Retorna

;---------------------------------------------------------------------------
;---                 SUB - N E X T   S C A N L I N E                     ---
;---                                                                     ---
;---   Entrada: HL --> Salida: HL ( Siguiente Scanline, teniendo en...   ---
;---            ...cuenta el posible cambio de Caracter o Tercio)        ---
;---------------------------------------------------------------------------
next_scan:
inc	h
ld	a,h		; 010T TSSS
and	$07		; 0000 0111
ret	nz		; NZ hemos terminado, Retorna

ld	a,l		; LLLC CCCC
add	a,$20		; 0010 0000
ld	l,a
ret	c		; Carry=1, entonces cambio de tercio y ret

ld	a,h		; 010T '1'000
sub	$08		; 010T '1'000
ld	h,a
ret		; Retorna

;---------------------------------------------------------------------------
;---               SUB - M O V E R   M A R C I A N O S                   ---
;---                                                                     ---
;---	DE(1)---> Parte Alta 'H'   ...  DE(2)---> Parte Baja 'L'         ---
;---    DE(3)---> Nro Marciano     ...  DE(4)---> ON/OFF                 ---
;---    DE(5)---> Mover Izda/Dcha  ...  DE(6)---> Nro Rotacion Marciano  ---
;---    DE(7)---> Cual Animacion de Marciano toca                        ---
;---    B ------> Bucle Nro.Marcianos, Bucles Scanlines Marcianos        ---
;---------------------------------------------------------------------------
mover_marcianos:
ld	b,$19		; Bucle de cuantos marcianos salen
ld	de,marcianos	; Posiciona DE en esa direccion 

bucle_marcianos:
ld	a,(de)		; Carga en A, H
ld	h,a
inc	de		; Inc DE...
ld	a,(de)
ld	l,a		; ...para cargar en A, L

;-------------------------- R O T A C I O N E S --------------------------
rotaciones:
inc	de
inc	de
ld	a,(de)
or	a
jr	z,continua_siguientemarciano3	; Marciano Inactivo... Jr siguiente

inc	de	; --- De(5)= Izda dcha ---
ld	a,(de)
cp	$01
jp	z,rotarmarciano_derecha		;---  OJO! JP  ---
ld	a,(de)
cp	$ff
jp	z,rotarmarciano_izquierda	;---  OJO! JP  ---

;-------------------------------------------------------------------------
continua_siguientemarciano:
inc	de
ld	a,(de)
dec	a
ld	(de),a
jr	nz,continua_siguientemarciano2

ld	a,$03
ld	(de),a

continua_siguientemarciano2:
inc	de			; Siguiente Marciano
djnz	bucle_marcianos		; Bucle Marcianos
ret			; Retorna

;---------------------------------------------------------------------------
continua_siguientemarciano3:
inc	de
inc	de
inc	de
jr	continua_siguientemarciano2

;---------------------------------------------------------------------------
;---        JR - R O T A R   D E R E C H A  ( M A R C I A N O )          ---
;---                                                                     ---
;---   PUSH DE para que ahora DE---> Puntero de Rotaciones de Marcianos  ---
;---------------------------------------------------------------------------
rotarmarciano_derecha:
inc	de
ld	a,(de)
inc	a
ld	(de),a
cp	$0c
jr	z,rotar_izquierda

;---------------------------------------------------------------
;---      C U A L   M A R C I A N O  ( R O T A R )           ---
;---------------------------------------------------------------
inc	de
ld	a,(de)
dec	a
jr	z,animacion_uno
dec	a
jr	z,animacion_dos
dec	a
jr	z,animacion_tres	 
jr	$

;--------------------------------------------------------------
animacion_dos:
dec	de
ld	a,(de)
ld	c,a

push	de
ld	de,sprites_rotamarciano2-24

bucle_incrementar2:
call incrementar_de
dec	c
jr	nz,bucle_incrementar2

jr	comienza_rotacion

;----------------------------------------------------------------
animacion_tres:
dec	de
ld	a,(de)			
ld	c,a

push	de
ld	de,sprites_rotamarciano-24

bucle_incrementar3:
call incrementar_de
dec	c
jr	nz,bucle_incrementar3

jr	comienza_rotacion	

;---------------------------------------------------------------
animacion_uno:
dec	de
ld	a,(de)
ld	c,a

push	de
ld	de,sprites_rotamarciano3-24

bucle_incrementar:
call incrementar_de
dec	c
jr	nz,bucle_incrementar

;---------------------------------------------------------------
comienza_rotacion:
push	bc
ld	b,$08		; Bucle de $08 Scanlines

bucle_rotacion:
ld	a,(de)
ld	(hl),a		; Dibuja el Marciano correspondiente
			; ...al Nro de Rotacion...
inc	de
inc	l
ld	a,(de)
ld	(hl),a		; ...siguiente Columna...

inc	de
inc	l
ld	a,(de)
ld	(hl),a		; ... Siguiente Columna (3 caracteres)

dec	l
dec	l
inc	h
inc	de		; Siguiente Scanline

;call	next_scan
djnz	bucle_rotacion

pop	bc
pop	de
inc	de			; (--- porque va a siguientemarciano2 ---)
jp	continua_siguientemarciano2	; -----  OJO! jp -----
jr 	$

;---------------------------------------------------------------------------
rotar_izquierda:
dec	de
ld	a,$ff
ld	(de),a

inc	de
xor	a
ld	(de),a
jr	continua_siguientemarciano

;---------------------------------------------------------------------------
rotar_derecha:
dec	de
ld	a,$01
ld	(de),a

inc	de
xor	a
ld	(de),a
jp	continua_siguientemarciano	; *** Jp ***

;---------------------------------------------------------------------------
;---       JR - R O T A R   I Z Q U I E R D A  ( M A R C I A N O )       ---
;---                                                                     ---
;---------------------------------------------------------------------------
rotarmarciano_izquierda:
inc	de
ld	a,(de)
inc	a
ld	(de),a
cp	$0c
jr	z,rotar_derecha

;---------------------------------------------------------------
;---      C U A L   M A R C I A N O  ( R O T A R )           ---
;---------------------------------------------------------------
inc	de
ld	a,(de)
dec	a
jr	z,animacion_unoizq
dec	a
jr	z,animacion_dosizq
dec	a
jr	z,animacion_tresizq	
jr	$

;--------------------------------------------------------------
animacion_dosizq:
dec	de
ld	a,(de)
ld	c,a

push	de
ld	de,sprites_rotamarciano2+264

bucle_incrementarizq2:
call decrementar_de
dec	c
jr	nz,bucle_incrementarizq2

jr	comienza_rotacionizq

;--------------------------------------------------------------
animacion_tresizq:
dec	de
ld	a,(de)			
ld	c,a

push	de
ld	de,sprites_rotamarciano+264

bucle_incrementarizq3:
call decrementar_de
dec	c
jr	nz,bucle_incrementarizq3

jr	comienza_rotacionizq

;--------------------------------------------------------------
animacion_unoizq:
dec	de
ld	a,(de)
ld	c,a

push	de
ld	de,sprites_rotamarciano3+264

bucle_incrementarizq:
call decrementar_de
dec	c
jr	nz,bucle_incrementarizq

;--------------------------------------------------------------
comienza_rotacionizq:
push	bc
ld	b,$08		; Bucle $08 Scanlines

bucle_rotacionizq:
ld	a,(de)
ld	(hl),a		; Dibuja Marciano correspondiente...
			; ... al Nro de Rotacion
inc	de
inc	l
ld	a,(de)
ld	(hl),a		; Siguiente Columna...

inc	de
inc	l
ld	a,(de)
ld	(hl),a		; Siguiente Columna (Total 3 caracteres)

dec	l
dec	l
inc	h
inc	de		; Siguente Scanline
;call	next_scan
djnz	bucle_rotacionizq

pop	bc
pop	de
inc	de			; (--- porque va a SiguienteMarciano2 ---)
jp	continua_siguientemarciano2	; --- OJO! utilizado JP ---
jr 	$

;---------------------------------------------------------------------------
incrementar_de:
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
ret		; Retorna

decrementar_de:
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
dec	de
ret		; Retorna

;---------------------------------------------------------------------------
sonido_marciano:
ld	a,h
sub	$57
ld	h,a
ld	(soni_disp),hl
ld	a,h
add	a,$57
ld	h,a

ld	a,$03
call	sonido
ret

;---------------------------------------------------------------------------
;---           S U B  -   I N I C I A   ATAQUE MARCIANO                  ---
;---------------------------------------------------------------------------
inicia_marcataque:
ld	a,(dificultad)		
ld	c,a		; Carga en C, la dificultad de los Marcianos
ld	a,(contador_it)
or	a			; Para atacar, ContadorIt tiene que ser >$10
cp	c			
ret	c			; Retorna Inmediato si <$10

ld	de,ataque_marciano	; Situa DE(1) ON/OFF
ld	a,(de)
or	a
ret	nz			; Retorna Inmediato si esta ACTIVO

;-----------------------------------------------------------------
push	de
jr	que_marcianoataca	; Buscar un Marciano que dispare
ataque_on:
pop	de

;-----------------------------------------------------------------
inc	a			; Activado! A=1
ld	(de),a			; Activado Ataque-Marciano DE(1)

inc	de
ld	h,$40			; Coordenada 'H' Inicial DE(2)
ld	a,h
ld	(de),a

inc	de
ld	a,c
inc	a
ld	l,a			; Coordenada 'L' Inicial DE(3)
ld	a,l
ld	(de),a

ld	a,$03			; Sonido Ataque Marciano
call	sonido
no_hayatacante:
ret		; Retorna

;---------------------------------------------------------------------------
;---           S U B -  E L   A T A Q U E   M A R C I A N O              ---
;---                                                                     ---
;---    DE(1)---> Ataque ON/OFF                                          ---
;---    DE(2)---> Coordenada 'H'  ...  DE(3)---> Coordenada 'L'          ---
;---------------------------------------------------------------------------
marc_ataque:
ld	de,ataque_marciano	; Situa DE(1) ON/OFF
ld	a,(de)
or	a
ret	z			; Retorna Inmediato si Ataque=OFF

;----------------------------------------------------------------
inc	de
ld	a,(de)
ld	h,a		; Carga en H ... DE(2)

inc	de
ld	a,(de)		; Carga en L ... DE(3)
ld	l,a

ld	b,$08		; Bucle $08 Scanlines

bucle_borramarcataque:
ld	(hl),$00	; Borrado
inc	h
djnz 	bucle_borramarcataque

ld	a,h
sub	$08
ld	h,a		; Vuelve al 1er Scanline
dec	de
ld	(de),a

ld	a,l
add	a,$20		; + $20 Siguiente Linea
call	c,aumenta_tercio	; Siguiente Tercio??
ld	l,a
inc	de
ld	(de),a

;----------------------------------------------------
;---               NOS HAN DADO??                 --- 
;----------------------------------------------------
dec	de		; Situa DE en 'H'
ld	a,(de)
inc	de
or	a
cp	$50
jr	nz,no_comprobar

ld	a,(navejugador_x)
ld	c,a
ld	a,(de)
cp	c
jp	z,game_over
inc	c
cp	c
jp	z,game_over

;----------------------------------------------------
no_comprobar:
dec	de
dec	de
ld	a,(de)	; Si Disparo-Marciano= OFF ...
or	a
ret	z	; ... Retorna Inmediato

;----------------------------------------------------
inc	de
inc	de
ld	b,$08		; Bucle $08 Scanlines

bucle_dibujamarcataque:
ld	(hl),%00011100	; Dibuja Disparo Ataque-Marciano
inc	h
djnz 	bucle_dibujamarcataque
ret			; Retorna

;---------------------------------------------------------------------------
aumenta_tercio:
push	af
ld	a,h
add	a,$08		; Suma Tercio +($08)
cp	$58		; Si $58, Disparo ha llegado abajo...
call	z,ataque_off	; ... Entonces Disparo= OFF

ld	h,a
ld	(de),a		; Si no, actualiza H a un nuevo Tercio y sigue...
pop	af
ret		; Retorna

;-------------------------------------
ataque_off:
dec	de
xor	a
;ld	a,$00
ld	(de),a	; Disparo-Marciano= OFF
inc	de

push	de
call	score	; Redibuja el Marcador
pop	de
ret		; Retorna

;---------------------------------------------------------------------------
;---           S U B -  Q U E   M A R C I A N O   A T A C A              ---
;---                                                                     ---
;---   DE(1)---> Coordenada 'H'   ...  DE(2)---> Coordenada 'L'          ---
;---   DE(3)---> Nro. de Marciano ...  DE(4)---> Ataque ON/OFF           ---
;---------------------------------------------------------------------------
que_marcianoataca:
ld	de,marcianos		; Situa DE en 'marcianos'
ld	a,(navejugador_x)	; Que Coordenada L tiene Nave-Jugador??...
add	a,$60			; ...y sumale $60
ld	c,a			; ...lo cargas en C

ld	b,$19			; Bucle $19 Marcianos Totales

bucle_busca_atacante:
inc	de			; Situate en DE(2) 'L'

bucle_alineado_conjugador:
ld	a,(de)			; Compara si estas debajo de algun Marciano
cp	c
jr	z,preataque_on		; Z, entonces Jr Preataque...

desactivado_sigue:	
ld	a,c
sub	$20			; Sube 'L' ...y Sigue buscando
ld	c,a
jr	nc,bucle_alineado_conjugador	; Bucle (hasta que se acabe el Tercio)

inc	de
inc	de
inc	de
inc	de
inc	de
inc	de			; Situate otra vez en DE(1)
djnz	bucle_busca_atacante

pop	de	; NO encontrado Posible atacante, entonces POP y regresa
jr	no_hayatacante	

;---------------------------------------------------------------------------
preataque_on:
inc	de
inc	de
ld	a,(de)	; Comprobar si REALMENTE hay un Marciano en esa posicion...
dec	de
dec	de
or	a
jr	z,desactivado_sigue	; Si Z, NO hay! Entonces sigue buscando...
jp	ataque_on	; Si no... Iniciar ataque (ON) *** OJO Jp ***

;---------------------------------------------------------------------------
;---                         SUB - D I S P A R O                         ---
;---                                                                     ---
;---   HL---> Posicion del disparo             B---> Bucle Scanlines     ---
;---  (Settings): Bit1= 1/0 Disparo ON/OFF                               ---
;---  (Disparo_y): Coordenada Y disparo 'H'                              ---
;---  (Disparo_x): Coordenada X disparo 'L'                              ---
;---------------------------------------------------------------------------
disparo:
ld	a,(settings)		; Si Disparo OFF...
bit	1,a			; Bit1= 0 ...
ret	z			; ... entonces Retorna

call	borrar_disparo
call	dibuja_disparo

ld	a,$03
call	sonido
ret				; Retorna

;---------------------------------------------------------------------------
;---                  SUB - I N I C I A   D I S P A R O                  ---
;---------------------------------------------------------------------------
inicia_disparo:
ld	a,(settings)		; ACTIVA/Inicia el Disparo
set	1,a			; Bit1= 1 (ON)
ld	(settings),a

ld	a,$04
ld	(cadencia),a

;------------------------------------------------------------------
ld	a,(rota_nave)
or	a			; Alinea Rotacion Disparo con ...
jr	z,rotacion_zero

ld	(rota_disparo),a	; ... Rotacion Nave-Jugador

;------------------------------------------------------------------
continua_rotacionzero:
ld	a,$50			; Coordenadas Iniciales del Disparo
ld	(disparo_y),a
ld	a,(navejugador_x)
;sub	$20			; --- (Justo encima de la Nave-Jugador) ---
ld	(disparo_x),a
ret				; Retorna

;---------------------------------------------------------------------------
rotacion_zero:
ld	a,$01
ld	(rota_disparo),a
jr	continua_rotacionzero

;---------------------------------------------------------------------------
;---                  SUB - B O R R A R   D I S P A R O                  ---
;---------------------------------------------------------------------------
borrar_disparo:
ld	a,(settings)
res	5,a			; Bit5 = 0 'BORRA' Disparo
ld	(settings),a

ld	a,(disparo_y)		; Actualiza H
ld	h,a
ld	a,(disparo_x)		; Actualiza L
ld	l,a

;----------------------------------------------------
inc	l
ld	b,$08			; Bucle $08 Scanlines

bucle_borrardisparo:
ld	(hl),$00
inc	h
djnz	bucle_borrardisparo	; Bucle Scanlines (Borrar)

call	atributos_disparo
dec	l
ret				; Retorna

;---------------------------------------------------------------------------
;---                  SUB - D I B U J A   D I S P A R O                  ---
;---------------------------------------------------------------------------
dibuja_disparo:
ld	a,(settings)
set	5,a		; Bit5 = 'DIBUJA' Disparo
ld	(settings),a

ld	a,(disparo_y)
ld	h,a		; Actualiza 'H' HL

ld	a,l
sub	$20		; Resta $20 (Sube un caracter)
;cp	$ef
ld	l,a
ld	(disparo_x),a	; Actualiza (disparo x), 'L'
call	c,tercio_anterior ; Si Carry=1 ... entonces Cambio de TERCIO

push	hl		;--------------------------------------------
call 	blanco		; --- SUB-Comprobar si hemos hecho BLANCO ---
pop	hl		; -------------------------------------------

;--------------------------------------------------------------------
call	sonido_disparo

ld	a,(settings)		; Si disparo OFF...
bit	1,a
ret	z			; ... Retorna

ld	a,(rota_disparo)    ; Alinear Rotacion Nave-Jugador con el Disparo
ld	b,a			; Carga en B,A...(Bucle de B rotaciones)
ld	a,$80			; Rotaciones Comienzan en 1000 0000

bucle_rotaciondisparo:
rrca				; Rota a la Dcha
djnz	bucle_rotaciondisparo

;------------------------------------------------------------------
inc	l
ld	b,$08			; Bucle $08 Scanlines

bucle_dibujardisparo:
ld	(hl),a			; Dibuja Disparo ($01)
inc	h
djnz	bucle_dibujardisparo	; Bucle Scanlines disparo

call	atributos_disparo
ret			; Retorna

;-------------------------------------------------------------------
;---        SUB -  A T T R   D E L   D I S P A R O               ---
;-------------------------------------------------------------------
atributos_disparo:
ld	a,h
sub	$08		; Resta 8 (Vuelve Principio del Scanline)
ld	h,a

cp	$50
jr	z,attr_dispa
cp	$48
jr	z,attr_disp11
cp	$40
jr	z,attr_disp18
;jr	$

attr_dispa:
ld	a,$5a
ld	h,a
ld	c,$02
jr	bucle_atributosdisparo

attr_disp11:
ld	a,$59
ld	h,a
ld	c,$04
jr	bucle_atributosdisparo

attr_disp18:
ld	a,$58
ld	h,a
ld	c,$04

bucle_atributosdisparo:
ld	a,(settings)
bit	5,a		; Si Bit5=1...entonces Jr Disparo-Attr=Amarillo(ON)...
jr	nz,attr_amarillo	; ...Si Bit5=0...entonces Attr=Verde (OFF)

ld	(hl),c		; Atributo Verde (Borrar)
ret		; Retorna

attr_amarillo:
ld	(hl),$46 	; Atributo de Disparo (Amarillo+Bright)
ret		; Retorna

;---------------------------------------------------------------------------
;---        SUB - T E R C I O   A N T E R I O R   ( Disparo )            ---
;---------------------------------------------------------------------------
tercio_anterior:
ld	a,(disparo_y)
cp	$50			
jr	nz,cuarenta_y8	; Si NO es $50... salta a comprobar si $48...

ld	a,$48		; $50! entonces sube a TERCIO $48
ld	h,a
ld	(disparo_y),a
ret			; Retorna

cuarenta_y8:
cp	$48
jr	nz,cuarenta	; Si NO es $48... salta porque es $40

ld	a,$40
ld	h,a
ld	(disparo_y),a	; $48! entonces sube a TERCIO $40
ret

cuarenta:
ld	a,(settings)	; Limite Superior alcanzado y ...
res	1,a		; desactivar el Disparo
ld	(settings),a
ret			; Retorna

;---------------------------------------------------------------------------
;---          SUB -  H E M O S   H E C H O   B L A N C O ??              ---
;---                                                                     ---
;---   DE(2)---> Coordenada 'L' del Marciano                             ---
;---   DE(4)---> Marciano ON/OFF                                         ---
;---------------------------------------------------------------------------
blanco:
ld	a,h
cp	$40
ret	nz	; Retorna Inmediato Si NO es el 1er TERCIO (No hay Marcianos)

;----------------------------------------------------
ld	de,marcianos	; Situa DE en ese puntero de memoria
inc	de
inc	de
inc	de	; ------  De(4) ---> ON/OFF  --------
ld	b,$19	; ------  Bucle $19 Marcianos Totales

bucle_quemarciano_abatido:
ld	a,(de)
or	a
jr	z,aqui_nohay	; Si Z, no hay Marciano, salta al siguiente...

;-------------------------------------------------
dec	de
dec	de		; ---  De(2) ---> 'L'  ---
ld	a,(de)
cp	l
jr	z,desactivar_marciano	; ... y Retorna

inc	l
cp	l
jr	z,desactivar_marciano	; ... y Retorna

inc	l
cp	l
jr	z,desactivar_marciano	; ... y Retorna

dec	l
dec	l

inc	de
inc	de
aqui_nohay:
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de	; ---  Se situa en De(4) ---> ON/OFF ---
djnz	bucle_quemarciano_abatido
ret				; Retorna

;---------------------------------------------------------------------------
desactivar_marciano:
inc	de
inc	de
ld	a,$00			; Desactiva el Marciano de esa Posicion...
ld	(de),a
call	inicia_explosion	; ... Y Inicia Explosion
ret			; Retorna

;--------------------------------------------------------------------------
sonido_disparo:
ld	a,h
sub	$39
ld	h,a
ld	(soni_disp),hl
ld	a,h
add	a,$39
ld	h,a
ret		; Retorna

;---------------------------------------------------------------------------
;---            SUB - I N I C I A   E X P L O S I O N                    ---
;---------------------------------------------------------------------------
inicia_explosion:
ld	a,(settings)
set	2,a		; ---     Activa la Explosion     ---
res	1,a		; *** Desactivar OFF el disparo tb ***
ld	(settings),a

ld	a,(score_012)
inc	a		; --- Incrementar Score ---
cp	$64		; Hemos Completado el Juego??
jr	z,juego_completado	; ... entonces Jr Completado
ld	(score_012),a

push	hl
call	score		; SUB Actualizar Score
pop	hl

ld	a,(cuantos_marc)
inc	a
cp	$19		; Hemos abatido a Todos??
call	z,activa_bit3
ld	(cuantos_marc),a

ld	a,$07			; 7 Frames de Explosion
ld	(contador_explo),a

ld	h,$40		; (Todos Marcianos en 1er Tercio)
ld	a,h
ld	(explo_y),a	; Coordenada Y de la Explosion

ld	a,l
ld	(explo_x),a	; Coordenada X de la Explosion
ret			; Retorna

;----------------------------------------------------------------
activa_bit3:
push	af
ld	a,(settings)
set	3,a		; Settings Bit3= 1 (Level Up) 
ld	(settings),a

ld	a,$59
ld	(pausa_i),a

xor	a
ld	(contador_it),a
pop	af
ret		; Retorna

;----------------------------------------------------------------
juego_completado:
ld	a,(settings)
set	0,a		; Bit0= 1 Juego Completado
ld	(settings),a

ld	a,$07			; 7 Frames de Explosion
ld	(contador_explo),a

ld	h,$40		; (Todos Marcianos en 1er Tercio)
ld	a,h
ld	(explo_y),a	; Coordenada Y de la Explosion

ld	a,l
ld	(explo_x),a	; Coordenada X de la Explosion
ret		; Retorna

;---------------------------------------------------------------------------
;---                  SUB -  L A   E X P L O S I O N                     ---
;---                                                                     ---
;---   DE ---> Puntero de Sprites Explosion                              ---
;---   HL ---> Puntero VRAM                                              ---
;---   Bit2 (Settings) = 1/0 Explosion ON/OFF                            ---
;---------------------------------------------------------------------------
explosion:
ld	a,(settings)
bit	2,a			; Si Bit2=0 = NO Explosion ...
ret	z			; ... y Retorna inmedianto

;--------------------------------------------------------------------			
ld	a,(explo_y)		; Actualiza H en exploY
ld	h,a
ld	a,(explo_x)		; Actualiza L en exploX
ld	l,a

ld	b,$08			; Bucle $08 Scanlines

bucle_scansborrado:
dec	l			; Dec L (para borrar antes y despues)
ld	(hl),$00		; ... Borrar ...
inc	l
inc	l
inc	l
ld	(hl),$00
dec	l
dec	l
inc	h
djnz bucle_scansborrado

ld	a,h			; Regresa al 1er Scanline (puntero Caracter)
sub	$08
ld	h,a

;--------------------------------------------------------------------
ld	a,(contador_explo)	; Frames de la explosion...
push	hl
call	sonido_explosion
pop	hl
dec	a			; ... decrementandose...
ld	(contador_explo),a	; Actualiza Frames Explosion
jr	z,anula_explosion	; Z entonces, Jr Fin de la explosion

ld	de,explosion_sprites	; Posiciona DE en esa direccion
ld	b,a			; B = Bucle para situar DE en el Sprite...
				; ... correspondiente (Incrementando 'E')
bucle_incrementosexplo:
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
djnz	bucle_incrementosexplo

;---------------------------------------------------------------------
ld	a,$01
call	sonido

;---------------------------------------------------------------------
ld	b,$08			; Bucle $08 Scanlines

bucle_explosion:
ld	a,(de)			; Carga en A, el Byte correspondiente
ld	(hl),a			; Imprimelo en HL

inc	l
inc	de
ld	a,(de)			; Siguiente Byte imprimelo a la DCHA
ld	(hl),a

dec	l
inc	h
inc	de			; Siguiente Byte a dibujar
djnz	bucle_explosion		; Bucle Explosion Marciano

halt
ret			; Retorna

;---------------------------------------------------------------------------
anula_explosion:
ld	a,(settings)
res	2,a		; Bit2 = 0 = Explosion OFF
ld	(settings),a

ld	a,(contador_explo)
ld	a,$07			; Reinicia el Contador de Explosion
ld	(contador_explo),a

ld	a,(explo_y)	; Actualiza H en exploY (para Borrado Final)
ld	h,a
ld	a,(explo_x)	; Actualiza L en exploX  ("     "      ")
ld	l,a

ld	b,$08		; Bucle $08 Scanlines

bucle_borradofinal:
ld	(hl),$00	; ... Borrado Final ...
inc	l
ld	(hl),$00
dec	l
inc	h
djnz bucle_borradofinal
ret			; Retorna

;---------------------------------------------------------------------------
sonido_explosion:
ld	h,a
ld	l,$07
ld	(soni_disp),hl
ret

;---------------------------------------------------------------------------
;---                    SUB - L E E R   T E C L A D O                    ---
;---                                                                     --- 
;---         Disparar ---------> Cursor JoyStick Arriba / Abajo          --- 
;---         Izquierda --------> Cursor JoyStick Izquierda               ---
;---         Derecha ----------> Cursor JoyStick Derecha                 ---
;---------------------------------------------------------------------------
teclado:
ld	a,(cadencia)
inc	a
cp	$25
jr	z,sepuede_disparar
ld	(cadencia),a
jr	tecla_izq

;-------------------- Permitir disparar (Cadencia) ------------------
sepuede_disparar:
ld	a,$ef			;Carg en A, puerto $ef (semifila 6...0)
in	a,($fe)			;Lee (In A) el puerto entrada $fe
bit	4,a			;Comprobamos estado del Bit4 (Tecla '6')
jr 	nz,tecla_disparo2	;NZ = '6' No pulsada, salta a la siguiente...

ld	a,(settings)		; Si el disparo esta ACTIVO ...
bit	1,a			; ... Bit1 = 1 ...
ret	nz			; ... Retorna

ld	a,(cadencia)
cp	$24			; Solo dispara si A = $24
jr	z,inicia_eldisparo

;--------------------------------------------------------------------
tecla_disparo2:
ld	a,$ef			;Carg en A, puerto $ef (semifila 6...0)
in	a,($fe)			;Lee (In A) el puerto entrada $fe
bit	3,a			;Comprobamos estado del Bit3 (Tecla 7)
jr 	nz,tecla_izq		;NZ = '7' No pulsada, salta a la siguiente...

ld	a,(settings)		; Si el disparo esta ACTIVO ...
bit	1,a			; ... Bit1 = 1 ...
ret	nz			; ... Retorna

ld	a,(cadencia)
cp	$24			; Solo dispara si A = $24
jr	z,inicia_eldisparo

;--------------------------------------------------------------------
tecla_izq:
ld	a,$f7			;Carg en A, puerto $fe (semifila 1...5)
in	a,($fe)			;Lee (In A) el puerto entrada $fe
bit	4,a			;Comprobamos estado del Bit4 (Tecla 5)
jr 	nz,tecla_dcha		;NZ = '5' No pulsada, salta a la siguiente...

ld	a,(rota_nave)
dec	a			; Decrementa la Rotacion
dec	a
cp	$ff
call	z,nave_izquierda	; Z, Decrementa un caracter
ld	(rota_nave),a
ret			; Retorna

;--------------------------------------------------------------------
tecla_dcha:
ld	a,$ef			;Carg en A, puerto $ef (semifila 6...0)
in	a,($fe)			;Lee (In A) el puerto entrada $fe
bit	2,a			;Comprobamos estado del Bit2 (Tecla 8)
ret 	nz			;NZ = '8' No pulsada, Retorna ...

ld	a,(rota_nave)
inc	a			; Incrementa la Rotacion
inc	a
cp	$09			; Si $09... Incrementa un caracter
call	z,nave_derecha	
ld	(rota_nave),a
ret			; Retorna

;---------------------------------------------------------------------------
inicia_eldisparo:
call	inicia_disparo
ret		; Retorna

;---------------------------------------------------------------------------
nave_izquierda:
ld	a,(navejugador_x)
dec	a			; Decrementa un caracter la Nave-Jugador
cp	$7f		; Limite Izquierdo??
jr	z,limite_izquierdo
ld	(navejugador_x),a
ld	a,$07
ret		; Retorna

;----------------------------------------------
limite_izquierdo:
ld	a,$80
ld	(navejugador_x),a
ld	a,$01
ret		; Retorna

;---------------------------------------------------------------------------
nave_derecha:
ld	a,(navejugador_x)
inc	a			; Incrementa un caracter la Nave-Jugador
cp	$9e		; Limite Derecho??
jr	z,limite_derecho
ld	(navejugador_x),a
ld	a,$01
ret		; Retorna

;-----------------------------------------------
limite_derecho:
ld	a,$9d
ld	(navejugador_x),a
ld	a,$07
ret		; Retorna

;---------------------------------------------------------------------------
;---       SUB - CONTADOR DE ITERACIONES del BUCLE PRINCIPAL             ---
;---------------------------------------------------------------------------
iteraciones:
ld	a,(contador_it)
inc	a
ld	(contador_it),a
ret

;---------------------------------------------------------------------------
;---        SUB -  I M P R I M E   C A D E N C I A  (Disparo)            ---
;---                                                                     ---
;---   DE---> Puntero para imprimir texto ...   HL---> Puntero VRAM      ---
;---                                                                     --- 
;---------------------------------------------------------------------------
imprime_cadencia:
ld	hl,$55e0
ld	b,$09		; Bucle $09 (Barrita Grafica de Cadencia)

bucle_borracadencia:
ld	(hl),%01010101	; Barrita Discontinua (OFF)
inc	l
djnz bucle_borracadencia

;-------------------------------------------------------------------
ld	hl,$55e0
ld	a,(cadencia)
sra	a
sra	a		; Multiplicar (para mas lentitud de cadencia)
ld	b,a		; Bucle B = A

bucle_cadencia:
ld	(hl),%11111111	; Barrita Cadencia (ON)
inc	l
djnz bucle_cadencia

;-------------------------------------------------------------------
ld 	hl,$50ea
ld	de,charset_abc+112
call	imprimir_char

ld	a,(cadencia)
cp	$24
jr	z,imprime_on

ld	de,charset_abc+40	; --- Imprimir OFF ---
call	imprimir_char
ld	de,charset_abc+40
call	imprimir_char
ret			; Retorna

;---------------------------------------------------------------------------
imprime_on:
ld	de,charset_abc+104	; --- Imprimir ON ---
call	imprimir_char
ld	de,charset1
call	imprimir_char
ret			; Retorna

;---------------------------------------------------------------------------
;---                SUB - M E N U   P R I N C I P A L                    ---
;---                                                                     ---
;---  C---> Z Comenzar (Ret)                                             ---
;---  HL--> Puntero VRAM        ...   DE---> Puntero para texto,etc.     ---
;---------------------------------------------------------------------------
menu_principal:
call	inicia_estrella

menu_principal2:
call	espacio		; SUB Scroll espacial estrellas
call	estrella	; SUB Animacion Estrella
call	attr_mp
call 	galax_jon
call	creditos
call 	pulse_continuar
ld	c,$01		; C=1... NO pulsada ... (continua en bucle MP)
call	teclado_mp	; Leer Teclado para avanzar...
ld	a,c
ret	z		; Retorna si C=0 
halt
halt
jr	menu_principal2		; bucle Menu Principal
ret		; No hace falta

;---------------------------------------------------------------------------
;---                SUB - T E C L A D O   MENU PRINCIPAL                 ---
;---                                                                     ---
;---      Cursor JoyStick ----> Avanzar (a jugar) ( C = Z )              ---                                                                   ---
;---------------------------------------------------------------------------
teclado_mp:
ld	a,$f7			;Carg en A, puerto $fe (semifila 1...5)
in	a,($fe)			;Lee (In A) el puerto entrada $fe
bit	4,a			;Comprobamos estado del Bit4 (Tecla 5)
jr 	nz,tecla_mp2		;NZ = '5' No pulsada, salta a la siguiente...
jr	comenzar_ajugar

tecla_mp2:
ld	a,$ef			;Carg en A, puerto $ef (semifila 6...0)
in	a,($fe)			;Lee (In A) el puerto entrada $fe
bit	4,a			;Comprobamos estado del Bit4 (Tecla '6')
jr 	nz,tecla_mp3		;NZ = '6' No pulsada, salta a la siguiente...
jr	comenzar_ajugar

tecla_mp3:
ld	a,$ef			;Carg en A, puerto $ef (semifila 6...0)
in	a,($fe)			;Lee (In A) el puerto entrada $fe
bit	3,a			;Comprobamos estado del Bit3 (Tecla 7)
jr 	nz,tecla_mp4		;NZ = '7' No pulsada, salta a la siguiente...
jr	comenzar_ajugar

tecla_mp4:
ld	a,$ef			;Carg en A, puerto $ef (semifila 6...0)
in	a,($fe)			;Lee (In A) el puerto entrada $fe
bit	2,a			;Comprobamos estado del Bit2 (Tecla 8)
ret 	nz			;NZ = '8' No pulsada, Retorna ...

comenzar_ajugar:
ld	a,$04
call	sonido
ld	c,$00			; C=0 ... Pulsada! Salir del Menu Principal
call	sub_cls
call	sub_clsattr	
ret		; Retorna

;---------------------------------------------------------------------------
; a b c d e f g h i j k l m n o p q r s t u v w x y z (c) 
;---      32      64      96      128     160     192
;---------------------------------------------------------------------------
creditos:
ld	hl,$50e7		; ------- Imprimir Creditos (IMI) ----------
ld	de,charset_abc+208
call	imprimir_char
ld	de,charset1
call	imprimir_char
ld	de,charset_abc+16
call	imprimir_char
ld	de,charset_abc+32
call 	imprimir_char
ld	de,charset_abc+104
call	imprimir_char
ld	de,charset_abc+152
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char
ld	de,charset_abc+112
call	imprimir_char
ld	de,charset1
call	imprimir_char
ld	de,charset_abc+64
call	imprimir_char
ld	de,charset_abc+96
call	imprimir_char
ld	de,charset_abc+64
call	imprimir_char
ld	de,charset1
call	imprimir_char
ld	de,charset_012+16
call	imprimir_char
ld	de,charset_012
call	imprimir_char
ld	de,charset_012+16
call	imprimir_char
ld	de,charset_012+16
call	imprimir_char	
;---------------------------------------------------------------------------
ld	hl,$5045
ld	de,charset_abc+120	; -------- Imprimir Programado por ---------
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char
ld	de,charset_abc+112
call 	imprimir_char
ld	de,charset_abc+48
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char
ld	de,charset_abc
call	imprimir_char
ld	de,charset_abc+96
call	imprimir_char
ld	de,charset_abc
call	imprimir_char
ld	de,charset_abc+24
call	imprimir_char
ld	de,charset_abc+112
call	imprimir_char
ld	de,charset1
call	imprimir_char
ld	de,charset_abc+120
call	imprimir_char
ld	de,charset_abc+112
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char
ld	de,charset_012+80
call	imprimir_char
ld	de,charset1
call	imprimir_char
ld	de,charset_abc+72
call	imprimir_char
ld	de,charset_012-16
call	imprimir_char
ld	de,charset_abc+32
call	imprimir_char
ld	de,charset_abc+48
call	imprimir_char
ld	de,charset_abc+160
call	imprimir_char
ld	de,charset_abc+64
call	imprimir_char
ld	de,charset_abc
call	imprimir_char	
ret		; Retorna

;---------------------------------------------------------------------------
; a b c d e f g h i j k l m n o p q r s t u v w x y z (c) 
;---      32      64      96      128     160     192
;---------------------------------------------------------------------------
galax_jon:
ld	hl,$4069		; ------  Imprimir Titulo (GALAX JON) ------
ld	de,galaxjon_letras
call	imprimir_galaxjon
ld	de,galaxjon_letras+32
call	imprimir_galaxjon
ld	de,galaxjon_letras+64
call	imprimir_galaxjon
ld	de,galaxjon_letras+32
call	imprimir_galaxjon
ld	de,galaxjon_letras+96
call	imprimir_galaxjon

ld	hl,$40cc
ld	de,galaxjon_letras+128
call	imprimir_galaxjon
ld	de,galaxjon_letras+160
call	imprimir_galaxjon
ld	de,galaxjon_letras+192
call	imprimir_galaxjon
ret			; Retorna

;---------------------------------------------------------------------------
; a b c d e f g h i j k l m n o p q r s t u v w x y z (c) 
;---      32      64      96      128     160     192
;---------------------------------------------------------------------------
pulse_continuar:
ld	hl,$48a6
ld	de,charset_abc+120	; -------  Imprimir Pulse continuar  -------
call	imprimir_char
ld	de,charset_abc+160
call	imprimir_char
ld	de,charset_abc+88
call	imprimir_char
ld	de,charset_abc+144
call	imprimir_char
ld	de,charset_abc+32
call	imprimir_char
ld	de,charset1
call	imprimir_char
ld	de,charset_abc+16
call	imprimir_char
ld	de,charset_abc+160
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char
ld	de,charset_abc+144
call	imprimir_char
ld	de,charset_abc+112
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char
ld	de,charset1
call	imprimir_char
ld	de,charset_abc+72
call	imprimir_char
ld	de,charset_abc+112
call	imprimir_char
ld	de,charset_abc+192
call	imprimir_char
ld	de,charset_abc+144
call	imprimir_char
ld	de,charset_abc+152
call	imprimir_char
ld	de,charset_abc+64
call	imprimir_char
ld	de,charset_abc+16
call 	imprimir_char
ld	de,charset_abc+80
call 	imprimir_char
ret		; Retorna

;---------------------------------------------------------------------------
;---                 SUB - I M P R I M I R   C H A R                     ---
;---------------------------------------------------------------------------
imprimir_char:
ld	b,$08		; Bucle $08 Scanlines

bucle_imprimir:
ld	a,(de)		; Carga en A, el Caracter a imprimir...
ld	(hl),a		; ... Imprimelo en HL
inc	h
inc	de
djnz	bucle_imprimir

ld	a,h
sub	$08
ld	h,a	; Volver al 1er Scanline
inc	l
ret		; Retorna

;---------------------------------------------------------------------------
;---           SUB - I M P R I M I R   G A L A X - J O N                 ---
;---------------------------------------------------------------------------
imprimir_galaxjon:
ld	b,$10		; Bucle 16 Scanlines

bucle_imprimirgalaxjon:
ld	a,(de)		; Carga en A, Byte a imprimir...
ld	(hl),a		; ...Imprimelo en HL

inc	l
inc	de
ld	a,(de)		; 2do Byte a imprimir...
ld	(hl),a

dec	l
inc	h
ld	a,h
cp	$48		; Cambio de Linea?? ... entonces Jr ...
call	z,linea_siguiente
inc	de
djnz	bucle_imprimirgalaxjon

ld	a,l
sub	$40
ld	l,a	; Volver al 1er Scanline para volver a imprimir...

ld	h,$40	; Volver al 1er Scanline para volver a imprimir...

inc	l
inc	l
inc	l
ret		; Retorna

;---------------------------------------------------------------------------
linea_siguiente:
sub	$08	; Vuelve al 1er Scanline...
ld	h,a

ld	a,l
add	a,$20	; ... Pero suma $20 (siguiente linea)
ld	l,a
ret		; Retorna

;---------------------------------------------------------------------------
;---              SUB -  INICIA ANIMACION ESTRELLA                       ---
;--------------------------------------------------------------------------- 
inicia_estrella:
ld	a,$01
ld	(rota_estrella),a
ret

;---------------------------------------------------------------------------
;---          SUB - A N I M A C I O N   E S T R E L L A                  ---
;---------------------------------------------------------------------------
estrella:
ld	hl,$4832
ld	de,estrella_anima-8

ld 	a,(rota_estrella)
or	a
cp	$1a
jr	nc,no_estrella
ld	b,a

bucle_increm:
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
djnz	bucle_increm

;------------------------------------------------------
ld	b,$08

bucle_scansestrella:
ld	l,$32
ld	a,(de)
ld	(hl),a		; Animacion estrellas brillantes...

ld	l,$45
ld	(hl),a		; ... Segunda estrella

ld	l,$d6
ld	(hl),a		; ... Tercera

inc	h
inc	de
djnz	bucle_scansestrella

ld	hl,$5932
ld	(hl),%01000111	; Attr de la 1ra estrella (Blanco)

no_estrella:
ld	a,(rota_estrella)
inc	a
cp	$50		; llegamos a $50?? ... entonces...
jr	z,reinicia_rs	; ...Reiniciar Rotacion Estrella
ld	(rota_estrella),a
ret		; Retorna

;----------------------------------------------------
reinicia_rs:
ld	a,$01
ld	(rota_estrella),a
ret		; Retorna

;---------------------------------------------------------------------------
;---                 SUB - A T T R  -  MENU PRINCIPAL                    ---
;---------------------------------------------------------------------------
attr_mp:
ld	hl,$5869
ld	b,$0e

bucle_attrmp:
ld	(hl),$04	; Attr Galax Jon (Verde arriba)
ld	a,l
add	a,$20
ld	l,a
ld	(hl),$06	; Attr Galax Jon (Amarillo abajo)
add	a,$40
ld	l,a
ld	(hl),$04
add	a,$20
ld	l,a
ld	(hl),$06
sub	$80
ld	l,a
inc	l
djnz bucle_attrmp

ld	hl,$5a45
ld	b,$10

bucle_attrprogramado:
ld	(hl),%01000101	; Attr Azul Claro Bright
inc	l
djnz bucle_attrprogramado

ld	hl,$5ae7
ld	b,$11

bucle_imi:
ld	(hl),%01000010	; Attr Rojo Bright
inc	l
djnz bucle_imi

ld	hl,$59a6
ld	b,$15

bucle_pulse:
ld	(hl),%10000011	; Attr Magenta Bright
inc	l
djnz bucle_pulse
ret		; Retorna

;---------------------------------------------------------------------------
;---              JR -   B U C L E   G A M E  O V E R                    ---
;---                                                                     ---
;---------------------------------------------------------------------------
game_over:
push	hl
push	de

ld	hl,$0c07
ld	(soni_disp),hl

ld	h,$50
ld	a,(navejugador_x)
ld	l,a

ld	c,$05		; Bucle $05 explosiones repetitivas Nave-Jugador

repeticiones:
push	bc
ld	de,nave_explosionsprites	; Situa DE (Sprites Explosion)
ld	c,$04		; Bucle $04 caracteres (Nave-Jugador 2x2 caracteres)

bucle_explonave:
ld	b,$10		; Bucle 16 Scanlines (2x2 Caracteres)

bucle_scansexplonave:
ld	a,$03
call	sonido		; Sonido Explosion Nave Jugador

ld	a,(de)		; Carga en A, Byte Explosion...
ld	(hl),a		; ... Imprimelo en HL

inc	l
inc	de
ld	a,(de)		; Siguente Byte (A la Dcha)
ld	(hl),a

inc	l
ld	(hl),$00	; Borrado del 3er (Byte-Rotacion)

dec	l
dec	l
inc	h
ld	a,h
cp	$58		; Cambio de Linea?? ... entonces Jr LineaSiguiente
call	z,linea_siguiente
inc	de
djnz bucle_scansexplonave

;halt
halt
halt		; Ralentizaciones
ld	a,l
sub	$40
ld	l,a	; Vuelve 2 lineas arriba (al 1er Scanline)

ld	h,$50	; Vuelve al 1er Scanline
dec	c		; Un bucle menos de explosion repetitiva
jr	nz,bucle_explonave

pop	bc
dec	c
jr	nz,repeticiones	; Bucle $05 explosion repetitiva

;-----------------------------------------------------------------
;ld	hl,$50af
ld	b,$18		; Bucle $18 Borrado de Explosion NaveJ

bucle_borradoexplonave:
ld	(hl),$00
inc	l
ld	(hl),$00

dec	l
inc	h
ld	a,h
cp	$58		; Cambio de linea??
call	z,linea_siguiente
djnz bucle_borradoexplonave

;-----------------------------------------------------------------
;---     G A M E   O V E R ??  /  V I D A   M E N O S ??       ---
;-----------------------------------------------------------------
ld	a,(vidas)
dec	a		; Decrementa una vida
ld	(vidas),a
pop	de
pop	hl
jr	nz,no_comprobar_pausai	; ... (mas abajo) ...

;-----------------------------------------------------------------
bucle_gameover:
call 	espacio
call	mover_marcianos
call 	disparo
call	explosion
call	score
call 	mensaje_gameover
call	pulse_enter

ld	a,$bf			;Carg en A, puerto $ef (semifila 6...0)
in	a,($fe)			;Lee (In A) el puerto entrada $fe
bit	0,a			;Comprobamos estado del Bit0 (Tecla ENTER)
jp 	z,updates_generales	;Z='ENTER' Pulsada Jr Updates y Comenzar...

halt				; Ralentiza
halt
jr	bucle_gameover	; Bucle GameOver

;---------------------------------------------------------
no_comprobar_pausai:
ld	a,$59		; Nueva Pausai (para PausaInicial)
ld	(pausa_i),a
ld	a,(settings)
res	7,a		; Bit7= 0 PausaInicial (ON)
ld	(settings),a
jp	no_comprobar

;---------------------------------------------------------------------------
; a b c d e f g h i j k l m n o p q r s t u v w x y z (c) 
;---      32      64      96      128     160     192
;---------------------------------------------------------------------------
mensaje_gameover:
ld	hl,$486c		; ---------  Imprimir GAME OVER  -----------
ld	de,charset_abc+48
call	imprimir_char
ld	de,charset_abc
call	imprimir_char
ld	de,charset_abc+96
call	imprimir_char
ld	de,charset_abc+32
call	imprimir_char
ld	de,charset1
call	imprimir_char
ld	de,charset_abc+112
call 	imprimir_char
ld	de,charset_abc+168
call	imprimir_char
ld	de,charset_abc+32
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char

;--------------------------------------------------------
ld	hl,$596c	; Attr Game Over
ld	b,$11

bucle_msggameover:
ld	(hl),%01000101	; Attr AzulClaro Bright
inc	l
djnz bucle_msggameover	
ret		; Retorna

;---------------------------------------------------------------------------
pulse_enter:
ld	hl,$5048
ld	de,charset_abc+32
call	imprimir_char
ld	de,charset_abc+104
call	imprimir_char
ld	de,charset_abc+152
call	imprimir_char
ld	de,charset_abc+32
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char
ld	de,charset1
call	imprimir_char
ld	de,charset_abc+112
call	imprimir_char
ld	de,charset_abc+152
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char
ld	de,charset_abc
call	imprimir_char
ld	de,charset1
call	imprimir_char
ld	de,charset_abc+120
call	imprimir_char
ld	de,charset_abc
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char
ld	de,charset_abc+152
call	imprimir_char
ld	de,charset_abc+64
call	imprimir_char
ld	de,charset_abc+24
call	imprimir_char
ld	de,charset_abc
call	imprimir_char

ld	hl,$5a48	; Atributos ENTER
ld	b,$05

bucle_attrenter:
ld	(hl),$06
inc	l
djnz bucle_attrenter

ld	hl,$5a4f	
ld	b,$0c

bucle_attrotra:
ld	(hl),$47	; Attr 'Otra Partida' (Blanco Bright)
inc	l
djnz	bucle_attrotra
ret			; Retorna

;---------------------------------------------------------------------------
;---               JR - F I N  (JUEGO COMPLETADO)                        ---
;---------------------------------------------------------------------------
fin:
call	score
ld	hl,$50fb
ld	de,charset_012+8
call	imprimir_char
ld	de,charset_012
call	imprimir_char
ld	de,charset_012
call	imprimir_char

bucle_staff:
call 	espacio
call 	disparo
call	dibuja_navejugador
call	explosion
call 	mensaje_gameover
call	mensaje_congrats
halt
jr	bucle_staff

jr $

;---------------------------------------------------------------------------
;---         S U B  -   MENSAJE   E N H O R A B U E N A                  ---
;---------------------------------------------------------------------------
mensaje_congrats:
ld	hl,$40cb
ld	de,charset_abc+32
call	imprimir_char
ld	de,charset_abc+104
call	imprimir_char
ld	de,charset_abc+56
call	imprimir_char
ld	de,charset_abc+112
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char
ld	de,charset_abc
call	imprimir_char
ld	de,charset_abc+8
call	imprimir_char
ld	de,charset_abc+160
call	imprimir_char
ld	de,charset_abc+32
call	imprimir_char
ld	de,charset_abc+104
call	imprimir_char
ld	de,charset_abc
call	imprimir_char
ld	de,charset1+8
call	imprimir_char

ld	hl,$58ca
ld	b,$0c
ld	a,$c6

bucle_attrcongrats:
ld	(hl),a		; Attr Enhorabuena! (Amarillo+Bright)
inc	l
djnz	bucle_attrcongrats
ret		; Retorna

;---------------------------------------------------------------------------
;---                    SUB - L E V E L   U P                            ---
;---------------------------------------------------------------------------
level_up:
ld	a,(settings)
bit	3,a		; Si Level-Up= 0 ... Retorna Inmediato
ret	z

ld	a,(pausa_i)	; Aprovechamos la variable Pausai, para contador...
dec	a		; ...de LevelUp tb... Despues se inicia otro Pausai	
jr	z,inicia_pausai_postnivel  ; ... para otra PausaInicial Post-nivel	
ld	(pausa_i),a

ld	hl,$488c
ld	de,charset_abc+88
call	imprimir_char
ld	de,charset_abc+32
call	imprimir_char
ld	de,charset_abc+168
call	imprimir_char
ld	de,charset_abc+32
call	imprimir_char
ld	de,charset_abc+88
call	imprimir_char
ld	de,charset1
call	imprimir_char
ld	de,charset_abc+160
call	imprimir_char
ld	de,charset_abc+120
call	imprimir_char

ld	hl,$598c
ld	b,$08

bucle_attrlevelup:
ld	(hl),%11000010
inc	l
djnz	bucle_attrlevelup
ret		;Retorna

;------------------------------------------------------------
inicia_pausai_postnivel:
ld	a,$59		; Nueva Pausai (para PausaInicial)
ld	(pausa_i),a

ld	a,(settings)
res	3,a		; Z = Level Up (OFF)
res	7,a		; Z = Pausa Inicial (ON)
ld	(settings),a

call	updates_postnivel

ld	a,(nivel)
inc	a		; Incremento de Nivel
ld	(nivel),a
cp	$02
call	nc,max_velocidad	; Si Nivel >= 2 MaxVelocidad

ld	a,(dificultad)
or	a
ret	z		; Siempre que NO sea Z...
sub	$30		; ...Aumenta la Dificultad 
ld	(dificultad),a
ret		; Retorna

;--------------------------------------------------------
max_velocidad:
ld	a,$01
ld	(velocidad),a
ret		; Retorna

;---------------------------------------------------------------------------
;---                SUB - P A U S A   I N I C I A L                      ---
;---------------------------------------------------------------------------
pausa_inicial:
ld	a,(settings)
bit	7,a		; Retorna Inmediato Si PausaInicial= 1 (OFF)
ret	nz

ld	a,(pausa_i)
dec	a		; Decremento de contador de Pausai
jr	z,gogogo	; Si Z, salta a 'Comenzar a Jugar'
ld	(pausa_i),a

call	mover_marcianos	; En PausaInicial se mueven los Marcianos
			; ...(Sin atacar)
ld	hl,$488b
ld	de,charset_abc+120	; --- Imprimir 'Preparado...' ---
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char
ld	de,charset_abc+32
call	imprimir_char
ld	de,charset_abc+120
call	imprimir_char
ld	de,charset_abc
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char
ld	de,charset_abc
call	imprimir_char
ld	de,charset_abc+24
call	imprimir_char
ld	de,charset_abc+112
call	imprimir_char
ld	de,charset_012-16
call	imprimir_char
ld	de,charset_012-16
call	imprimir_char
ld	de,charset_012-16
call	imprimir_char

ld	hl,$598b
ld	b,$0c			; Bucle Attr 'Preparado...'

bucle_attrpreparado:
ld	(hl),$45		; Attr 'Preparado...' (Azul Claro)
inc	l
djnz	bucle_attrpreparado
ret		; Retorna

;-------------------- COMENZAR A JUGAR --------------------------
gogogo:
ld	a,$59
ld	(pausa_i),a	; Reinicia Nueva Pausai (para posterior)

ld	a,(settings)
set	7,a		; Bit7= 1, Pausa Inicial= OFF
ld	(settings),a

ld	a,$02
call	sonido
inc	a
call	sonido

ld	hl,$488b	; Situar HL para borrar 'Preparado...'
ld	b,$0c		; Bucle Borrado

bucle_borrapreparado:
push	bc
ld	b,$08		; Bucle $08 Scanlines

bucle_scansbp:
ld	(hl),$00	; Borrado
inc	h
djnz	bucle_scansbp

ld	a,h
sub	$08		; Vuelve al 1er Scanline
ld	h,a
inc	l
pop	bc
djnz	bucle_borrapreparado	
ret		; Retorna

;---------------------------------------------------------------------------
;---                         SUB - S C O R E                             ---
;---------------------------------------------------------------------------
score:
ld	hl,$50f5		; ------------  Imprimir Score  ------------
ld	de,charset_abc+144
call	imprimir_char
ld	de,charset_abc+16
call	imprimir_char
ld	de,charset_abc+112
call	imprimir_char
ld	de,charset_abc+136
call	imprimir_char
ld	de,charset_abc+32
call 	imprimir_char
ld	de,charset_012+80
call	imprimir_char

ld	de,charset_012
call	imprimir_char
ld	de,charset_012
call	imprimir_char

call	calcula_score	; SUB Imprimir-Calcular Score

;------------------------------------------
ld	a,(nivel)	; Dibuja Banderitas
or	a
ret	z		; Retorna (Nivel 1)
ld	hl,$50ed
ld	de,banderita

ld	b,a		; Bucle Cuantas Banderitas

bucle_banderitas:
push	bc
ld	b,$08		; Bucle $08 Scanlines

bucle_scansband:
ld	a,(de)
ld	(hl),a		; 'Mastil'

inc	l
inc	de
ld	a,(de)
ld	(hl),a		; 'Bandera'
dec	l

inc	h
inc	de
djnz	bucle_scansband

ld	de,banderita	; Reinicia DE (Bytes Banderitas)
inc	l
inc	l
ld	a,h
sub	$08		; Vuelve al 1er Scanline
ld	h,a

pop	bc
djnz	bucle_banderitas
ret			; Retorna

;--------------------------------------------------------------------------
;---              SUB -  C A L C U L A    S C O R E                     ---
;--------------------------------------------------------------------------
calcula_score:
ld	a,(score_012)
or	a
ret	z		; Si SCORE= 0 ... entonces Retorna Inmediato
ld	b,a		; B=A (Bucle)
xor	a		; A=0

ld	de,charset_012
ld	hl,$50fc	; Situa Hl (imprimir Unidades)

bucle_score:
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	de
inc	a
cp	$0a
call	z,decenas_1
cp	$14
call	z,decenas_1
cp	$1e
call	z,decenas_1
cp	$28
call	z,decenas_1
cp	$32
call	z,decenas_1
cp	$3c
call	z,decenas_1
cp	$46
call	z,decenas_1
cp	$50
call	z,decenas_1
cp	$5a
call	z,decenas_1
djnz 	bucle_score	; Fin Bucle (por defecto)

call	imprimir_char	; Imprimir UNIDADES
ret		; Retorna

;--------------------------------------------------------------------------
decenas_1:
ld	de,charset_012
push	de
push	hl
push	bc
push	af

ld	hl,$50fb	; Situa HL (Imprimir Decenas)
cp	$0a
jr	z,decenas_11
cp	$14
jr	z,decenas_12
cp	$1e
jr	z,decenas_13
cp	$28
jr	z,decenas_14
cp	$32
jr	z,decenas_15
cp	$3c
jr	z,decenas_16
cp	$46
jr	z,decenas_17
cp	$50
jr	z,decenas_18
cp	$5a
jr	z,decenas_19
jr	$

decenas_11:
ld	de,charset_012+8
jr	imprime_decenas

decenas_12:
ld	de,charset_012+16
jr	imprime_decenas

decenas_13:
ld	de,charset_012+24
jr	imprime_decenas

decenas_14:
ld	de,charset_012+32
jr	imprime_decenas

decenas_15:
ld	de,charset_012+40
jr	imprime_decenas

decenas_16:
ld	de,charset_012+48
jr	imprime_decenas

decenas_17:
ld	de,charset_012+56
jr	imprime_decenas

decenas_18:
ld	de,charset_012+64
jr	imprime_decenas

decenas_19:
ld	de,charset_012+72

imprime_decenas:
call	imprimir_char	; Imprime Decenas

pop	af
pop	bc
pop 	hl
pop	de
ret	; Retorna

;--------------------------------------------------------------------------
;---            JR -  U P D A T E S  P O S T - N I V E L                ---
;--------------------------------------------------------------------------
updates_postnivel:
xor	a
ld	(contador_it),a		; Contador Iteraciones = 0
ld	(cuantos_marc),a	; Cuantos Marc = 0

call	sub_attr		; SUB restablecer atributos Iniciales
call	reseteo_marcianos	; SUB resetea los Marcianos
ret		; Retorna

;--------------------------------------------------------------------------
;---           JR -  U P D A T E S   G E N E R A L E S                  ---
;--------------------------------------------------------------------------
updates_generales:
ld	a,$00
ld	(izda_dcha),a
ld	(cuantos_marc),a
ld	(settings),a
ld	(score_012),a
ld	a,$03
ld	(rota_nave),a
ld	(vidas),a
ld	a,$04
ld	(cadencia),a
call	sonido		; Suena al Pulsar ENTER para Comenzar otra...
ld	a,$02
ld	(velocidad),a
ld	a,$8f
ld	(navejugador_x),a

call	reseteo_marcianos	; Resetea los Marcianos
jp	comienzo_ymp		; ***** Comienza el juego! *****

;---------------------------------------------------------------
reseteo_marcianos:
ld	de,marcianos		; Situa DE en puntero Marcianos
ld	b,$19			; Bucle $19 Marcianos

bucle_updatemarcianos:
inc	de
inc	de
inc	de

ld	a,$01
ld	(de),a			; Marcianos= ON

inc	de
ld	(de),a			; Movimiento Inicial= a la Dcha

inc	de
xor	a
ld	(de),a			; Rotacion= 0

inc	de
ld	a,$03
ld	(de),a			; Animacion Inicial= 3

inc	de
djnz	bucle_updatemarcianos
ret			; Retorna

;---------------------------------------------------------------------------
;---                     SUB - R A L E N T I Z A                         ---
;---------------------------------------------------------------------------
ralentiza:
dec	a
ret	z

halt			; Ralentiza tantas veces como iteraciones de bucle
jr	nz,ralentiza
ret		; No hace falta

;---------------------------------------------------------------------------
;---                   SUB - A T T R   G E N E R A L                     ---
;---                                                                     ---
;---------------------------------------------------------------------------
sub_attr:
ld	hl,$5800		; Attr de Estrellas (Colorines Pseudo Random)
ld	b,$02

bucle_attrestrellastercio:
push	bc
ld	b,$ff		; Bucle $ff (Todo el Tercio) 
ld	a,$42		; ($42) Primer Color=2 (Rojo Bright)

bucle_attrestrellas:
ld	(hl),a		; Carga en HL, el Attr correspondiente
inc	l
inc	a
cp	$48		; $48??... entonces volver al 1er color (Rojo Bright)
call	z,reinicia_colorestrellas
djnz	bucle_attrestrellas

inc	h
pop	bc
djnz	bucle_attrestrellastercio

;---------------------------------------------------------------------------
ld	hl,$5a80
ld	b,$40

bucle_attrnavejugador:
ld	a,b
cp	$21
jr	c,azulclaro

ld	(hl),$02	; Nave (parte superior, roja)
inc	l
djnz	bucle_attrnavejugador

azulclaro:
ld	(hl),$05	; Nave (Parte inferior, azulclaro)
inc	l
djnz	bucle_attrnavejugador

;-----------------------------------------------------------
ld	de,marcianos
ld	b,$19

bucle_attrmarcianos:
ld	h,$58
inc	de
ld	a,(de)
ld	l,a
ld	(hl),$04	; Marcianos (Verde 1er caracter)

inc	l
ld	(hl),$04	; Marcianos (Verde 2do caracter)

inc	l
ld	(hl),$04	; Marcianos (Verde 3er caracter)
inc 	de
inc	de
inc	de
inc	de
inc	de
inc	de	
djnz bucle_attrmarcianos

;-----------------------------------------------------------
ld	hl,$5aea
ld	(hl),$06	; Attr (ON/OFF Amarillo)
inc	l
ld	(hl),$06
inc	l
ld	(hl),$06	

ld	hl,$5af5
ld	b,$06
bucle_attrscore:
ld	(hl),$06	; Attr Score (Amarillo)
inc	l
djnz bucle_attrscore

ld	hl,$5aee
ld	a,$44

ld	(hl),a		; Banderitas (Verdes)
inc	l
inc	l
ld	(hl),a
inc	l
inc	l
ld	(hl),a
inc	l
inc	l
ld	(hl),a
ret		; Retorna

;---------------------------------------------------------------------------
reinicia_colorestrellas:
ld	a,$42		; Reinicia colores ($42=2 Rojo Bright)
ret		; Retorna

;---------------------------------------------------------------------------
;---                    S U B - C L S  ATRIBUTOS                         ---
;---------------------------------------------------------------------------
sub_clsattr: 
ld	a,%01000111	; Carga en A, Atributos (tinta Blanca)
ld	hl,$5800
ld	(hl),a
ld	de,$5801
ld	bc,$02ff
ldir			; Carga e Incrementa
ret			; Retorna

;--------------------------------------------------------------------------
;---		               SUB -  C L S                             ---
;--------------------------------------------------------------------------
sub_cls:
ld	a,$00
;ld	a,%01010101
ld	hl,$4000	;Carga en Hl, (1ra posicion VRAM)
ld	(hl),a		;Carga borrado en (HL)
ld	de,$4001	;Carga en DE, (uno mas que HL)
ld	bc,$17ff	;Nro veces (bucle)
ldir			;Carga e Incrementa
ret			;retorna

;----------------------------------------------------------------
;---		     S U B  -  S O N I D O S                  ---
;---                                                          ---
;--- ( Los sonidos son originarios del Juego PoromPong...     ---
;---   ... de Juan Antonio Rubio, canal RETROPARLA )          ---
;---                                                          ---                                              
;----------------------------------------------------------------
sonido:
push	de		; Salvaguardar DE,HL
push	hl

dec	a
jr	z,sonido_pala

dec	a
jr	z,sonido_rebote

dec	a
jr	z,sonido_vidamenos

dec	a
jr	z,sonido_pulsamenus

jr	$

sonido_pala:
ld	hl,s_2		; Carga en HL la nota
ld	de,s2_dura/$05	; Carga en DE la duracion
jr	emitir_sonido	; Salta a emitir el sonido

sonido_rebote:
ld	hl,s_3		; Carga en Hl la nota	
ld	de,s3_dura/$05	; Carga en DE la duracion
jr	emitir_sonido	; Salta a emitir el sonido

sonido_vidamenos:
ld	hl,(soni_disp)	; Carga en HL la nota
ld	de,s1_dura/$10	; Carga en DE la duracion
jr	emitir_sonido	; Salta emitir sonido

sonido_pulsamenus:
ld	hl,s_4		; Carga en HL la nota
ld	de,s4_dura	; Carga en DE la duracion
jr	emitir_sonido	; Salta a emitir sonido

jr	$

;----------------------------------------------------
emitir_sonido:
push	af		; Salvaguardar AF,BC,IX...
push	bc
push	ix
call	beeper		; SUB rutina sistema SONIDOS
pop	ix
pop	bc
pop	af

pop	hl
pop	de		; Recupera AF,BC,IX,HL,DE

ret			;Retorna

;--------------------------------------------------------------------------
;---                      G R A P H I C   D A T A                       ---
;--------------------------------------------------------------------------
;Pixel Size:      ( 24,  64)
;Char Size:       (  3,   8)
;Sort Priorities: X char, Char line, Y char
;Data Outputted:  Gfx+Attr
;Interleave:      Sprite
;Mask:            No
explosion_sprites:
	DEFB	  0,  0,  0,  0, 64,  0,  0,  4
	DEFB	 24, 16, 64,  8,  4,  0,128,130
explosion_sprites2:
	DEFB	  0,  0,  0,  0,  4, 64,  1,  0
	DEFB	  1,128,  2, 32,  0,  0,  0,  0
	DEFB	  0,  0,  9,  0,  8, 32,  0, 64
	DEFB	  4,  0,  1, 32,  0,  0,  0,  0
	DEFB	  0, 16,  1,  0,  4,  0,  0, 76
	DEFB	 18,  0,  4, 16,  0, 72,  0,  0
	DEFB	  1, 64,  8,  4, 34, 16,  4,  0
	DEFB	 16,  2, 64, 16,  2,  4, 16, 64
	DEFB	  4, 16, 64,  0,  0,  4,  2,  0
	DEFB	 64,  9,  0,  0,132,  2, 32,136
	DEFB	  0,  0,  0,  0,  8,  0,  0,  1
	DEFB	128,  0,  0,128,  0,  2, 32,  0
;Pixel Size:      ( 24,  64)
;Char Size:       (  3,   8)
;Sort Priorities: X char, Char line, Y char
;Data Outputted:  Gfx+Attr
;Interleave:      Sprite
;Mask:            No
sprites_rotamarciano:
	DEFB	 16, 32,  0,  8, 64,  0, 63,240
	DEFB	  0,119,184,  0,191,244,  0,188
	DEFB	244,  0,144, 36,  0, 12,192,  0
	DEFB	  8, 16,  0,  4, 32,  0, 31,248
	DEFB	  0, 59,220,  0, 95,250,  0, 94
	DEFB	122,  0, 72, 18,  0,  6, 96,  0
	DEFB	  4,  8,  0,  2, 16,  0, 15,252
	DEFB	  0, 29,238,  0, 47,253,  0, 47
	DEFB	 61,  0, 36,  9,  0,  3, 48,  0
	DEFB	  2,  4,  0,  1,  8,  0,  7,254
	DEFB	  0, 14,247,  0, 23,254,128, 23
	DEFB	158,128, 18,  4,128,  1,152,  0
	DEFB	  1,  2,  0,  0,132,  0,  3,255
	DEFB	  0,  7,123,128, 11,255, 64, 11
	DEFB	207, 64,  9,  2, 64,  0,204,  0
	DEFB	  0,129,  0,  0, 66,  0,  1,255
	DEFB	128,  3,189,192,  5,255,160,  5
	DEFB	231,160,  4,129, 32,  0,102,  0
	DEFB	  0, 64,128,  0, 33,  0,  0,255
	DEFB	192,  1,222,224,  2,255,208,  2
	DEFB	243,208,  2, 64,144,  0, 51,  0
	DEFB	  0, 32, 64,  0, 16,128,  0,127
	DEFB	224,  0,239,112,  1,127,232,  1
	DEFB	121,232,  1, 32, 72,  0, 25,128
	DEFB	  0, 16, 32,  0,  8, 64,  0, 63
	DEFB	240,  0,119,184,  0,191,244,  0
	DEFB	188,244,  0,144, 36,  0, 12,192
	DEFB	  0,  8, 16,  0,  4, 32,  0, 31
	DEFB	248,  0, 59,220,  0, 95,250,  0
	DEFB	 94,122,  0, 72, 18,  0,  6, 96
	DEFB	  0,  4,  8,  0,  2, 16,  0, 15
	DEFB	252,  0, 29,238,  0, 47,253,  0
	DEFB	 47, 61,  0, 36,  9,  0,  3, 48
sprites_rotamarciano2:
	DEFB	 16, 32,  0,  8, 64,  0, 63,240
	DEFB	  0,119,184,  0,191,244,  0, 60
	DEFB	240,  0, 16, 32,  0, 16, 32,  0
	DEFB	  8, 16,  0,  4, 32,  0, 31,248
	DEFB	  0, 59,220,  0, 95,250,  0, 30
	DEFB	120,  0,  8, 16,  0,  8, 16,  0
	DEFB	  4,  8,  0,  2, 16,  0, 15,252
	DEFB	  0, 29,238,  0, 47,253,  0, 15
	DEFB	 60,  0,  4,  8,  0,  4,  8,  0
	DEFB	  2,  4,  0,  1,  8,  0,  7,254
	DEFB	  0, 14,247,  0, 23,254,128,  7
	DEFB	158,  0,  2,  4,  0,  2,  4,  0
	DEFB	  1,  2,  0,  0,132,  0,  3,255
	DEFB	  0,  7,123,128, 11,255, 64,  3
	DEFB	207,  0,  1,  2,  0,  1,  2,  0
	DEFB	  0,129,  0,  0, 66,  0,  1,255
	DEFB	128,  3,189,192,  5,255,160,  1
	DEFB	231,128,  0,129,  0,  0,129,  0
	DEFB	  0, 64,128,  0, 33,  0,  0,255
	DEFB	192,  1,222,224,  2,255,208,  0
	DEFB	243,192,  0, 64,128,  0, 64,128
	DEFB	  0, 32, 64,  0, 16,128,  0,127
	DEFB	224,  0,239,112,  1,127,232,  0
	DEFB	121,224,  0, 32, 64,  0, 32, 64
	DEFB	  0, 16, 32,  0,  8, 64,  0, 63
	DEFB	240,  0,119,184,  0,191,244,  0
	DEFB	 60,240,  0, 16, 32,  0, 16, 32
	DEFB	  0,  8, 16,  0,  4, 32,  0, 31
	DEFB	248,  0, 59,220,  0, 95,250,  0
	DEFB	 30,120,  0,  8, 16,  0,  8, 16
	DEFB	  0,  4,  8,  0,  2, 16,  0, 15
	DEFB	252,  0, 29,238,  0, 47,253,  0
	DEFB	 15, 60,  0,  4,  8,  0,  4,  8
sprites_rotamarciano3:
	DEFB	 16, 32,  0,136, 68,  0,159,228
	DEFB	  0,183,180,  0,127,248,  0, 60
	DEFB	240,  0, 16, 32,  0, 32, 16,  0
	DEFB	  8, 16,  0, 68, 34,  0, 79,242
	DEFB	  0, 91,218,  0, 63,252,  0, 30
	DEFB	120,  0,  8, 16,  0, 16,  8,  0
	DEFB	  4,  8,  0, 34, 17,  0, 39,249
	DEFB	  0, 45,237,  0, 31,254,  0, 15
	DEFB	 60,  0,  4,  8,  0,  8,  4,  0
	DEFB	  2,  4,  0, 17,  8,128, 19,252
	DEFB	128, 22,246,128, 15,255,  0,  7
	DEFB	158,  0,  2,  4,  0,  4,  2,  0
	DEFB	  1,  2,  0,  8,132, 64,  9,254
	DEFB	 64, 11,123, 64,  7,255,128,  3
	DEFB	207,  0,  1,  2,  0,  2,  1,  0
	DEFB	  0,129,  0,  4, 66, 32,  4,255
	DEFB	 32,  5,189,160,  3,255,192,  1
	DEFB	231,128,  0,129,  0,  1,  0,128
	DEFB	  0, 64,128,  2, 33, 16,  2,127
	DEFB	144,  2,222,208,  1,255,224,  0
	DEFB	243,192,  0, 64,128,  0,128, 64
	DEFB	  0, 32, 64,  1, 16,136,  1, 63
	DEFB	200,  1,111,104,  0,255,240,  0
	DEFB	121,224,  0, 32, 64,  0, 64, 32
	DEFB	  0, 16, 32,  0,136, 68,  0,159
	DEFB	228,  0,183,180,  0,127,248,  0
	DEFB	 60,240,  0, 16, 32,  0, 32, 16
	DEFB	  0,  8, 16,  0, 68, 34,  0, 79
	DEFB	242,  0, 91,218,  0, 63,252,  0
	DEFB	 30,120,  0,  8, 16,  0, 16,  8
	DEFB	  0,  4,  8,  0, 34, 17,  0, 39
	DEFB	249,  0, 45,237,  0, 31,254,  0
	DEFB	 15, 60,  0,  4,  8,  0,  8,  4
;Pixel Size:      ( 16,  64)
;Char Size:       (  2,   8)
;Sort Priorities: X char, Char line, Y char
;Data Outputted:  Gfx+Attr
;Interleave:      Sprite
;Mask:            No
nave_explosionsprites:
	DEFB	  0,  0,  0,  0,  0,  0,  0,  0
	DEFB	  0,  0,  0,  0,  1,  0,  2,192
	DEFB	  1,192,  1,  0,  2, 64,  0,  0
	DEFB	  0,  0,  0,  0,  0,  0,  0,  0
	DEFB	  0,  0,  0,  0,  0,  0,  4,  0
	DEFB	  1,136,  3,192, 35,224,  3, 96
	DEFB	  3,224,  1,192,  2, 32,  4,  0
	DEFB	  0,  0,  0,  0,  0,  0,  0,  0
	DEFB	  0,  0,  0,128, 12,130,  2,144
	DEFB	  0,160,119,112, 28,208, 11,232
	DEFB	  3, 72, 39,140, 13, 36,  0,160
	DEFB	 18,216, 24,  8, 32,  2,  0,  0
	DEFB	 68,128,113,137,  9, 51, 13,118
	DEFB	135,216,167,248, 42,240, 13,210
	DEFB	 15,240,235,236, 15,196,134, 38
	DEFB	 49,144,100,  3,193, 81, 19,  4
	DEFB	 62, 62, 62, 62, 62, 62, 62, 62
	DEFB	 62, 62, 62, 62, 62, 62, 62, 62
;Pixel Size:      ( 24, 128)
;Char Size:       (  3,  16)
;Sort Priorities: X char, Char line, Y char
;Data Outputted:  Gfx+Attr
;Interleave:      Sprite
;Mask:            No
sprites_rotanavejugador:
	DEFB	  1,128,  0,  1,128,  0,  3,192
	DEFB	  0,  7,224,  0, 15,240,  0, 31
	DEFB	248,  0, 29,184,  0,  1,128,  0
	DEFB	 67,194,  0,231,231,  0,239,247
	DEFB	  0,255,255,  0,242, 79,  0,225
	DEFB	135,  0,227,199,  0, 79,242,  0
	DEFB	  0,192,  0,  0,192,  0,  1,224
	DEFB	  0,  3,240,  0,  7,248,  0, 15
	DEFB	252,  0, 14,220,  0,  0,192,  0
	DEFB	 33,225,  0,115,243,128,119,251
	DEFB	128,127,255,128,121, 39,128,112
	DEFB	195,128,113,227,128, 39,249,  0
	DEFB	  0, 96,  0,  0, 96,  0,  0,240
	DEFB	  0,  1,248,  0,  3,252,  0,  7
	DEFB	254,  0,  7,110,  0,  0, 96,  0
	DEFB	 16,240,128, 57,249,192, 59,253
	DEFB	192, 63,255,192, 60,147,192, 56
	DEFB	 97,192, 56,241,192, 19,252,128
	DEFB	  0, 48,  0,  0, 48,  0,  0,120
	DEFB	  0,  0,252,  0,  1,254,  0,  3
	DEFB	255,  0,  3,183,  0,  0, 48,  0
	DEFB	  8,120, 64, 28,252,224, 29,254
	DEFB	224, 31,255,224, 30, 73,224, 28
	DEFB	 48,224, 28,120,224,  9,254, 64
	DEFB	  0, 24,  0,  0, 24,  0,  0, 60
	DEFB	  0,  0,126,  0,  0,255,  0,  1
	DEFB	255,128,  1,219,128,  0, 24,  0
	DEFB	  4, 60, 32, 14,126,112, 14,255
	DEFB	112, 15,255,240, 15, 36,240, 14
	DEFB	 24,112, 14, 60,112,  4,255, 32
	DEFB	  0, 12,  0,  0, 12,  0,  0, 30
	DEFB	  0,  0, 63,  0,  0,127,128,  0
	DEFB	255,192,  0,237,192,  0, 12,  0
	DEFB	  2, 30, 16,  7, 63, 56,  7,127
	DEFB	184,  7,255,248,  7,146,120,  7
	DEFB	 12, 56,  7, 30, 56,  2,127,144
	DEFB	  0,  6,  0,  0,  6,  0,  0, 15
	DEFB	  0,  0, 31,128,  0, 63,192,  0
	DEFB	127,224,  0,118,224,  0,  6,  0
	DEFB	  1, 15,  8,  3,159,156,  3,191
	DEFB	220,  3,255,252,  3,201, 60,  3
	DEFB	134, 28,  3,143, 28,  1, 63,200
	DEFB	  0,  3,  0,  0,  3,  0,  0,  7
	DEFB	128,  0, 15,192,  0, 31,224,  0
	DEFB	 63,240,  0, 59,112,  0,  3,  0
	DEFB	  0,135,132,  1,207,206,  1,223
	DEFB	206,  1,255,254,  1,228,158,  1
	DEFB	195, 14,  1,199,142,  0,159,228
;-------------------------------------------------------------
; ASM source file created by SevenuP v1.20 - SevenuP (C)
; Copyright 2002-2006 by Jaime Tejedor Gomez, aka Metalbrain
; GRAPHIC DATA:
; Pixel Size:      (  8, 512)
; Char Size:       (  1,  64)
; Sort Priorities: Char line, Y char
; Data Outputted:  Gfx
;-------------------------------------------------------------
charset1:
   DEFB   0,  0,  0,  0,  0,  0,  0,  0,   0, 24, 24, 24, 24,  0, 24,  0
   DEFB   0,108,108, 72,  0,  0,  0,  0,   0,  0,  0,  0,  0,  0,  0,  0
   DEFB   0,  0,  0,  0,  0,  0,  0,  0,   0,  0,  0,  0,  0,  0,  0,  0
   DEFB  56,  0, 76, 56,110,196,122,  0,   0, 12, 12,  8,  0,  0,  0,  0
   DEFB   0, 24,  0, 48, 48, 48, 24,  0,   0, 24,  0, 12, 12, 12, 24,  0
   DEFB   0,  0,  0,  0,  0,  0,  0,  0,   0, 24,  0,126,126, 24, 24,  0
   DEFB   0,  0,  0,  0,  0, 12, 12,  8,   0,  0,  0,126,126,  0,  0,  0
   DEFB   0,  0,  0,  0,  0, 56, 56,  0,   0,  0,  6, 12, 24, 48, 96,  0
charset_012:
   DEFB 124,  0,206,214,230,254,124,  0,  28,  0,124, 28, 28, 28, 28,  0
   DEFB 124,  0,198, 28,112,254,254,  0, 124,  0,198, 12,198,254,124,  0
   DEFB  12,  0, 60,108,254,254, 12,  0, 254,  0,192,252, 14,254,252,  0
   DEFB  60,  0,224,252,198,254,124,  0, 254,  0, 14, 28, 28, 56, 56,  0
   DEFB 124,  0,198,124,198,254,124,  0, 124,  0,198,126,  6,126,124,  0
   DEFB   0,  0, 24, 24,  0, 24, 24,  0, 118,  6,192,254,254,198,198,  0
   DEFB 246,  6,192,252,192,254,254,  0,  12, 12, 48, 56, 56, 56, 56,  0
   DEFB 118,  6,192,198,198,254,124,  0, 198,  6,192,198,198,254,124,  0
   DEFB   0, 24,  0, 24, 24, 24, 24,  0
charset_abc:
   DEFB 124,  0,198,254,254,198,198,  0
   DEFB 252,  0,198,252,198,254,252,  0, 124,  0,198,192,198,254,124,  0
   DEFB 252,  0,198,198,198,254,252,  0, 254,  0,192,252,192,254,254,  0
   DEFB 254,  0,224,252,224,224,224,  0, 124,  0,192,206,198,254,124,  0
   DEFB 198,  0,198,254,254,198,198,  0,  56,  0, 56, 56, 56, 56, 56,  0
   DEFB   6,  0,  6,  6,198,254,124,  0, 198,  0,220,248,252,206,198,  0
   DEFB 224,  0,224,224,224,254,254,  0, 198,  0,254,254,214,198,198,  0
   DEFB 198,  0,246,254,222,206,198,  0, 124,  0,198,198,198,254,124,  0
   DEFB 252,  0,198,254,252,192,192,  0, 124,  0,198,198,198,252,122,  0
   DEFB 252,  0,198,254,252,206,198,  0, 126,  0,224,124,  6,254,252,  0
   DEFB 254,  0, 56, 56, 56, 56, 56,  0, 198,  0,198,198,198,254,124,  0
   DEFB 198,  0,198,198,238,124, 56,  0, 198,  0,198,198,214,254,108,  0
   DEFB 198,  0,124, 56,124,238,198,  0, 198,  0,238,124, 56, 56, 56,  0
   DEFB 254,  0, 28, 56,112,254,254,  0  ;60,102,219,133,133,219,102, 60
   DEFB	60,66,157,161,161,157,66,60
   DEFB   0,  0, 96, 48, 24, 12,  6,  0,  24,  0, 24, 48, 96,102, 60,  0
   DEFB  60,  0, 70, 12, 24,  0, 24,  0,   0,  0,  0,  0,  0,  0,  0,126
;Pixel Size:      ( 16, 124)
;Char Size:       (  2,  16)
;Sort Priorities: X char, Char line, Y char
;Data Outputted:  Gfx+Attr
;Interleave:      Sprite
;Mask:            No
galaxjon_letras:
	DEFB	  0,  0, 63,252,127,254,127,254
	DEFB	125,252,124,  0,124,  0,124,252
	DEFB	125,254,125,254,125,254,124, 14
	DEFB	127,254,127,254, 63,252,  0,  0
	DEFB	  0,  0, 63,252,127,254,127,254
	DEFB	 63,238,  0, 14,  0, 14, 63,238
	DEFB	127,254,127,254,112, 30,112, 30
	DEFB	127,254,127,254, 63,252,  0,  0
	DEFB	  0,  0, 56,  0,124,  0,124,  0
	DEFB	124,  0,124,  0,124,  0,124,  0
	DEFB	124,  0,124,  0,124,  0,123,252
	DEFB	127,254,127,254, 63,252,  0,  0
	DEFB	  0,  0, 96,  6,112, 14,120, 30
	DEFB	 60, 60, 30,120, 15,240,  7,224
	DEFB	  7,224, 15,240, 30,120, 60, 60
	DEFB	120, 30,112, 14, 96,  6,  0,  0
	DEFB	  0,  0,  0, 28,  0, 62,  0, 62
	DEFB	  0, 62,  0, 62,  0, 62,  0, 62
	DEFB	  0, 62, 56, 62,124, 30,127,254
	DEFB	127,254,127,254, 63,252,  0,  0
	DEFB	  0,  0, 63,252,127,254,127,254
	DEFB	126,126,124, 62,124, 62,124, 62
	DEFB	124, 62,124, 62,124, 62,126,126
	DEFB	127,254,127,254, 63,252,  0,  0
	DEFB	  0,  0,127,252,127,254,127,254
	DEFB	120, 30,120, 30,120, 30,120, 30
	DEFB	120, 30,120, 30,120, 30,120, 30
	DEFB	120, 30,120, 30, 48, 12,  0,  0
	DEFB	  0,  0,  0,  0,  0,  0,  0,  0
	DEFB	  0,  0,  0,  0,  0,  0,  0,  0
	DEFB	  0,  0,  0,  0,  0,  0,  0,  0
	DEFB	  0,  0,  0,  0,  0,  0,  0,  0
banderita:
	DEFB	  1,224,  1,252,  1,255,  1,252
	DEFB	  1,224,  1,  0,  1,  0,  1,  0
;Pixel Size:      (  8,  48)
;Char Size:       (  1,   6)
;Sort Priorities: Char line, Y char
;Data Outputted:  Gfx+Attr
;Interleave:      Sprite
;Mask:            No
estrella_anima:
	DEFB	  0,  0,  0,  0,  8,  0,  0,  0
	DEFB	  0,  0,  0,  0,  8,  0,  0,  0
;----------------------------------------------
	DEFB	  0,  0,  0,  8, 20,  8,  0,  0
	DEFB	  0,  0,  0,  8, 20,  8,  0,  0
;----------------------------------------------
	DEFB	  0,  0,  8,  8, 54,  8,  8,  0
	DEFB	  0,  0,  8,  8, 54,  8,  8,  0
;----------------------------------------------
	DEFB	  0,  0,  8, 28, 54, 28,  8,  0
	DEFB	  0,  0,  8, 28, 54, 28,  8,  0
;----------------------------------------------
	DEFB	  0,  8, 42, 28,127, 28, 42,  8
	DEFB	  0,  8, 42, 28,127, 28, 42,  8
	DEFB	  0,  8, 42, 28,127, 28, 42,  8
	DEFB	  0,  8, 42, 28,127, 28, 42,  8
;----------------------------------------------
	DEFB	  0,  8,  8, 20,107, 20,  8,  8
	DEFB	  0,  8,  8, 20,107, 20,  8,  8
	DEFB	  0,  8,  8, 20,107, 20,  8,  8
	DEFB	  0,  8,  8, 20,107, 20,  8,  8
	DEFB	  0,  8,  8, 20,107, 20,  8,  8
	DEFB	  0,  8,  8, 20,107, 20,  8,  8
	DEFB	  0,  8,  8, 20,107, 20,  8,  8
	DEFB	  0,  8,  8, 20,107, 20,  8,  8
	DEFB	  0,  8,  8, 20,107, 20,  8,  8
	DEFB	  0,  8,  8, 20,107, 20,  8,  8
	DEFB	  0,  8,  8, 20,107, 20,  8,  8
	DEFB	  0,  8,  8, 20,107, 20,  8,  8
	DEFB	  0,0,0,0,0,0,0,0

; ---------------------   $24 36 estrellas   ---------------------------
estrellas:						
defb	$42,$0f,2,$47,$07,8,$4a,$83,64,$55,$1c,32,$50,$af,32,$4f,$28,1
defb	$56,$05,4,$51,$10,32,$44,$14,64,$46,$4e,32,$49,$19,16,$4d,$eb,32
defb	$51,$62,16,$53,$16,16,$40,$1a,8,$43,$88,4,$46,$14,2,$54,$a7,16
defb	$4b,$19,16,$4f,$0c,32,$41,$04,64,$52,$28,32,$50,$15,8,$57,$6d,4
defb	$52,$32,32,$44,$08,64,$43,$c6,16,$53,$1b,8,$4a,$29,64,$4b,$1a,16
defb	$4e,$97,128,$47,$68,16,$45,$14,32,$42,$11,64,$55,$15,8,$57,$ac,32

velocidad	defb $02	; Velocidad del juego (RAPIDO) 1,2,3...(LENTO)
izda_dcha	defb $00	; Marciano va a la Izda/Dcha
;rota_marciano	defb $00	; Rotacion del Marciano (0,1,2...)
cuantos_marc	defb $00	; (Contador de Marcianos que vas eliminando)
score_012	defb $00	; Score (Contador de Marcianos que vas eliminando)
dificultad	defb $60	; Dificultad (Intensidad de los disparos Marcianos)
vidas		defb $03	; Vidas del Jugador (3 por defecto)
nivel		defb $00	; Nivel actual (Tb donde dibujar Banderita)
;cual_marciano	defb $03	; Que animacion de Marciano imprimir (3,2,1)...
disparo_y	defb $50	; Posicion Y ('H' L) del disparo
disparo_x	defb $6f	; Posicion "X" (H 'L') del disparo
cadencia	defb $04	; Cadencia del disparo ($04)
explo_y		defb $40	; Posicion Y ('H'--> hl) de la Explosion
explo_x		defb $00	; Posicion X ('L'--> hl) de la Explosion
contador_explo	defb $07	; Contador Fotogramas Explosion
contador_it	defb $00	; Contador General Iteraciones Bucle
navejugador_x	defb $8f	; Coordenada X, 'L' (hl) de la Nave-Jugador
rota_nave	defb $03	; Rotacion de la Nave-Jugador (1,2,3...)
rota_disparo	defb $03	; Rotacion del Disparo (Depende de RotaNave)
rota_estrella   defb $01	; Rotacion Animacion Estrella (Menu Principal)
pausa_i		defb $59	; Pausa Inicial (Preparado)...
soni_disp	defw $0407	; Sonido del Disparo
settings	defb $00	; Bits utilizados (Todos)	 
; Bit0 = 1 Juego Completado! Staff  ...  Bit1 = 1/0 Disparo ON/OFF
; Bit2 = 1/0 Explosion ON/OFF       ...  Bit3 = 1/0 LevelUp ON/OFF
; Bit4 = 0/1 GameOver               ...  Bit5 = 0 Borra-Disparo / 1 Dibuja-Disparo
; Bit6 = 0/1 Ataque-Marciano OFF/ON ...  Bit7 = 0/1 Pausa Inicial/Jugar

ataque_marciano:
defb	$00,$40,$02

marcianos:
defb	$40,$22,$01,$01,$01,$00,$03
defb	$40,$26,$02,$01,$01,$00,$03
defb	$40,$2a,$03,$01,$01,$00,$03
defb	$40,$2e,$04,$01,$01,$00,$03
defb	$40,$32,$05,$01,$01,$00,$03
defb	$40,$36,$06,$01,$01,$00,$03
defb	$40,$3a,$07,$01,$01,$00,$03

defb	$40,$64,$08,$01,$01,$00,$03
defb	$40,$68,$09,$01,$01,$00,$03
defb	$40,$6c,$0a,$01,$01,$00,$03
defb	$40,$70,$0b,$01,$01,$00,$03
defb	$40,$74,$0c,$01,$01,$00,$03
defb	$40,$78,$0d,$01,$01,$00,$03
defb	$40,$7c,$0e,$01,$01,$00,$03

defb	$40,$a2,$0f,$01,$01,$00,$03
defb	$40,$aa,$10,$01,$01,$00,$03
defb	$40,$b2,$11,$01,$01,$00,$03
defb	$40,$ba,$12,$01,$01,$00,$03

defb	$40,$e3,$13,$01,$01,$00,$03
defb	$40,$e7,$14,$01,$01,$00,$03
defb	$40,$eb,$15,$01,$01,$00,$03
defb	$40,$ef,$16,$01,$01,$00,$03
defb	$40,$f3,$17,$01,$01,$00,$03
defb	$40,$f7,$18,$01,$01,$00,$03
defb	$40,$fb,$19,$01,$01,$00,$03

end $8000
