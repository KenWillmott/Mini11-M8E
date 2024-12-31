; MC68HC11A1 register definitions:
; from buf25.asm buffalo source
; existing defines added

PORTA	EQU	$00
		; $01 reserved
PIOC	EQU	$02
PORTC	EQU	$03
PORTB	EQU	$04
PORTCL	EQU	$05
		; $06 reserved
DDRC	EQU	$07
PORTD	EQU	$08
DDRD	EQU	$09
PORTE	equ	$0A           ; port e
CFORC	EQU	$0B
OC1M	EQU	$0C
OC1D	EQU	$0D
TCNT	equ	$0E           ; timer count
TIC1	EQU	$10
TIC2	EQU	$12
TIC3	EQU	$14
TOC1	EQU	$16
TOC2	EQU	$18
TOC3	EQU	$1A
TOC4	EQU	$1C
TOC5	equ	$1E           ; oc5 reg
TCTL1	equ	$20           ; timer control 1
TCTL2	equ	$21           ; timer control 2
TMSK1	equ	$22           ; timer mask 1
TFLG1	equ	$23           ; timer flag 1
TMSK2	equ	$24           ; timer mask 2
PACTL	EQU	$26
PACNT	EQU	$27
SPCR	EQU	$28
SPSR	EQU	$29
SPDR	EQU	$2A
BAUD	equ	$2B           ; sci baud reg
SCCR1	equ	$2C           ; sci control1 reg
SCCR2	equ	$2D           ; sci control2 reg
SCSR	equ	$2E           ; sci status reg
SCDR	equ	$2F           ; sci data reg
ADCTL	EQU	$30
ADR1	EQU	$31
ADR2	EQU	$32
ADR3	EQU	$33
ADR4	EQU	$34
		; $35-$38 reserved
OPTION	equ	$39           ; option reg
COPRST	equ	$3A           ; cop reset reg
PPROG	equ	$3B           ; ee prog reg
HPRIO	equ	$3C           ; hprio reg
INIT	equ	$3D           ; RAM and IO mapping reg
TEST1	EQU	$3E
CONFIG	equ	$3F           ; config register

; some other CPU attributes:

NUMVEC		equ	20	; number of CPU vectors to create
NUMREG		equ	11	; number of CPU registers

; Register flag definitions:

TDRE	equ	$80
RDRF	equ	$20

