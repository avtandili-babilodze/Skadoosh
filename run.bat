@echo off
REM One-click launcher for Skadoosh (Windows).
REM Downloads Godot 4.3 automatically on first run, then plays the game.
setlocal
set "DIR=%~dp0"
set "VER=4.3-stable"
set "BIN=%DIR%.godot-bin"
set "EXE=%BIN%\Godot_v%VER%_win64.exe"

REM 1) Use Godot from PATH if available.
where godot >nul 2>nul && (set "GODOT=godot" & goto run)

REM 2) Use a previously downloaded local copy.
if exist "%EXE%" (set "GODOT=%EXE%" & goto run)

REM 3) Otherwise download a local copy (no system install needed).
echo Godot not found. Downloading Godot %VER% (one-time, ~70 MB)...
if not exist "%BIN%" mkdir "%BIN%"
powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://github.com/godotengine/godot/releases/download/%VER%/Godot_v%VER%_win64.exe.zip' -OutFile '%BIN%\godot.zip'"
powershell -NoProfile -Command "Expand-Archive -Force -Path '%BIN%\godot.zip' -DestinationPath '%BIN%'"
del "%BIN%\godot.zip"
set "GODOT=%EXE%"

:run
echo Launching Skadoosh with: %GODOT%
"%GODOT%" --path "%DIR%"
endlocal
