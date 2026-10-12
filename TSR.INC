;******************************************************************************
;*				    TSR.INC
;*-----------------------------------------------------------------------------
;* Install and removal of the TSRs in this folder (CLOCK, CAP, PALSHOT),
;* included after their resident part.
;* - INT 2Fh (multiplex) answers the install check: AH = MPX_ID, AL = 0 is
;*   answered with AL = FFh, BX = SIGNATURE, ES = the resident copy.
;* - A second run removes the resident copy, only while every vector it
;*   hooked still points at it; the old vectors come from the resident
;*   copy.
;* - The environment is freed at install.
;*
;* The program including it defines, before it (resident):
;*   MPX_ID, SIGNATURE	its multiplex ID and reply
;*   vec_table		the vectors it hooks, an entry each: db vector,
;*			dw offset handler, dd the old vector (its handler
;*			chains through it); ended by db 0FFh
;*   NEED_DOS31		(optional) DOS 3.1 or later required
;*   NEED_VGA		(optional) a VGA or MCGA required
;*   NEED_INIT		(optional) init, a near proc, called before hooking
;* and after it (not resident):
;*   msg_name		'NAME$', put before every message
;*   msg_intro		the install banner, '$' ended
;******************************************************************************

	VEC_ENTRY	equ	7	; db vector, dw handler, dd old

	oldint2F	dd	?

;*---
;* multiplex: the install check answered, the rest chained
newint2F	proc	far
	cmp	ah, MPX_ID
	jne	chain2F
	or	al, al
	jne	chain2F
	mov	al, 0FFh
	mov	bx, SIGNATURE
	push	cs
	pop	es
	iret
chain2F:
	jmp	dword ptr cs:[oldint2F]
newint2F	endp

;*---
;* main program (not resident)
resident:
ifdef	NEED_DOS31
	; DOS 3.1 or later
	mov	ah, 30h
	int	21h
	cmp	al, 3
	jb	old_dos
	ja	dos_ok
	cmp	ah, 10
	jae	dos_ok
old_dos:
	mov	dx, offset msg_nodos
	jmp	say_exit
dos_ok:
endif
ifdef	NEED_VGA
	; a VGA or MCGA
	mov	ax, 1A00h
	int	10h
	cmp	al, 1Ah
	je	vga_ok
	mov	dx, offset msg_novga
	jmp	say_exit
vga_ok:
endif
	; installed already? ask through the multiplex interrupt
	mov	ax, MPX_ID * 256	; AH = MPX_ID, AL = 0
	xor	bx, bx
	int	2Fh
	cmp	al, 0FFh
	jne	not_there
	cmp	bx, SIGNATURE
	je	remove_it
not_there:
	jmp	install_it

remove_it:
	; ES = the resident copy: removed only while nothing has hooked
	; its vectors since
	mov	bp, es
	mov	al, 2Fh
	mov	dx, offset newint2F
	call	ours
	jne	cannot
	mov	si, offset vec_table
check_vec:
	mov	al, [si]
	cmp	al, 0FFh
	je	restore
	mov	dx, [si + 1]
	call	ours
	jne	cannot
	add	si, VEC_ENTRY
	jmp	short check_vec

restore:
	; the vectors the resident copy saved
	mov	es, bp
	mov	si, offset vec_table
restore_vec:
	mov	al, [si]
	cmp	al, 0FFh
	je	restore_2F
	push	ds
	lds	dx, es:[si + 3]
	mov	ah, 25h
	int	21h
	pop	ds
	add	si, VEC_ENTRY
	jmp	short restore_vec
restore_2F:
	push	ds
	lds	dx, es:[oldint2F]
	mov	ax, 252Fh
	int	21h
	pop	ds

	; its memory (the environment went at install)
	mov	ah, 49h
	int	21h
	mov	dx, offset msg_removed
	jmp	short say_exit
cannot:
	mov	dx, offset msg_busy
say_exit:
	call	say
	int	20h

install_it:
ifdef	NEED_INIT
	call	init
endif
	mov	si, offset vec_table
hook_vec:
	mov	al, [si]
	cmp	al, 0FFh
	je	hook_2F
	mov	dx, [si + 1]
	lea	di, [si + 3]
	call	hook
	add	si, VEC_ENTRY
	jmp	short hook_vec
hook_2F:
	mov	al, 2Fh
	mov	dx, offset newint2F
	mov	di, offset oldint2F
	call	hook

	; the environment is not needed
	mov	es, ds:[2Ch]
	mov	ah, 49h
	int	21h
	mov	word ptr ds:[2Ch], 0

	mov	ah, 09h
	mov	dx, offset msg_intro
	int	21h
	mov	dx, offset msg_installed
	call	say

	mov	dx, offset resident	; terminate stay and resident
	int	27h

;*---
;* ZF set when vector AL points at BP:DX
ours		proc	near
	push	es
	push	bx
	mov	ah, 35h
	int	21h
	cmp	bx, dx
	jne	ours1
	mov	bx, es
	cmp	bx, bp
ours1:	pop	bx
	pop	es
	ret
ours		endp

;*---
;* vector AL kept at DS:DI, then pointed at DS:DX
hook		proc	near
	push	ax
	push	es
	mov	ah, 35h
	int	21h
	mov	[di], bx
	mov	[di + 2], es
	pop	es
	pop	ax
	mov	ah, 25h
	int	21h
	ret
hook		endp

;*---
;* the program's name, then the message at DX
say		proc	near
	push	dx
	mov	ah, 09h
	mov	dx, offset msg_name
	int	21h
	pop	dx
	mov	ah, 09h
	int	21h
	ret
say		endp

	msg_installed	db	' installed.',13,10,'$'
	msg_removed	db	' removed!',13,10,'$'
	msg_busy	db	' cannot be removed: another program has hooked',13,10
			db	'its interrupts since. Remove that first.',13,10,'$'
ifdef	NEED_DOS31
	msg_nodos	db	' needs DOS 3.1 or later.',13,10,'$'
endif
ifdef	NEED_VGA
	msg_novga	db	' needs a VGA or MCGA.',13,10,'$'
endif
