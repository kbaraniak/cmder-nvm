@echo off
REM ===========================================================================
REM  cmder-nvm - PACK
REM
REM  Builds the release archive that SETUP.cmd unpacks.
REM
REM  Run this from a git checkout to produce the release artifact:
REM
REM      pack.cmd
REM
REM  The archive name comes from the VERSION file, so there is a single source
REM  of truth for the version. Cmder.exe and bin\nvm.exe are verified against
REM  manifest.json before packing: a release that ships an unverified binary is
REM  a broken release, and this is the last point where that is still cheap to
REM  catch.
REM ===========================================================================
setlocal EnableExtensions

set "PACK_ROOT=%~dp0"
if "%PACK_ROOT:~-1%"=="\" set "PACK_ROOT=%PACK_ROOT:~0,-1%"
set "PACK_STAGE=%TEMP%\cmder-nvm-pack-%RANDOM%"

echo.
echo   cmder-nvm pack
echo   ===============
echo.

REM --- Read the version -----------------------------------------------------
if not exist "%PACK_ROOT%\VERSION" (
    echo   [error] VERSION not found at %PACK_ROOT%\VERSION
    echo.
    exit /b 1
)
set "PACK_VERSION="
for /f "usebackq tokens=* delims=" %%v in ("%PACK_ROOT%\VERSION") do (
    if not defined PACK_VERSION set "PACK_VERSION=%%v"
)
set "PACK_VERSION=%PACK_VERSION: =%"
if not defined PACK_VERSION (
    echo   [error] VERSION is empty.
    echo.
    exit /b 1
)

set "PACK_ZIP=%PACK_ROOT%\cmder-nvm-v%PACK_VERSION%.zip"

echo   [info] Version : %PACK_VERSION%
echo   [info] Archive : %PACK_ZIP%
echo.

REM --- Verify the binaries before packing ------------------------------------
echo   [info] Verifying binaries ...
call "%PACK_ROOT%\lib\manifest.cmd" verify "%PACK_ROOT%\Cmder.exe" "cmder.sha256"
if errorlevel 1 (
    echo.
    echo   [error] Refusing to pack: Cmder.exe does not match manifest.json.
    echo           Update manifest.json if the binary was replaced on purpose.
    echo.
    exit /b 1
)
call "%PACK_ROOT%\lib\manifest.cmd" verify "%PACK_ROOT%\bin\nvm.exe" "nvm-windows.sha256"
if errorlevel 1 (
    echo.
    echo   [error] Refusing to pack: bin\nvm.exe does not match manifest.json.
    echo.
    exit /b 1
)
echo   [ok]   Binaries match manifest.json.
echo.

REM --- Stage the payload ----------------------------------------------------
REM Copying to a staging folder first keeps the archive free of development-only
REM files (.git, caches, an already-unpacked nodejs\) and lets Compress-Archive
REM produce paths relative to a clean root.
echo   [info] Staging payload ...
if exist "%PACK_STAGE%" rd /s /q "%PACK_STAGE%"
mkdir "%PACK_STAGE%" >nul 2>&1
if not exist "%PACK_STAGE%" (
    echo   [error] Unable to create %PACK_STAGE%
    echo.
    exit /b 1
)

for %%d in (bin vendor config opt icons lib) do (
    if exist "%PACK_ROOT%\%%d" (
        xcopy /e /i /q /y "%PACK_ROOT%\%%d" "%PACK_STAGE%\%%d" >nul
        if errorlevel 1 (
            echo   [error] Failed to copy %%d
            echo.
            exit /b 1
        )
    )
)

REM lib\ is required because SETUP.cmd reads manifest.json through
REM lib\manifest.cmd, and oobe.sh sources lib\oobe\*.sh at runtime, so a
REM Windows-only payload would silently break the Linux flow.
for %%f in (Cmder.exe install.cmd doctor.cmd oobe.sh manifest.json VERSION LICENSE) do (
    if exist "%PACK_ROOT%\%%f" copy /y "%PACK_ROOT%\%%f" "%PACK_STAGE%\" >nul 2>&1
)

REM The Cmder version marker contains a space, so it is copied separately.
if exist "%PACK_ROOT%\Version 1.3.24.236" copy /y "%PACK_ROOT%\Version 1.3.24.236" "%PACK_STAGE%\" >nul 2>&1

echo   [ok]   Staged.
echo.

REM --- Create the archive ---------------------------------------------------
if exist "%PACK_ZIP%" del /q "%PACK_ZIP%" >nul 2>&1

echo   [info] Creating %PACK_ZIP% ...
REM Join-Path avoids embedding a backslash inside a quoted PowerShell string.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Compress-Archive -Path (Join-Path $env:PACK_STAGE '*') -DestinationPath $env:PACK_ZIP -Force; exit 0 } catch { exit 1 }" >nul 2>&1

if errorlevel 1 (
    echo   [error] Compression failed.
    echo.
    exit /b 1
)

rd /s /q "%PACK_STAGE%" >nul 2>&1

REM --- Verify ---------------------------------------------------------------
if not exist "%PACK_ZIP%" (
    echo   [error] Archive was not created.
    echo.
    exit /b 1
)

for %%z in ("%PACK_ZIP%") do echo   [ok]   Created %%~zf
echo.
echo   Next: copy SETUP.cmd and the archive into the same folder and run
echo   SETUP.cmd to unpack and launch. SETUP.cmd finds cmder-nvm-v*.zip.
echo.

exit /b 0
