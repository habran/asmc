!include srcpath

regress:
	echo.
	echo.
	if exist *.exe del *.exe
	if exist *.obj del *.obj
	for %%f in (src\*.asm) do call :testasm %%f
	echo.
	exit
	:testasm
	asmc -q -ws -D_UNICODE -DDEBUG -I$(inc_dir) %1
	linkw op q symt _wcstart file %~n1
	if not exist %~n1.exe exit
	%~n1
	if errorlevel 1 exit
	echo.
	del %~n1.obj
	del %~n1.exe

