include consx.inc

    .code

getxyw proc uses ebx x, y

    mov ebx,getxya(x, y)
    getxyc(x, y)
    mov ah,bl
    ret

getxyw endp

    END
