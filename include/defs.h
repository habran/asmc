#ifndef __INC_DEFS
#define __INC_DEFS
#define _ASMLIB_ 224
#ifdef __cplusplus
 extern "C" {
#endif

#ifndef WINAPI
#ifdef _M_X64
#define WINAPI
#else
#define WINAPI __stdcall
#endif
#endif
#ifdef	_DLL
#define _CRTIMP __declspec(dllimport)
#else
#define _CRTIMP
#endif

typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef unsigned long DWORD;
typedef unsigned __int64 QWORD;

#define _OFF_T_DEFINED
#define _SIZE_T_DEFINED
#ifdef _WIN64
typedef __int64 _off_t;
typedef unsigned __int64 size_t;
typedef __int64 intptr_t;
#else
typedef long _off_t;
typedef unsigned int size_t;
typedef int intptr_t;
#endif

#define _TIME_T_DEFINED
#define _INO_T_DEFINED
#define _WCHAR_T_DEFINED
#define _DEV_T_DEFINED
#define _VA_LIST_DEFINED
typedef long time_t;
typedef unsigned short _ino_t;
typedef unsigned short wchar_t;
typedef unsigned int _dev_t;
typedef char * va_list;
typedef wchar_t wint_t;
typedef wchar_t wctype_t;

#define NULL	0

#ifdef __cplusplus
 }
#endif
#endif
