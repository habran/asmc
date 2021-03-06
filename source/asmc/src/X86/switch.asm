include string.inc
include stdio.inc
include stdlib.inc
include alloc.inc

include asmc.inc
include token.inc
include hll.inc

    .code

    option proc: private
    assume esi:  ptr hll_item

addlq_label_b proc fastcall id, buffer
    AddLineQueueX("%s%s", GetLabelStr( id, buffer ), LABELQUAL)
    ret
addlq_label_b endp

addlq_label proc id
local buffer[32]:sbyte
    addlq_label_b(id, &buffer)
    ret
addlq_label endp

addlq_jxx_label proc x, id
local buffer[32]:sbyte
    AddLineQueueX("%r %s", x, GetLabelStr(id, &buffer))
    ret
addlq_jxx_label endp

RenderCase proc uses esi edi ebx hll:ptr hll_item, case:ptr hll_item, buffer:LPSTR

    mov esi,hll
    mov ebx,case
    mov edi,buffer
    mov edx,[ebx].hll_item.condlines

    .if !edx

        addlq_jxx_label(T_JMP, [ebx].hll_item.labels[LSTART*4])

    .elseif strchr(edx, '.') && BYTE PTR [eax+1] == '.'

        mov BYTE PTR [eax],0
        add eax,2
        push    eax
        AddLineQueueX( "cmp %s,%s", [esi].condlines, edx )
        mov edi,GetHllLabel()
        addlq_jxx_label(T_JB, edi)
        pop eax
        AddLineQueueX( "cmp %s,%s", [esi].condlines, eax )
        addlq_jxx_label(T_JBE, [ebx].hll_item.labels[LSTART*4])
        addlq_label(edi)
    .else
        AddLineQueueX( "cmp %s,%s", [esi].condlines, edx )
        addlq_jxx_label(T_JE, [ebx].hll_item.labels[LSTART*4])

    .endif
    ret

RenderCase endp

RenderCCMP proc uses esi edi ebx hll:ptr hll_item, buffer:LPSTR

    mov esi,hll
    mov edi,buffer
    AddLineQueueX( "%s%s", edi, LABELQUAL )
    mov ebx,[esi].caselist
    .while  ebx

        RenderCase( esi, ebx, edi )
        mov ebx,[ebx].hll_item.caselist
    .endw
    ret

RenderCCMP endp

GetLowCount proc hll:ptr hll_item, min, dist

    mov ecx,min
    add ecx,dist
    mov edx,hll
    xor eax,eax
    mov edx,[edx].hll_item.caselist

    .while edx
        .ifs [edx].hll_item.flags & HLLF_TABLE && ecx >= [edx].hll_item.labels

            add eax,1
        .endif
        mov edx,[edx].hll_item.caselist
    .endw
    ret

GetLowCount endp

GetHighCount proc hll:ptr hll_item, max, dist

    mov ecx,max
    sub ecx,dist
    mov edx,hll
    xor eax,eax
    mov edx,[edx].hll_item.caselist

    .while edx
        .ifs [edx].hll_item.flags & HLLF_TABLE && ecx <= [edx].hll_item.labels

            add eax,1
        .endif
        mov edx,[edx].hll_item.caselist
    .endw
    ret

GetHighCount endp

SetLowCount proc uses esi hll:ptr hll_item, count, min, dist

    mov ecx,min
    mov edx,count
    add ecx,dist
    xor eax,eax
    mov esi,hll
    mov esi,[esi].caselist

    .while  esi
        .ifs [esi].flags & HLLF_TABLE && ecx < [esi].labels

            and [esi].flags,NOT HLLF_TABLE
            dec DWORD PTR [edx]
            add eax,1
        .endif
        mov esi,[esi].caselist
    .endw
    mov edx,[edx]
    ret

SetLowCount endp

SetHighCount proc uses esi hll:ptr hll_item, count, max, dist

    mov ecx,max
    mov edx,count
    sub ecx,dist
    xor eax,eax
    mov esi,hll
    mov esi,[esi].caselist

    .while esi

        .ifs [esi].flags & HLLF_TABLE && ecx > [esi].labels

            and [esi].flags,NOT HLLF_TABLE
            dec DWORD PTR [edx]
            add eax,1
        .endif
        mov esi,[esi].caselist
    .endw
    mov edx,[edx]
    ret

SetHighCount endp

GetCaseVal proc fastcall private hll, val

    mov eax,[ecx].hll_item.caselist
    .while eax

        .if [eax].hll_item.flags & HLLF_TABLE && \
            [eax].hll_item.labels == edx

            .break
        .endif
        mov ecx,eax
        mov eax,[eax].hll_item.caselist
    .endw
    ret

GetCaseVal endp

RemoveVal proc fastcall private hll, val

    .if GetCaseVal()

        and [eax].hll_item.flags,NOT HLLF_TABLE
        mov eax,1
    .endif
    ret

RemoveVal endp

GetCaseValue proc uses esi edi ebx hll, tokenarray, dcount, scount
    local   i, opnd:expr

    xor edi,edi ; dynamic count
    xor ebx,ebx ; static count

    mov esi,hll
    mov esi,[esi].caselist

    .while esi

        .if [esi].flags & HLLF_NUM

            or [esi].flags,HLLF_TABLE
            Tokenize( [esi].condlines, 0, tokenarray, TOK_DEFAULT )
            mov ModuleInfo.token_count,eax
            mov i,0
            mov ecx,eax
            EvalOperand( &i, tokenarray, ecx, &opnd, EXPF_NOERRMSG )
            .break .if eax != NOT_ERROR

            mov eax,DWORD PTR opnd.value64
            mov edx,DWORD PTR opnd.value64[4]
            .if opnd.kind == EXPR_ADDR

                mov ecx,opnd.sym
                add eax,[ecx].asym._offset
                xor edx,edx
            .endif
            mov [esi].labels[LTEST*4],eax
            mov [esi].labels[LEXIT*4],edx
            inc ebx
        .elseif [esi].condlines

            inc edi
        .endif
        mov esi,[esi].caselist
    .endw

    Tokenize( ModuleInfo.currsource, 0, tokenarray, TOK_DEFAULT )
    mov ModuleInfo.token_count,eax

    mov eax,dcount
    mov [eax],edi
    mov eax,scount
    mov [eax],ebx
    ;
    ; error A3022 : .CASE redefinition : %s(%d) : %s(%d)
    ;
    .if ebx && Parse_Pass != PASS_1

        mov esi,hll
        mov esi,[esi].caselist
        mov edi,[esi].caselist

        .while edi

            .if [esi].flags & HLLF_NUM

                .if GetCaseVal( esi, [esi].labels )

                    asmerr( 3022,
                        [esi].condlines,
                        [esi].labels,
                        [eax].hll_item.condlines,
                        [eax].hll_item.labels )
                .endif
            .endif
            mov esi,[esi].caselist
            mov edi,[esi].caselist
        .endw
    .endif

    mov eax,ebx
    ret
GetCaseValue endp

GetMaxCaseValue proc uses esi edi ebx hll, min, max, min_table, max_table

    mov esi,hll
    xor edi,edi
    mov eax,80000000h
    mov edx,7FFFFFFFh
    mov esi,[esi].caselist

    .while esi

        .if [esi].flags & HLLF_TABLE

            inc edi
            mov ecx,[esi].labels
            .ifs eax <= ecx

                mov eax,ecx
            .endif
            .ifs edx >= ecx

                mov edx,ecx
            .endif
        .endif
        mov esi,[esi].caselist
    .endw

    .if !edi

        mov eax,edi
        mov edx,edi
    .endif

    mov ebx,max
    mov ecx,min
    mov [ebx],eax
    mov [ecx],edx

    mov esi,hll
    mov ecx,1
    mov eax,MIN_JTABLE

    .if !( [esi].flags & HLLF_ARGREG )

        add eax,2
        add ecx,1
        .if !( [esi].flags & HLLF_ARG16 or HLLF_ARG32 or HLLF_ARG64 )

            add eax,1
            .if !( ModuleInfo.aflag & _AF_REGAX )

                add eax,10
            .endif
        .endif
    .endif
    mov esi,min_table
    mov [esi],eax
    mov esi,max_table
    mov eax,edi
    shl eax,cl
    mov [esi],eax

    mov eax,[ebx]
    sub eax,edx
    mov ecx,edi
    add eax,1
    ret
GetMaxCaseValue endp

RenderCaseExit proc fastcall private hll

    mov eax,hll
    .while  [eax].hll_item.caselist

        mov eax,[eax].hll_item.caselist
    .endw

    .if eax != hll

        .if !( [eax].hll_item.flags & HLLF_ENDCOCCUR )

            .if Parse_Pass == PASS_1 && !( ModuleInfo.aflag & _AF_PASCAL )

                asmerr( 7007 )
            .endif
            addlq_jxx_label(T_JMP, [hll].hll_item.labels[LEXIT*4])
        .endif
    .endif
    ret
RenderCaseExit endp

    assume esi:ptr asm_tok

IsCaseColon proc uses esi edi ebx tokenarray:ptr asm_tok

    mov esi,tokenarray
    xor edi,edi
    xor edx,edx

    .while [esi].token != T_FINAL

        mov al,[esi].token
        mov ah,[esi-16].token
        mov ecx,[esi-16].tokval
        .switch

          .case al == T_OP_BRACKET : inc edx : .endc
          .case al == T_CL_BRACKET : dec edx : .endc
          .case al == T_COLON

            .endc .if edx
            .endc .if ah == T_REG && ecx >= T_ES && ecx <= T_ST

            mov [esi].token,T_FINAL
            mov edi,esi
            .break
        .endsw
        add esi,16
    .endw
    mov eax,edi
    ret
IsCaseColon endp

    assume  ebx: ptr asm_tok

RenderMultiCase proc uses esi edi ebx i:ptr SDWORD, buffer:ptr SBYTE, tokenarray:ptr asm_tok

local result, colon

    mov ebx,tokenarray
    add ebx,16
    mov eax,ebx
    mov esi,ebx
    xor edi,edi
    mov result,edi

    IsCaseColon( ebx )
    mov colon,eax

    .while 1
        ;
        ; Split .case 1,2,3 to
        ;
        ;   .case 1
        ;   .case 2
        ;   .case 3
        ;
        mov al,[ebx].token
        .switch al

          .case T_FINAL : .break

          .case T_OP_BRACKET : inc edi : .endc
          .case T_CL_BRACKET : dec edi : .endc

          .case T_COMMA
            .endc .if edi

            mov edx,[ebx].tokpos
            mov BYTE PTR [edx],0
            strcpy( buffer, [esi].tokpos )
            lea esi,[ebx+16]
            mov BYTE PTR [edx],','

            inc result
            AddLineQueueX( ".case %s", buffer )
            mov [ebx].token,T_FINAL
        .endsw
        add ebx,16
    .endw

    mov ebx,colon
    .if ebx

        mov [ebx].token,T_COLON
    .endif

    mov eax,result
    .if eax

        AddLineQueueX( ".case %s", [esi].tokpos )

        mov ebx,tokenarray
        xor eax,eax
        .while [ebx].token != T_FINAL

            add eax,1
            add ebx,16
        .endw
        mov ebx,i
        mov [ebx],eax

        .if ModuleInfo.aflag & _AF_PASCAL

            and ModuleInfo.aflag,NOT _AF_PASCAL

            .if ModuleInfo.list

                LstWrite( LSTTYPE_DIRECTIVE, GetCurrOffset(), 0 )
            .endif
            RunLineQueue()

            or ModuleInfo.aflag,_AF_PASCAL
        .endif
        mov eax,1
    .endif
    ret
RenderMultiCase endp

CompareMaxMin proc reg, max, min, around
    AddLineQueueX( "cmp %s,%d", reg, min )
    AddLineQueueX( "jl %s", around )
    AddLineQueueX( "cmp %s,%d", reg, max )
    AddLineQueueX( "jg %s", around )
    ret
CompareMaxMin endp

;
; Move .SWITCH <arg> to [R|E]AX
;
GetSwitchArg proc uses ebx reg, flags, arg
local buffer[64]:sbyte

    .if !( ModuleInfo.aflag & _AF_REGAX )

        AddLineQueueX( "push %r", reg )
    .endif

    GetResWName( reg, &buffer )

    mov eax,flags
    mov edx,reg
    mov ebx,arg

    .if !( eax & HLLF_ARG16 or HLLF_ARG32 or HLLF_ARG64 )
        ;
        ; BYTE value
        ;
        mov ecx,ModuleInfo.curr_cpu
        and ecx,P_CPU_MASK
        .if ecx >= P_386

            .if eax & HLLF_ARGMEM

                AddLineQueueX( "movsx %r,BYTE PTR %s", edx, ebx )
            .else
                AddLineQueueX( "movsx %r,%s", edx, ebx )
            .endif
        .else
            .if _stricmp( "al", ebx )

                AddLineQueueX( "mov al,%s", ebx )
            .endif
            AddLineQueue ( "cbw" )
        .endif

    .elseif eax & HLLF_ARG16
        ;
        ; WORD value
        ;
        .if ModuleInfo.Ofssize == USE16

            .if eax & HLLF_ARGMEM

                AddLineQueueX( "mov %r,WORD PTR %s", edx, ebx )
            .elseif _stricmp( ebx, &buffer )

                AddLineQueueX( "mov %r,%s", edx, ebx )
            .endif
        .elseif eax & HLLF_ARGMEM

            AddLineQueueX( "movsx %r,WORD PTR %s", edx, ebx )
        .else
            AddLineQueueX( "movsx %r,%s", edx, ebx )
        .endif

    .elseif eax & HLLF_ARG32
        ;
        ; DWORD value
        ;
        .if ModuleInfo.Ofssize == USE32

            .if eax & HLLF_ARGMEM

                AddLineQueueX( "mov %r,DWORD PTR %s", edx, ebx )
            .elseif _stricmp( ebx, &buffer )

                AddLineQueueX( "mov %r,%s", edx, ebx )
            .endif
        .elseif eax & HLLF_ARGMEM

            AddLineQueueX( "movsxd %r,DWORD PTR %s", edx, ebx )
        .else
            AddLineQueueX( "movsxd %r,%s", edx, ebx )
        .endif
    .else
        ;
        ; QWORD value
        ;
        AddLineQueueX( "mov %r,QWORD PTR %s", edx, ebx )
    .endif
    ret

GetSwitchArg endp

    assume esi:ptr hll_item
    assume ebx:ptr hll_item

RenderSwitch proc uses esi edi ebx hll:ptr hll_item, tokenarray:ptr asm_tok,
    buffer:     LPSTR,  ; *switch.labels[LSTART]
    l_exit:     LPSTR   ; *switch.labels[LEXIT]

local \
    r_dw:       DWORD,  ; dw/dd/dq
    r_db:       DWORD,  ; "DB"/"DW"
    r_size:     DWORD,  ; 2/4/8
    dynamic:    DWORD,  ; number of dynmaic cases
    default:    DWORD,  ; hll_item * if exist
    static:     DWORD,  ; number of static const values
    tables:     DWORD,  ; number of tables
    lcount:     DWORD,  ; number of labels in table
    icount:     DWORD,  ; number of index to labels in table
    tcases:     DWORD,  ; number of cases in table
    ncases:     DWORD,  ; number of cases not in table
    min_table:  DWORD,
    max_table:  DWORD,
    min[2]:     SDWORD, ; minimum const value
    max[2]:     SDWORD, ; maximum const value
    dist:       SDWORD, ; max - min
    l_start[16]:SBYTE,  ; current start label
    l_jtab[16]: SBYTE,  ; jump table address
    labelx[16]: SBYTE,  ; label symbol
    use_index:  BYTE


    mov esi,hll
    mov edi,buffer
    xor eax,eax
    mov tables,eax
    mov ncases,eax
    mov default,eax
    ;
    ; get static case-count
    ;
    GetCaseValue( esi, tokenarray, &dynamic, &static )

    .if ModuleInfo.aflag & _AF_NOTABLE || eax < MIN_JTABLE
        ;
        ; Time NOTABLE/TABLE
        ;
        ; .case *   3   4       7       8       9       10      16      60
        ; NOTABLE 1401  2130    5521    5081    7681    9481    18218   158245
        ; TABLE   1521  3361    4402    6521    7201    7881    9844    68795
        ; elseif  1402  4269    5787    7096    8481    10601   22923   212888
        ;
        RenderCCMP( esi, edi )
        jmp toend
    .endif

    mov ecx,2
    mov eax,T_DW
    .if ModuleInfo.Ofssize == USE32

        mov ecx,4
        mov eax,T_DD

    .elseif ModuleInfo.Ofssize == USE64

        mov ecx,8
        mov eax,T_DQ
    .endif

    mov r_dw,eax
    mov r_size,ecx

    strcpy( &l_start, edi )
    ;
    ; flip exit to default if exist
    ;
    .if [esi].flags & HLLF_ELSEOCCUR

        .for eax = esi, ebx = [esi].caselist: ebx: eax = ebx, ebx = [ebx].caselist

            .if [ebx].flags & HLLF_DEFAULT

                mov [eax].hll_item.caselist,0
                mov default,ebx
                GetLabelStr( [ebx].labels[LSTART*4], l_exit )
                .break
            .endif
        .endf
    .endif

    mov cl,ModuleInfo.casealign
    .if cl

        mov eax,1
        shl eax,cl
        AddLineQueueX( "ALIGN %d", eax )
    .endif
    AddLineQueueX( "%s%s", &l_start, LABELQUAL )

    .if dynamic

        .for eax = esi, ebx = [esi].caselist: ebx: eax = ebx, ebx = [ebx].caselist

            .if !( [ebx].flags & HLLF_NUM )

                mov ecx,[ebx].caselist
                mov [eax].hll_item.caselist,ecx
                RenderCase( esi, ebx, edi )
            .endif
        .endf
    .endif

    .while [esi].condlines

        GetMaxCaseValue( esi, &min, &max, &min_table, &max_table )

        mov dist,eax
        mov tcases,ecx
        mov ncases,0

        .break .if ecx < min_table

        .for ebx = ecx:,
             ebx >= min_table,
             max > edx,
             eax > max_table: ebx = tcases

            GetLowCount ( esi, min, max_table )
            mov ebx,eax
            GetHighCount( esi, max, max_table )

            .switch
              .case ebx < min_table
                .break .if !RemoveVal( esi, min )
                sub tcases,eax
                .endc
              .case eax < min_table
                .break .if !RemoveVal( esi, max )
                sub tcases,eax
                .endc
              .case ebx >= eax
                mov ebx,tcases
                SetLowCount( esi, &tcases, min, max_table )
                .endc
              .default
                mov ebx,tcases
                SetHighCount( esi, &tcases, max, max_table )
                .endc
            .endsw
            add ncases,eax

            GetMaxCaseValue( esi, &min, &max, &min_table, &max_table )
            mov dist,eax
            .break .if ebx == tcases
        .endf

        mov eax,tcases
        .break .if eax < min_table

        mov use_index,0
        .if eax < dist && ModuleInfo.Ofssize == USE64

            inc use_index
        .endif
        ;
        ; Create the jump table lable
        ;
        GetLabelStr( GetHllLabel(), &l_jtab )

        mov edi,l_exit
        .if ncases

            mov edi,GetLabelStr( GetHllLabel(), &l_start )
        .endif
        mov ebx,[esi].condlines
        .if !( [esi].flags & HLLF_NOTEST )
            CompareMaxMin(ebx, max, min, edi)
        .endif

        mov eax,[esi].flags
        mov cl,ModuleInfo.Ofssize

        .if cl == USE16

            .if !( ModuleInfo.aflag & _AF_REGAX )
                AddLineQueue("push ax")
            .endif
            .if [esi].flags & HLLF_ARGREG
                .if ModuleInfo.aflag & _AF_REGAX
                    .if _stricmp("ax", ebx)
                        AddLineQueueX( "mov ax,%s", ebx )
                    .endif
                    AddLineQueue("xchg ax,bx")
                .else
                    AddLineQueue("push bx")
                    AddLineQueue("push ax")
                    .if _stricmp("bx", ebx)
                        AddLineQueueX("mov bx,%s", ebx)
                    .endif
                .endif
            .else
                .if !( ModuleInfo.aflag & _AF_REGAX )
                    AddLineQueue( "push bx" )
                .endif
                GetSwitchArg(T_AX, [esi].flags, ebx)
                .if ModuleInfo.aflag & _AF_REGAX
                    AddLineQueue("xchg ax,bx")
                .else
                    AddLineQueue("mov bx,ax")
                .endif
            .endif
            .if min
                AddLineQueueX("sub bx,%d", min)
            .endif
            AddLineQueue("add bx,bx")
            .if ModuleInfo.aflag & _AF_REGAX
                AddLineQueueX("mov bx,cs:[bx+%s]", &l_jtab)
                AddLineQueue ("xchg ax,bx")
                AddLineQueue ("jmp ax")
            .else
                AddLineQueueX("mov ax,cs:[bx+%s]", &l_jtab)
                AddLineQueue ("mov bx,sp")
                AddLineQueue ("mov ss:[bx+4],ax")
                AddLineQueue ("pop ax")
                AddLineQueue ("pop bx")
                AddLineQueue ("retn")
            .endif

        .elseif cl == USE32

            .if !( eax & HLLF_ARGREG )

                GetSwitchArg(T_EAX, [esi].flags, ebx)
                .if use_index
                    .if dist < 256
                        AddLineQueueX("movzx eax,BYTE PTR [eax+IT%s-(%d)]", &l_jtab, min)
                    .else
                        AddLineQueueX("movzx eax,WORD PTR [eax*2+IT%s-(%d*2)]", &l_jtab, min)
                    .endif
                    .if ModuleInfo.aflag & _AF_REGAX
                        AddLineQueueX("jmp [eax*4+%s]", &l_jtab)
                    .else
                        AddLineQueueX("mov eax,[eax*4+%s]", &l_jtab)
                    .endif
                .elseif ModuleInfo.aflag & _AF_REGAX
                    AddLineQueueX("jmp [eax*4+%s-(%d*4)]", &l_jtab, min)
                .else
                    AddLineQueueX("mov eax,[eax*4+%s-(%d*4)]", &l_jtab, min)
                .endif
                .if !( ModuleInfo.aflag & _AF_REGAX )
                    AddLineQueue("xchg eax,[esp]")
                    AddLineQueue("retn")
                .endif
            .else
                .if use_index
                    .if !( ModuleInfo.aflag & _AF_REGAX )
                        AddLineQueueX("push %s", ebx)
                    .endif
                    .if dist < 256
                        AddLineQueueX("movzx %s,BYTE PTR [%s+IT%s-(%d)]", ebx, ebx, &l_jtab, min)
                    .else
                        AddLineQueueX("movzx %s,WORD PTR [%s*2+IT%s-(%d*2)]", ebx, ebx, &l_jtab, min)
                    .endif
                    .if ModuleInfo.aflag & _AF_REGAX
                        AddLineQueueX("jmp [%s*4+%s]", ebx, &l_jtab)
                    .else
                        AddLineQueueX("mov %s,[%s*4+%s]", ebx, ebx, &l_jtab)
                        AddLineQueueX("xchg %s,[esp]", ebx)
                        AddLineQueue ("retn")
                    .endif
                .else
                    AddLineQueueX("jmp [%s*4+%s-(%d*4)]", ebx, &l_jtab, min)
                .endif
            .endif

        .else
            .if !([esi].flags & HLLF_ARGREG)
                GetSwitchArg(T_RAX, [esi].flags, ebx)
            .else
                .if !(ModuleInfo.aflag & _AF_REGAX)
                    AddLineQueue("push rax")
                .endif
                .if _memicmp(ebx, "rax", 3)
                    AddLineQueueX("mov rax,%s", ebx)
                .endif
            .endif
            AddLineQueue("push rcx")

            .if use_index
                AddLineQueueX("lea rcx,IT%s", &l_jtab)
                .if dist < 256
                    AddLineQueueX("movzx rax,BYTE PTR [rcx+rax-(%d)]", min)
                .else
                    AddLineQueueX("movzx rax,WORD PTR [rcx+rax*2-(%d*2)]", min)
                .endif
                AddLineQueueX("lea rcx,%s", &l_jtab)
                AddLineQueue("mov rax,[rcx+rax*8]")
            .else
                AddLineQueueX("lea rcx,%s", &l_jtab)
                AddLineQueueX("mov rax,[rcx+rax*8-(%d*8)]", min)
            .endif

            .if ModuleInfo.aflag & _AF_REGAX
                AddLineQueue("pop rcx")
                AddLineQueue("jmp rax")
            .else
                AddLineQueue("mov rcx,[rsp+8]")
                AddLineQueue("mov [rsp+8],rax")
                AddLineQueue("mov rax,rcx")
                AddLineQueue("pop rcx")
                AddLineQueue("retn")
            .endif
        .endif
        ;
        ; Create the jump table
        ;
        AddLineQueueX("ALIGN %d", r_size)
        AddLineQueueX("%s%s", &l_jtab, LABELQUAL)

        .if use_index

            push edi

            .for ebx = -1, ; offset
                 edi = -1, ; table index
                 esi = [esi].caselist: esi: esi = [esi].caselist

                .if [esi].flags & HLLF_TABLE

                    .break .if !SymFind(GetLabelStr([esi].labels[LSTART*4], &labelx))

                    .if ebx != [eax].asym._offset

                        mov ebx,[eax].asym._offset
                        inc edi
                    .endif
                    ;
                    ; use case->next pointer as index...
                    ;
                    mov [esi].next,edi
                .endif
            .endf
            mov edx,esi
            inc edi
            mov lcount,edi

            pop edi

            .for esi = hll, ebx = -1,
                 esi = [esi].caselist: esi: esi = [esi].caselist

                .if [esi].flags & HLLF_TABLE && ebx != [esi].next

                    AddLineQueueX(" %r %s ; .case %s", r_dw,
                        GetLabelStr([esi].labels[LSTART*4], &labelx), [esi].condlines)
                    mov ebx,[esi].next
                .endif
            .endf

            mov esi,hll
            AddLineQueueX(" %r %s ; .default", r_dw, l_exit)

            mov eax,max
            sub eax,min
            inc eax
            mov icount,eax
            mov ebx,T_DB
            .if eax > 256

                .if ModuleInfo.Ofssize == USE16

                    asmerr(2022, 1, 2)
                    jmp toend
                .endif
                mov ebx,T_DW
            .endif
            mov r_db,ebx
            AddLineQueueX( "IT%s LABEL BYTE", &l_jtab )

            .for ebx = 0: ebx < icount: ebx++
                ;
                ; loop from min value
                ;
                mov eax,min
                add eax,ebx

                .if GetCaseVal( esi, eax )
                    ;
                    ; Unlink block
                    ;
                    mov edx,[eax].hll_item.caselist
                    mov [ecx].hll_item.caselist,edx
                    ;
                    ; write block to table
                    ;
                    AddLineQueueX( " %r %d", r_db, [eax].hll_item.next )

                .else
                    ;
                    ; else make a jump to exit or default label
                    ;
                    AddLineQueueX( " %r %d", r_db, lcount )
                .endif
            .endf
            AddLineQueueX( "ALIGN %d", r_size )
        .else
            .for ebx = 0: ebx < dist: ebx++
                ;
                ; loop from min value
                ;
                mov eax,min
                add eax,ebx

                .if GetCaseVal( esi, eax )
                    ;
                    ; Unlink block
                    ;
                    mov edx,[eax].hll_item.caselist
                    mov [ecx].hll_item.caselist,edx
                    ;
                    ; write block to table
                    ;
                    mov ecx,[eax].hll_item.labels[LSTART*4]
                    addlq_jxx_label( r_dw, ecx )
                .else
                    ;
                    ; else make a jump to exit or default label
                    ;
                    AddLineQueueX( "%r %s", r_dw, l_exit )
                .endif
            .endf
        .endif

        .if ncases
            ;
            ; Create the new start label
            ;
            AddLineQueueX( "%s%s", &l_start, LABELQUAL )

            .for ebx = [esi].caselist: ebx: ebx = [ebx].caselist

                or [ebx].flags,HLLF_TABLE
            .endf
        .endif
    .endw

    .for ebx = [esi].caselist: ebx: ebx = [ebx].caselist

        RenderCase( esi, ebx, buffer )
    .endf

    .if default && [esi].caselist

        AddLineQueueX( "jmp %s", l_exit )
    .endif
toend:
    ret
RenderSwitch endp

    assume  ebx: ptr asm_tok
    assume  esi: ptr hll_item

SwitchStart proc uses esi edi ebx i:SINT, tokenarray:ptr asm_tok

local rc:SINT, cmd:UINT, buffer[MAX_LINE_LEN]:SBYTE

    mov rc,NOT_ERROR
    mov ebx,tokenarray
    lea edi,buffer

    mov eax,i
    shl eax,4
    mov eax,[ebx+eax].tokval
    mov cmd,eax
    inc i

    mov esi,ModuleInfo.HllFree
    .if !esi

        mov esi,LclAlloc( sizeof( hll_item ) )
    .endif
    ExpandCStrings( tokenarray )

    xor eax,eax
    mov [esi].labels[LEXIT*4],eax
    mov [esi].flags,eax
    mov [esi].cmd,HLL_SWITCH
    mov [esi].flags,HLLF_WHILE
    .if ModuleInfo.aflag & _AF_NOTEST

        or  [esi].flags,HLLF_NOTEST
        and ModuleInfo.aflag,NOT _AF_NOTEST
    .endif

    xor eax,eax
    mov [esi].labels[LSTART*4],eax  ; set by .CASE
    mov [esi].labels[LTEST*4],eax   ; set by .CASE
    mov [esi].labels[LEXIT*4],eax   ; set by .BREAK
    mov [esi].condlines,eax
    mov [esi].caselist,eax

    mov eax,i
    shl eax,4
    .if [ebx+eax].asm_tok.token != T_FINAL

        ExpandHllProc( edi, i, ebx )
        cmp eax,ERROR
        je  toend

        .if BYTE PTR [edi]

            QueueTestLines( edi )
            or  [esi].flags,HLLF_ARGREG
            jmp set_arg_size
        .else
            mov ecx,i
            shl ecx,4
            mov eax,[ebx+ecx].asm_tok.tokval
            .switch eax
              .case T_AX .. T_DI
                or  [esi].flags,HLLF_ARG16
                .if ModuleInfo.Ofssize == USE16

                    or [esi].flags,HLLF_ARGREG
                .endif
              .case T_AL .. T_BH
                .endc
              .case T_EAX .. T_EDI
                or  [esi].flags,HLLF_ARG32
                .if ModuleInfo.Ofssize == USE32

                    or [esi].flags,HLLF_ARGREG
                .endif
                .if ModuleInfo.Ofssize == USE64

                    or [esi].flags,HLLF_ARG3264
                .endif
                .endc
              .case T_RAX .. T_R15
                or  [esi].flags,HLLF_ARG64
                .if ModuleInfo.Ofssize == USE64

                    or [esi].flags,HLLF_ARGREG
                .endif
                .endc
              .default
                or  [esi].flags,HLLF_ARGMEM
                mov eax,[ebx+ecx].asm_tok.string_ptr
                .if SymFind( eax )

                    mov eax,[eax].asym.total_size
                    .if eax == 2

                        or [esi].flags,HLLF_ARG16
                    .elseif eax == 4

                        or [esi].flags,HLLF_ARG32
                    .elseif eax == 8

                        or [esi].flags,HLLF_ARG64
                    .endif
                .else
                set_arg_size:
                    .if ModuleInfo.Ofssize == USE16

                        or [esi].flags,HLLF_ARG16
                    .elseif ModuleInfo.Ofssize == USE32

                        or [esi].flags,HLLF_ARG32
                    .else
                        or [esi].flags,HLLF_ARG64
                    .endif
                .endif
            .endsw
        .endif

        strlen( strcpy( edi, [ebx+16].asm_tok.tokpos ) )
        inc eax
        push eax
        LclAlloc(eax)
        pop ecx
        mov [esi].condlines,eax
        memcpy(eax, edi, ecx)
    .endif

    mov eax,i
    shl eax,4
    .if ![esi].flags && ([ebx+eax].asm_tok.token != T_FINAL && rc == NOT_ERROR)

        mov rc,asmerr(2008, [ebx+eax].asm_tok.tokpos)
    .endif

    .if esi == ModuleInfo.HllFree

        mov eax,[esi].next
        mov ModuleInfo.HllFree,eax
    .endif
    mov eax,ModuleInfo.HllStack
    mov [esi].next,eax
    mov ModuleInfo.HllStack,esi

    mov eax,rc
toend:
    ret
SwitchStart endp

SwitchEnd proc uses esi edi ebx i:SINT, tokenarray:ptr asm_tok

local rc:SINT,cmd:SINT, buffer[MAX_LINE_LEN]:SBYTE, l_exit[16]:SBYTE    ; exit or default label

    mov esi,ModuleInfo.HllStack
    .if !esi

        asmerr(1011)
        jmp toend
    .endif

    mov eax,[esi].next
    mov ecx,ModuleInfo.HllFree
    mov ModuleInfo.HllStack,eax
    mov [esi].next,ecx
    mov ModuleInfo.HllFree,esi
    mov rc,NOT_ERROR
    lea edi,buffer
    mov ebx,tokenarray
    mov ecx,[esi].cmd

    .if ecx != HLL_SWITCH

        asmerr(1011)
        jmp toend
    .endif

    inc i
    cmp [esi].labels[LTEST*4],0
    je  done
    .if [esi].labels[LSTART*4] == 0

        mov [esi].labels[LSTART*4],GetHllLabel()
    .endif
    .if [esi].labels[LEXIT*4] == 0

        mov [esi].labels[LEXIT*4],GetHllLabel()
    .endif

    GetLabelStr( [esi].labels[LEXIT*4], edi )
    RenderCaseExit( esi )
    strcpy( &l_exit, edi )
    GetLabelStr( [esi].labels[LSTART*4], edi )

    assume ebx:ptr hll_item
    mov ebx,[esi].caselist

    mov cl,ModuleInfo.casealign
    .if cl

        mov eax,1
        shl eax,cl
        AddLineQueueX( "ALIGN %d", eax )
    .endif

    .if ![esi].condlines

        AddLineQueueX( "%s%s", edi, LABELQUAL )

        .while ebx

            .if ![ebx].condlines

                addlq_jxx_label(T_JMP, [ebx].labels[LSTART*4])
            .elseif [ebx].flags & HLLF_EXPRESSION

                mov i,1
                or  [ebx].flags,HLLF_WHILE
                ExpandHllExpression( ebx, &i, tokenarray, LSTART, 1, edi )
            .else
                QueueTestLines( [ebx].condlines )
            .endif
            mov ebx,[ebx].caselist
        .endw
    .else
        RenderSwitch(esi, tokenarray, edi, &l_exit)
    .endif

    assume ebx:ptr asm_tok
done:
    mov eax,[esi].labels[LEXIT*4]
    .if eax

        addlq_label(eax)
    .endif

    mov eax,rc
toend:
    ret
SwitchEnd endp

_lk_HllContinueIf proto :ptr sdword, :ptr asm_tok

SwitchExit proc uses esi edi ebx i, tokenarray:ptr asm_tok

local   rc:     SINT,
        cont0:  SINT,
        cmd:    SINT,
        buff    [16]:SBYTE,
        buffer  [MAX_LINE_LEN]:SBYTE

    mov esi,ModuleInfo.HllStack
    .if !esi

        asmerr(1011)
        jmp toend
    .endif

    ExpandCStrings( tokenarray )

    lea edi,buffer
    mov rc,NOT_ERROR
    mov ebx,i
    shl ebx,4
    add ebx,tokenarray
    mov eax,[ebx].tokval
    mov cmd,eax
    xor ecx,ecx     ; exit level 0,1,2,3
    mov cont0,ecx

    .switch eax

      .case T_DOT_DEFAULT
        .if [esi].flags & HLLF_ELSEOCCUR

            asmerr( 2142 )
            jmp toend
        .endif
        .if [ebx+16].token != T_FINAL

            asmerr( 2008, [ebx].tokpos )
            jmp toend
        .endif
        or [esi].flags,HLLF_ELSEOCCUR

      .case T_DOT_CASE

        .while esi && [esi].cmd != HLL_SWITCH

            mov esi,[esi].next
        .endw
        .if [esi].cmd != HLL_SWITCH

            asmerr( 1010, [ebx].string_ptr )
            jmp toend
        .endif

        .if [esi].labels[LSTART*4] == 0
            ;
            ; First case..
            ;
            mov [esi].labels[LSTART*4],GetHllLabel()
            addlq_jxx_label(T_JMP, eax)

        .elseif ModuleInfo.aflag & _AF_PASCAL

            .if [esi].labels[LEXIT*4] == 0

                mov [esi].labels[LEXIT*4],GetHllLabel()
            .endif
            RenderCaseExit( esi )

        .elseif Parse_Pass == PASS_1
            ;
            ; error A7007: .CASE without .ENDC: assumed fall through
            ;
            mov eax,esi
            .while [eax].hll_item.caselist

                mov eax,[eax].hll_item.caselist
            .endw

            .if eax != esi && !( [eax].hll_item.flags & HLLF_ENDCOCCUR )

                asmerr( 7007 )
            .endif
        .endif

        ;
        ; .case a, b, c, ...
        ;
        .endc .if RenderMultiCase( &i, edi, ebx )

        mov cl,ModuleInfo.casealign
        .if cl

            mov eax,1
            shl eax,cl
            AddLineQueueX( "ALIGN %d", eax )
        .endif

        inc [esi].labels[LTEST*4]
        mov ecx,GetHllLabel()
        push ecx
        addlq_label(ecx)

        LclAlloc(sizeof(hll_item))
        pop ecx
        mov edx,esi
        mov esi,eax
        mov eax,[edx].hll_item.condlines
        mov [esi].labels[LSTART*4],ecx

        .while  [edx].hll_item.caselist

            mov edx,[edx].hll_item.caselist
        .endw
        mov [edx].hll_item.caselist,esi

        inc i   ; skip past the .case token
        add ebx,16

        push eax ;
        push ebx ; handle .case <expression> : ...
        push esi ;
        .for esi = 0 : IsCaseColon(ebx) : ebx += 16, esi = [ebx].tokpos

            mov ebx,eax
            .if esi

                mov eax,[ebx].tokpos
                mov BYTE PTR [eax],0
                AddLineQueue(esi)
                mov eax,[ebx].tokpos
                mov BYTE PTR [eax],':'
            .else
                sub eax,tokenarray
                shr eax,4
                mov ModuleInfo.token_count,eax
            .endif
        .endf
        .if esi

            AddLineQueue(esi)
        .endif
        pop esi
        pop ebx
        pop eax

        .if eax && cmd != T_DOT_DEFAULT

            push eax
            push ebx
            push edi
            xor  edi,edi

            .while  1
                movzx eax,[ebx].token
                ;
                ; .CASE BYTE PTR [reg+-*imm]
                ; .CASE ('A'+'L') SHR (8 - H_BITS / ... )
                ;
                .switch eax

                  .case T_CL_BRACKET
                    .if edi == 1

                        .if [ebx+16].token == T_FINAL

                            or [esi].flags,HLLF_NUM
                            .break
                        .endif
                    .endif
                    sub edi,2
                  .case T_OP_BRACKET
                    inc edi
                  .case T_PERCENT   ; %
                  .case T_INSTRUCTION   ; XOR, OR, NOT,...
                  .case '+'
                  .case '-'
                  .case '*'
                  .case '/'
                    .endc

                  .case T_STYPE ; BYTE, WORD, ...
                    .break .if [ebx+16].tokval == T_PTR
                    jmp STRING

                  .case T_FLOAT ; 1..3 ?
                    .break  .if [ebx+16].token == T_DOT
                    jmp STRING
                  .case T_UNARY_OPERATOR    ; offset x
                    .break  .if [ebx].tokval != T_OFFSET
                    jmp STRING
                  .case T_ID
                    .if SymFind( [ebx].string_ptr )

                        .break .if [eax].asym.state != SYM_INTERNAL
                        .break .if !([eax].asym.mem_type == MT_NEAR || \
                                  [eax].asym.mem_type == MT_EMPTY)
                    .elseif Parse_Pass != PASS_1

                        .break
                    .endif
                  .case T_STRING
                  .case T_NUM
                    STRING:
                    .if [ebx+16].token == T_FINAL

                        or [esi].flags,HLLF_NUM
                        .break
                    .endif
                    .endc
                  .default
                  ; T_REG
                  ; T_OP_SQ_BRACKET
                  ; T_DIRECTIVE
                  ; T_QUESTION_MARK
                  ; T_BAD_NUM
                  ; T_DBL_COLON
                  ; T_CL_SQ_BRACKET
                  ; T_COMMA
                  ; T_COLON
                  ; T_FINAL
                    .break
                .endsw
                add ebx,16
            .endw
            pop edi
            pop ebx
            pop eax
        .endif

        .if cmd == T_DOT_DEFAULT

            or [esi].flags,HLLF_DEFAULT
        .else
            .if [ebx].token == T_FINAL

                asmerr( 2008, [ebx-16].tokpos )
                jmp toend
            .endif
            .if !eax

                mov ebx,i
                EvaluateHllExpression( esi, &i, tokenarray, LSTART, 1, edi )
                mov i,ebx
                mov rc,eax
                .endc .if eax == ERROR
            .else
                mov eax,ModuleInfo.token_count
                shl eax,4
                add eax,tokenarray
                mov eax,[eax].asm_tok.tokpos
                sub eax,[ebx].tokpos
                mov WORD PTR [edi+eax],0
                memcpy(edi, [ebx].tokpos, eax)
            .endif
            strlen(edi)
            inc eax
            push eax
            LclAlloc(eax)
            pop ecx
            mov [esi].condlines,eax
            memcpy(eax, edi, ecx)
        .endif
        mov eax,ModuleInfo.token_count
        mov i,eax
        .endc

      .case T_DOT_ENDC

        .for edx = esi: esi,
             [esi].cmd != HLL_SWITCH: esi = [esi].next
        .endf
        .for : esi, ecx: ecx--

            .for esi = [esi].next: esi,
                 [esi].cmd != HLL_SWITCH: esi = [esi].next
            .endf
        .endf

        .if !esi

            asmerr( 1011 )
            jmp toend
        .endif

        .if [esi].labels[LEXIT*4] == 0

            mov [esi].labels[LEXIT*4],GetHllLabel()
        .endif

        mov ecx,LEXIT
        .if cmd != T_DOT_ENDC

            mov ecx,LSTART
        .endif

        inc i
        add ebx,16
        mov cmd,T_DOT_ENDC

        .if ecx == LSTART && [ebx].token == T_OP_BRACKET

            .if strrchr( strcpy( edi, [ebx+16].tokpos ), ')' )

                .while  eax > edi && \
                    (BYTE PTR [eax-1] == ' ' || \
                     BYTE PTR [eax-1] == 9)

                    sub eax,1
                .endw
                mov BYTE PTR [eax],0

                push    esi
                mov esi,[esi].caselist
                .while  esi
                    mov eax,[esi].condlines
                    .if eax
                        .if !strcmp( edi, eax )

                        addlq_jxx_label(T_JMP, [esi].labels[LSTART*4])
                        .break
                        .endif
                    .endif
                    mov esi,[esi].caselist
                .endw

                mov eax,esi
                pop esi
                .if !eax && [esi].condlines

                    AddLineQueueX( "mov %s,%s",  [esi].condlines, edi )
                    addlq_jxx_label(T_JMP, [esi].labels[LSTART*4])
                .endif

                mov eax,ModuleInfo.token_count
                mov i,eax
            .endif
        .else
            _lk_HllContinueIf(&i, tokenarray)
        .endif
        .endc

      .case T_DOT_GOTOSW3
        inc ecx
      .case T_DOT_GOTOSW2
        inc ecx
      .case T_DOT_GOTOSW1
        inc ecx
      .case T_DOT_GOTOSW
        mov eax,T_DOT_ENDC
        .gotosw
    .endsw

    mov ebx,i
    shl ebx,4
    add ebx,tokenarray

    .if [ebx].token != T_FINAL && rc == NOT_ERROR

        asmerr( 2008, [ebx].tokpos )
        mov rc,ERROR
    .endif

    mov eax,rc
toend:
    ret
SwitchExit endp

    option proc: public

SwitchDirective proc uses esi edi ebx i:SINT, tokenarray:ptr asm_tok

    mov ecx,i
    mov edx,tokenarray
    mov eax,ecx
    shl eax,4
    mov eax,[edx+eax].asm_tok.tokval
    xor ebx,ebx

    .switch eax
      .case T_DOT_CASE
      .case T_DOT_GOTOSW
      .case T_DOT_GOTOSW1
      .case T_DOT_GOTOSW2
      .case T_DOT_GOTOSW3
      .case T_DOT_DEFAULT
      .case T_DOT_ENDC
        mov ebx,SwitchExit(ecx, edx)
        .endc
      .case T_DOT_ENDSW
        mov ebx,SwitchEnd(ecx, edx)
        .endc
      .case T_DOT_SWITCH
        mov ebx,SwitchStart(ecx, edx)
        .endc
    .endsw

    .if ModuleInfo.list

        LstWrite( LSTTYPE_DIRECTIVE, GetCurrOffset(), 0 )
    .endif

    .if ModuleInfo.line_queue.head

        RunLineQueue()
    .endif

    mov eax,ebx

toend:
    ret

SwitchDirective endp

    END
