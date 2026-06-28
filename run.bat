@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title Skadoosh Launcher
set "VER=4.3-stable"
set "BIN=%~dp0.godot-bin"
set "EXE=%BIN%\Godot_v%VER%_win64.exe"
set "GODOT_BIN="

REM ============================================================
REM  Auto-update from GitHub (quietly skipped if offline).
REM  Kept at the top so the relaunch after an update is safe.
REM ============================================================
set "REPO=avtandili-babilodze/Skadoosh"
set "BRANCH=main"
set "VERFILE=%~dp0.skadoosh_version"
if defined SKADOOSH_NOUPDATE goto afterupdate

echo Checking for updates...
set "REMOTE="
for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "try { (Invoke-RestMethod -UseBasicParsing -Headers @{ 'User-Agent'='Skadoosh' } 'https://api.github.com/repos/%REPO%/commits/%BRANCH%').sha } catch { '' }"`) do set "REMOTE=%%S"
if not defined REMOTE ( echo   Update check skipped - offline? & goto afterupdate )
if not exist "%VERFILE%" ( >"%VERFILE%" echo !REMOTE!& goto afterupdate )
set "LOCALV="
set /p LOCALV=<"%VERFILE%"
if /i "!REMOTE!"=="!LOCALV!" ( echo   Already up to date.& goto afterupdate )

echo   New version found - downloading update...
powershell -NoProfile -Command "$ErrorActionPreference='Stop'; try { $z=Join-Path $env:TEMP 'skadoosh_update.zip'; $d=Join-Path $env:TEMP 'skadoosh_update'; Invoke-WebRequest -UseBasicParsing 'https://codeload.github.com/%REPO%/zip/refs/heads/%BRANCH%' -OutFile $z; if(Test-Path $d){Remove-Item -Recurse -Force $d}; Expand-Archive -Force $z $d; $src=Get-ChildItem -Directory $d | Select-Object -First 1; Copy-Item -Recurse -Force (Join-Path $src.FullName '*') '%~dp0'; Remove-Item -Recurse -Force $d,$z; exit 0 } catch { exit 1 }"
if errorlevel 1 ( echo   Update failed - launching current version.& goto afterupdate )
>"%VERFILE%" echo !REMOTE!
if exist "%~dp0.godot" rmdir /s /q "%~dp0.godot"
echo   Update complete - restarting...
set SKADOOSH_NOUPDATE=1
start "" "%~f0"
exit
:afterupdate

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
REM First run / after update: build the asset import cache.
if not exist "%CD%\.godot\imported" (
    echo First run - importing assets, please wait...
    "%GODOT_BIN%" --path "%CD%" --headless --import
)

echo.
echo Starting Skadoosh...
echo (Logging to "%~dp0skadoosh-log.txt")
echo.
"%GODOT_BIN%" --path "%CD%" --verbose > "%~dp0skadoosh-log.txt" 2>&1
set "RC=%errorlevel%"
echo.
echo Godot exited with code %RC%.
if %RC% neq 0 (
    echo.
    echo The game closed unexpectedly. Last 30 lines of the log:
    echo ------------------------------------------------------------
    powershell -NoProfile -Command "Get-Content '%~dp0skadoosh-log.txt' -Tail 30"
    echo ------------------------------------------------------------
    echo Full log saved to skadoosh-log.txt
)
pause
exit /b %RC%

:error
echo.
echo ============================================================
echo  Something went wrong launching Skadoosh.
echo  - If the download failed, check your internet connection.
echo  - You can also install Godot 4.3 yourself and re-run this.
echo ============================================================
pause
exit /b 1
