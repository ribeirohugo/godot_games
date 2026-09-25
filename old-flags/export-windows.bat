@echo off
rem Exports the game as a standalone Windows .exe into build\windows\.
setlocal
call "%~dp0..\_config.bat" "%~dp0." || exit /b 1

if not exist "%TEMPLATES%\windows_release_x86_64.exe" (
    echo Windows export templates not found in:
    echo   %TEMPLATES%
    echo Install them: open the editor, Editor ^> Manage Export Templates ^> Download and Install.
    exit /b 1
)

if not exist "%PROJECT%\build\windows" mkdir "%PROJECT%\build\windows"
"%GODOT_CONSOLE%" --headless --path "%PROJECT%" --export-release "Windows" "%PROJECT%\build\windows\OldFlags.exe"
if errorlevel 1 (
    echo Export failed, see the messages above.
    exit /b 1
)
echo.
echo Done: build\windows\OldFlags.exe
