include stdio.inc

	.code

printf	proc c format:LPSTR, argptr:VARARG
	_stbuf( addr stdout )
	push	eax
	_output( addr stdout, format, addr argptr )
	pop	edx
	push	eax
	_ftbuf( edx, addr stdout )
	pop	eax
	ret
printf	endp

	END
