include string.inc
include stdio.inc
include alloc.inc
include winbase.inc

TEST_OVERLAP	equ 1
strnicmp	equ <_strnicmp>

.data
ALIGN	16
str_1	db 4096-3 dup('x'),"xxx",0
ALIGN	16
str_2	db 4096-3 dup('x'),"xxz",0
ALIGN	16
str_3	db 64 dup('x'),"xxx",0
abcd	db "abcd",0
abc1	db "abC",0
abc2	db "Abc",0,"xx"
arg_1	dd str_1
arg_2	dd str_2
arg_3	dd 4096

s1	db "Xxxxxxxxxxxxxxxabcxxxx",0
s2	db "xxxxxxxxxxxxxxxabcdxxx",0
s3	db "xxxxxxxxxxxxxxxAbcxxxx",0
s4	db "xxxxxxxxxxxxxxxabCdxxx",0
z1	db "xxxxxxxxxxxxxxxabc",0
z2	db "xxxxxxxxxxxxxxxabcd",0
z3	db "xxxxxxxxxxxxxxxAbc",0
z4	db "xxxxxxxxxxxxxxxabCd",0
z5	db "abc",0
z6	db "abc ",0
z7	db " "
z8	db 0

table	dd s1,s1,0
	dd s2,s2,0
	dd s3,s3,0
	dd s4,s4,0
	dd s1,s3,0
	dd s3,s1,0
	dd s1,s2,-1
	dd s1,s4,-1
	dd s3,s2,-1
	dd s3,s4,-1
	dd s2,s1,1
	dd s4,s1,1
	dd s2,s3,1
	dd s4,s3,1
	dd z1,z2,1
	dd z1,z4,1
	dd z3,z2,1
	dd z3,z4,1
	dd z2,z1,-1
	dd z4,z1,-1
	dd z2,z3,-1
	dd z4,z3,-1
	dd z6,z5,-1
	dd z5,z6,1
	dd z7,z8,-1
	dd z8,z7,1
	dd 0,0,0

nerror	dd 0

.code

main	PROC c


	.if strnicmp(arg_1, arg_1, arg_3)
	    printf( "error 1: eax = %d (%d) strnicmp\n", eax, 0 )
	    inc	   nerror
	.endif

	.if strnicmp(addr str_1, addr str_2, arg_3) != -1
	    printf( "error 2: eax = %d (%d) strnicmp\n", eax, -1 )
	    inc	   nerror
	.endif
	.if strnicmp(addr abc2, addr abc1, 5)
	    printf( "error 3: eax = %d (%d) strnicmp\n", eax, 0 )
	    inc	   nerror
	.endif
	.if strnicmp(addr abcd, addr abc1, 3)
	    printf( "error 4: eax = %d (%d) strnicmp\n", eax, 0 )
	    inc	   nerror
	.endif
	.if strnicmp(addr abcd, addr abc1, 4) !=1
	    printf( "error 5: eax = %d (%d) strnicmp\n", eax, 1 )
	    inc	   nerror
	.endif
	.if strnicmp(addr z5, addr z6, 4) !=-1
	    printf( "error 6: eax = %d (%d) strnicmp\n", eax, -1 )
	    inc	   nerror
	.endif
	.if strnicmp(addr z6, addr z5, 4) !=1
	    printf( "error 7: eax = %d (%d) strnicmp\n", eax, 1 )
	    inc	   nerror
	.endif

ifdef TEST_OVERLAP
	.if VirtualAlloc(0,4096,MEM_COMMIT,PAGE_READWRITE)
	    push MEM_RELEASE
	    push 0
	    push eax
	    mov	 ebx,eax
	    mov	 edi,eax
	    mov	 ecx,4096
	    mov	 eax,'x'
	    rep	 stosb
	    mov	 edi,4096
	    mov	 BYTE PTR [ebx+4096-1],0
	    lea	 eax,[ebx+15]
	    invoke strnicmp,eax,ebx,64
	    .repeat
		dec	edi
		inc	ebx
		invoke	strnicmp,ebx,ebx,edi
	    .until edi == 4096 - 33
	    call VirtualFree
	.endif
endif

	mov edi,esi
	lea esi,table
	.repeat
	    lodsd
	    mov ecx,eax
	    lodsd
	    strnicmp( eax, ecx, 100 )
	    mov edx,eax
	    mov ecx,[esi-8]
	    mov ebx,[esi-4]
	    lodsd
	    .if eax != edx
		printf( "error: eax = %d (%d) strnicmp(%s, %s)\n", edx, eax, ebx, ecx )
		inc nerror
		.break
	    .endif
	    mov eax,[esi]
	.until !eax

toend:
	mov	eax,nerror
	ret
main	ENDP

	END
