@echo off
REM ===========================================================================
REM  cmder-nvm - SETUP
REM
REM  One-click bootstrap for a packed distribution. Run this from the folder
REM  that contains the release archive:
REM
REM      1. unpacks the payload into .\cmder-nvm\ (unless it is already
REM         unpacked, which is the case in a git checkout)
REM      2. verifies bin\nvm.exe against manifest.json
REM      3. confirms the first-run hook is in place
REM      4. launches Cmder in that folder
REM
REM  This script never modifies config\user_profile.cmd. The first-run hook
REM  ships as config\profile.d\cmder-nvm.cmd, which Cmder executes on shell
REM  start, so installing does not dirty a git checkout.
REM
REM  Re-running this script is safe: an existing installation is left alone.
REM ===========================================================================
setlocal EnableExtensions

REM --- Resolve the folder holding this script --------------------------------
set "SETUP_ROOT=%~dp0"
if "%SETUP_ROOT:~-1%"=="\" set "SETUP_ROOT=%SETUP_ROOT:~0,-1%"
set "SETUP_NAME=cmder-nvm"

REM pack.cmd names the archive cmder-nvm-v^<VERSION^>.zip, but a plain
REM cmder-nvm.zip is also accepted so a hand-renamed download still works.
set "SETUP_ZIP="
if exist "%SETUP_ROOT%\cmder-nvm.zip" set "SETUP_ZIP=%SETUP_ROOT%\cmder-nvm.zip"
if not defined SETUP_ZIP for /f "usebackq delims=" %%z in (`dir /b /o-n "%SETUP_ROOT%\cmder-nvm-v*.zip" 2^>nul`) do (
    if not defined SETUP_ZIP set "SETUP_ZIP=%SETUP_ROOT%\%%z"
)

echo.
echo   cmder-nvm setup
echo   ===============
echo.

REM ===========================================================================
REM  1. Locate or unpack the payload
REM ===========================================================================

REM A git checkout already has Cmder.exe at the root, so use it in place. A
REM downloaded release ships the archive, which is unpacked into a subfolder
REM to keep the download folder tidy.
set "PAYLOAD="

if exist "%SETUP_ROOT%\Cmder.exe" (
    set "PAYLOAD=%SETUP_ROOT%"
    echo   [info] Using the existing unpacked distribution.
    goto :payload_ready
)

if not defined SETUP_ZIP goto :no_payload

REM Skip the extraction when a previous run already unpacked it.
if exist "%SETUP_ROOT%\%SETUP_NAME%\Cmder.exe" (
    set "PAYLOAD=%SETUP_ROOT%\%SETUP_NAME%"
    echo   [info] Already unpacked, skipping extraction.
    goto :payload_ready
)

echo   [info] Unpacking %SETUP_ZIP% ...
call :unpack "%SETUP_ZIP%" "%SETUP_ROOT%\%SETUP_NAME%" "%SETUP_ROOT%\%SETUP_NAME%\Cmder.exe"
if errorlevel 1 (
    echo.
    echo   [error] Could not unpack the archive.
    echo.
    exit /b 1
)
set "PAYLOAD=%SETUP_ROOT%\%SETUP_NAME%"

:payload_ready
echo   [info] Payload : %PAYLOAD%
echo.

REM ===========================================================================
REM  2. Verify nvm-windows
REM ===========================================================================
REM Nothing is downloaded during setup. nvm-windows is bundled and checked
REM against manifest.json, so a corrupted or tampered download is caught here
REM rather than at first use.

if not exist "%PAYLOAD%\bin\nvm.exe" (
    echo   [error] bin\nvm.exe is missing from the payload.
    echo.
    exit /b 1
)

call "%PAYLOAD%\lib\manifest.cmd" verify "%PAYLOAD%\bin\nvm.exe" "nvm-windows.sha256"
if errorlevel 1 (
    echo.
    echo   [error] bin\nvm.exe does not match manifest.json.
    echo.
    exit /b 1
)

echo   [ok]   nvm-windows verified against manifest.json.
echo.

REM ===========================================================================
REM  3. Confirm the first-run hook
REM ===========================================================================
REM Cmder runs every *.cmd in config\profile.d on shell start (vendor\init.bat
REM line 385), and that directory is already on PATH by then (line 377). The
REM hook is a shipped file, not something this script writes, so there is
REM nothing to append and nothing to undo on re-run.

if not exist "%PAYLOAD%\config\profile.d\cmder-nvm.cmd" (
    echo   [error] %PAYLOAD%\config\profile.d\cmder-nvm.cmd is missing.
    echo.
    echo           This payload is incomplete. Re-download the release zip.
    echo.
    exit /b 1
)

echo   [ok]   First-run hook: config\profile.d\cmder-nvm.cmd
echo.

REM ===========================================================================
REM  4. Launch Cmder
REM ===========================================================================

:launch
if not exist "%PAYLOAD%\Cmder.exe" (
    echo   [error] Cmder.exe not found in %PAYLOAD%
    echo.
    exit /b 1
)

echo   [info] Starting Cmder ...
echo.

REM /start makes Cmder open in the payload folder. The first-run hook runs
REM inside that window and prepares the environment.
start "" "%PAYLOAD%\Cmder.exe" /start "%PAYLOAD%"

exit /b 0

:no_payload
echo   [error] No cmder-nvm archive found next to SETUP.cmd, and this is not an
echo           unpacked checkout either.
echo.
echo           Expected one of:
echo             %SETUP_ROOT%\Cmder.exe
echo             %SETUP_ROOT%\cmder-nvm.zip
echo             %SETUP_ROOT%\cmder-nvm-v*.zip
echo.
echo           Download the latest release, or run this script from a git
echo           checkout.
echo.
exit /b 1


REM ===========================================================================
REM  :unpack <archive> <target-dir> <sentinel>
REM
REM  Extracts the distribution. Expand-Archive handles the zip on Windows 10
REM  and PowerShell 5+; bsdtar (shipped with Windows 10 1803+) is the fallback
REM  for anything older.
REM
REM  The sentinel is a file that must exist after a successful extraction, so a
REM  truncated or wrong archive is never mistaken for a good unpack.
REM ===========================================================================
:unpack
set "UNPACK_ARCHIVE=%~1"
set "UNPACK_TARGET=%~2"
set "UNPACK_SENTINEL=%~3"

mkdir "%UNPACK_TARGET%" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Expand-Archive -Path $env:UNPACK_ARCHIVE -DestinationPath $env:UNPACK_TARGET -Force; exit 0 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto :unpack_verify

tar -xf "%UNPACK_ARCHIVE%" -C "%UNPACK_TARGET%" >nul 2>&1
if errorlevel 1 (
    echo   [error] Failed to extract %UNPACK_ARCHIVE%
    exit /b 1
)

:unpack_verify
if not exist "%UNPACK_SENTINEL%" (
    echo   [error] %UNPACK_ARCHIVE% did not contain %UNPACK_SENTINEL%
    exit /b 1
)

echo   [ok]   Extracted to %UNPACK_TARGET%
exit /b 0
