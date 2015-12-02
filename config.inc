;--------------------------
; config.inc
;--------------------------

	list	p=16f690
#include    <p16f690.inc>

;**********************************************
; Port config:
; * PortC  : Out - display-data
; * RA4    : Out - display-RS
; * RA5    : Out - display-E
;
; * RA0    : IN  - RSSI 
; * RA1    : IN  - RSSI reference
;
; * RB4    : OUT - LED
; * RB5    : OUT - RS232 output
; * RB6    : IN  - RS232 input
;**********************************************
#define CLOCKSPEED      		.8000000	; 8 MHz Osc
;#define CLOCKSPEED       		.4000000	; 4 MHz Osc
#define	OSCTUNE_VALUE			.0


;***************************************
; Values required by display.asm
;***************************************
#define	DISPLAY_PORT			PORTC
#define	DISPLAY_PORT_RS			PORTA, 4
#define	DISPLAY_PORT_E			PORTA, 5
