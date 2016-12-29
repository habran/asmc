include direct.inc
include errno.inc

	.code

_rmdir	PROC directory:LPSTR

	.if	!RemoveDirectoryA( directory )

		RemoveDirectoryW( __allocwpath( directory ) )
	.endif

	.if	!eax
		osmaperr()
	.else
		xor eax,eax
	.endif
	ret

_rmdir	ENDP

	END