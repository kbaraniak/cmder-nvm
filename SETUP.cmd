@echo off
REM ===========================================================================
REM  cmder-nvm - SETUP
REM
REM  One-click bootstrap for a packed distribution. Run this from the folder
REM  that contains cmder-nvm.zip:
REM
REM      1. unpacks Cmder + cmder-nvm into .\cmder-nvm\ (unless it is already
REM         unpacked, which is the case in a git checkout)
REM      2. verifies the nvm-windows binary is present
REM      3. arranges for install.cmd to run automatically the first time Cmder
REM         opens, so the user is not left with an unconfigured terminal
REM      4. launches Cmder in that folder
REM
REM  Re-running this script is safe: an existing installation is left alone and
REM  install.cmd is only wired in while it has not run yet.
REM ===========================================================================
setlocal EnableExtensions

REM --- Resolve the folder holding this script --------------------------------
set "SETUP_ROOT=%~dp0"
if "%SETUP_ROOT:~-1%"=="\" set "SETUP_ROOT=%SETUP_ROOT:~0,-1%"
set "SETUP_ZIP=%SETUP_ROOT%\cmder-nvm.zip"
set "SETUP_NAME=cmder-nvm"

echo.
echo   cmder-nvm setup
echo   ===============
echo.

REM ===========================================================================
REM  1. Locate or unpack the payload
REM ===========================================================================

REM A git checkout already has Cmder.exe at the root, so use it in place. A
REM downloaded release ships the zip, which is unpacked into a subfolder to
REM keep the download folder tidy.
set "PAYLOAD="

if exist "%SETUP_ROOT%\Cmder.exe" (
    set "PAYLOAD=%SETUP_ROOT%"
    echo   [info] Using the existing unpacked distribution.
    goto :payload_ready
)

if not exist "%SETUP_ZIP%" (
    echo   [error] cmder-nvm.zip not found next to SETUP.cmd.
    echo.
    echo           Expected: %SETUP_ZIP%
    echo.
    echo           Download the latest release, or run this script from a
    echo           git checkout where Cmder.exe is already present.
    echo.
    exit /b 1
)

REM Skip the extraction when a previous run already unpacked it.
if exist "%SETUP_ROOT%\%SETUP_NAME%\Cmder.exe" (
    set "PAYLOAD=%SETUP_ROOT%\%SETUP_NAME%"
    echo   [info] Already unpacked, skipping extraction.
    goto :payload_ready
)

echo   [info] Unpacking %SETUP_ZIP% ...
call :unpack "%SETUP_ZIP%" "%SETUP_ROOT%\%SETUP_NAME%"
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
REM  2. Verify the nvm-windows binary
REM ===========================================================================

REM install.cmd downloads nvm.exe by itself when it is missing, so this is a
REM warning rather than a hard stop: setup can continue and let install.cmd
REM try to fetch it.
if not exist "%PAYLOAD%\bin\nvm.exe" (
    echo   [warn] bin\nvm.exe is missing.
    echo          install.cmd will attempt to download it on first run.
    echo.
)

REM ===========================================================================
REM  3. Wire install.cmd into the Cmder startup
REM ===========================================================================

REM Cmder calls %CMDER_ROOT%\config\user_profile.cmd on every shell start (see
REM vendor\init.bat), so a one-line conditional hook there is the reliable way
REM to run install.cmd exactly once, inside a real Cmder window.
REM
REM The guard is the presence of settings.txt: install.cmd creates it on a
REM successful run, so once it exists the hook becomes a no-op and Cmder starts
REM normally on subsequent launches.
set "HOOK_FILE=%PAYLOAD%\config\user_profile.cmd"

if not exist "%HOOK_FILE%" (
    echo   [error] %HOOK_FILE% is missing, cannot configure startup.
    echo.
    exit /b 1
)

findstr /c:"cmder-nvm: run install.cmd" "%HOOK_FILE%" >nul 2>&1
if not errorlevel 1 (
    echo   [info] install.cmd is already wired into the Cmder startup.
    goto :launch
)

REM Appended rather than overwritten so any customisations in user_profile.cmd
REM survive. The guard makes this a no-op once install.cmd has run.
>>"%HOOK_FILE%" echo @REM --- cmder-nvm: run install.cmd on first launch (added by SETUP.cmd) ---
>>"%HOOK_FILE%" echo @if not exist "%~dp0..\nodejs\settings.txt" call "%~dp0..\install.cmd"
>>"%HOOK_FILE%" echo @REM --- end cmder-nvm hook ---

echo   [ok]   install.cmd will run the first time Cmder opens.
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

REM /start makes Cmder open in the payload folder. The install hook above runs
REM inside that window on first launch.
start "" "%PAYLOAD%\Cmder.exe" /start "%PAYLOAD%"

exit /b 0


REM ===========================================================================
REM  :unpack <archive> <target-dir>
REM
REM  Extracts the distribution. Expand-Archive handles the zip on Windows 10
REM  and PowerShell 5+; bsdtar (shipped with Windows 10 1803+) is the fallback
REM  for anything older.
REM ===========================================================================
:unpack
set "UNPACK_ARCHIVE=%~1"
set "UNPACK_TARGET=%~2"

mkdir "%UNPACK_TARGET%" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Expand-Archive -Path $env:UNPACK_ARCHIVE -DestinationPath $env:UNPACK_TARGET -Force; exit 0 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto :unpack_done

tar -xf "%UNPACK_ARCHIVE%" -C "%UNPACK_TARGET%" >nul 2>&1
if errorlevel 1 (
    echo   [error] Failed to extract %UNPACK_ARCHIVE%
    exit /b 1
)

:unpack_done

REM A truncated or wrong archive must not be mistaken for a good unpack.
if not exist "%UNPACK_TARGET%\Cmder.exe" (
    echo   [error] Archive did not contain Cmder.exe.
    exit /b 1
)

echo   [ok]   Extracted to %UNPACK_TARGET%
exit /b 0