include string.inc

	.code

wcschr	PROC USES edi s1:ptr wchar_t, w:wchar_t
	xor	eax,eax
	mov	edi,s1
@@:
	mov	ax,[edi]
	test	ax,ax
	jz	@F
	add	edi,2
	cmp	ax,word ptr w
	jne	@B
	mov	eax,edi
	sub	eax,2
@@:
	ret
wcschr	ENDP

	END
