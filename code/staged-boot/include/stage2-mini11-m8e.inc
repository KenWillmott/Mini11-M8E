;
;	Mini 11/M8E Bootstrap
;
; Multi stage boot system. This is stage #2.
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
; 2024-12-12 Change load destination and size to 512 bytes at $FC00

		; MC68HC11A1 register definitions:
		include	../include/HC11defs.inc
		; M8E hardware specific definitions:
		include	../include/M8Edefs.inc
		; first stage boot loader definitions:
		include	../include/miniboot-mini11-m8e.inc

VIRTUALROM	equ	false	; include vectors in upper RAM?

; assume stack and variables at internal RAM just below EEPROM,
; share with stage 1
; stage 2 resides on sector 0 of the SD

STKBAS		equ	SYSVAR-1

; SD status codes
CTMMC		equ	1
CTSD2		equ	2
CTSDBLK		equ	3
CTSD1		equ	4

; alias for read sector block number

BLOCK_NUM	equ	SD_READ_BLOCK+3

; shared variables
; located in main RAM

		org	SYSVAR		; system variables block at top page of RAM
					; stack just below

CARDTYPE:	rmb	1
BUF:		rmb	4
		rmb	6		; SD_READ_BLOCK imported
SD_RB_END:
		rmb	2		; DESTINATION imported

; local variables

BLOCK_COUNT:	rmb	1



; stage 2 load address is above internal RAM
; but it will be the first sector on the boot SD
; (stage one is in EEPROM)

		org	0
		phase	IRAMND

		fdb	$6811	; own valid code signature

; turn on status LED
START:		ldaa	#$80
		staa	PORTA,X
		bset	PACTL,X $80

; start up messages

SDBOOT:		ldy	#INIT1		; announce stage 2
		jsr	STROUT

	if	VIRTUALROM == true
; first target address is 1k virtual ROM above paging latch
; for now we are not using it, CPU vectors will be installed later
		ldd	#VROMBS
		std	DESTINATION
		inc	BLOCK_NUM+1	; skip over stage 2 at sector 0 on SD
		ldaa	#2		; 2 blocks = 1k VROM size
		staa	BLOCK_COUNT
		jsr	GET_SECTORS
	endif

; second target address is 14k upper RAM workspace
		ldd	#NVRAMHI
		std	DESTINATION
		inc	BLOCK_NUM+1		; skip over stage 1,2 at sector 0,1 on SD
;		ldaa	#REGBAS-NVRAMHI/512	; transfer to fill upper RAM
		ldaa	#$1c		; hard coded to avoid phase sync error
		staa	BLOCK_COUNT
		jsr	GET_SECTORS

; Done transfer disk to RAM destination

		ldy	#INIT2		; send OK message
		jsr	STROUT

		jsr	SENDCSFF	; purpose unknown
		bclr	PORTD,X $20	; lower CS

		ldy	#DESTINATION
		ldd	,Y
		cpd	#$6811
		bne	NOBOOT

; Jump to program that we installed
		ldaa	CARDTYPE
		jmp	2,Y


; end initialization section
; *********************************

; **************
; support routines

; get one sector
; on entry, block number is set, number of blocks is on stack
GET_SECTORS:	jsr	LOADER		; fetch a sector
		inc	BLOCK_NUM+1	; point to next sector
		cmpa	BLOCK_COUNT
		bne	GET_SECTORS	; more sectors to fetch?
		rts

; end support routines
; **************

; ***************
; some print routines

SDFAILD:	jsr	PHEX	; print err code in D
SDFAILB:	tba		; print err code in B
SDFAILA:	jsr	PHEX	; print err code in A
		rts

; error message handling:

NOBOOT: 	ldy	#NOBMSG
FAULT:		jsr	STROUT
STOPB:		bra	STOPB

; end of code section

; *******************************
; Data Section

; constants

INIT1:		fcc	'S2:'
		fcb	0
INIT2:		fcc	'OK'
		fcb	$0d, $0a, 0
NOBMSG:		fcc	'S3 data not found'
		fcb	0

; end second stage code
; ***********************

		dephase

		END
