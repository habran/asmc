; _bsrnd() - Bit Scan Reverse
;
; Scans source operand for first bit set. If a bit is found
; set the index to first set bit + 1 is returned.
;
include intn.inc

.code

_bsrnd proc uses esi ebx o:ptr, n:dword

    mov esi,o
    mov ecx,n
    xor eax,eax
    mov ebx,ecx
    shl ebx,5
    .while ecx
        sub ebx,32
        mov edx,[esi+ecx*4-4]
        bsr edx,edx
        .ifnz
            lea eax,[ebx+edx+1]
            .break
        .endif
        dec ecx
    .endw
    ret

_bsrnd endp

    end
