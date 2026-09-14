@echo off
rem Shared settings for the .bat scripts in every game folder.
rem Usage from a game folder:  call "%~dp0..\_config.bat" "%~dp0." || exit /b 1
rem Godot's location comes from .env next to this file (see .env.example).

rem Game project folder passed by the caller.
set "PROJECT=%~1"

set "ENV_FILE=%~dp0.env"
if not exist "%ENV_FILE%" (
    echo Settings file not found: %ENV_FILE%
    echo Copy .env.example to .env and set your Godot path.
    exit /b 1
)

rem Read KEY=VALUE lines; lines starting with # are comments.
for /f "usebackq eol=# tokens=1,* delims==" %%a in ("%ENV_FILE%") do set "%%a=%%b"

if not defined GODOT (
    echo GODOT is not set in %ENV_FILE%
    exit /b 1
)
if not defined GODOT_VERSION (
    echo GODOT_VERSION is not set in %ENV_FILE%
    exit /b 1
)
if not exist "%GODOT%" (
    echo Godot not found at:
    echo   %GODOT%
    echo Fix the GODOT path in %ENV_FILE%
    exit /b 1
)

rem The _console.exe next to Godot prints output to this terminal and waits until done.
set "GODOT_CONSOLE=%GODOT:.exe=_console.exe%"

rem .NET (mono) builds use their own templates; "mono" in the path marks them.
set "TEMPLATES=%APPDATA%\Godot\export_templates\%GODOT_VERSION%.stable"
if not "%GODOT:mono=%"=="%GODOT%" set "TEMPLATES=%TEMPLATES%.mono"

rem Shared code (like the intro) lives in common\ next to this file. Godot can only load files
rem inside the project, so each folder in it is mirrored into <game>\common\ before every run.
rem Edit the files in the root common\, not the copies: the copies are overwritten each time.
for /d %%d in ("%~dp0common\*") do (
    robocopy "%%d" "%PROJECT%\common\%%~nxd" /MIR /NJH /NJS /NFL /NDL /NP >nul
    if errorlevel 8 (
        echo Could not copy %%d into %PROJECT%\common
        exit /b 1
    )
)
exit /b 0
