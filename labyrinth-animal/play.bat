@echo off
rem Runs the game directly, without the editor.
setlocal
call "%~dp0_config.bat" || exit /b 1
start "" "%GODOT%" --path "%PROJECT%"
