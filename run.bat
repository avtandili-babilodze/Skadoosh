@echo off
cd /d "%~dp0"
title Skadoosh Launcher

set "VER=4.3-stable"
set "BIN=%~dp0.godot-bin"
set "EXE=%BIN%\Godot_v%VER%_win64.exe"
set "GODOT_BIN="

echo Looking for Godot 4.3...

REM 1) Explicit %GODOT% override (a full path to a Godot .exe).
if not "%GODOT%"=="" if exist "%GODOT%" set "GODOT_BIN=%GODOT%"
if defined GODOT_BIN goto launch

REM 2) Godot already on PATH.
where godot >nul 2>&1
if %errorlevel% equ 0 set "GODOT_BIN=godot"
if defined GODOT_BIN goto launch

REM 3) A copy we downloaded on a previous run.
if exist "%EXE%" set "GODOT_BIN=%EXE%"
if defined GODOT_BIN goto launch

REM 4) Download Godot (one-time, no system install needed).
echo.
echo Godot was not found. Downloading Godot %VER% (one-time, ~70 MB)...
echo Please wait, this may take a minute...
if not exist "%BIN%" mkdir "%BIN%"
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri 'https://github.com/godotengine/godot/releases/download/%VER%/Godot_v%VER%_win64.exe.zip' -OutFile '%BIN%\godot.zip' } catch { exit 1 }"
if %errorlevel% neq 0 goto error

echo Extracting...
powershell -NoProfile -Command "try { Expand-Archive -Force -Path '%BIN%\godot.zip' -DestinationPath '%BIN%' } catch { exit 1 }"
if %errorlevel% neq 0 goto error
del "%BIN%\godot.zip" >nul 2>&1
set "GODOT_BIN=%EXE%"

:launch
echo.
echo Starting Skadoosh...
"%GODOT_BIN%" --path "%CD%"
if %errorlevel% neq 0 goto error
exit /b 0

:error
echo.
echo ============================================================
echo  Something went wrong launching Skadoosh.
echo  - If the download failed, check your internet connection.
echo  - You can also install Godot 4.3 yourself and re-run this.
echo ============================================================
pause
exit /b 1
