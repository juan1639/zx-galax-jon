org $8000

;========================   C O N S T A N T E S   ========================
JUGADOR_Y		equ	$50
JUGADOR_LIMITE_IZ	equ	$80
JUGADOR_LIMITE_DE	equ	$9d

;==========================================================================
;---			C O M I E N Z O   P R O G R A M A		---
;---									---
;---      		    CLS + ATRIBUTOS GENERALES                   ---
;--------------------------------------------------------------------------
call	sub_cls
call 	sub_clsattr
call	sub_set_attr_generales

;==========================================================================
;---                                                                    ---
;---	               B U C L E    P R I N C I P A L                   ---
;---                                                                    ---
;==========================================================================
bucle_principal:
	call	teclado
	call	dibuja_jugador
	halt

	jr	bucle_principal
	jr 	$		; =========================================
;==========================================================================
;=====                                                                =====
;=====                        S U B R U T I N A S                     =====
;=====                                                                =====
;==========================================================================
;---		             SUB - DIBUJA JUGADOR                       ---
;---                                                                    ---
;---  HL---> Coordenadas Jugador        ...  B---> Bucle Scanlines      ---
;---  DE---> Puntero direcciones Sprite ...  				---
;==========================================================================
dibuja_jugador:
	ld	a,JUGADOR_Y
	ld	h,a
	ld	a,(jugador_x)
	ld	l,a

	;--------------------------------------------------------------------
	; Cargar bytes-nave en 'de' y comprobar la rotacion actual de la nave
	;--------------------------------------------------------------------
	ld 	de, nave_jugador

	ld 	a, (jugador_rot)
	or	a
	jr	z, rotacion_zero	; salta porque la rotacion es 0

	;--------------------------------------------------------------
	; Bucle para llegar a los bytes correspondientes a la rotacion
	;--------------------------------------------------------------
	ld 	b,a

	bucle_select_rot:
		call incrementar_de

	djnz	bucle_select_rot

	;-----------------------------------------------------
	; Aqui ya se dibuja la nave (sabiendo ya la rotacion)
	;-----------------------------------------------------
	rotacion_zero:
		ld 	b, $10

	bucle_dibuja_jugador:
		ld	a, (de)
		ld	(hl),a

		inc	l
		inc	de

		ld	a,(de)
		ld	(hl),a

		inc	l
		inc	de

		ld	a,(de)
		ld	(hl),a

		dec	l
		dec	l

		call check_next_fila

		inc 	de
		djnz	bucle_dibuja_jugador
		ret

; -----------------------------------------------------
; 	+48 en DE
; -----------------------------------------------------
incrementar_de:
	ld   a,e
	add  a,48
	ld   e,a
	jr   nc,ret_inc_de

	inc  d

ret_inc_de:
	ret

;----------------------------------------------------
; 	-48 en DE
;----------------------------------------------------
decrementar_de:
	ld   a,e
	sub  48
	ld   e,a
	jr   nc,ret_dec_de
	
	dec  d

ret_dec_de:
	ret

; -------------------------------------------------------------
; Checkear si debemos inc SCANLINE o pasar a la siguiente FILA
; -------------------------------------------------------------
check_next_fila:
	ld	a,h
	and	%00000111
	cp	%00000111
	jr 	nz, next_scanline

	ld	a,h
	xor	%00000111
	ld	h,a

	ld	a,l
	add	a, $20
	ld	l,a
	ret

next_scanline:
	inc h
	ret

;===========================================================================
;---                    SUB - L E E R   T E C L A D O                    ---
;---                                                                     ---  
;---         Izquierda --------> 'Z' o Cursor JoyStick Izquierda         ---
;---         Derecha ----------> 'X' o Cursor JoyStick Derecha           ---
;---         Disparo ----------> 'Spc' o Cursor JoyStick Arriba          ---
;---------------------------------------------------------------------------
teclado:
;-----------------------------------------------------------
; AQUI COMPROBAMOS LA POSIBLE PULSACION DE LA TECLA DISPARO
;-----------------------------------------------------------
disparo:
	ld	a,$7f		
	in	a,($fe)
	bit	0,a
	jr	nz,tecla_izq	; NZ = 'spc' No pulsada, salta a comprobar la siguiente...

	;------------------------------------------------------
	; Si llega aqui... Tecla 'disparo' Pulsada!
	;------------------------------------------------------
	ld	a,(settings)
	or 	a
	bit	3,a
	jr	nz,tecla_izq				

	set	3,a
	ld	(settings),a

;-------------------------------------------------------------
; AQUI COMPROBAMOS LA POSIBLE PULSACION DE LA TECLA IZQUIERDA
;-------------------------------------------------------------
tecla_izq:
	ld	a,$fe
	in	a,($fe)
	bit	1,a
	jr	nz,tecla_dcha

	;-------------------------------------------------------
	; Y SI LLEGA AQUI, ES QUE HEMOS PULSADO IZQUIERDA Y ...
	; ...PROCEDEMOS A ROTAR O MOVER AL JUGADOR A LA IZDA
	;-------------------------------------------------------
	ld	a,(jugador_rot)	; Rotar a la izda
	or 	a
	jr	z, mover_caracter_izda

	dec	a
	ld	(jugador_rot),a
	ret

	mover_caracter_izda:
		ld	a,(jugador_x)	; Mover a la izda
		cp	JUGADOR_LIMITE_IZ
		ret	z

		dec	a
		ld	l,a
		ld	(jugador_x), a

		ld	a, $07
		ld	(jugador_rot),a
		ret

;-----------------------------------------------------------
; AQUI COMPROBAMOS LA POSIBLE PULSACION DE LA TECLA DERECHA
;-----------------------------------------------------------
tecla_dcha:
	ld	a,$fe
	in	a,($fe)
	bit	2,a
	ret	nz

	;-----------------------------------------------------
	; Y SI LLEGA AQUI, ES QUE HEMOS PULSADO DERECHA Y ...
	; ...PROCEDEMOS A ROTAR O MOVER AL JUGADOR A LA DCHA
	;-----------------------------------------------------
	ld	a,(jugador_rot)	; Rotar a la dcha
	inc	a
	ld	(jugador_rot),a
	and 	%00001000
	ret 	z

	mover_caracter_dcha:
	ld	a,$07
	ld	(jugador_rot),a

	ld	a,(jugador_x)	; Mover a la dcha
	cp	JUGADOR_LIMITE_DE
	ret z

	inc	a
	ld	l,a
	ld	(jugador_x), a

	ld	a,$00
	ld	(jugador_rot),a
	ret

;===========================================================================
;---                    S U B - ATRIBUTOS GENERALES                      ---
;---------------------------------------------------------------------------
sub_set_attr_generales:
	ld	hl,$5a80
	ld	b,$20

	bucle_attr_generales:
		ld	a,%01000010	; Rojo Brillante (Parte alta de la nave)
		ld	(hl),a		; (0 Flash, 1 Brillo, 000 Fondo negro, 010 Tinta Roja)

		ld	a,l
		add	a,$20
		ld	l,a
		ld	a,%01000101	; Azul claro Brillante (parte baja de la nave)
		ld	(hl),a		; (0 Flash, 1 Brillo, 000 Fondo negro, 101 Tinta Azul Clara)

		ld	a,l
		sub	$20
		ld	l,a

		inc	l

		djnz	bucle_attr_generales
		ret

;===========================================================================
;---                    S U B - C L S  ATRIBUTOS                         ---
;---------------------------------------------------------------------------
sub_clsattr:
	ld 	a,%00000110
	ld 	hl,$5800
	ld	(hl),a
	ld	de,$5801
	ld	bc,$02ff
	ldir
	ret

;==========================================================================
;---		               SUB -  C L S                             ---
;--------------------------------------------------------------------------
sub_cls:
	ld	a,$00
	ld	hl,$4000
	ld	(hl),a
	ld	de,$4001
	ld	bc,$17ff
	ldir
	ret

;=============================================================================
;---                                                                       ---
;---                           S P R I T E S                               ---
;---                                                                       ---
;-----------------------------------------------------------------------------
; ASM source file created by SevenuP v1.20
; SevenuP (C) Copyright 2002-2006 by Jaime Tejedor Gomez, aka Metalbrain

;GRAPHIC DATA:
;Pixel Size:      ( 16,  16)
;Char Size:       (  2,   2)
;Sort Priorities: X char, Char line, Y char
;Data Outputted:  Gfx+Attr
;Interleave:      Sprite
;Mask:            No

;-----------------------------------------------
; NAVE JUGADOR (Incluidas las rotaciones)
;-----------------------------------------------
nave_jugador:
	DEFB	  1,128,  0,  3,192,  0,  7,224
	DEFB	  0, 15,240,  0, 15,240,  0,  9
	DEFB	144,  0, 73,146,  0, 65,130,  0
	DEFB	229,167,  0,237,183,  0,253,191
	DEFB	  0,252, 63,  0,246,111,  0,230
	DEFB	103,  0,224,  7,  0, 64,  2,  0

	DEFB	  0, 96,  0,  0,240,  0,  1,248
	DEFB	  0,  3,252,  0,  3,252,  0,  2
	DEFB	100,  0, 18,100,128, 16, 96,128
	DEFB	 57,105,192, 59,109,192, 63,111
	DEFB	192, 63, 15,192, 61,155,192, 57
	DEFB	153,192, 56,  1,192, 16,  0,128

	DEFB	  0, 48,  0,  0,120,  0,  0,252
	DEFB	  0,  1,254,  0,  1,254,  0,  1
	DEFB	 50,  0,  9, 50, 64,  8, 48, 64
	DEFB	 28,180,224, 29,182,224, 31,183
	DEFB	224, 31,135,224, 30,205,224, 28
	DEFB	204,224, 28,  0,224,  8,  0, 64

	DEFB	  0, 24,  0,  0, 60,  0,  0,126
	DEFB	  0,  0,255,  0,  0,255,  0,  0
	DEFB	153,  0,  4,153, 32,  4, 24, 32
	DEFB	 14, 90,112, 14,219,112, 15,219
	DEFB	240, 15,195,240, 15,102,240, 14
	DEFB	102,112, 14,  0,112,  4,  0, 32

	DEFB	  0, 12,  0,  0, 30,  0,  0, 63
	DEFB	  0,  0,127,128,  0,127,128,  0
	DEFB	 76,128,  2, 76,144,  2, 12, 16
	DEFB	  7, 45, 56,  7,109,184,  7,237
	DEFB	248,  7,225,248,  7,179,120,  7
	DEFB	 51, 56,  7,  0, 56,  2,  0, 16

	DEFB	  0,  6,  0,  0, 15,  0,  0, 31
	DEFB	128,  0, 63,192,  0, 63,192,  0
	DEFB	 38, 64,  1, 38, 72,  1,  6,  8
	DEFB	  3,150,156,  3,182,220,  3,246
	DEFB	252,  3,240,252,  3,217,188,  3
	DEFB	153,156,  3,128, 28,  1,  0,  8

	DEFB	  0,  3,  0,  0,  7,128,  0, 15
	DEFB	192,  0, 31,224,  0, 31,224,  0
	DEFB	 19, 32,  0,147, 36,  0,131,  4
	DEFB	  1,203, 78,  1,219,110,  1,251
	DEFB	126,  1,248,126,  1,236,222,  1
	DEFB	204,206,  1,192, 14,  0,128,  4

	DEFB	  0,  1,128,  0,  3,192,  0,  7
	DEFB	224,  0, 15,240,  0, 15,240,  0
	DEFB	  9,144,  0, 73,146,  0, 65,130
	DEFB	  0,229,167,  0,237,183,  0,253
	DEFB	191,  0,252, 63,  0,246,111,  0
	DEFB	230,103,  0,224,  7,  0, 64,  2

	DEFB	  0,192,  0,  1,224,  0,  3,240
	DEFB	  0,  7,248,  0,  7,248,  0,  4
	DEFB	200,  0, 36,201,  0, 32,193,  0
	DEFB	114,211,128,118,219,128,126,223
	DEFB	128,126, 31,128,123, 55,128,115
	DEFB	 51,128,112,  3,128, 32,  1,  0

;-----------------------------------------------------------------------------
;---		V A R I A B L E S  en  M E M O R I A                       ---
;-----------------------------------------------------------------------------
jugador_x	defb $8f	; Coordenada X, 'L' (hl) del Jugador (la h es constante)

jugador_rot	defb $00	; Rotacion actual del jugador

jugador_set	defb $00	; Settings del Jugador (Bits utilizados)...
; Bit0 = 1 Transicion vida menos       ...  Bit1 = 1 
; Bit2 = 1 			       ...  Bit3 = 1 
; Bit4 = 1 			       ...  Bit5 = 1
; Bit6 = 1 			       ...  Bit7 = 1

settings	defb $00	; Settings generales (Bits utilizados)...	 
; Bit0 = 1 Siguiente Nivel (adelante)   ...   Bit1 = 1 Transicion vida menos
; Bit2 = 1 Game Over                    ...   Bit3 = 1 Disparando
; Bit4 = 1 			        ...   Bit5 = 1 
; Bit6 = 1 				...   Bit7 = 1 

; ----------------------------------------------------------------------------
end	$8000
