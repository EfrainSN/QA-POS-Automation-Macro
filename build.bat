@echo off
setlocal enabledelayedexpansion
title Compilador QA POS Automation Macro

echo ==============================================================================
echo  COMPILACION AUTOMATICA - QA POS AUTOMATION MACRO
echo ==============================================================================

set "AHK2EXE=%LOCALAPPDATA%\Programs\AutoHotkey\Compiler\Ahk2Exe.exe"
if not exist "%AHK2EXE%" set "AHK2EXE=C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
set "BASE64=%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe"
if not exist "%BASE64%" set "BASE64=C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
set "BASE32=%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey32.exe"
if not exist "%BASE32%" set "BASE32=C:\Program Files\AutoHotkey\v2\AutoHotkey32.exe"

if not exist "%AHK2EXE%" (
    echo [ERROR] No se encontro Ahk2Exe.exe en las rutas estandar.
    pause
    exit /b 1
)

for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command "(Get-Content '%~dp0QA_POS_Automation_Macro.ahk' -TotalCount 15 | Select-String 'VERSION:\s*([0-9]+\.[0-9]+)').Matches.Groups[1].Value"`) do (
    set "VER_NUM=%%A"
)
if "%VER_NUM%"=="" set "VER_NUM=2.3"
set "VER_TAG=v%VER_NUM%"

echo [*] Version detectada: %VER_TAG%
echo [*] Compilador: %AHK2EXE%

set "OUT64=%~dp0QA_POS_Automation_Macro_%VER_TAG%.exe"
set "OUT32=%~dp0QA_POS_Automation_Macro_%VER_TAG%_x86.exe"

echo.
echo [*] Compilando version x64: %OUT64%
"%AHK2EXE%" /in "%~dp0QA_POS_Automation_Macro.ahk" /out "%OUT64%" /base "%BASE64%"
if %errorlevel% neq 0 (
    echo [ERROR] Fallo la compilacion x64.
    pause
    exit /b 1
)
echo [OK] Compilacion x64 completada.

echo.
echo [*] Compilando version x86 (32 bits): %OUT32%
"%AHK2EXE%" /in "%~dp0QA_POS_Automation_Macro.ahk" /out "%OUT32%" /base "%BASE32%"
if %errorlevel% neq 0 (
    echo [ERROR] Fallo la compilacion x86.
    pause
    exit /b 1
)
echo [OK] Compilacion x86 completada.

echo.
echo ==============================================================================
echo  COMPILACION EXITOSA:
echo   - %OUT64%
echo   - %OUT32%
echo ==============================================================================
ping -n 3 127.0.0.1 >nul
