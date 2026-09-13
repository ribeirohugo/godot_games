@echo off
rem Exports the game for browsers into build\web\.
setlocal
call "%~dp0..\_config.bat" "%~dp0." || exit /b 1

if not exist "%TEMPLATES%\web_nothreads_release.zip" (
    echo Web export templates not found in:
    echo   %TEMPLATES%
    echo Install them: open the editor, Editor ^> Manage Export Templates ^> Download and Install.
    exit /b 1
)

if not exist "%PROJECT%\build\web" mkdir "%PROJECT%\build\web"
"%GODOT_CONSOLE%" --headless --path "%PROJECT%" --export-release "Web" "%PROJECT%\build\web\index.html"
if errorlevel 1 (
    echo Export failed, see the messages above.
    exit /b 1
)
echo.
echo Done: build\web\index.html
echo Run serve-web.bat to play it in your browser.
