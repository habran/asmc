include consx.inc

	.code

wcputs	PROC USES ecx edx esi edi p:PVOID, l, max, string:LPSTR
	mov	edi,p
	movzx	edx,BYTE PTR l
	add	edx,edx
	movzx	ecx,WORD PTR max
	mov	ah,ch
	mov	ch,[edi+1]
	and	ch,0F0h
	.if	ch == at_background[B_Menus]
		or	ch,at_foreground[F_MenusKey]
	.elseif ch == at_background[B_Dialog]
		or	ch,at_foreground[F_DialogKey]
	.else
		xor	ch,ch
	.endif
	mov	esi,string
	call	__wputs
	ret
wcputs	ENDP

	END