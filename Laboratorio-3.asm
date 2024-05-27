.include "./m328Pdef.inc"

;
; Ejemplo_Interrupción_Timer0.asm
;
; Created: 12/9/2021 22:00:38
; Author : curso de microprocesadores
;

; Empiezo con los vectores de interrupción
.ORG 0x0000
	jmp		start		;dirección de comienzo (vector de reset) 
.ORG PCI1addr
	jmp     _pci1_int   ;salto a rutina del PCI1 (botón)
.ORG OC0Aaddr 
	jmp		_tmr0_int	;salto a del timer 0

.def contador_timer = r21
.def segundos = r22
.def minutos = r23
.def pausado = r24
.def digito = r25


; ---------------------------------------------------------------------------------------
; acá empieza el programa
start:
;configuro los puertos:
;	PB2 PB3 PB4 PB5	- son los LEDs del shield
    ldi		r16,	0b00111101	
	out		DDRB,	r16			;4 LEDs del shield son salidas
	out		PORTB,	r16			;apago los LEDs

	ldi		r16,	0b00000000	
	out		DDRC,	r16			;3 botones del shield son entradas
;-------------------------------------------------------------------------------------
;Configuro el TMR0 y su interrupcion.
	ldi		r16,	0b00000010	
	out		TCCR0A,	r16			;configuro para que cuente hasta OCR0A y vuelve a cero (reset on compare), ahí dispara la interrupción
	ldi		r16,	0b00000101	
	out		TCCR0B,	r16			;prescaler = 1024
	ldi		r16,	124	
	out		OCR0A,	r16			;comparo con 125
	ldi		r16,	0b00000010	
	sts		TIMSK0,	r16			;habilito la interrupción (falta habilitar global)
;-------------------------------------------------------------------------------------
;Configuro el TMR1 y su interrupcion. (botón A1 / pin PC1)
	ldi r16, 0b00000010			
	sts PCICR, r16				;configuro el PCIFR (pin change interrupt control register) para el puerto C (Orden: BCD)
	ldi r16, 0b00001110	
	sts PCMSK1, r16				;configuro el PCMSK1 (pines 1, 2 y 3 del puerto C, para botones A1, A2 y A3)

	ldi		r16,	0b10010000
	out		DDRD,	r16			;configuro PD.4 y PD.7 como salidas
	cbi		PORTD,	7			;PD.7 a 0, es el reloj serial, inicializo a 0
	cbi		PORTD,	4			;PD.4 a 0, es el reloj del latch, inicializo a 0

;-------------------------------------------------------------------------------------
;Inicializo algunos registros que voy a usar como variables.
	ldi		contador_timer,	0x00		;inicializo contador_timer para contar las llamadas al timer
	ldi     segundos,    0x00        ;inicializo segundos para contar los segundos transcurridos
	ldi     minutos,    0x00        ;inicializo segundos para contar los segundos transcurridos
	ldi     pausado,    0x00        ;inicializo r26 para almacenar el estado del cronómetro
	ldi     digito,    0x00 
;-------------------------------------------------------------------------------------

; Tabla de traducción de números a segmentos del display de 7 segmentos
; Los valores son los segmentos activos para formar los dígitos del 0 al 9
segment_table:
  .db 0b00000011, 0x00 ; 0
  .db 0b10011111, 0x00 ; 1
  .db 0b00100101, 0x00 ; 2
  .db 0b00001101, 0x00 ; 3
  .db 0b10011001, 0x00 ; 4
  .db 0b01001001, 0x00 ; 5
  .db 0b01000001, 0x00 ; 6
  .db 0b00011111, 0x00 ; 7
  .db 0b00000001, 0x00 ; 8
  .db 0b00001001, 0x00 ; 9

apagar:		; apaga todo el display de 7 segmentos
	ldi r16,0
	ldi r17,0b11110000
	call sacanum

;Programa principal ... acá puedo hacer lo que quiero

comienzo:
	sei							;habilito las interrupciones globales(set interrupt flag)

loop:
	nop
	nop
	jmp	loop

;RUTINAS
;-------------------------------------------------------------------------------------

; ------------------------------------------------
; Rutina de atención a la interrupción del Timer0.
; ------------------------------------------------
; recordar que el timer 0 fue configurado para interrumpir cada 125 ciclos (5^3), y tiene un prescaler 1024 = 2^10.
; El reloj de I/O está configurado @ Fclk = 16.000.000 Hz = 2^10*5^6; entonces voy a interrumpir 125 veces por segundo
; esto sale de dividir Fclk por el prescaler y el valor de OCR0A.

_tmr0_int:		
		push	r16
		in      r16, SREG      
		push    r16
		call    actualizar_leds
		cpi     pausado, 1			  ;está pausado el cronómetro?
		breq    _tmr0_out			  ;si la condición anterior se cumple, cortamos la ejecución del timer
		cpi		contador_timer, 125	  ;comparo contador_timer con 125, llegamos al valor necesario para 1 segundo?
		breq	_tmr0_segundo		  ;si se cumple, brancheamos a _tmr0_segundo
		inc		contador_timer	      ;aumento el contador de llamadas al timer
		rjmp	_tmr0_out             ;salto a la salida del timer
_tmr0_segundo:
		ldi		contador_timer, 0	  ;reseteo el valor de contador_timer a 0
		cpi		segundos, 60	      ;comparo segundos con 60, llegamos a 60 segundos?
		breq	_tmr0_minuto          ;si se cumple, brancheamos a _tmr0_minuto
		inc     segundos	          ;aumento el contador de segundos
		rjmp	_tmr0_out			  ;salto a la salida del timer
_tmr0_minuto:
		ldi     segundos, 0           ;reseteo el valor de segundos a 0
		inc     minutos			      ;aumento el contador de minutos
		rjmp    _tmr0_out
_tmr0_out:
		pop     r16
		out     SREG, r16
		pop		r16
	    reti						  ;retorno de la rutina de interrupción del Timer0

; ------------------------------------------------
; Rutina de atención a la interrupción botones A1, A2 y A3.
; ------------------------------------------------
; Botón A1: Reiniciar el cronometro a 0
; Botón A2: Pausar el cronometro
; Botón A3: Play al cronometro


_pci1_int:
		push	r16
		in      r16, SREG      
		push    r16        
		sbis	PINC, 1				;ignoro la instrucción que sigue si A1 no está presionado
		rjmp	_pci1_boton_A1		;salto al bloque de A1
		sbis	PINC, 2				;ignoro la instrucción que sigue si A2 no está presionado
		rjmp    _pci1_boton_A2		;salto al bloque de A2
		sbis	PINC, 3				;ignoro la instrucción que sigue si A3 no está presionado
		rjmp    _pci1_boton_A3		;salto al bloque de A3
_pci1_out:
		pop     r16
		out     SREG, r16
		pop		r16
		reti
_pci1_boton_A1:
		ldi     segundos, 0              ;reinicio el contador de segundos a 0
		ldi     minutos, 0              ;reinicio el contador de minutos a 0
		rjmp    _pci1_out	        ;salto a la salida de la interrupción
_pci1_boton_A2:  
		ldi     pausado, 1				;pauso el cronometro
		rjmp    _pci1_out			;salto a salida de la interrupción
_pci1_boton_A3:
		ldi     pausado, 0				;play al cronometro
		rjmp    _pci1_out			;salto a salida de la interrupción


actualizar_leds:
		cpi digito, 0
		breq actualizar_0
		cpi digito, 1
		breq actualizar_1
		cpi digito, 2
		breq actualizar_2
		cpi digito, 3
		breq actualizar_3
		ret
actualizar_0:
		ldi digito, 1
		mov r18, minutos
		ldi r19, 10
		call divmod
		mov r16, r20
		ldi r17, 0b10000000
		call sacanum
		ret
actualizar_1:	
		ldi digito, 2
		mov r18, minutos
		ldi r19, 10
		call divmod
		mov r16, r18
		ldi r17, 0b01000000
		call sacanum
		ret
actualizar_2:
		ldi digito, 3
		mov r18, segundos
		ldi r19, 10
		call divmod
		mov r16, r20
		ldi r17, 0b00100000
		call sacanum
		ret
actualizar_3:
		ldi	digito, 0
		mov r18, segundos
		ldi r19, 10
		call divmod
		mov r16, r18
		ldi r17, 0b00010000
		call sacanum
		ret

;-------------------------------------------------------------------------------------
; La rutina sacanum, envía lo que hay en r16 y r17 al display de 7 segmentos
; r16 - contiene los LEDs a prender/apagar 0 - prende, 1 - apaga
; r17 - contiene el dígito: r17 = 1000xxxx 0100xxxx 0010xxxx 0001xxxx del dígito menos al más significativo.
sacanum: 
	ldi r18, 0                       ; Clear r18
    ldi ZH, high(segment_table * 2) ; Load the high byte of the address
    ldi ZL, low(segment_table * 2)  ; Load the low byte of the address
	lsl r16
    add ZL, r16                      ; Add the offset to ZL
    adc ZH, r18                      ; Add the carry to the high byte
    lpm r16, Z                        ; Load the value from the table into r16
	call	dato_serie
	mov		r16, r17
	call	dato_serie
	sbi		PORTD, 4		;PD.4 a 1, es LCH el reloj del latch
	cbi		PORTD, 4		;PD.4 a 0, 
	ret
	;Voy a sacar un byte por el 7seg
dato_serie:
	ldi		r18, 0x08 ; lo utilizo para contar 8 (8 bits)
loop_dato1:
	cbi		PORTD, 7		;SCLK = 0 reloj en 0
	lsr		r16				;roto a la derecha r16 y el bit 0 se pone en el C
	brcs	loop_dato2		;salta si C=1
	cbi		PORTB, 0		;SD = 0 escribo un 0 
	rjmp	loop_dato3
loop_dato2:
	sbi		PORTB, 0		;SD = 1 escribo un 1
loop_dato3:
	sbi		PORTD, 7		;SCLK = 1 reloj en 1
	dec		r18
	brne	loop_dato1; cuando r17 llega a 0 corta y vuelve
	ret

; Division routine (r0/r1, result in r0 quotient, r2 remainder)
divmod:
    clr r20           ; Clear remainder
divmod_loop:
    cp r18, r19        ; Compare r0 with r1
    brlo divmod_done ; If r0 < r1, we are done
    sub r18, r19       ; Subtract r1 from r0
    inc r20           ; Increment remainder
    rjmp divmod_loop ; Repeat until r0 < r1
divmod_done:
    ret
