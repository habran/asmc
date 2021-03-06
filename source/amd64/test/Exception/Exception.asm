include stdio.inc
include stdlib.inc
include signal.inc

    .code

GeneralFailure PROC signo
    .if ecx != SIGTERM
        printf("EXCEPTION ")
        mov eax,signo
        .switch eax
          .case SIGINT
            printf("SIGINT: interrupt\n")
            .endc
          .case SIGILL
            printf("SIGILL: illegal instruction - invalid function ime\n")
            .endc
          .case SIGFPE
            printf("SIGFPE: floating point exception\n")
            .endc
          .case SIGSEGV
            printf("SIGSEGV: segment violation\n")
            .endc
          .case SIGTERM
            printf("SIGTERM: Software termination signal from kill\n")
            .endc
          .case SIGABRT
            printf("SIGABRT: abnormal termination triggered by abort call\n")
            .endc
        .endsw
        mov rax,pCurrentException
        PrintContext(
            [rax].EXCEPTION_POINTERS.ContextRecord,
            [rax].EXCEPTION_POINTERS.ExceptionRecord )
    .endif
    exit(1)
    ret
GeneralFailure ENDP

main proc frame:ExceptionHandler

    .endprolog

    lea r10,GeneralFailure

    signal(SIGINT,   r10) ; interrupt
    signal(SIGILL,   r10) ; illegal instruction - invalid function image
    signal(SIGFPE,   r10) ; floating point exception
    signal(SIGSEGV,  r10) ; segment violation
    signal(SIGTERM,  r10) ; Software termination signal from kill
    signal(SIGABRT,  r10) ; abnormal termination triggered by abort call

    mov rcx,-1
    mov rdx,2
    xor rax,rax
    mov [rax],al

toend:
    ret

main endp

    end
