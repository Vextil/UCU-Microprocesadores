.include "./m328Pdef.inc"
.org 0x00

setup:
	ldi r16,0b00111100
	out DDRB,r16

start:
    ldi r16,0b11011111
    out PORTB,r16
	call delay  

	ldi r16,0b11101111
    out PORTB,r16
	call delay  

	ldi r16,0b11110111
    out PORTB,r16
	call delay  

	ldi r16,0b11111011
    out PORTB,r16
	call delay

	ldi r16,0b11110111
    out PORTB,r16
	call delay

	ldi r16,0b11101111
    out PORTB,r16
	call delay  

    rjmp start

delay:
    ldi r20, 0x80
outer_loop: ; (3 instrucciones por loop + 197.119 de inner_loop) x 81 = 15.966.882
    ldi r21, 0xFF
inner_loop: ; (3 instrucciones por loop + 767 de inner_inner_loop) x 256 = 197.120 - 1 (ultima vuelta brne uno menos) = 197.119
    ldi r22, 0xFF
inner_inner_loop: ; 3 instrucciones por loop, 256 x 3 = 768 - 1 (ultima vuelta brne uno menos) = 767
    dec r22
    brne inner_inner_loop
    dec r21
    brne inner_loop
    dec r20
    brne outer_loop
    ret
