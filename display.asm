#include "config.inc"

#ifndef DISPLAY_PORT
	error	"DISPLAY_PORT must be defined, for example: PORTC"
#endif
#ifndef DISPLAY_PORT_RS
	error	"DISPLAY_PORT_RS must be defined, for example: PORTA,0"
#endif
#ifndef DISPLAY_PORT_E
	error	"DISPLAY_PORT_E must be defined, for example: PORTA,0"
#endif
#ifndef CLOCKSPEED
	error	"CLOCKSPEED must be defined, for example: .8000000"
#endif


	udata
DelayCounter1	res 1
DelayCounter2	res 1


	code
	
Display_init
	global	Display_init
	banksel	PORTA
	; set the E pin to high since it is the high->low change which tells the display to accept the data
	bsf		DISPLAY_PORT_E
	call	Delay_2_5_ms
	; select a blinking cursor
	movlw	b'00001100'	; enable display with no cursor
	call 	Display_write_cmd
	movlw	b'00111000'	; we are using a 2x16 chars @ 5x7 dots display
	call 	Display_write_cmd
	return

Display_clear
	global	Display_clear
	banksel	PORTC
	movlw	0x01
	call	Display_write_cmd
	return

Display_set_pos_line1
	global	Display_set_pos_line1
	banksel	PORTC
	iorlw	0x80				; set the first bits
	call 	Display_write_cmd	; set the cursor to the position currently in W
	return

Display_set_pos_line2
	global	Display_set_pos_line2
	banksel	PORTC
	iorlw	0xc0				; set the first two bits
	call 	Display_write_cmd	; set the cursor to the position currently in W
	return

Display_digit_char
	global	Display_digit_char
	banksel	PORTC
	addlw	0x30
	call	Display_write_char
	return

Display_write_char
	global	Display_write_char
	
	bsf		DISPLAY_PORT_RS	; get ready to write chars
	movwf	DISPLAY_PORT
	bcf		DISPLAY_PORT_E	; set the E pin to high again
	call	Delay_2_5_ms
	bsf		DISPLAY_PORT_E	; set the E pin to high
	bcf		DISPLAY_PORT_RS	; set the RS pin to low
	return

Display_write_cmd
	; Write the char
	movwf	DISPLAY_PORT
	bcf		DISPLAY_PORT_E	; set the E pin low
	call	Delay_2_5_ms
	bsf		DISPLAY_PORT_E	; set the E pin to high
	call	Delay_2_5_ms
	return	
	
Delay_2_5_ms
	if CLOCKSPEED == .8000000
				;4993 cycles
		movlw	0xE6
		movwf	DelayCounter1
		movlw	0x04
		movwf	DelayCounter2
	else
		if CLOCKSPEED == .4000000
				;2493 cycles
			movlw	0xF2
			movwf	DelayCounter1
			movlw	0x02
			movwf	DelayCounter2
		else
			error "Unsupported clockspeed"
		endif
	endif
Delay_2_5_ms_0
	decfsz	DelayCounter1, f
	goto	$+2
	decfsz	DelayCounter2, f
	goto	Delay_2_5_ms_0

			;3 cycles
	goto	$+1
	nop

			;4 cycles (including call)
	return
	
	end