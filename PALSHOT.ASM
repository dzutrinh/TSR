;******************************************************************************
;*				  PALSHOT.ASM
;*-----------------------------------------------------------------------------
;* Function:	Capture the current palette and store it into a file.
;* 		The file is named: PALSHOT.PAL and it will be put in the
;*		current disk and directory
;*-----------------------------------------------------------------------------
;* Note:	This program works in every video mode of a VGA or MCGA
;*		In Windows 3.x, 9x, this program does not have any effectives
;*		The resident part is in SNAP.INC, install and removal in
;*		TSR.INC.
;*-----------------------------------------------------------------------------
;* Written by Trinh D.D. Nguyen
;* Copyright (c) 1998-2005 by Infinity Software
;******************************************************************************

;*-- CAPTURED PALETTE FILE STRUCTURE:
;* Red/Green/Blue/.../Red/Green/Blue (256 DAC entries, 768 bytes)

	F_CREAT		equ	3Ch
	F_WRITE		equ	40h
	F_CLOSE		equ	3Eh
	F_DELETE	equ	41h

	MPX_ID		equ	0DEh	; INT 2Fh multiplex ID
	SIGNATURE	equ	5053h	; its reply

code	segment	para 'CODE'
	assume	cs:code, ds:code, es:code, ss: code
	org	100h

begin:	jmp	resident

	; file name for storing the palette
	filename	db	'PALSHOT.PAL', 0
	filehandle	dw	(?)	; palette file handle

	; variable for storing the palette
	palette		db	3 * 256 dup (0)

;*---
;* the DAC to PALSHOT.PAL; CF set on a failure (and no file left)
capture		proc	near
	mov	di, offset palette
	call	read_dac

	mov	ah, F_CREAT		; file open
	xor	cx, cx			; normal attribute
	mov	dx, offset filename
	int	21h
	jc	cap_fail		; error on opened
	mov	filehandle, ax		; store file handle

	mov	ah, F_WRITE		; write palette into file
	mov	bx, filehandle
	mov	cx, 768
	mov	dx, offset palette
	int	21h
	jc	cap_bad
	cmp	ax, 768
	jne	cap_bad

	mov	ah, F_CLOSE		; close file
	mov	bx, filehandle
	int	21h
	jc	cap_gone
	clc
	ret

cap_bad:
	mov	ah, F_CLOSE		; a short file: closed and deleted
	mov	bx, filehandle
	int	21h
cap_gone:
	mov	ah, F_DELETE
	mov	dx, offset filename
	int	21h
cap_fail:
	stc
	ret
capture		endp

	include	snap.inc
	include	tsr.inc

	msg_name	db	'PALSHOT.COM$'
	msg_intro	db	13,10
			db	'PALSHOT.COM - Snap the current palette into a file',13,10
			db	'Coded by Trinh D.D. Nguyen',13,10
			db	'(c) 1998-2015 by Infinity Software',13,10
			db	13,10
			db	'Hit F12 to snap a palette.',13,10
			db	'Palette shot will store in the file PALSHOT.PAL.',13,10
			db	'Next call of program will remove it from memory.',13,10
			db	13,10,'$'

	legalcopyright	db	13, 10
			db	'PALETTE CAPTURE'

code	ends
	end	begin
