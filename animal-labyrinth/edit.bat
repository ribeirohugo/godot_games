@echo off
rem Opens this project in the Godot editor.
setlocal
call "%~dp0..\_config.bat" "%~dp0." || exit /b 1
start "" "%GODOT%" --path "%PROJECT%" -e
