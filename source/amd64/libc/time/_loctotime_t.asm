include time.inc
include winbase.inc

	.code

_loctotime_t PROC uses rsi rdi rbx,
	year:	SINT,
	month:	SINT,
	day:	SINT,
	hour:	SINT,
	minute: SINT,
	second: SINT
local	tb:	tm

	mov	eax,ecx		; year
	sub	eax,1900
	mov	ebx,eax
	cmp	eax,_BASE_YEAR
	jb	error
	cmp	eax,_MAX_YEAR
	ja	error

	lea	r10,_days
	;mov	edx,month
	mov	ecx,[r10+rdx*4-4]
	add	ecx,r8d		; day
	.if	!( eax & 3 ) && edx > 2
		inc	ecx
	.endif

	mov	esi,ecx
	mov	ecx,eax
	sub	eax,_BASE_YEAR
	mov	edx,365
	mul	edx
	dec	ecx
	shr	ecx,2
	lea	rax,[rax+rcx-_LEAP_YEAR_ADJUST]
	add	eax,esi
	mov	ecx,24
	mul	ecx
	add	eax,r9d		; hour
	mov	ecx,60
	mul	ecx
	add	eax,minute
	mul	ecx
	add	eax,second
	mov	edi,eax

	call	_tzset
	add	edi,_timezone

	mov	ecx,month
	dec	ecx
	mov	edx,hour
	mov	tb.tm_yday,esi
	mov	tb.tm_year,ebx
	mov	tb.tm_mon,ecx
	mov	tb.tm_hour,edx
	cmp	_daylight,0
	je	@F
	_isindst( addr tb )
	test	eax,eax
	jz	@F
	sub	edi,3600
@@:
	mov	eax,edi
toend:
	ret
error:
	mov	eax,-1
	jmp	toend
_loctotime_t ENDP

	END
