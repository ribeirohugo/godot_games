@echo off
rem Builds an MSIX package for the Microsoft Store into build\msix\ (see ..\_msix.ps1).
rem Store values come from msix.env. Run "export-msix.bat sign" to also sign it with a local test
rem certificate, so it can be installed on this PC before uploading.
setlocal
call "%~dp0..\_config.bat" "%~dp0." || exit /b 1

if not exist "%TEMPLATES%\windows_release_x86_64.exe" (
    echo Windows export templates not found in:
    echo   %TEMPLATES%
    echo Install them: open the editor, Editor ^> Manage Export Templates ^> Download and Install.
    exit /b 1
)

set "SIGN="
if /i "%~1"=="sign" set "SIGN=-Sign"

set "PS=powershell"
where pwsh >nul 2>nul && set "PS=pwsh"
%PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\_msix.ps1" -Project "%PROJECT%" -Godot "%GODOT_CONSOLE%" -Exe Jogo24.exe %SIGN%
if errorlevel 1 exit /b 1
