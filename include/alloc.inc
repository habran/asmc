ifndef __LIBC_INC
 include libc.inc
endif
.xlist
IFDEF __PE__
option	dllimport:<msvcrt>
ENDIF
;
; All allocations are of size n * _GRANULARITY
;
_GRANULARITY		equ 0x10	; align 16
_PAGESIZE_		equ 0x1000	; one page
_SEGSIZE_		equ 0x10000	; one segment (i.e., 64 Kb)
_HEAP_REGIONMAX		equ 0x40	; Max number of regions: 64
					; For small memory systems:
_HEAP_REGIONSIZE_S	equ 0x4000	; Initial region size (16K)
_HEAP_MAXREGSIZE_S	equ 0x1000000	; Maximum region size (16M)
					; For large memory systems:
_HEAP_REGIONSIZE_L	equ 0x100000	; Initial region size  (1M)
_HEAP_MAXREGSIZE_L	equ 0x1000000	; Maximum region size (16M)
_HEAP_GROWSIZE		equ 0x40000	; Default grow increment (64K)
_HEAP_GROWMIN		equ _PAGESIZE_	; Minimum grow inc (1 page)
_HEAP_GROWSTART		equ _PAGESIZE_	; Startup grow increment
_HEAP_COALESCE		equ -1		; Coalesce heap value
_HEAP_EMPTYLIST_SIZE	equ (1 * _PAGESIZE_)

S_HEAP		STRUC SIZE_T		; Memory Block Header: 16/32 byte
h_size		SIZE_T ?
h_type		BYTE ?			; 0 unused, 1 local, 2 global, 3 aligned
h_prev		PVOID ?			; global block's (user size)
h_next		PVOID ?			; local block's (chunck size)
S_HEAP		ENDS

externdef	_amblksiz:dword
externdef	_heap_base:size_t
externdef	_heap_free:size_t

malloc		proto __cdecl :size_t
realloc		PROTO __cdecl :ptr, :size_t
free		proto __cdecl :ptr
calloc		proto __cdecl :dword, :dword
_aligned_malloc proto __cdecl dwSize:size_t, alignment:UINT

IFNDEF __PE__

_alloca64	proto __cdecl :dword, :dword
ifdef _WIN64
alloca	macro dwSize:req, ReservedStack:=<@ReservedStack>
	exitm<_alloca64( dwSize, ReservedStack )>
	endm
else
alloca		proto __cdecl :dword
endif
ifdef _LINUX
salloc	macro string
	push string
	malloc(addr [strlen(string)+1])
	pop ecx
	.if eax
	    strcpy(eax, string)
	    test eax,eax
	.endif
	endm
else
salloc		proto __cdecl :LPSTR
endif

__coreleft	proto __cdecl
__purgeheap	proto __cdecl

ELSE
alloca		proto __cdecl :dword
option		dllimport:<kernel32>
ENDIF
;;;;;;;;;;;;;;; kernel32

GMEM_MOVEABLE	equ 0x0002
GMEM_DDESHARE	equ 0x2000

GlobalAlloc	proto WINAPI uFlags:UINT, dwBytes:SIZE_T
GlobalFree	proto WINAPI :HANDLE
GlobalLock	proto WINAPI :HANDLE
GlobalUnlock	proto WINAPI :HANDLE
GetProcessHeap	proto WINAPI
HeapAlloc	proto WINAPI :HANDLE, dwFlags:DWORD, dwBytes:SIZE_T
HeapFree	proto WINAPI :HANDLE, dwFlags:DWORD, lpMem:PVOID

.list
