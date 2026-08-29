@echo off
REM Build debug APK (arm64-v8a only)
REM abiFilters is already set to arm64-v8a in app/build.gradle defaultConfig

setlocal
cd /d "%~dp0"

echo.
echo [1/2] Building debug APK (arm64-v8a only)...
call gradlew.bat assembleDebug --no-daemon
if errorlevel 1 (
    echo.
    echo BUILD FAILED
    exit /b 1
)

echo.
echo [2/2] Done. Output APK:
for /f "delims=" %%f in ('dir /b /s "app\build\outputs\apk\debug\app-debug.apk"') do set APK=%%f
if defined APK (
    echo   %APK%
    for %%A in ("%APK%") do echo   size=%%~zA bytes
) else (
    echo   APK not found!
)

echo.
echo Build finished.
endlocal
