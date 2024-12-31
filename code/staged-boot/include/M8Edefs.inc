; M8Edefs.inc
; 2024-12-12	create KW

; Expected memory usage:
; NVRAMLO	46k workspace
; NVRAMHI	14k workspace
; IRAMND	768 byte scratchpad
; VROMBS	1k virtual ROM (firmware in NVRAM)

;***************
;   SYSTEM HARDWARE SPECIFIC EQUATES   *
;***************

NVRAMLO		equ	$0000	; start NVRAM
EEPROM		equ	$B600	; 512 byte on chip EEPROM
NVRAMHI		equ	$B800	; continuation of NVRAM

REGBAS		equ	$F000	; start of MCU registers (X addressed usually)
IRAMBS		equ	$F040	; start of CPU internal ram
IRAMND		equ	$F100	; continuation of NVRAM

BUSIO		equ	$F400	; M8 bus I/O
MEMLAT		equ	$F800	; memory paging latch
VROMBS		equ	$FC00	; start of 1k virtual rom
