@echo off
REM ===========================================================================
REM  cmder-nvm - PACK
REM
REM  Builds cmder-nvm.zip, the single-file distribution that SETUP.cmd unpacks.
REM
REM  Run this from a git checkout to produce the release artifact:
REM
REM      pack.cmd
REM
REM  The archive is rooted so that Cmder.exe, bin\, vendor\ and config\ sit at
REM  the top level, which is the layout SETUP.cmd and install.cmd expect.
REM ===========================================================================
setlocal EnableExtensions

set "PACK_ROOT=%~dp0"
if "%PACK_ROOT:~-1%"=="\" set "PACK_ROOT=%PACK_ROOT:~0,-1%"
set "PACK_ZIP=%PACK_ROOT%\cmder-nvm.zip"
set "PACK_STAGE=%TEMP%\cmder-nvm-pack-%RANDOM%"

echo.
echo   cmder-nvm pack
echo   ===============
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

for %%d in (bin vendor config opt icons) do (
    if exist "%PACK_ROOT%\%%d" (
        xcopy /e /i /q /y "%PACK_ROOT%\%%d" "%PACK_STAGE%\%%d" >nul
        if errorlevel 1 (
            echo   [error] Failed to copy %%d
            echo.
            exit /b 1
        )
    )
)

REM Top-level files that belong in the distribution. The Cmder version marker
REM contains a space, so it is copied separately rather than in this list.
for %%f in (Cmder.exe install.cmd LICENSE) do (
    if exist "%PACK_ROOT%\%%f" copy /y "%PACK_ROOT%\%%f" "%PACK_STAGE%\" >nul 2>&1
)
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
echo   Next: copy SETUP.cmd and cmder-nvm.zip into the same folder and run
echo   SETUP.cmd to unpack and launch.
echo.

exit /b 0