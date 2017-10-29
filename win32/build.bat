@echo off
Setlocal EnableDelayedExpansion
set basename=x64-vcruntime140-ruby240

set optflagsbase=/O2 /GL /Zo /Zi /favor:INTEL64 /arch:AVX
set ldflagsbase=/incremental:no /debug /opt:ref /opt:icf
set basedir=%~dp0
set outdir=!basedir!usr
set verbose=

@mkdir !basedir!build 2>nul
cd !basedir!build

if "%1" neq "" (
	set next=%1
	shift
	goto !next!
)

:link
@rem for the extensions
call :miniruby

@rem for core ruby
del !basename!.dll
@if not exist !basename!.pgd (
   call :doinstrument
)
del !basename!.dll
nmake !verbose! up install "OPTFLAGS=!optflagsbase!" "LDFLAGS=!ldflagsbase! /LTCG:PGUPDATE"
@if errorlevel 1 ( exit %errorlevel% )
mkdir !outdir!\lib\ruby\vendor_ruby\rubygems\defaults\
copy !basedir!\rubygems_hooks.rb  !outdir!\lib\ruby\vendor_ruby\rubygems\defaults\operating_system.rb
@if errorlevel 1 ( exit %errorlevel% )
@if "%CI%" equ "" (
	signtool sign /a /t http://time.certum.pl !outdir!\bin\*.exe !outdir!\bin\!basename!.dll
)
goto :eof

:miniruby
nmake !verbose! "OPTFLAGS=!optflagsbase!" "LDFLAGS=!ldflagsbase! /LTCG" miniruby
@if errorlevel 1 ( exit %errorlevel% )
goto :eof

:rebuild
call :clean
goto :link

:instrument
call :doinstrument
copy /y !basename!.dll !outdir!\bin\!basename!.dll
echo Run the test scenarios you wish to optimise for using the binary in usr\bin, then rerun '%0 optimise'
goto :eof

:doinstrument
del *.dll
nmake !verbose! "OPTFLAGS=!optflagsbase!" "LDFLAGS=!ldflagsbase! /LTCG:PGINSTRUMENT"
@if errorlevel 1 ( exit %errorlevel% )
goto :eof

:optimise
@rem Remove the profile information generated by ruby calls used in the build process.
del *.pgc
echo Place all the .pgc files in the win32\usr\bin directory.
pause
move !outdir!\bin\!basename!*.pgc .\
del !outdir!\bin\*.pgc
pgomgr /merge !basename!.pgd
del !basename!.pgc

goto :link

:configure
set params=
:configure_loop
if [%1]==[] goto configure_afterloop
set params=!params! %1
shift
goto configure_loop
:configure_afterloop

call !basedir!configure --prefix=!outdir! --without-ext "dbm,gdbm,dl/callback,pty,readline,syslog,tk,tk/tkutil" --disable-install-doc --target=x64-mswin64 !params!
call :clean

:clean
nmake clean
@if errorlevel 1 ( exit %errorlevel% )
del !basename!.pgd
