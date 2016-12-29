/****************************************************************************
*
*  This code is Public Domain.
*
*  ========================================================================
*
* Description:	handles EQU and '=' directives.
*
****************************************************************************/

#include <ctype.h>

#include <globals.h>
#include <memalloc.h>
#include <parser.h>
#include <expreval.h>
#include <equate.h>
#include <tokenize.h>
#include <macro.h>
#include <fastpass.h>
#include <listing.h>
#include <input.h>
#include <fixup.h>

#if defined(LLONG_MAX) || defined(__GNUC__) || defined(__TINYC__)
/* gcc needs suffixes if the constants won't fit in long type */
const int_64 maxintvalues[] = { 0x00000000ffffffffULL, 0x00000000ffffffffULL,
0x7fffffffffffffffULL
};
const int_64 minintvalues[] = { 0xffffffff00000000ULL, 0xffffffff00000000ULL,
0x8000000000000000ULL
};
#else
/* the "i64" suffixes shouldn't be necessary, but sometimes it's needed (OCC) */
const int_64 maxintvalues[] = { 0x00000000ffffffffi64, 0x00000000ffffffffi64,
0x7fffffffffffffffi64
};
const int_64 minintvalues[] = { 0xffffffff00000000i64, 0xffffffff00000000i64,
0x8000000000000000i64
};
#endif

/* set the value of a constant (EQU) or an assembly time variable (=) */

static void __fastcall SetValue( struct asym *sym, struct expr *opndx )
/**********************************************************/
{

    sym->isequate = TRUE;
    sym->state = SYM_INTERNAL;
    sym->isdefined = TRUE;
    if ( opndx->kind == EXPR_CONST ) {
	sym->mem_type = opndx->mem_type;
	sym->uvalue = opndx->uvalue;
	sym->value3264 = opndx->hvalue;
	sym->segment = NULL;
	sym->isproc = FALSE;
    } else {
	sym->isproc = opndx->sym->isproc;
	/* for a PROC alias, copy the procinfo extension! */
	if ( sym->isproc ) {
	    struct dsym *dir = (struct dsym *)sym;
	    dir->e.procinfo = ((struct dsym *)opndx->sym)->e.procinfo;
	}
	sym->mem_type = opndx->mem_type;
	/* v2.01: allow equates of variables with arbitrary type.
	 * Currently the expression evaluator sets opndx.mem_type
	 * to the mem_type of the type (i.e. QWORD for a struct with size 8),
	 * which is a bad idea in this case. So the original mem_type of the
	 * label is used instead.
	 */
	if ( opndx->sym->mem_type == MT_TYPE && opndx->explicit == FALSE ) {
	    sym->mem_type = opndx->sym->mem_type;
	    sym->type = opndx->sym->type;
	}
	sym->value3264 = 0; /* v2.09: added */
	sym->segment = opndx->sym->segment;

	/* labels are supposed to be added to the current segment's label_list chain.
	 * this isn't done for alias equates, for various reasons.
	 * consequently, if the alias was forward referenced, ensure that a third pass
	 * will be done! regression test forward5.asm.
	 */
	if ( sym->variable ) {
	    sym->offset = opndx->sym->offset + opndx->value;
	    if ( Parse_Pass == PASS_2 && sym->fwdref ) {
		ModuleInfo.PhaseError = TRUE;
	    }
	} else {
	    if( Parse_Pass != PASS_1 && sym->offset != ( opndx->sym->offset + opndx->value ) ) {
		ModuleInfo.PhaseError = TRUE;
	    }
	    sym->offset = opndx->sym->offset + opndx->value;
	    BackPatch( sym );
	}

    }
    return;
}

/* the '=' directive defines an assembly time variable.
 * this can only be a number (constant or relocatable).
 */

static struct asym * __fastcall CreateAssemblyTimeVariable( struct asm_tok tokenarray[] )
/***************************************************************************/
{
    struct asym		*sym;
    const char		*name = tokenarray[0].string_ptr;
    int			i = 2;
    struct expr		opnd;

    /* v2.08: for plain numbers ALWAYS avoid to call evaluator */
    if ( tokenarray[2].token == T_NUM &&
	tokenarray[3].token == T_FINAL ) {
	_atoow( &opnd.llvalue, tokenarray[i].string_ptr, tokenarray[i].numbase, tokenarray[i].itemlen );
    check_number:
	opnd.kind = EXPR_CONST;
	opnd.mem_type = MT_EMPTY; /* v2.07: added */
	/* v2.08: check added. the number must be 32-bit */
	if ( opnd.hlvalue != 0 ||
	    opnd.value64 < minintvalues[ModuleInfo.Ofssize] ||
	    opnd.value64 > maxintvalues[ModuleInfo.Ofssize] ) {
	    EmitConstError( &opnd );
	    return( NULL );
	}
    } else {
	/* v2.09: don't create not-(yet)-defined symbols. Example:
	 * E1 = E1 or 1
	 * must NOT create E1.
	 */
	if ( EvalOperand( &i, tokenarray, Token_Count, &opnd, 0 ) == ERROR )
	    return( NULL );
	if( tokenarray[i].token != T_FINAL ) {
	    asmerr(2008, tokenarray[i].string_ptr );
	    return( NULL );
	}

	/* expression may be a constant or a relocatable item.
	 * v2.09: kind may be EXPR_CONST and still include an undefined symbol.
	 * This is caused by MakeConst() in expreval.c. Brackets changed so
	 * opnd.sym is also checked for opnd.kind == EXPR_CONST.
	 */
	if( opnd.kind != EXPR_CONST &&
	   ( opnd.kind != EXPR_ADDR || opnd.indirect == TRUE ) ||
	    ( opnd.sym != NULL && opnd.sym->state != SYM_INTERNAL ) ) {
	    /* v2.09: no error if argument is a forward reference,
	     * but don't create the variable either. Will enforce an
	     * error if referenced symbol is still undefined in pass 2.
	     */
	    if( opnd.sym && opnd.sym->state == SYM_UNDEFINED && opnd.indirect == FALSE ) {
		if ( StoreState == FALSE ) FStoreLine(0); /* make sure this line is evaluated in pass two */
	    } else
		asmerr( 2026 );
	    return( NULL );
	}

	/* v2.08: accept any result that fits in 64-bits from expression evaluator */
	if ( opnd.hlvalue != 0 ) {
	    EmitConstError( &opnd );
	    return( NULL );
	}
	/* for quoted strings, the same restrictions as for plain numbers apply */
	if ( opnd.quoted_string )
	    goto check_number;
    }

    sym = SymSearch( name );
    if( sym == NULL || sym->state == SYM_UNDEFINED ) {
	if( sym == NULL ) {
	    sym = SymCreate( name );
	} else {
	    sym_remove_table( &SymTables[TAB_UNDEF], (struct dsym *)sym );
	    sym->fwdref = TRUE;
	}
	sym->issaved = StoreState; /* v2.10: added */
    } else if ( sym->state == SYM_EXTERNAL && sym->weak == TRUE && sym->mem_type == MT_EMPTY ) {
	sym_ext2int( sym );
	sym->issaved = StoreState; /* v2.10: added */
    } else {
	if ( sym->state != SYM_INTERNAL ||
	    ( sym->variable == FALSE &&
	     ( opnd.uvalue != sym->uvalue || opnd.hvalue != sym->value3264 ) ) ) {
	    asmerr( 2005, sym->name );
	    return( NULL );
	}
	/* v2.04a regression in v2.04. Do not save the variable when it
	 * is defined the first time
	 * v2.10: store state only when variable is changed and has been
	 * defined BEFORE SaveState() has been called.
	 */
	//if ( StoreState && sym->issaved == FALSE && sym->isdefined == TRUE ) {
	if ( StoreState && sym->issaved == FALSE ) {
	    SaveVariableState( sym );
	}
    }
    sym->variable = TRUE;
    /* v2.09: allow internal variables to be set */
    if ( sym->predefined && sym->sfunc_ptr )
	sym->sfunc_ptr( sym, &opnd );
    else
	SetValue( sym, &opnd );
    return( sym );
}

/* '=' directive.*/

int EqualSgnDirective( int i, struct asm_tok tokenarray[] )
/**************************************************************/
{
    struct asym *sym;

    if( tokenarray[0].token != T_ID ) {
	return( asmerr(2008, tokenarray[0].string_ptr ) );
    }
    if ( sym = CreateAssemblyTimeVariable( tokenarray ) ) {
	if ( ModuleInfo.list == TRUE ) {
	    LstWrite( LSTTYPE_EQUATE, 0, sym );
	}
	return( NOT_ERROR );
    }
    return( ERROR );
}

/* CreateVariable().
 * define an assembly time variable directly without using the token buffer.
 * this is used for some internally generated variables (SIZESTR, INSTR, @Cpu)
 * NO listing is written! The value is ensured to be max 16-bit wide.
 */
struct asym *CreateVariable( const char *name, int value )
/********************************************************/
{
    struct asym	     *sym;

    sym = SymSearch( name );
    if( sym == NULL ) {
	sym = SymCreate( name );
	sym->issaved = StoreState; /* v2.10 */
    } else if ( sym->state == SYM_UNDEFINED ) {
	sym_remove_table( &SymTables[TAB_UNDEF], (struct dsym *)sym );
	sym->fwdref = TRUE;
	sym->issaved = StoreState; /* v2.10 */
    } else {
	if ( sym->isequate == FALSE ) {
	    asmerr( 2005, name );
	    return( NULL );
	}
	sym->value3264 = 0;
	/*
	 * v2.09: don't save variable when it is defined the first time
	 * v2.10: store state only when variable is changed and has been
	 * defined BEFORE SaveState() has been called.
	 */
	if ( StoreState && sym->issaved == FALSE ) {
	    SaveVariableState( sym );
	}
    }
    sym->isdefined  = TRUE;
    sym->state	  = SYM_INTERNAL;
    sym->variable = TRUE;
    sym->value	  = value;
    sym->isequate = TRUE;
    return( sym );
}

/*
 * CreateConstant()
 * this is the worker behind EQU.
 * EQU may define 3 different types of equates:
 * - numeric constants (with or without "type")
 * - relocatable items ( aliases )
 * - text macros
 * the argument may be
 * - an expression which can be evaluated to a number or address
 * - a text literal (enclosed in <>)
 * - anything. This will also become a text literal.
 */

struct asym *CreateConstant( struct asm_tok tokenarray[] )
/********************************************************/
{
    struct asym		*sym;
    const char		*name = tokenarray[0].string_ptr;
    int			i = 2;
    ret_code		rc;
    char		*p;
    bool		cmpvalue = FALSE;
    struct expr		opnd;
    char		argbuffer[MAX_LINE_LEN];

    sym = SymSearch( name );

    /* if a literal follows, the equate MUST be(come) a text macro */
    if ( tokenarray[2].token == T_STRING && tokenarray[2].string_delim == '<' )
	return ( SetTextMacro( tokenarray, sym, name, NULL ) );

    if( sym == NULL ||
       sym->state == SYM_UNDEFINED ||
       ( sym->state == SYM_EXTERNAL && sym->weak == TRUE && sym->isproc == FALSE ) ) {
	/* It's a "new" equate.
	 * wait with definition until type of equate is clear
	 */
    } else if( sym->state == SYM_TMACRO ) {

	return ( SetTextMacro( tokenarray, sym, name, tokenarray[2].tokpos ) );

    } else if( sym->isequate == FALSE ) {

	asmerr( 2005, name );
	return( NULL );

    } else {
	if ( sym->asmpass == ( Parse_Pass & 0xFF ) )
	    cmpvalue = TRUE;
	sym->asmpass = Parse_Pass;
    }

    /* try to evaluate the expression */

    if ( tokenarray[2].token == T_NUM && Token_Count == 3 ) {

	p = tokenarray[2].string_ptr;
    do_single_number:
	/* value is a plain number. it will be accepted only if it fits into 32-bits.
	 * Else a text macro is created.
	 */
	_atoow( &opnd.llvalue, tokenarray[2].string_ptr, tokenarray[2].numbase, tokenarray[2].itemlen );
    check_single_number:
	opnd.instr = EMPTY;
	opnd.kind = EXPR_CONST;
	opnd.mem_type = MT_EMPTY; /* v2.07: added */
	opnd.flags1 = 0;
	/* v2.08: does it fit in 32-bits */
	if ( opnd.hlvalue == 0 && opnd.value64 >= minintvalues[ModuleInfo.Ofssize] &&
	    opnd.value64 <= maxintvalues[ModuleInfo.Ofssize] ) {
	    rc = NOT_ERROR;
	    i++;
	} else
	    return ( SetTextMacro( tokenarray, sym, name, p ) );

    } else {
	p = tokenarray[2].tokpos;
	if ( Parse_Pass == PASS_1 ) {
	    /* if the expression cannot be evaluated to a numeric value,
	     * it's to become a text macro. The value of this macro will be
	     * the original (unexpanded!) line - that's why it has to be
	     * saved here to argbuffer[].
	     */
	    strcpy( argbuffer, p );
	    /* expand EQU argument (macro functions won't be expanded!) */
	    if ( ExpandLineItems( p, 2, tokenarray, FALSE, TRUE ) )
		/* v2.08: if expansion result is a plain number, handle is specifically.
		 * this is necessary because values of expressions may be 64-bit now.
		 */
		p = argbuffer; /* ensure that p points to unexpanded source */
		if ( tokenarray[2].token == T_NUM && Token_Count == 3 ) {
		    goto do_single_number;
		}
	}
	rc = EvalOperand( &i, tokenarray, Token_Count, &opnd, EXPF_NOERRMSG | EXPF_NOUNDEF );

	/* v2.08: if it's a quoted string, handle it like a plain number */
	/* v2.10: quoted_string field is != 0 if kind == EXPR_FLOAT,
	 * so this is a regression in v2.08-2.09.
	 */
	if ( opnd.quoted_string && opnd.kind == EXPR_CONST ) {
	    i--; /* v2.09: added; regression in v2.08 and v2.08a */
	    goto check_single_number;
	}

	/* check here if last token has been reached? */
    }
    /* what is an acceptable 'number' for EQU?
     * 1. a numeric value - if magnitude is <= 64 (or 32, if it's a plain number)
     *	  This includes struct fields.
     * 2. an address - if it is direct, has a label and is of type SYM_INTERNAL -
     *	  that is, no forward references, no seg, groups, externals;
     *	  Anything else will be stored as a text macro.
     * v2.04: large parts rewritten.
     */
    if ( rc != ERROR &&
	tokenarray[i].token == T_FINAL &&
	( ( opnd.kind == EXPR_CONST && opnd.hlvalue == 0 ) || /* magnitude <= 64 bits? */
	 ( opnd.kind == EXPR_ADDR && opnd.indirect == FALSE &&
	  opnd.sym != NULL &&
	  //opnd.sym->state != SYM_EXTERNAL ) ) && /* SYM_SEG, SYM_GROUP are also not ok */
	  opnd.sym->state == SYM_INTERNAL ) ) &&
	( opnd.instr == EMPTY ) ) {

	if ( !sym ) {
	    sym = SymCreate( name );
	    sym->asmpass = Parse_Pass;
	} else if ( sym->state == SYM_UNDEFINED ) {
	    sym_remove_table( &SymTables[TAB_UNDEF], (struct dsym *)sym );
	    sym->fwdref = TRUE;
	} else if ( sym->state == SYM_EXTERNAL ) {
	    sym_ext2int( sym );
	} else if ( cmpvalue ) {
	    if ( opnd.kind == EXPR_CONST ) {
		/* for 64bit, it may be necessary to check 64bit value! */
		/* v2.08: always compare 64-bit values */
		if ( sym->value != opnd.value || sym->value3264 != opnd.hvalue ) {
		    asmerr( 2005, name );
		    return( NULL );
		}
	    } else if ( opnd.kind == EXPR_ADDR ) {
		if ( ( sym->offset != ( opnd.sym->offset + opnd.value ) ) || ( sym->segment != opnd.sym->segment ) ) {
		    asmerr( 2005, name );
		    return( NULL );
		}
	    }
	}
	sym->variable = FALSE;
	SetValue( sym, &opnd );
	return( sym );
    }
    return ( SetTextMacro( tokenarray, sym, name, argbuffer ) );
}

/* EQU directive.
 * This function is called rarely, since EQU
 * is a preprocessor directive handled directly inside PreprocessLine().
 * However, if fastpass is on, the preprocessor step is skipped in
 * pass 2 and later, and then this function may be called.
 */

int EquDirective( int i, struct asm_tok tokenarray[] )
/*********************************************************/
{
    struct asym *sym;

    if( tokenarray[0].token != T_ID ) {
	return( asmerr(2008, tokenarray[0].string_ptr ) );
    }
    if ( sym = CreateConstant( tokenarray ) ) {
	if ( ModuleInfo.list == TRUE ) {
	    LstWrite( LSTTYPE_EQUATE, 0, sym );
	}
	return( NOT_ERROR );
    }
    return( ERROR );
}