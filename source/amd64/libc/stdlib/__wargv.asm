include stdlib.inc
include crtl.inc
include winbase.inc

.data
__wargv	 dq 0
_wpgmptr dq 0

.code

Install proc private
    mov __wargv,setwargv(addr __argc, GetCommandLineW())
    mov rax,[rax]
    mov _wpgmptr,rax
    ret
Install endp

pragma_init Install, 4

    end
