;**********************************************
; Code for RS-232 communication, to be included in
; your program.
;
;
;**********************************************

#include "config.inc"

#ifndef RS232_TX_PORT
	error	"RS232_TX_PORT must be defined, for example: PORTA,0"
#endif
#ifndef RS232_RX_PORT
	error	"RS232_RX_PORT must be defined, for example: PORTA,1"
#endif
#ifndef RS232_BAUD
	error	"RS232_BAUD must be defined, for example: .9600"
#endif
#ifndef CLOCKSPEED
	error	"CLOCKSPEED must be defined, for example: .8000000"
#endif

#define	rs232_read_max		.15
#define rs232_read_timeout 	0x00


	udata
Temp				res 1
Counter				res 1
ByteCounter			res 1
DelayCounter 		res 1
RS232ReceiveBuf		res	rs232_read_max
RS232ReceiveBufAddr	res	2
	global		RS232ReceiveBuf

	code

; Init module
RS232_Init
	global	RS232_Init

	; send stop bit to indicate idle
	banksel	PORTB
	bsf		RS232_TX_PORT
	call	RS232_Send_w_delay
	
	return

; Reads up to "rs232_read_max" bytes from rs232
; The received bytes are stored into RS232ReceiveBuf
; W contains the number of bytes read. 0 is used to indicate timeout
RS232_receive_W
	global	RS232_receive_W

	banksel	ByteCounter
	movlw	0x00
	movwf	ByteCounter ; used to keep track of bytes read

	; set the starting addr
	banksel	RS232ReceiveBuf
	movlw	HIGH	RS232ReceiveBuf
	movwf	RS232ReceiveBufAddr
	movlw	LOW		RS232ReceiveBuf
	movwf	RS232ReceiveBufAddr+1

RS232_receive_W_start
	; configure timeout value into "Counter"
	banksel	Counter
	movlw	rs232_read_timeout
	movwf	Counter
RS232_receive_W_wait_for_start
	; did we hit timeout?
	banksel	Counter
	decfsz	Counter, F
	goto	RS232_receive_W_wait_continue
	goto	RS232_receive_W_return
RS232_receive_W_wait_continue
	banksel	PORTB
	btfsc	RS232_RX_PORT
	goto	RS232_receive_W_wait_for_start

	; start bit received, wait to the middle of a bit before recoding
	banksel	Counter
	movlw	0x08
	movwf	Counter ; used as bit counter
	call	RS232_Send_w_delay_half	; move to the middle of the start bit

RS232_receive_W_reading
	; wait delay time
	call	RS232_Send_w_delay		; moves to the middle of the next bit

	; read bit from port now
	banksel	PORTB					; 2
	bsf		STATUS, C				; 1
	btfss	RS232_RX_PORT			; 1
	bcf		STATUS, C				; 1

	; push bit onto buffer Temp
	banksel	Temp					; 2
	rrf		Temp, F					; 1

	; are we done with current byte?
	banksel	Counter					; 2
	decfsz	Counter, F				; 1
	goto	RS232_receive_W_reading	; 2
	
	; current byte completed
	call	RS232_Send_w_delay		; forward to middle of stop bit

	; Write byte to buffer:
	; configure the address to which we write the current byte
	movfw	RS232ReceiveBufAddr+1
	movwf	FSR
	bcf		STATUS, IRP
	btfsc	RS232ReceiveBufAddr, 0
	bsf		STATUS, IRP
	; store the byte now
	movfw	Temp
	movwf	INDF
	; set the pointer one address forward
	incf	RS232ReceiveBufAddr+1, F
	; update the number of bytes stores in the buffer so far
	banksel	ByteCounter
	incf	ByteCounter, F

	; read next byte
	goto	RS232_receive_W_start
RS232_receive_W_return
	banksel	ByteCounter
	movfw	ByteCounter
	return


RS232_Send_W
	global	RS232_Send_W

	banksel	Temp
	movwf	Temp
	movlw	0x08
	movwf	Counter
	; send start bit
	banksel	PORTB
	bcf		RS232_TX_PORT
	call	RS232_Send_w_delay
RS232_Send_w_loop
	banksel	Temp					; 2
	rrf		Temp, F					; 1
	banksel	PORTB					; 2
	BTFSS   STATUS, C				; 1
    BCF     RS232_TX_PORT			; 1
	BTFSC   STATUS, C				; 1
	BSF     RS232_TX_PORT			; 1
	call	RS232_Send_w_delay		
	decfsz	Counter, F				; 1
	goto	RS232_Send_w_loop		; 2
	
	; send stop bit
	banksel	PORTB
	bsf		RS232_TX_PORT
	call	RS232_Send_w_delay
	call	RS232_Send_w_delay
	return

RS232_Send_w_delay
	banksel	DelayCounter
    
	if (CLOCKSPEED == .4000000 && RS232_BAUD == .9600)
        ; 104 cycles
		movlw	0x1e
		nop
	else
		if (CLOCKSPEED == .4000000 && RS232_BAUD == .4800) || (CLOCKSPEED == .8000000 && RS232_BAUD == .9600)
            ; 208 cycles
			movlw	0x3f
		else
			if (CLOCKSPEED == .8000000 && RS232_BAUD == .4800)
				; 416 cycles
				movlw	0x89
			else
				error	"Unimplemented clockspeed/baud configuration"
			endif
		endif
	endif
	
	movwf	DelayCounter
	decfsz	DelayCounter, F
	goto	$-1
	return	

RS232_Send_w_delay_half
	banksel	DelayCounter
    
	if (CLOCKSPEED == .4000000 && RS232_BAUD == .9600)
        ; 1/2 of 104 cycles
		movlw	0x0f
		nop
	else
		if (CLOCKSPEED == .4000000 && RS232_BAUD == .4800) || (CLOCKSPEED == .8000000 && RS232_BAUD == .9600)
            ; 1/2 of 208 cycles
			movlw	0x20
		else
			if (CLOCKSPEED == .8000000 && RS232_BAUD == .4800)
				; 1/2 of 416 cycles
				movlw	0x43
			else
				error	"Unimplemented clockspeed/baud configuration"
			endif
		endif
	endif
	
	movwf	DelayCounter
	decfsz	DelayCounter, F
	goto	$-1
	return	

	end