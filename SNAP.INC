;******************************************************************************
;*				    SNAP.INC
;*-----------------------------------------------------------------------------
;* The F12 part of CAP and PALSHOT (resident; included before TSR.INC).
;* - F12 (seen at the keyboard, INT 09h) only asks for a capture; the key
;*   is taken back out of the BIOS buffer, held down it counts once.  The
;*   capture is made
;*   from the timer (INT 08h) or DOS idle (INT 28h) once DOS and the disk
;*   BIOS (INT 13h) are free, on our own stack and PSP, with Ctrl-C ignored
;*   and critical errors failed.  0050:0000 (the BIOS's Print Screen
;*   status byte) holds the capture's: 1 busy, 0 done, FFh failed.
;* - Needs DOS 3.1 or later and a VGA or MCGA.
;*
;* The program including it defines, before it:
;*   capture		near proc: DS = ES = CS, interrupts on; CF set on a
;*			failure
;******************************************************************************

	NEED_DOS31	equ	1	; for TSR.INC
	NEED_VGA	equ	1
	NEED_INIT	equ	1

	KEY_F12		equ	58h	; F12's scan code (pressed; +80h released)

	;*---
	;* the vectors hooked (TSR.INC): vector, handler, the old one
	vec_table	label	byte
			db	09h
			dw	offset newint09
	oldint09	dd	?
			db	13h
			dw	offset newint13
	oldint13	dd	?
			db	28h
			dw	offset newint28
	oldint28	dd	?
			db	08h
			dw	offset newint08
	oldint08	dd	?
			db	0FFh

	;*---
	;* resident variables
	oldint23	dd	?	; while capturing
	oldint24	dd	?
	indos		dd	?	; InDOS; the byte before: critical error
	pending		db	0	; F12 pressed, capture not made
	f12_down	db	0	; F12 held
	busy		db	0	; capturing
	in_disk		db	0	; inside INT 13h
	save_ss		dw	?
	save_sp		dw	?
	their_psp	dw	?

	snap_stack	db	512 dup (?)
	stack_top	equ	this word

;*---
;* keyboard: the key handled first; F12 pressed asks for a capture, the
;* key it put in the BIOS buffer taken back
newint09	proc	far
	push	ax
	push	bx
	push	ds
	mov	ax, 40h
	mov	ds, ax
	mov	bx, ds:[1Ch]		; BX = the buffer's tail before the key
	in	al, 60h			; AL = the key
	pushf
	call	dword ptr cs:[oldint09]
	cmp	al, KEY_F12
	jne	not_f12
	mov	ds:[1Ch], bx		; F12 out of the buffer
	cmp	cs:f12_down, 0
	jne	exit09			; held: repeats ignored
	mov	cs:f12_down, 1
	cmp	cs:pending, 0
	jne	exit09
	cmp	cs:busy, 0
	jne	exit09
	mov	cs:pending, 1
	mov	byte ptr ds:[100h], 1	; 0050:0000: capture in progress
	jmp	short exit09
not_f12:
	cmp	al, KEY_F12 + 80h
	jne	exit09
	mov	cs:f12_down, 0		; released
exit09:	pop	ds
	pop	bx
	pop	ax
	iret
newint09	endp

;*---
;* timer: the tick first, then the capture if DOS is free
newint08	proc	far
	pushf
	call	dword ptr cs:[oldint08]
	cmp	cs:pending, 0
	je	exit08
	cmp	cs:busy, 0
	jne	exit08
	cmp	cs:in_disk, 0
	jne	exit08
	push	ds
	push	si
	lds	si, cs:[indos]
	cmp	byte ptr [si], 0	; DOS not running
	jne	test08
	cmp	byte ptr [si - 1], 0	; no critical error
test08:	pop	si
	pop	ds
	jne	exit08
	call	do_work
exit08:	iret
newint08	endp

;*---
;* DOS idle (waiting for a key inside INT 21h): DOS calls allowed
newint28	proc	far
	pushf
	call	dword ptr cs:[oldint28]
	cmp	cs:pending, 0
	je	exit28
	cmp	cs:busy, 0
	jne	exit28
	cmp	cs:in_disk, 0
	jne	exit28
	push	ds
	push	si
	lds	si, cs:[indos]
	cmp	byte ptr [si], 1	; only the idle call itself
	ja	test28
	cmp	byte ptr [si - 1], 0
test28:	pop	si
	pop	ds
	jne	exit28
	call	do_work
exit28:	iret
newint28	endp

;*---
;* disk BIOS: counted while inside
newint13	proc	far
	sti
	inc	cs:in_disk
	pushf
	call	dword ptr cs:[oldint13]
	pushf
	dec	cs:in_disk
	popf
	retf	2			; its flags (CF) to the caller
newint13	endp

;*---
;* while capturing: Ctrl-C ignored, a critical error failed
no_break	proc	far
	iret
no_break	endp

fail_error	proc	far
	mov	al, 3
	iret
fail_error	endp

;*---
;* the capture, from INT 08h or INT 28h (interrupts off): our stack, PSP,
;* INT 23h and 24h around it; every register kept
do_work		proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	bp
	push	ds
	push	es
	mov	cs:busy, 1
	mov	cs:pending, 0
	mov	cs:save_ss, ss
	mov	cs:save_sp, sp
	mov	ax, cs
	mov	ss, ax
	mov	sp, offset stack_top
	sti
	mov	ds, ax
	mov	es, ax

	mov	ah, 51h
	int	21h
	mov	their_psp, bx
	mov	ah, 50h
	mov	bx, cs
	int	21h
	mov	ax, 3523h
	int	21h
	mov	word ptr oldint23, bx
	mov	word ptr oldint23 + 2, es
	mov	ax, 3524h
	int	21h
	mov	word ptr oldint24, bx
	mov	word ptr oldint24 + 2, es
	push	cs
	pop	es
	mov	dx, offset no_break
	mov	ax, 2523h
	int	21h
	mov	dx, offset fail_error
	mov	ax, 2524h
	int	21h

	cld
	call	capture
	mov	al, 0
	jnc	work_done
	mov	al, 0FFh
work_done:
	push	ds
	mov	bx, 50h
	mov	ds, bx
	mov	byte ptr ds:[0], al	; the capture's status
	pop	ds

	push	ds
	lds	dx, oldint24
	mov	ax, 2524h
	int	21h
	pop	ds
	push	ds
	lds	dx, oldint23
	mov	ax, 2523h
	int	21h
	pop	ds
	mov	ah, 50h
	mov	bx, their_psp
	int	21h

	cli
	mov	ss, save_ss
	mov	sp, save_sp
	mov	cs:busy, 0
	pop	es
	pop	ds
	pop	bp
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
do_work		endp

;*---
;* the 256 DAC entries to ES:DI (768 bytes) through the ports; the DAC's
;* write index put back for a program that was setting colours
read_dac	proc	near
	push	ax
	push	cx
	push	dx
	mov	dx, 3C8h
	in	al, dx
	mov	ah, al			; AH = their write index
	mov	dx, 3C7h
	xor	al, al
	out	dx, al
	mov	dx, 3C9h
	mov	cx, 768
read_dac1:
	in	al, dx
	stosb
	loop	read_dac1
	mov	dx, 3C8h
	mov	al, ah
	out	dx, al
	pop	dx
	pop	cx
	pop	ax
	ret
read_dac	endp

;*---
;* at install (TSR.INC, before the vectors are hooked): where InDOS is
init		proc	near
	push	es
	mov	ah, 34h
	int	21h			; ES:BX = InDOS
	mov	word ptr indos, bx
	mov	word ptr indos + 2, es
	pop	es
	ret
init		endp
