@echo off
rem Opens this project in the Godot editor.
setlocal
call "%~dp0_config.bat" || exit /b 1
start "" "%GODOT%" --path "%PROJECT%" -e
