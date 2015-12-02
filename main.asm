	errorlevel  -302


	#include "config.inc" 
	
	__CONFIG       _CP_OFF & _CPD_OFF & _WDT_OFF & _BOR_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT  & _MCLRE_OFF & _FCMEN_OFF & _IESO_OFF
	
	
	udata_shr
temp				res	1
BufferPosition		res	2
rotary_last_state	res 1
rotary_new_state	res 1
rotary_result		res 1 ; bit[0]:1=has changed,0=no change; bit[1]:0=cw,1=ccw
counter				res 1
d1					res	1
d2					res 1
d3					res	1
STATUS_TEMP			res	1
W_TEMP				res	1
color_red			res 1
color_green			res 1
color_blue			res 1


	; imported from the display module:
	extern	Display_init
	extern	Display_clear
	extern	Display_set_pos_line1
	extern	Display_set_pos_line2
	extern	Display_write_char
	extern	Display_digit_char

Interrupt	CODE	0x4
	pagesel	_interrupt
	goto	_interrupt	
	
Reset		CODE	0x0
	pagesel	_init
	goto	_init
	code
	
_init
	; set the requested clockspeed
	banksel	OSCCON
	if CLOCKSPEED == .8000000
		movlw	b'01110000'
	else
		if CLOCKSPEED == .4000000
			movlw	b'01100000'
		else
			error	"Unsupported clockspeed"
		endif
	endif
	movwf	OSCCON

	; set the OSCTUNE value now
	banksel	OSCTUNE
	movlw	OSCTUNE_VALUE
	movwf	OSCTUNE
	
	; setup option register
	banksel	OPTION_REG
	movlw	b'00001100'	
		;	  ||||||||---- PS0 - Timer 0: 
		;	  |||||||----- PS1
		;	  ||||||------ PS2
		;	  |||||------- PSA -  Assign prescaler to Timer0
		;	  ||||-------- TOSE - LtoH edge
		;	  |||--------- TOCS - Timer0 uses IntClk
		;	  ||---------- INTEDG - falling edge RB0
		;	  |----------- NOT_RABPU - pull-ups enabled
	movwf	OPTION_REG
	; configure the watch-dog timer now
	CLRWDT
	movlw	b'00010111' ; 65536 + enable
	banksel	WDTCON
	movwf	WDTCON
	
	; Select the clock for our A/D conversations
	BANKSEL	ADCON1
	MOVLW 	B'01010000'	; ADC Fosc/16
	MOVWF 	ADCON1

	; all ports to digital
	banksel	ANSEL
	clrf	ANSEL
	clrf	ANSELH
	
	; Configure PortA as output, except PA0 & PA1
	BANKSEL TRISA
	clrf	TRISA
	bsf		TRISA,TRISA0
	bsf		TRISA,TRISA1
	
	; Set entire portB as output
	BANKSEL	TRISB
	clrf	TRISB
	
	; Set entire portC as output
	BANKSEL	TRISC
	clrf	TRISC	
	
	; set all output ports to 0
	banksel	PORTA
	clrf	PORTA
	clrf	PORTB
	clrf	PORTC
	
	; configure interrupt
	movfw	PORTA		; read port to get current status
	banksel	IOCA
	bsf		IOCA, IOCA0
	bsf		IOCA, IOCA1
	; enable interrupt
	bsf		INTCON, RABIE
	bsf		INTCON, GIE

	; init the display
	call	Display_init

	clrf	counter
	clrf	rotary_new_state
	clrf	rotary_last_state
	clrf	rotary_result
	; start with red
	movlw	.255
	movwf	color_red
	clrf	color_green
	clrf	color_blue

_main

	; test
	
	;movlw	'W'
	;call	Display_write_char
	;movlw	'e'
	;call	Display_write_char
	;movlw	'l'
	;call	Display_write_char
	;movlw	'c'
	;call	Display_write_char
	;movlw	'o'
	;call	Display_write_char
	;movlw	'm'
	;call	Display_write_char
	;movlw	'e'
	;call	Display_write_char
	;movlw	'!'
	;call	Display_write_char
	;movlw	' '
	;call	Display_write_char
	;movlw	':'
	;;call	Display_write_char
	;movlw	'-'
	;call	Display_write_char
	;movlw	')'
	;call	Display_write_char

	;movfw	counter
	;call	Display_digit_char
	;movlw	' '
	;call	Display_write_char


	btfss	rotary_result,0
	goto	_main

	call	RotaryChanged ; change detected, handle it

	movlw	.0
	call	Display_set_pos_line1
	movfw	counter
	call	Display_digit_char

	goto	_main

; routine to handle rotary change as defined in rotary_result
RotaryChanged
	btfss	rotary_result,1
	goto	RotaryChanged_cw
	goto	RotaryChanged_ccw
RotaryChanged_cw
	incf	counter,F
	goto	RotaryChanged_done
RotaryChanged_ccw
	decf	counter,F
	goto	RotaryChanged_done
RotaryChanged_done
	clrf	rotary_result ; result consumed. Clear register
	return


_interrupt
	; save context
	MOVWF 	W_TEMP 		;Copy W to TEMP register
	SWAPF 	STATUS,W 	;Swap status to be saved into W
	CLRF 	STATUS 		;bank 0, regardless of current bank, Clears IRP,RP1,RP0
	MOVWF 	STATUS_TEMP ;Save status to bank zero STATUS_TEMP register
	
	; clear the RABIF bit
	banksel	PORTA
	movfw	PORTA
	bcf		INTCON, RABIF

	; calc rotary change direction and store it in rotary_result
	call	ReadRotary

	; re-enable interrupt
	bsf		INTCON, GIE

	; restore context
	SWAPF 	STATUS_TEMP,W 	;Swap STATUS_TEMP register into W
	MOVWF 	STATUS 			;Move W into STATUS register
	SWAPF 	W_TEMP,F 		;Swap W_TEMP
	SWAPF 	W_TEMP,W 		;Swap W_TEMP into W
	RETFIE	

; read the rotary state and determines the change of direction
ReadRotary
	; clear the result
	clrf	rotary_result
	; read current state into rotary_new_state
	banksel	PORTA
	bcf		rotary_new_state, 0
	btfsc	PORTA,0
	bsf		rotary_new_state, 0
	bcf		rotary_new_state, 1
	btfsc	PORTA,1
	bsf		rotary_new_state, 1

	; we know for sure that something has changed, figure out what
	; we do this by using a lookup table. The look-up key
	; is <current_state><new_state>

	; move last_state into temp[2-3] and new_state into temp[0-1]
	clrf	temp
	movfw	rotary_last_state
	movwf	temp
	bcf		STATUS,C
	rlf		temp, F
	bcf		STATUS,C
	rlf		temp, F
	bcf		temp,0
	btfsc	rotary_new_state,0
	bsf		temp,0
	bcf		temp,1
	btfsc	rotary_new_state,1
	bsf		temp,1

	; lookup the result in the table
	movlw 	HIGH RotaryResultTable
	movwf 	PCLATH
	movfw	temp
	call	RotaryResultTable
	movwf	rotary_result
	; done

	; store new state as last for next round 
	movfw	rotary_new_state
	movwf	rotary_last_state
	return

RotaryResultTable 
	; the rotary result: bit[0]:1=something has changed,0=no change; bit[1]0=cc direction,1=ccw direction
	; so: 00 (0) - no change
	;     01 (1) - changed in cc direction
	;     11 (3) - changed in ccw direction
	addwf	PCL, F
	retlw	.0 ; 0
	retlw	.3 ; 1
	retlw	.1 ; 2
	retlw	.0 ; 3
	retlw	.1 ; 4
	retlw	.0 ; 5
	retlw	.0 ; 6
	retlw	.3 ; 7
	retlw	.3 ; 8
	retlw	.0 ; 9
	retlw	.0 ; 10
	retlw	.1 ; 11
	retlw	.0 ; 12
	retlw	.1 ; 13
	retlw	.3 ; 14
	retlw	.0 ; 15


_delay_250ms
	banksel	d1
			;499994 cycles
	movlw	0x03
	movwf	d1
	movlw	0x18
	movwf	d2
	movlw	0x02
	movwf	d3
_delay_250ms_0
	decfsz	d1, f
	goto	$+2
	decfsz	d2, f
	goto	$+2
	decfsz	d3, f
	goto	_delay_250ms_0

			;2 cycles
	goto	$+1

			;4 cycles (including call)
	return
	


Delay_50ms
			;99993 cycles
	movlw	0x1E
	movwf	d1
	movlw	0x4F
	movwf	d2
Delay_50ms_0
	decfsz	d1, f
	goto	$+2
	decfsz	d2, f
	goto	Delay_50ms_0

			;3 cycles
	goto	$+1
	nop

			;4 cycles (including call)
	return


	end