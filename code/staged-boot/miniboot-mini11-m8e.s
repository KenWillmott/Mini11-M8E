;
;	Mini 11/M8E Bootstrap
;
; Multi stage boot system. This is stage #1.
;
; 1. Boot from MCU internal EEPROM, load the OS loader
; 2. Run OS loader, load the OS
; 3. Run the OS

; for SD interface info:
; www.sdcard.org/developers/tech/sdcard/pls/Simplified_Physical_Layer_Spec.pdf

; modified by Ken Willmott from Mini11 Bootstrap by Alan Cox
;
; 2024-06-29 change baud rate for 7.3278 Mhz crystal
; 2024-07-10 Add full system initialization
; 2024-07-12 make serial routines stand alone in ROM
; 2024-12-11 Move full system initialization to loader, simplify serial
; 2024-12-12 Change load destination and size to 1k VROM at $FC00
; 2024-12-19 Clean up and prepare for stage 2 plundering


	; MC68HC11A1 register definitions:
	include	../include/HC11defs.inc
	; M8E hardware specific definitions:
	include	../include/M8Edefs.inc

	; export for stage 2 boot
	SHARED	SYSVAR, LOADER, SD_READ_BLOCK, DESTINATION, SENDCSFF
	SHARED	PHEX, HEXDIGIT, DECDIGIT, CHOUT, STROUT

; put stack and variables at internal RAM just below EEPROM
SYSVAR		equ	EEPROM-$10
STKBAS		equ	SYSVAR-1

; SD status codes
CTMMC		equ	1
CTSD2		equ	2
CTSDBLK		equ	3
CTSD1		equ	4

STAGE2DEST	equ	IRAMND	; target address is base of upper 14k

; place in CPU on chip EEPROM
		ORG	EEPROM

			; Put the internal RAM at F040-F0FF
			; and I/O at F000-F03F. This costs us 64bits of IRAM
			; but gives us a nicer contiguous addressing map.
START:		ldaa	#$FF
		staa  	$1000+INIT

		ldx	#REGBAS		; X = base of CPU registers
	   	lds	#STKBAS-1   	; SET STACK POINTER

		ldd	#$6020		; A=$60 B=$20
		staa	HPRIO,x		; enable expanded mode (external memory)
			; Configure mux to cancel serial loopback
			; controlled by PA5
		stab	PORTA,X		; output = 1

		ldd	#$1301		; A=$13 B=$01
		staa	OPTION,X	;COP slow, clock startup DLY still on
			; Set up the memory for 64k contiguous RAM
			; bank 0 = block 0, bank 1 = block 1
		stab	MEMLAT

			; configure serial
			; Serial is 115200 8N1 for the 7.3728MHz crystal
		ldd	#$000c		; A=$00 B=$0c
		staa	BAUD,X		; BAUD
		staa	SCCR1,X		; SCCR1
		stab	SCCR2,X		; SCCR2

			; check boot select pin PE0
		ldaa	PORTE,x
		lsra
		bcc	SDBOOT		; pin strapped low, boot from SD
		jmp	NVRAMHI	; else boot user code

			; Ensure CS1 high
			; regardless of any surprises at reset
;		ldaa	#$80
;		staa	PORTA,X
;		bset	PACTL,X $80

; start up messages

SDBOOT:		ldy	#INIT1
		jsr	STROUT

; Following code is borrowed from HC11 Mini
; with minor modifications
; Probe for an SD card

		ldaa	#$38		; SPI outputs on
		staa	DDRD,X
		ldaa	#$52		; SPI on, master, mode 0, slow (125Khz)
		staa	SPCR,X

; copy read command buffer to RAM

		ldy	#SD_READ_BLOCK
RBLOOP:		ldaa	READ_SINGLE_BLOCK-SD_READ_BLOCK,y
		staa	0,y
		iny
		cpy	#SD_RB_END
		bne	RBLOOP

; set up transfer destination

		ldd	#STAGE2DEST
		std	DESTINATION

; initialize card

		jsr	SENDCSFF	; Raise CS send clocks
		ldaa	#200
CSLOOP:
		jsr	SENDFF
		deca
		bne	CSLOOP		; Allow time for SD to stabilize

		ldy	#GO_IDLE_STATE	; attempt to reset card
		bsr	SENDCMD
		decb			; 1 ?
		bne	SDFAILB		; not in idle state if != 1

		ldy	#SEND_IF_COND	; CMD8 to check idle state
		jsr	SENDCMD
		decb
		beq	DONEWCARD
		jsr	OLDCARD		; jump if not in idle state
		bra	ELSEOLD

DONEWCARD:	jsr	NEWCARD
ELSEOLD:	jsr	LOADER		; load first sector
		jmp	ALLDONE		; wrap up and exit

; This constant had to be moved down in memory to make it easy
; to copy it into RAM
READ_SINGLE_BLOCK:	fcb $51,0,0,0,0,$01	; CMD17	read single data block


; end initialization section
; *********************************

; **************
; command execution routines

SENDACMD:	pshy		; send prefix for application specific command
		ldy	#APP_CMD
		jsr	SENDCMD
		puly

SENDCMD:	jsr	SENDCSFF	; send command setup
		bclr	PORTD,X $20	; lower CS
		cmpy	#GO_IDLE_STATE
		beq	NOWAITFF	; skip wait for $FF when card is initialized

WAITFF:		jsr	SENDFF
		incb
		bne	WAITFF		; wait for an $FF response

NOWAITFF:	ldaa	#6		; Command count, 4 bytes data, CRC all preformatted

SENDLP:		ldab	,Y		; send command bytes
		jsr	SEND
		iny
		deca
		bne	SENDLP
		jsr	SENDFF

WAITRET:	jsr	SENDFF
		BITB	#$80
		bne	WAITRET		; wait for completion
		cmpb	#$00
		rts

; end command execution routines
; **************

; ******************
; as named, get 4 bytes

GET4:		ldaa	#4
		ldy	#BUF
GET4L:		jsr	SENDFF
		stab	,Y
		iny
		deca
		bne	GET4L
		rts

;SDFAIL2:	bra SDFAILB		; redundant stub?
; ***************
; some print routines

SDFAILD:	jsr	PHEX	; print err code in D
SDFAILB:	tba		; print err code in B
SDFAILA:	jsr	PHEX	; print err code in A
		ldy	#ERROR
		jmp	FAULT

; ****************
; card type discovery and setup

; **********************
; new style card setup subroutine

NEWCARD:	bsr	GET4		; get card info
		ldd	BUF+2
		cmpd	#$01AA		; check for 2.7-3.6 voltage accepted
		bne	SDFAILD

WAIT41:		ldy	#SD_SEND_OP_COMD_HCS	; wait until idle
		jsr	SENDACMD
		bne	WAIT41

		ldy	#READ_OCR
		jsr	SENDCMD
		bne	SDFAILB		; confirm card is working SDHC or SDXC

		bsr	GET4
		ldaa	BUF
		anda	#$40
		bne	BLOCKSD2	; determine block size, 1 or 512 bytes
		ldaa	#CTSD2			; type = D2
		bra	INITOK
BLOCKSD2:	ldaa	#CTSDBLK
INITOK:		staa	CARDTYPE		; type = D_block

		rts

; ***********************
; old style card setup subroutine

OLDCARD:	ldy	#SD_SEND_OP_COMD	; FIXME _0 check ?
		jsr	SENDACMD
		cmpb	#2
		BHS	MMC

WAIT41_0:	ldy	#SD_SEND_OP_COMD
		jsr	SENDACMD
		bne	WAIT41_0
		ldaa	#CTSD1
		staa	CARDTYPE		; type = D1
		bra	SECSIZE

MMC:		ldy	#SEND_OP_COND
		jsr	SENDCMD
		bne	MMC
		ldaa	#CTMMC
		staa	CARDTYPE		; type = MMC

SECSIZE:	ldy	#SET_BLOCKLEN		; set block length to 512
		jsr	SENDCMD
		bne	SDFAILB

		rts

; follow NEWCARD/OLDCARD initialization section

LOADER:		bsr	SENDCSFF		; select device
		ldy	#SD_READ_BLOCK		; request a sector
		jsr	SENDCMD
		bne	SDFAILB

WAITDATA:	jsr	SENDFF
		cmpb	#$FE
		bne	WAITDATA		; ready?

		ldy	#DESTINATION		; target address start
		clra

DATALOOP:	jsr	SENDFF			; transfer 512 bytes
		stab	0,Y
		jsr	SENDFF
		stab	1,Y
		iny
		iny
		deca
		bne	DATALOOP

		bsr	SENDCSFF	; wrap up - purpose unknown
		bclr	PORTD,X $20	; lower CS

		rts

; Done transfer disk to RAM destination

; exit and jump to stage 2

ALLDONE:	ldy	#INIT3		; send OK message
		jsr	STROUT

		ldy	#STAGE2DEST
		ldd	,Y
		cpd	#$6811
		bne	NOBOOT

; Jump to loader that we installed
		ldaa	CARDTYPE
		jmp	2,Y

;
; This lot must preserve A
;

SENDCSFF:	bset	PORTD,X $20
SENDFF:		ldab	#$FF

SEND:		stab	SPDR,X
SENDW:		brclr	SPSR,X $80 SENDW
		ldab	SPDR,X
		rts

; error message handling:

NOBOOT: 	ldy	#NOBMSG
FAULT:		jsr	STROUT
STOPB:		bra	STOPB

;
; Serial Output
;
PHEX:		psha		; print a hex digit in A
		lsra
		lsra
		lsra
		lsra
		bsr	HEXDIGIT
		pula
		anda	#$0F
HEXDIGIT:	cmpa	#10
		bmi	DECDIGIT
		adda	#7

DECDIGIT:	adda	#'0'			; print value in A as a numeral
CHOUT:		brclr	SCSR,X TDRE CHOUT	; print a char
		staa	SCDR,X
		rts

; print a string
STROUT:		ldaa	,Y
		beq	STRDONE
		bsr	CHOUT
		iny
		bra	STROUT
STRDONE:	rts

; end of code section

; *******************************
; Data Section

; constants

;
; SD Card Commands
;

GO_IDLE_STATE:		fcb $40,0,0,0,0,$95	; CMD0	init card
SEND_OP_COND:		fcb $41,0,0,0,0,$01	; CMD1 	Send host capacity info and init
SEND_IF_COND:		fcb $48,0,0,$01,$AA,$87	; CMD8	verify interface condition
SET_BLOCKLEN:		fcb $50,0,0,2,0,$01	; CMD16 set block length (if not SDHC or SDXC)
;READ_SINGLE_BLOCK:	fcb $51,0,0,0,0,$01	; CMD17	read single data block (const moved down in memory)
APP_CMD:		fcb $77,0,0,0,0,$01	; CMD55	escape for app specific command
READ_OCR:		fcb $7A,0,0,0,0,$01	; CMD58	read card OCR register
SD_SEND_OP_COMD:	fcb $69,0,0,0,0,$01	; ACMD41_0	Send host capacity info and init
SD_SEND_OP_COMD_HCS:	fcb $69,$40,0,0,0,$01	; ACMD41	(HCS bit set)

;READ_MULTIPLE_BLOCK:	fcb $52,0,0,0,0,$01	; CMD18	read multiple data block
;STOP_TRANSMISSION:	fcb $4C,0,0,0,0,$01	; CMD12 stop transmission of multiple blocks

INIT1:		fcc	'B:'	; indicate boot
		fcb	0
INIT3:		fcc	'S1:'	; indicate stage 1
		fcb	0
ERROR:		fcc	'E'	; error
		fcb	0
NOBMSG:		fcc	'N'	; card not present
		fcb	0

; default EEPROM storage values at end of EEPROM:

		org	NVRAMHI-1
		fcb	$A0		; RTC default calibration constant

; variables
; located in main RAM

		org	SYSVAR		; system variables block at top page of RAM
					; stack just below

CARDTYPE:	rmb	1
BUF:		rmb	4
SD_READ_BLOCK:	rmb	6
SD_RB_END:
DESTINATION:	rmb	2

		END
