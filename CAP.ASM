;******************************************************************************
;*				    CAP.ASM
;*-----------------------------------------------------------------------------
;* Function:	Capture an image and store it into a file.
;* 		The files are named SNAP0000.CAP, SNAP0001.CAP, ... (the first
;*		number not used yet) and put in the current disk and directory
;*-----------------------------------------------------------------------------
;* Note:	This program works only in VGA/MCGA 320x200, 256 colors (mode
;*		13h, not mode X) and in text modes (0-3, 7; any rows), the
;*		page being shown.
;*		In Windows 3.x, 9x, this program does not have any effectives
;*              due to the fact that the keyboard is already hooked by OS.
;*		The resident part is in SNAP.INC, install and removal in
;*		TSR.INC.
;*-----------------------------------------------------------------------------
;* Written by Trinh D.D. Nguyen
;* Copyright (c) 1998-2017 by Infinity Software
;******************************************************************************

;*-- CAPTURED IMAGE FILE STRUCTURE:
;* First part	: 64000 bytes of image data in graphic mode or
;*		  columns x rows x 2 bytes of screen data in text mode
;*		  (4000 for 80x25)
;* Second part	: 768 bytes of palette data; in text mode the 16 colors as
;*		  shown, at the DAC entries the default palette registers use
;* Total	: 64768 bytes for graphic mode or
;*		  4768 bytes for 80x25 text mode

	F_CREAT_NEW	equ	5Bh
	F_WRITE		equ	40h
	F_CLOSE		equ	3Eh
	F_DELETE	equ	41h
	E_EXISTS	equ	50h

	MPX_ID		equ	0DDh	; INT 2Fh multiplex ID
	SIGNATURE	equ	4350h	; its reply

code	segment	para 'CODE'
	assume	cs:code, ds:code, es:code, ss: code
	org	100h

begin:	jmp	resident

	; file name for storing the captured image: SNAPnnnn.CAP
	filename	db	'SNAP0000.CAP', 0
	next_num	dw	0	; the number tried first
	filehandle	dw	(?)	; image file handle

	; what is captured
	vram_seg	dw	(?)
	vram_off	dw	(?)
	vram_len	dw	(?)
	text_mode	db	(?)

	; variable for storing the palette
	palette		db	3 * 256 dup (0)
	pal_regs	db	17 dup (0)	; 16 palette registers, border
	shown		db	3 * 16 dup (0)	; the 16 text colors as shown
	; the DAC entries of the default palette registers (mode 3)
	text_dac	db	00h, 01h, 02h, 03h, 04h, 05h, 14h, 07h
			db	38h, 39h, 3Ah, 3Bh, 3Ch, 3Dh, 3Eh, 3Fh

;*---
;* the screen and palette to a new SNAPnnnn.CAP; CF set on a failure
capture		proc	near
	push	ds
	mov	ax, 40h			; DS = BIOS data area
	mov	ds, ax
	mov	al, ds:[49h]		; AL = video mode
	cmp	al, 13h
	je	cap_vga
	mov	bx, 0B000h
	cmp	al, 7
	je	cap_text
	mov	bx, 0B800h
	cmp	al, 3
	jbe	cap_text
	pop	ds
	stc				; not a mode we capture
	ret

cap_text:
	mov	ax, ds:[4Ah]		; columns
	mov	cl, ds:[84h]		; rows - 1
	xor	ch, ch
	inc	cx
	mul	cx
	shl	ax, 1			; AX = bytes on a page
	mov	dx, ds:[4Eh]		; DX = the shown page's start
	pop	ds
	mov	vram_seg, bx
	mov	vram_off, dx
	mov	vram_len, ax
	mov	text_mode, 1
	jmp	short cap_pal

cap_vga:
	pop	ds
	; chain-4 (sequencer register 4, bit 3) or it is mode X: not one
	; 320x200 picture at A000h; their sequencer index put back
	mov	dx, 3C4h
	in	al, dx
	mov	ah, al
	mov	al, 4
	out	dx, al
	inc	dx
	in	al, dx
	dec	dx
	xchg	al, ah
	out	dx, al
	test	ah, 8
	jnz	cap_linear
	stc
	ret
cap_linear:
	mov	vram_seg, 0A000h
	mov	vram_off, 0
	mov	vram_len, 64000
	mov	text_mode, 0

cap_pal:
	mov	di, offset palette
	call	read_dac
	cmp	text_mode, 0
	je	cap_name
	call	text_colors

cap_name:
	; a new file: the first number not used yet
	mov	ax, next_num
	cmp	ax, 10000
	jae	cap_fail		; SNAP9999.CAP was the last
	call	set_number
	mov	ah, F_CREAT_NEW		; fails when the file exists
	xor	cx, cx			; normal attribute
	mov	dx, offset filename
	int	21h
	jnc	cap_made
	cmp	ax, E_EXISTS
	jne	cap_fail
	inc	next_num
	jmp	short cap_name
cap_fail:
	stc
	ret

cap_made:
	mov	filehandle, ax		; store file handle
	inc	next_num

	mov	ah, F_WRITE		; write image data into file
	mov	bx, filehandle
	mov	cx, vram_len
	mov	dx, vram_off
	push	ds
	mov	ds, vram_seg
	int	21h
	pop	ds
	jc	cap_bad
	cmp	ax, vram_len
	jne	cap_bad

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
	stc
	ret
capture		endp

;*---
;* AX (0 - 9999) as the file name's four digits
set_number	proc	near
	mov	di, offset filename + 7
	mov	cx, 4
	mov	bx, 10
set_number1:
	xor	dx, dx
	div	bx
	add	dl, '0'
	mov	[di], dl
	dec	di
	loop	set_number1
	ret
set_number	endp

;*---
;* text mode: the 16 attribute colors as the screen shows them (palette
;* registers, color page, DAC) put at the DAC entries the default palette
;* registers use, so a viewer setting only the DAC shows them right
text_colors	proc	near
	mov	ax, 1009h		; ES:DX = the palette registers
	mov	dx, offset pal_regs
	int	10h
	mov	ax, 101Ah		; BL = paging mode, BH = color page
	int	10h
	mov	dx, bx			; DL = paging mode, DH = color page

	xor	bx, bx			; BX = attribute color
	mov	di, offset shown
text_colors1:
	mov	al, pal_regs[bx]
	mov	ah, dh
	or	dl, dl
	jnz	text_colors2
	and	al, 3Fh			; 4 pages of 64
	mov	cl, 6
	jmp	short text_colors3
text_colors2:
	and	al, 0Fh			; 16 pages of 16
	mov	cl, 4
text_colors3:
	shl	ah, cl
	add	al, ah			; AL = its DAC entry
	xor	ah, ah
	mov	si, ax
	add	si, ax
	add	si, ax
	mov	al, palette[si]
	mov	[di], al
	mov	al, palette[si + 1]
	mov	[di + 1], al
	mov	al, palette[si + 2]
	mov	[di + 2], al
	add	di, 3
	inc	bx
	cmp	bx, 16
	jb	text_colors1

	xor	bx, bx
	mov	si, offset shown
text_colors4:
	mov	al, text_dac[bx]
	xor	ah, ah
	mov	di, ax
	add	di, ax
	add	di, ax
	mov	al, [si]
	mov	palette[di], al
	mov	al, [si + 1]
	mov	palette[di + 1], al
	mov	al, [si + 2]
	mov	palette[di + 2], al
	add	si, 3
	inc	bx
	cmp	bx, 16
	jb	text_colors4
	ret
text_colors	endp

	include	snap.inc
	include	tsr.inc

	; data
	msg_name	db	'CAP.COM$'
	msg_intro	db	13,10
			db	'CAP.COM - Snap the screen into a file',13,10
			db	'Coded by Trinh D.D. Nguyen',13,10
			db	'(c) 1998-2015 by Infinity Software',13,10
			db	13,10
			db	'Hit F12 to take a screen shot.',13,10
			db	'Screen shots are stored in SNAP0000.CAP, SNAP0001.CAP, ...',13,10
			db	'Next program call will remove it from memory.',13,10
			db	13,10,'$'

	legalcopyright	db	13, 10
			db	'IMAGE CAPTURE v1.0',13,10
			db	'FREE FOR NON-COMMERCIAL USES'

code	ends
	end	begin
