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

;-------------------------------------------------------------------------------------
;Inicializo algunos registros que voy a usar como variables.
	ldi		r24,	0x00		;inicializo r24 para contar las llamadas al timer
	ldi     r25,    0x00        ;inicializo r25 para contar los segundos transcurridos
	ldi     r26,    0x00        ;inicializo r26 para almacenar el estado del cronómetro
;-------------------------------------------------------------------------------------


;Programa principal ... acá puedo hacer lo que quiero

comienzo:
	sei							;habilito las interrupciones globales(set interrupt flag)

loop1:
	nop
	nop
	nop
	nop
	ori r16, 0xFF
	nop
	nop
	nop
	brne	loop1
loop2:
	nop
	nop
	nop
fin:
	rjmp loop2

;RUTINAS
;-------------------------------------------------------------------------------------

; ------------------------------------------------
; Rutina de atención a la interrupción del Timer0.
; ------------------------------------------------
; recordar que el timer 0 fue configurado para interrumpir cada 125 ciclos (5^3), y tiene un prescaler 1024 = 2^10.
; El reloj de I/O está configurado @ Fclk = 16.000.000 Hz = 2^10*5^6; entonces voy a interrumpir 125 veces por segundo
; esto sale de dividir Fclk por el prescaler y el valor de OCR0A.

_tmr0_int:			
		cpi     r26, 1				;está pausado el cronómetro?
		breq    _tmr0_out			;si la condición anterior se cumple, cortamos la ejecución del timer
		cpi		r24, 125			;comparo r24 con 125, llegamos al valor necesario para 1 segundo?
		breq	_tmr0_segundo		;si se cumple, brancheamos a _tmr0_segundo
		inc		r24					;aumento el contador de llamadas al timer
		rjmp	_tmr0_out           ;salto a la salida del timer
_tmr0_segundo:
		ldi		r24, 0	            ;reseteo el valor de r24 a 0
		sbi		PINB, 2			    ;toggle LED (D4)
		cpi		r25, 255			;comparo r25 con 255, llegamos a 255 segundos?
		breq	_tmr0_segundosCero  ;si se cumple, brancheamos a _tmr0_segundosCero
		inc     r25					;aumento el contador de segundos
		rjmp	_tmr0_out			;salto a la salida del timer
_tmr0_segundosCero:
		ldi     r25, 0              ;reseteo el valor de r25 a 0
		sbi		PINB, 3             ;toggle LED (D3)
_tmr0_out:
	    reti						;retorno de la rutina de interrupción del Timer0

; ------------------------------------------------
; Rutina de atención a la interrupción botones A1, A2 y A3.
; ------------------------------------------------
; Botón A1: Reiniciar el cronometro a 0
; Botón A2: Pausar el cronometro
; Botón A3: Play al cronometro


_pci1_int:
		sbi		PINB, 5				;toggle LED (D1) para indicar que entramos a esta interrupción
		sbis	PINC, 1				;ignoro la instrucción que sigue si A1 no está presionado
		rjmp	_pci1_boton_A1		;salto al bloque de A1
		sbis	PINC, 2				;ignoro la instrucción que sigue si A2 no está presionado
		rjmp    _pci1_boton_A2		;salto al bloque de A2
		sbis	PINC, 3				;ignoro la instrucción que sigue si A3 no está presionado
		rjmp    _pci1_boton_A3		;salto al bloque de A3
_pci1_out:
		reti
_pci1_boton_A1:
		ldi r25, 0                  ;reinicio el contador de segundos a 0
		rjmp _pci1_out				;salto a la salida de la interrupción
_pci1_boton_A2:  
		ldi r26, 1					;pauso el cronometro
		rjmp _pci1_out				;salto a salida de la interrupción
_pci1_boton_A3:
		ldi r26, 0					;play al cronometro
		rjmp _pci1_out				;salto a salida de la interrupción
