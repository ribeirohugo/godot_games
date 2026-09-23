@echo off
rem Exports a signed Android APK for the Amazon Appstore into build\amazon\.
rem The release keystore comes from ANDROID_KEYSTORE* in ..\.env (see ..\.env.example).
rem Raise version/code (and version/name) of the "Android" preset in export_presets.cfg for every upload.
setlocal
call "%~dp0..\_config.bat" "%~dp0." || exit /b 1

if not exist "%TEMPLATES%\android_release.apk" (
    echo Android export templates not found in:
    echo   %TEMPLATES%
    echo Install them: open the editor, Editor ^> Manage Export Templates ^> Download and Install.
    exit /b 1
)

if not defined ANDROID_KEYSTORE (
    echo ANDROID_KEYSTORE is not set in ..\.env, see ..\.env.example.
    exit /b 1
)
if not exist "%ANDROID_KEYSTORE%" (
    echo Keystore not found: %ANDROID_KEYSTORE%
    echo Create it once and keep a backup: every update of the app must be signed with the same key.
    echo   keytool -genkeypair -v -keystore "%ANDROID_KEYSTORE%" -alias %ANDROID_KEYSTORE_USER% -keyalg RSA -keysize 2048 -validity 10000
    echo Use the ANDROID_KEYSTORE_PASSWORD from .env as both the keystore and the key password.
    exit /b 1
)

rem Godot reads the release keystore from these variables, so no secrets go in export_presets.cfg.
set "GODOT_ANDROID_KEYSTORE_RELEASE_PATH=%ANDROID_KEYSTORE%"
set "GODOT_ANDROID_KEYSTORE_RELEASE_USER=%ANDROID_KEYSTORE_USER%"
set "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=%ANDROID_KEYSTORE_PASSWORD%"

if not exist "%PROJECT%\build\amazon" mkdir "%PROJECT%\build\amazon"
"%GODOT_CONSOLE%" --headless --path "%PROJECT%" --export-release "Android" "%PROJECT%\build\amazon\AnimalLabyrinth.apk"
if errorlevel 1 (
    echo Export failed, see the messages above.
    exit /b 1
)
echo.
echo Done: build\amazon\AnimalLabyrinth.apk
