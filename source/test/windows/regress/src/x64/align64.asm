include windows.inc

	.code

	mov	al,TYPE_ALIGNMENT(BYTE)
	mov	bl,TYPE_ALIGNMENT(WORD)
	mov	cl,TYPE_ALIGNMENT(DWORD)
	mov	dl,TYPE_ALIGNMENT(QWORD)

	mov	al,PROBE_ALIGNMENT(BYTE)
	mov	bl,PROBE_ALIGNMENT(WORD)
	mov	cl,PROBE_ALIGNMENT(DWORD)
	mov	dl,PROBE_ALIGNMENT(QWORD)

	END
