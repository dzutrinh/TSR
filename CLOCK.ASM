;*-----------------------------------------------------------------------------
;*                               CLOCK.ASM
;*-----------------------------------------------------------------------------
;* Function:	Install a removable TSR driver to display current time at
;*		the top right corner of the screen.
;*-----------------------------------------------------------------------------
;* Version 1.1
;* Coded by Trinh D.D. Nguyen
;* Copyrights (c) 2017 by Inifinty Software
;*-----------------------------------------------------------------------------
;* Notes:
;* - the time comes from the BIOS tick count (0040:006C), not the RTC
;* - drawn only in text modes 0-3 (B800h) and 7 (B000h), on the shown page
;* - install and removal in TSR.INC: the resident copy is found through
;*   INT 2Fh (multiplex) and removed only while INT 1Ch and INT 2Fh still
;*   point at it
code	segment para 'CODE'
	assume	cs:code, ds:code, es:code, ss:code
	org 100h

	;*---
	;* constants
	CLOCK_ATTR	equ	1Eh	; yellow text - blue background
	MONO_ATTR	equ	70h	; reverse video (mode 7)
	BLINK		equ	80h	; blinking (the separator)
	SEPARATOR	equ	':'
	CLOCK_LEN	equ	5	; hh:mm

	; multiplex interrupt: our ID, the reply's signature
	MPX_ID		equ	0DCh
	SIGNATURE	equ	4454h	; 'DT'

	; ticks a day (1800B0h) / minutes a day (1440) = 19663 / 18
	TICK_MUL	equ	18
	TICK_DIV	equ	19663

start:	jmp	resident

	;*---
	;* the vectors hooked (TSR.INC): vector, handler, the old one
	vec_table	label	byte
			db	1Ch
			dw	offset newint1C
	oldint1C	dd	?
			db	0FFh

;*---
;* our new interrupt 1C vector handler: the clock drawn, then the old
;* handler chained
newint1C	proc	far
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	ds
	push	es

	cld
	mov	ax, 40h			; DS = BIOS data area
	mov	ds, ax

	; text modes only: 0-3 at B800h, 7 at B000h
	mov	al, ds:[49h]		; AL = video mode
	mov	bh, CLOCK_ATTR
	mov	cx, 0B800h
	cmp	al, 7
	jne	not_mono
	mov	bh, MONO_ATTR
	mov	cx, 0B000h
	jmp	short place
not_mono:
	cmp	al, 3
	ja	done			; a graphics mode: nothing drawn

place:	mov	es, cx
	mov	di, ds:[4Eh]		; DI = the shown page's start
	mov	ax, ds:[4Ah]		; AX = columns
	sub	ax, CLOCK_LEN
	shl	ax, 1
	add	di, ax			; DI = top right, CLOCK_LEN cells

	; minutes since midnight = ticks * 18 / 19663 (the BIOS has just
	; counted this tick, so both words belong together)
	mov	cx, TICK_MUL
	mov	ax, ds:[6Ch]
	mul	cx			; DX:AX = low word * 18
	mov	si, ax
	push	dx
	mov	ax, ds:[6Eh]
	mul	cx			; AX = high word * 18 (high <= 18h)
	pop	dx
	add	dx, ax
	mov	ax, si			; DX:AX = ticks * 18
	mov	cx, TICK_DIV
	div	cx			; AX = minutes (0 - 1440)

	mov	cl, 60
	div	cl			; AL = hours, AH = minutes
	cmp	al, 24
	jb	hours_ok
	sub	al, 24
hours_ok:
	mov	cl, ah			; CL = minutes

	; hours
	aam				; AH = tens, AL = units
	add	ax, 3030h
	mov	dx, ax
	mov	ah, bh
	mov	al, dh
	stosw				; first digit
	mov	al, dl
	stosw				; second digit

	mov	ah, bh
	or	ah, BLINK
	mov	al, SEPARATOR
	stosw				; hour separator

	; minutes
	mov	al, cl
	aam
	add	ax, 3030h
	mov	dx, ax
	mov	ah, bh
	mov	al, dh
	stosw				; first digit
	mov	al, dl
	stosw				; second digit

done:	pop	es
	pop	ds
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax

	jmp	dword ptr cs:[oldint1C]
newint1C	endp

	include	tsr.inc

	msg_name	db	'Clock driver$'
	msg_intro	db	'Clock driver for DOS - v1.1',13,10
			db	'Coded by Trinh D.D. Nguyen',13,10
			db	13,10
			db	'Run this program again to uninstall it.',13,10
			db	'$'

code	ends
	end	start
