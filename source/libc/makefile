!include srcpath

AFLAGS	= /coff /Cs /Zi /I$(inc_dir) /r
LFLAGS	= /q /b /n /c /fac

$(lib_dir)\libc.lib:
	asmc $(AFLAGS) $(src_dir)\libc\*.asm
	libw $(LFLAGS) $@ *.obj
	del *.obj
