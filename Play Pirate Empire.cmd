@echo off
REM ===================================================================
REM  Play Pirate Empire — double-click launcher
REM
REM  Runs the game directly from source with the Godot engine. This is
REM  NOT a packaged .exe: building one needs Godot's export templates,
REM  which are not installed on this machine (see docs/09_VISUAL_BUG_
REM  TRACKER.md). Nothing is compiled or copied — the game runs from the
REM  project folder, so any code change is picked up on next launch.
REM
REM  If you move the Godot install, edit GODOT below. The path is kept
REM  in sync with the GODOT_PATH in .mcp.json.
REM ===================================================================

setlocal

set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe"

REM Run from this script's own folder, so the launcher works no matter
REM what the working directory is when it gets double-clicked.
REM
REM %~dp0 always ends in a backslash, and "%PROJECT%" would therefore expand
REM to "D:\Pirate-game\" — where the trailing \" escapes the closing quote and
REM Godot receives a mangled path ('Invalid project path specified'). Strip the
REM trailing backslash so the quoted argument terminates properly.
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

if not exist "%GODOT%" (
	echo.
	echo  ERROR: Could not find the Godot engine.
	echo.
	echo    Looked for: %GODOT%
	echo.
	echo  The engine is not stored in this project ^(it is gitignored^),
	echo  so it has to be installed separately. Install Godot 4.x, then
	echo  edit the GODOT line in this file to point at the new location.
	echo.
	pause
	exit /b 1
)

if not exist "%PROJECT%\project.godot" (
	echo.
	echo  ERROR: No project.godot next to this launcher.
	echo  Keep this file in the Pirate-game project root.
	echo.
	pause
	exit /b 1
)

echo Launching Pirate Empire...
"%GODOT%" --path "%PROJECT%"
set "EXITCODE=%ERRORLEVEL%"

REM Only hold the window open on a crash — a clean exit just closes.
if not "%EXITCODE%"=="0" (
	echo.
	echo  The game exited with code %EXITCODE%.
	echo  If it crashed, the error text above is the useful part.
	echo.
	pause
)

endlocal
exit /b %EXITCODE%
