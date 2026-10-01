@echo off
REM ===========================================================================
REM  cmder-nvm - SETUP
REM
REM  One-click bootstrap. This is the only script a user needs to run.
REM
REM      1. locates the payload: the checkout it runs from, or the release
REM         archive next to it
REM      2. unpacks Cmder from lib\cmder-<version>.zip after verifying its
REM         SHA-256 against manifest.json
REM      3. verifies bin\nvm.exe against manifest.json
REM      4. installs the first-run hook into config\profile.d\
REM      5. launches Cmder, which runs the hook and prepares Node.js
REM
REM  Nothing is downloaded: Cmder and nvm-windows are both bundled, so the
REM  bootstrap works with no network. This script never modifies a tracked
REM  file, so installing in a checkout leaves `git status` clean.
REM
REM  Re-running this script is safe: it is idempotent at every step.
REM ===========================================================================
setlocal EnableExtensions

REM --- Resolve the folder holding this script --------------------------------
set "SETUP_ROOT=%~dp0"
if "%SETUP_ROOT:~-1%"=="\" set "SETUP_ROOT=%SETUP_ROOT:~0,-1%"
set "SETUP_NAME=cmder-nvm"

echo.
echo   cmder-nvm setup
echo   ===============
echo.

REM ===========================================================================
REM  1. Locate the payload
REM ===========================================================================
REM Two shapes are supported: a checkout (or an already-unpacked release),
REM where lib\manifest.cmd is right here; and a downloaded release, where the
REM archive sits next to SETUP.cmd and is unpacked into a subfolder.
set "PAYLOAD="

if exist "%SETUP_ROOT%\lib\manifest.cmd" (
    set "PAYLOAD=%SETUP_ROOT%"
    echo   [info] Using the existing unpacked distribution.
    goto :payload_ready
)

REM pack.cmd names the archive cmder-nvm-v^<VERSION^>.zip, but a plain
REM cmder-nvm.zip is also accepted so a hand-renamed download still works.
set "SETUP_ZIP="
if exist "%SETUP_ROOT%\cmder-nvm.zip" set "SETUP_ZIP=%SETUP_ROOT%\cmder-nvm.zip"
if not defined SETUP_ZIP for /f "usebackq delims=" %%z in (`dir /b /o-n "%SETUP_ROOT%\cmder-nvm-v*.zip" 2^>nul`) do (
    if not defined SETUP_ZIP set "SETUP_ZIP=%SETUP_ROOT%\%%z"
)

if not defined SETUP_ZIP goto :no_payload

REM Skip the extraction when a previous run already unpacked it.
if exist "%SETUP_ROOT%\%SETUP_NAME%\lib\manifest.cmd" (
    set "PAYLOAD=%SETUP_ROOT%\%SETUP_NAME%"
    echo   [info] Already unpacked, skipping extraction.
    goto :payload_ready
)

echo   [info] Unpacking %SETUP_ZIP% ...
call :unpack "%SETUP_ZIP%" "%SETUP_ROOT%\%SETUP_NAME%" "%SETUP_ROOT%\%SETUP_NAME%\lib\manifest.cmd"
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
REM  2. Unpack Cmder
REM ===========================================================================
REM Cmder lives in lib\ as a verified archive rather than as a vendored tree,
REM so updating it is one file plus one digest instead of a diff over hundreds
REM of files. A corrupted or tampered archive is caught here.
echo   [1/4] Unpacking Cmder ...

set "CMDER_ARCHIVE="
for /f "usebackq delims=" %%a in (`call "%PAYLOAD%\lib\manifest.cmd" get "cmder.archive"`) do (
    if not defined CMDER_ARCHIVE set "CMDER_ARCHIVE=%%a"
)
if not defined CMDER_ARCHIVE goto :no_cmder_archive

if not exist "%PAYLOAD%\%CMDER_ARCHIVE%" (
    echo   [error] %CMDER_ARCHIVE% is missing from the payload.
    echo.
    echo           This distribution is incomplete. Re-download the release.
    echo.
    exit /b 1
)

call "%PAYLOAD%\lib\manifest.cmd" verify "%PAYLOAD%\%CMDER_ARCHIVE%" "cmder.archive.sha256"
if errorlevel 1 (
    echo.
    echo   [error] The Cmder archive does not match manifest.json.
    echo.
    exit /b 1
)

REM Extraction is skipped when Cmder is already in place, so a re-run does not
REM overwrite a config the user has since customised.
if exist "%PAYLOAD%\Cmder.exe" (
    echo         already unpacked, skipping.
    goto :cmder_ready
)

call :unpack "%PAYLOAD%\%CMDER_ARCHIVE%" "%PAYLOAD%" "%PAYLOAD%\Cmder.exe"
if errorlevel 1 (
    echo.
    echo   [error] Could not unpack Cmder.
    echo.
    exit /b 1
)

:cmder_ready
call "%PAYLOAD%\lib\manifest.cmd" verify "%PAYLOAD%\Cmder.exe" "cmder.sha256"
if errorlevel 1 (
    echo.
    echo   [error] Cmder.exe does not match manifest.json after unpacking.
    echo.
    exit /b 1
)
echo         verified.
echo.

REM ===========================================================================
REM  3. Verify nvm-windows
REM ===========================================================================
REM Also bundled, also verified. nvm-windows is never fetched at install time:
REM upstream no longer publishes the portable archive, and a binary downloaded
REM during setup would make the install non-reproducible.
echo   [2/4] Verifying nvm-windows ...

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

echo         verified.
echo.

REM ===========================================================================
REM  4. Install the first-run hook
REM ===========================================================================
REM Cmder runs every *.cmd in config\profile.d on shell start (vendor\init.bat
REM line 385), and bin\ is already on PATH by then (line 377). The hook is a
REM tracked source file in src\ that is copied into the generated config\, so
REM nothing under version control is written to.
echo   [3/4] Installing the first-run hook ...

set "HOOK_SRC=%PAYLOAD%\src\profile.d\cmder-nvm.cmd"
set "HOOK_DST=%PAYLOAD%\config\profile.d\cmder-nvm.cmd"

if not exist "%HOOK_SRC%" (
    echo   [error] %HOOK_SRC% is missing, cannot configure startup.
    echo.
    exit /b 1
)

if not exist "%PAYLOAD%\config\profile.d" mkdir "%PAYLOAD%\config\profile.d" >nul 2>&1
if not exist "%PAYLOAD%\config\profile.d" (
    echo   [error] Unable to create %PAYLOAD%\config\profile.d
    echo.
    exit /b 1
)

copy /y "%HOOK_SRC%" "%HOOK_DST%" >nul 2>&1
if not exist "%HOOK_DST%" (
    echo   [error] Unable to install the first-run hook.
    echo.
    exit /b 1
)

echo         config\profile.d\cmder-nvm.cmd
echo.

REM ===========================================================================
REM  5. Launch Cmder
REM ===========================================================================

:launch
echo   [4/4] Starting Cmder ...
echo.

REM /start makes Cmder open in the payload folder. The first-run hook runs
REM inside that window and prepares the environment.
start "" "%PAYLOAD%\Cmder.exe" /start "%PAYLOAD%"

exit /b 0


REM ===========================================================================
REM  :no_payload / :no_cmder_archive
REM ===========================================================================
:no_payload
echo   [error] No cmder-nvm distribution found.
echo.
echo           Expected either:
echo             %SETUP_ROOT%\lib\manifest.cmd        (a checkout)
echo             %SETUP_ROOT%\cmder-nvm.zip           (a release)
echo             %SETUP_ROOT%\cmder-nvm-v*.zip
echo.
echo           Download the latest release, or run this script from a git
echo           checkout.
echo.
exit /b 1

:no_cmder_archive
echo   [error] manifest.json does not declare a Cmder archive.
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

if not exist "%UNPACK_TARGET%" mkdir "%UNPACK_TARGET%" >nul 2>&1

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

exit /b 0
