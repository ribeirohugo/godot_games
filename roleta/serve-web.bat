@echo off
rem Serves build\web\ on http://localhost:8060 and opens it in your browser.
rem Browsers can't run the game from a double-clicked index.html, it needs a web server.
setlocal
set "WEB=%~dp0build\web"

if not exist "%WEB%\index.html" (
    echo No web build found. Run export-web.bat first.
    exit /b 1
)

echo Serving %WEB% on http://localhost:8060  (press Ctrl+C to stop)
start "" http://localhost:8060
python -m http.server 8060 --bind 127.0.0.1 --directory "%WEB%"
