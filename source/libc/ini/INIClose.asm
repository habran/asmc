include alloc.inc
include ini.inc

    .code

    assume esi:ptr S_INI
    assume edi:ptr S_INI

INIClose proc uses esi edi ebx ini:LPINI

    mov esi,ini

    .while esi

        .if [esi].entry

            free([esi].entry)
        .endif

        mov edi,[esi].value
        .while edi

            .if [edi].entry

                free([edi].entry)
            .endif

            mov eax,edi
            mov edi,[edi].next
            free(eax)
        .endw

        mov eax,esi
        mov esi,[esi].next
        free(eax)
    .endw
    ret

INIClose endp

    END
