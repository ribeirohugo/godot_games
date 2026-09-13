@echo off
rem Shared settings for the other .bat scripts in this folder.
rem If you move Godot, change the path below (or set a GODOT environment variable).

if not defined GODOT set "GODOT=C:\etc\godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"

rem The _console.exe next to Godot prints output to this terminal and waits until done.
set "GODOT_CONSOLE=%GODOT:.exe=_console.exe%"

rem Trailing "." avoids a backslash right before a closing quote.
set "PROJECT=%~dp0."

set "TEMPLATE_VERSION=4.7.2.stable"
echo %GODOT% | find /i "mono" >nul && set "TEMPLATE_VERSION=4.7.2.stable.mono"
set "TEMPLATES=%APPDATA%\Godot\export_templates\%TEMPLATE_VERSION%"

if not exist "%GODOT%" (
    echo Godot not found at:
    echo   %GODOT%
    echo Edit _config.bat with the right path.
    exit /b 1
)
exit /b 0
