@echo off
REM for /r %%i in (*.cue, *.gdi) do chdman.exe createcd -i "%%i" -o "%%~ni.chd" --force
REM timeout /t 10
call conf\config.bat
@echo off

set headertitle="PC Engine CD\TurboGraphix 16 CD-ROM .cue to .chd"
set headerdesc="Converts PC Engine CD\TurboGraphix 16 CD-ROM .cue and .bin files to an easy-to-manage .chd"
set headerlog=%0

call conf\log.bat
echo retro-tools v.%version% %headertitle% - %DATE%-%TIME%: > %log%

call conf\header.bat

setlocal enabledelayedexpansion
set rompath=%1
set "b="

:main
	echo -- ROMs location - [%1]
	if [%1] EQU [] (
		echo -- Missing folder for conversion. Exiting...
		goto :EOF
	)
	set /p p=-- ^(c^)onvert or e^(x^)it: 

	if "%p%" == "x" (
		set "s="
		goto :EOF
		)
	if "%p%" == "c" ( 
		goto dothedancefandango	
	) 

:dothedancefandango
:: Handle compressed files
for /r %1 %%z in (*.7z, *.zip, *.rar) DO ( 
	if exist "%rpipce%\%%~nz.chd" (
		echo  %%~nz.chd exists on %rpipce%
		echo  %DATE% %TIME% - [INFO] - %%~nz.chd available >> %log%
		) else (
		7z x -y "%%z" -o%1
		bin\chdman.exe createcd -i "%%~dz%%~pz%%~nz%%~xz" -o "%%~dz%%~pz%%~nz.chd" --force
		bin\chdman.exe verify -i "%%~dz%%~pz%%~nz.chd"
		if !ERRORLEVEL! NEQ 0 (
			echo [ERROR] Verification failed: %%~dz%%~pz%%~nz.chd - not copied, source files kept
			echo %DATE% %TIME% - [ERROR] - Verification failed: %%~dz%%~pz%%~nz.chd >> %log%
			) else (
			echo Copying %%~nz.chd to %rpipce%
			move /y "%%~dz%%~pz%%~nz.chd" "%rpipce%"
			if exist "%rpipce%\%%~nz.chd" ( echo %DATE% %TIME% - [INFO] - Copied %%~nz.chd to %rpipce% >> %log% )
			if not exist "%rpipce%\%%~nz.chd" ( echo %DATE% %TIME% - [ERROR] - Copy failed: %%~nz.chd to %rpipce% >> %log% )
			if exist "%rpipce%\%%~nz.chd" (
				for /r %1 %%b in (*.cue, *.bin) DO (
					del %%b
					echo Deleted %%b
					set "b="
				)
			)
		)
		)
	)

:: Handle uncompressed files
for /r %1 %%z in (*.cue, *.iso) DO (
	if exist "%rpipce%\%%~nz.chd" (
		 echo %%~nz.chd exists on %rpipce%
		 echo %DATE% %TIME% - [INFO] - %%~nz.chd available >> %log%
		) else (
		bin\chdman.exe createcd -i "%%~dz%%~pz%%~nz%%~xz" -o "%%~dz%%~pz%%~nz.chd" --force
		bin\chdman.exe verify -i "%%~dz%%~pz%%~nz.chd"
		if !ERRORLEVEL! NEQ 0 (
			echo [ERROR] Verification failed: %%~dz%%~pz%%~nz.chd - not copied, source files kept
			echo %DATE% %TIME% - [ERROR] - Verification failed: %%~dz%%~pz%%~nz.chd >> %log%
			) else (
			echo Copying %%~nz.chd to %rpipce%
			move /y "%%~dz%%~pz%%~nz.chd" "%rpipce%"
			if exist "%rpipce%\%%~nz.chd" ( echo %DATE% %TIME% - [INFO] - Copied %%~nz.chd to %rpipce% >> %log% )
			if not exist "%rpipce%\%%~nz.chd" ( echo %DATE% %TIME% - [ERROR] - Copy failed: %%~nz.chd to %rpipce% >> %log% )
			)
		)
	)