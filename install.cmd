@echo off
REM ===========================================================================
REM  cmder-nvm bootstrap installer (Windows / Cmder)
REM
REM  Creates the portable nvm environment inside this distribution and then
REM  offers to install a Node.js version. The repository root is resolved from
REM  the script location so the installer works from any working directory.
REM ===========================================================================
setlocal EnableExtensions

REM --- Environment layout ---------------------------------------------------
REM NVM_PATH    : root of this distribution
REM NVM_HOME    : where nvm-windows keeps the installed Node.js versions
REM NVM_SYMLINK : where nvm-windows points the "active" version
set "NVM_PATH=%~dp0"
if "%NVM_PATH:~-1%"=="\" set "NVM_PATH=%NVM_PATH:~0,-1%"
set "NVM_HOME=%NVM_PATH%\nodejs"
set "NVM_SYMLINK=%NVM_PATH%\node"
set "NVM_SETTINGS=%NVM_HOME%\settings.txt"

echo Bootstrap Installer (cmder-nvm v2.1)
echo.

REM --- Verify we are running on a 64-bit OS ---------------------------------
REM nvm-windows is a 64-bit binary; PROCESSOR_ARCHITEW6432 is only set when a
REM 32-bit process runs on a 64-bit OS, so both variables must be checked.
set "SYS_ARCH=32"
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "SYS_ARCH=64"
if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "SYS_ARCH=64"
if "%SYS_ARCH%"=="32" (
    echo [ERROR] cmder-nvm requires 64-bit Windows, nvm-windows is 64-bit only.
    exit /b 1
)

REM --- Make sure the nvm-windows binary is available -----------------------
REM A normal checkout already ships bin\nvm.exe, so this returns immediately.
REM It only reaches out to the network when the binary is genuinely missing.
call :ensure_nvm
if errorlevel 1 (
    echo [ERROR] The nvm-windows binary is unavailable, cannot continue.
    exit /b 1
)
echo.

REM --- Create the nvm home --------------------------------------------------
if not exist "%NVM_HOME%" (
    mkdir "%NVM_HOME%"
    if not exist "%NVM_HOME%" (
        echo [ERROR] Unable to create "%NVM_HOME%".
        exit /b 1
    )
)

REM --- Write settings.txt ---------------------------------------------------
REM One redirect per line instead of a parenthesised block: a block breaks when
REM the path itself contains a parenthesis, which is common under Program Files.
>"%NVM_SETTINGS%"  echo root: %NVM_HOME%
>>"%NVM_SETTINGS%" echo path: %NVM_SYMLINK%
>>"%NVM_SETTINGS%" echo arch: %SYS_ARCH%
>>"%NVM_SETTINGS%" echo proxy: none
if not exist "%NVM_SETTINGS%" (
    echo [ERROR] Unable to write "%NVM_SETTINGS%".
    exit /b 1
)
echo nvm home : %NVM_HOME%
echo nvm link : %NVM_SYMLINK%
echo nvm arch : %SYS_ARCH%
echo.

REM ===========================================================================
REM  Node.js version menu
REM ===========================================================================
echo NodeJS: Select node version to install in 5 sec:
echo ^- 1. NodeJS v16
echo ^- 2. NodeJS v18 (LTS)
echo ^- 3. NodeJS v19
echo ^- 4. NodeJS v20 (LTS)
echo ^- 5. NodeJS v21
echo ^- 6. NodeJS latest LTS
echo ^- 7. NodeJS latest
echo ^- 0. Exit
choice /T 5 /N /C:12345670 /D 7 /M "Option > "

REM ERRORLEVEL is the 1-based position inside /C, so "0" is the 8th option.
if "%ERRORLEVEL%"=="1" goto n16
if "%ERRORLEVEL%"=="2" goto n18
if "%ERRORLEVEL%"=="3" goto n19
if "%ERRORLEVEL%"=="4" goto n20
if "%ERRORLEVEL%"=="5" goto n21
if "%ERRORLEVEL%"=="6" goto n_lts
if "%ERRORLEVEL%"=="7" goto n_latest
if "%ERRORLEVEL%"=="8" goto stop

:n16
call :install_version v16.20.2 "NodeJS v16"
exit /b %ERRORLEVEL%

:n18
call :install_version v18.19.0 "NodeJS v18 (LTS)"
exit /b %ERRORLEVEL%

:n19
call :install_version v19.9.0 "NodeJS v19"
exit /b %ERRORLEVEL%

:n20
call :install_version v20.10.0 "NodeJS v20 (LTS)"
exit /b %ERRORLEVEL%

:n21
call :install_version v21.5.0 "NodeJS v21"
exit /b %ERRORLEVEL%

:n_lts
call :install_version lts "NodeJS latest LTS"
exit /b %ERRORLEVEL%

:n_latest
call :install_version latest "NodeJS latest"
exit /b %ERRORLEVEL%

:stop
echo Thank you for use
echo NodeJS: You can install another version later, using: install\node_js {VER}
exit /b 0

REM ===========================================================================
REM  :install_version <version> <label>
REM
REM  Installs the requested version and then switches to it. `call` is used
REM  instead of `start` so the child runs in this console and the exit code of
REM  the install is visible here.
REM ===========================================================================
:install_version
echo NodeJS: Installing %~2. Please Wait...
call "%NVM_PATH%\bin\install\node_js.cmd" %~1
if errorlevel 1 (
    echo [ERROR] Installation of %~2 failed.
    exit /b 1
)
call "%NVM_PATH%\bin\use\node.cmd" %~1
exit /b %ERRORLEVEL%

REM ===========================================================================
REM  :ensure_nvm
REM
REM  Verifies bin\nvm.exe exists and downloads it when it does not.
REM
REM  Distribution ships with bin\nvm.exe, so this is a no-op in the normal
REM  case. It exists for partial checkouts and slimmed-down distributions
REM  where the binary was excluded.
REM
REM  Download transports, in order:
REM    1. curl      (bundled with Windows 10 1803+ and Cmder's MSYS2 tools)
REM    2. PowerShell (Invoke-WebRequest, always present on Windows)
REM    3. clear error with manual instructions
REM
REM  Override the source with NVM_WINDOWS_URL to point at a mirror or a
REM  specific release, e.g.
REM    set NVM_WINDOWS_URL=https://example.com/nvm-noinstall.zip
REM ===========================================================================
:ensure_nvm
set "NVM_EXE=%NVM_PATH%\bin\nvm.exe"

if exist "%NVM_EXE%" (
    echo nvm     : %NVM_EXE%
    exit /b 0
)

echo nvm     : not found, attempting download...

REM Default to the portable archive. "noinstall" is used deliberately: the
REM regular installer modifies PATH and registers a system-wide symlink,
REM which requires admin rights this project deliberately avoids.
if not defined NVM_WINDOWS_VERSION set "NVM_WINDOWS_VERSION=1.1.12"
if not defined NVM_WINDOWS_URL set "NVM_WINDOWS_URL=https://github.com/coreybutler/nvm-windows/releases/download/v%NVM_WINDOWS_VERSION%/nvm-noinstall.zip"

set "NVM_CACHE=%NVM_PATH%\.oobe-cache"
set "NVM_ZIP=%NVM_CACHE%\nvm-noinstall.zip"
set "NVM_TMP=%NVM_ZIP%.part"

if not exist "%NVM_CACHE%" mkdir "%NVM_CACHE%" 2>nul

REM Reuse a previously downloaded archive instead of fetching it again.
if exist "%NVM_ZIP%" (
    echo     reusing cached archive
) else (
    call :download_nvm
    if errorlevel 1 (
        echo [ERROR] Failed to download nvm-windows from:
        echo           %NVM_WINDOWS_URL%
        echo.
        echo         Download it manually and place nvm.exe in:
        echo           %NVM_PATH%\bin\nvm.exe
        echo.
        echo         Or point NVM_WINDOWS_URL at a working mirror, e.g.
        echo           set NVM_WINDOWS_URL=https://example.com/nvm-noinstall.zip
        exit /b 1
    )
)

REM --- Unpack and install nvm.exe -------------------------------------------
REM The archive contains nvm.exe at its root; only that file is needed.
if not exist "%NVM_PATH%\bin" mkdir "%NVM_PATH%\bin" 2>nul
if not exist "%NVM_PATH%\bin" (
    echo [ERROR] Unable to create "%NVM_PATH%\bin".
    exit /b 1
)

call :extract_nvm "%NVM_ZIP%" "%NVM_PATH%\bin"
if errorlevel 1 (
    echo [ERROR] Unable to unpack %NVM_ZIP%.
    exit /b 1
)

if not exist "%NVM_EXE%" (
    echo [ERROR] nvm.exe is missing after unpacking; the archive may be corrupt.
    exit /b 1
)

REM A truncated download can leave a file that exists but will not run, so
REM confirm the binary actually executes before relying on it.
"%NVM_EXE%" version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] The downloaded nvm.exe could not be executed.
    exit /b 1
)

echo     installed %NVM_EXE%
exit /b 0

REM ---------------------------------------------------------------------------
REM  :download_nvm
REM
REM  Fetches NVM_WINDOWS_URL to NVM_ZIP, trying each transport in turn.
REM ---------------------------------------------------------------------------
:download_nvm
echo     downloading %NVM_WINDOWS_URL%

REM Transport 1: curl. -f fails on HTTP errors so a 404 page is never
REM mistaken for a valid archive; -L follows redirects off GitHub.
where curl >nul 2>&1
if not errorlevel 1 (
    curl -fL --retry 2 --connect-timeout 15 -o "%NVM_TMP%" "%NVM_WINDOWS_URL%" >nul 2>&1
    if not errorlevel 1 if exist "%NVM_TMP%" (
        move /y "%NVM_TMP%" "%NVM_ZIP%" >nul
        exit /b 0
    )
)

REM Transport 2: PowerShell. Invoke-WebRequest follows redirects by default
REM and is present on every supported Windows version.
if exist "%NVM_TMP%" del /q "%NVM_TMP%" >nul 2>&1
where powershell >nul 2>&1
if not errorlevel 1 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "try { $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri $env:NVM_WINDOWS_URL -OutFile $env:NVM_TMP -UseBasicParsing; exit 0 } catch { exit 1 }" >nul 2>&1
    if not errorlevel 1 if exist "%NVM_TMP%" (
        move /y "%NVM_TMP%" "%NVM_ZIP%" >nul
        exit /b 0
    )
)

if exist "%NVM_TMP%" del /q "%NVM_TMP%" >nul 2>&1
echo     [warn] no usable download transport (curl or PowerShell required)
exit /b 1

REM ---------------------------------------------------------------------------
REM  :extract_nvm <zip> <target-dir>
REM
REM  Unpacks nvm.exe from the archive. Expand-Archive handles the zip; tar is
REM  used as a fallback because Windows 10 1803+ ships bsdtar, which can read
REM  zip archives. Only nvm.exe and nvmw.exe are copied out, so a stray
REM  settings.txt in the archive cannot overwrite the one written by
REM  install.cmd.
REM ---------------------------------------------------------------------------
:extract_nvm
set "NVM_ZIP_FILE=%~1"
set "NVM_TARGET=%~2"
set "NVM_STAGE=%NVM_CACHE%\nvm-extract"

if exist "%NVM_STAGE%" rd /s /q "%NVM_STAGE%" >nul 2>&1
mkdir "%NVM_STAGE%" 2>nul

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Expand-Archive -Path $env:NVM_ZIP_FILE -DestinationPath $env:NVM_STAGE -Force; exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    tar -xf "%NVM_ZIP_FILE%" -C "%NVM_STAGE%" >nul 2>&1
    if errorlevel 1 (
        rd /s /q "%NVM_STAGE%" >nul 2>&1
        exit /b 1
    )
)

copy /y "%NVM_STAGE%\nvm.exe" "%NVM_TARGET%\nvm.exe" >nul 2>&1
copy /y "%NVM_STAGE%\nvmw.exe" "%NVM_TARGET%\nvmw.exe" >nul 2>&1

REM Fall back to a recursive search if the archive nests its contents.
REM This must run before the staging directory is removed.
if not exist "%NVM_TARGET%\nvm.exe" (
    for /f "usebackq delims=" %%f in (`dir /s /b "%NVM_STAGE%\nvm.exe" 2^>nul`) do (
        copy /y "%%f" "%NVM_TARGET%\nvm.exe" >nul 2>&1
    )
    for /f "usebackq delims=" %%f in (`dir /s /b "%NVM_STAGE%\nvmw.exe" 2^>nul`) do (
        copy /y "%%f" "%NVM_TARGET%\nvmw.exe" >nul 2>&1
    )
)

rd /s /q "%NVM_STAGE%" >nul 2>&1

exit /b 0
