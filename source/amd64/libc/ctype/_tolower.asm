include ctype.inc

	.code

	OPTION PROLOGUE:NONE, EPILOGUE:NONE

_tolower PROC char:SINT

	movzx	eax,BYTE PTR [esp+4]
	sub	al,'A'+'a'
	ret	4

_tolower ENDP

	END

