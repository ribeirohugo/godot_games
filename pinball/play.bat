@echo off
rem Runs the game directly, without the editor.
setlocal
call "%~dp0..\_config.bat" "%~dp0." || exit /b 1
start "" "%GODOT%" --path "%PROJECT%"
