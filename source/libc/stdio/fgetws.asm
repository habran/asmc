include stdio.inc

	.code

	ASSUME	ebx:ptr _iobuf

fgetws	PROC USES esi edi ebx buf:LPWSTR, count:SINT, fp:LPFILE

	mov edi,buf
	mov esi,count
	mov ebx,fp
	xor eax,eax

	.repeat
		.break .ifs esi <= eax

		dec esi
		.for : esi: esi--

			dec [ebx]._cnt
			.ifl
				_filwbuf(ebx)
				.if eax == -1

					.break .if edi != buf

					xor eax,eax
					.break(1)
				.endif
			.else
				mov eax,[ebx]._ptr
				add [ebx]._ptr,2
				mov ax,[eax]
			.endif
			stosw
			.break .if ax == 10
		.endf
		xor eax,eax
		stosw
		or eax,buf
	.until	1
	ret

fgetws	ENDP

	END
