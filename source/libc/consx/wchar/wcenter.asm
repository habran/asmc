include consx.inc

	.code

wcenter PROC USES eax ecx edx esi edi wp:PVOID, l, string:LPSTR
	__wcpath( wp, l, string )
	.if ecx
		mov edi,wp
		mov esi,edx
		.if edi == eax
			mov eax,l
			sub eax,ecx
			and al,not 1
			add eax,edi
		.endif
		mov edi,eax
		.repeat
			mov al,[esi]
			mov [edi],al
			add edi,2
			add esi,1
		.untilcxz
	.endif
	ret
wcenter ENDP

	END