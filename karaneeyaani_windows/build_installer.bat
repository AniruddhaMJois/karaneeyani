@echo off
setlocal enabledelayedexpansion

echo =======================================================
echo   Karaneeyaani - Windows Installer Build Script
echo =======================================================
echo.

cd /d "%~dp0"

echo [1/3] Fetching Flutter dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] Flutter pub get failed.
    exit /b %errorlevel%
)

echo.
echo [2/3] Compiling Windows Desktop Release binary (karaneeyaani.exe)...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo [ERROR] Flutter build windows failed. Please verify Visual Studio 2022 with C++ desktop workload is installed.
    exit /b %errorlevel%
)

echo.
echo [3/3] Packaging Windows Setup Installer (.exe)...
where iscc >nul 2>nul
if %errorlevel% equ 0 (
    echo Compiling Inno Setup installer package...
    iscc "windows\installer\karaneeyaani_installer.iss"
    if %errorlevel% equ 0 (
        echo.
        echo =======================================================
        echo   BUILD SUCCESSFUL!
        echo.
        echo   Direct Installer Location:
        echo   %~dp0build\installer\Karaneeyaani-Setup.exe
        echo.
        echo   Standalone Release Binary Location:
        echo   %~dp0build\windows\x64\runner\Release\karaneeyaani.exe
        echo =======================================================
    ) else (
        echo [WARNING] Inno Setup compilation failed.
    )
) else (
    echo [INFO] Inno Setup Compiler (iscc.exe) was not found in PATH.
    echo Standalone executable bundle is ready at:
    echo   %~dp0build\windows\x64\runner\Release\karaneeyaani.exe
    echo.
    echo To package into a single Karaneeyaani-Setup.exe installer:
    echo   1. Install Inno Setup: winget install JRSoftware.InnoSetup
    echo   2. Re-run this script, or compile windows\installer\karaneeyaani_installer.iss
)

echo.
pause
