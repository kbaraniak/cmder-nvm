@echo off
REM ===========================================================================
REM  cmder-nvm - doctor
REM
REM  Reports the state of the installation. Every check prints [OK], [WARN] or
REM  [FAIL] and a value, so a problem is visible without reading any script.
REM
REM  Usage:
REM    doctor.cmd
REM
REM  Exit code is 0 when nothing failed, 1 when at least one check failed.
REM  Warnings do not fail the run.
REM
REM  Delayed expansion is enabled here because the counters and the
REM  settings.txt parser both need to read a variable inside a block. Unlike
REM  install.cmd, doctor never rewrites PATH, so the usual hazard of delayed
REM  expansion corrupting a PATH entry does not apply here. An install path
REM  containing "!" may still be misreported; install.cmd itself handles it.
setlocal EnableExtensions EnableDelayedExpansion

REM ===========================================================================

REM --- Environment layout ---------------------------------------------------
REM NVM_PATH    : root of this distribution
REM NVM_HOME    : where nvm-windows keeps the installed Node.js versions
REM NVM_SYMLINK : where nvm-windows points the active version
set "NVM_PATH=%~dp0"
if "%NVM_PATH:~-1%"=="\" set "NVM_PATH=%NVM_PATH:~0,-1%"
set "NVM_HOME=%NVM_PATH%\nodejs"
set "NVM_SYMLINK=%NVM_PATH%\node"
set "NVM_EXE=%NVM_PATH%\bin\nvm.exe"
set "NVM_SETTINGS=%NVM_PATH%\bin\settings.txt"

set "FAILURES=0"
set "WARNINGS=0"

echo.
echo   cmder-nvm doctor
echo   ================
echo.
echo   install: %NVM_PATH%
echo.

REM ---------------------------------------------------------------------------
REM  1. Platform
REM ---------------------------------------------------------------------------
echo   Platform
call :check_architecture
call :report
echo.

REM ---------------------------------------------------------------------------
REM  2. Bundled binaries
REM ---------------------------------------------------------------------------
echo   Binaries
if exist "%NVM_PATH%\Cmder.exe" (
    call :ok "Cmder.exe present"
    call :verify_binary "%NVM_PATH%\Cmder.exe" "cmder.sha256"
) else (
    call :fail "Cmder.exe missing"
)
if exist "%NVM_EXE%" (
    call :ok "bin\nvm.exe present"
    call :verify_binary "%NVM_EXE%" "nvm-windows.sha256"
    call :report_nvm_version
) else (
    call :fail "bin\nvm.exe missing"
    echo          This distribution is incomplete; re-download the release zip.
)
call :report
echo.

REM ---------------------------------------------------------------------------
REM  3. nvm layout
REM ---------------------------------------------------------------------------
echo   nvm layout
if exist "%NVM_HOME%" (
    call :ok "NVM_HOME exists"
    call :ok "NVM_HOME = %NVM_HOME%"
) else (
    call :fail "NVM_HOME missing: %NVM_HOME%"
    echo          Run install.cmd to create it.
)

REM The symlink is where nvm-windows points the active version. It must live
REM inside this installation: a symlink pointing elsewhere means another nvm
REM owns the active version and `nvm use` will not behave predictably.
if exist "%NVM_SYMLINK%\*" (
    call :ok "NVM_SYMLINK resolves: %NVM_SYMLINK%"
) else (
    call :warn "NVM_SYMLINK does not resolve: %NVM_SYMLINK%"
    echo          No Node.js version is active. Run: use\node lts
)

if exist "%NVM_SETTINGS%" (
    call :ok "settings.txt present"
    call :check_settings
) else (
    call :fail "settings.txt missing: %NVM_SETTINGS%"
    echo          Run install.cmd to create it.
)
call :report
echo.

REM ---------------------------------------------------------------------------
REM  4. Installed versions
REM ---------------------------------------------------------------------------
echo   Node.js
set "INSTALLED="
for /f "usebackq delims=" %%d in (`dir /b /ad "%NVM_HOME%" 2^>nul`) do (
    if /i "%%d" v* (
        if not defined INSTALLED set "INSTALLED=%%d"
        call :ok "installed: %%d"
    )
)
if not defined INSTALLED (
    call :warn "no Node.js versions installed under %NVM_HOME%"
    echo          Install one with: install\node_js lts
)
call :report
echo.

REM ---------------------------------------------------------------------------
REM  5. Active version on PATH
REM ---------------------------------------------------------------------------
echo   Active session
where node >nul 2>&1
if errorlevel 1 (
    call :warn "node is not on PATH in this session"
    echo          Run: use\node lts
) else (
    for /f "usebackq delims=" %%v in (`node --version 2^>nul`) do (
        if not "%%v"=="" call :ok "node --version = %%v"
    )
)

where npm >nul 2>&1
if errorlevel 1 (
    call :warn "npm is not on PATH in this session"
) else (
    for /f "usebackq delims=" %%v in (`npm --version 2^>nul`) do (
        if not "%%v"=="" call :ok "npm --version = %%v"
    )
)
call :report
echo.

REM ---------------------------------------------------------------------------
REM  6. Distribution integrity
REM ---------------------------------------------------------------------------
echo   Version
if exist "%NVM_PATH%\VERSION" (
    set "DOC_VERSION="
    for /f "usebackq tokens=* delims=" %%v in ("%NVM_PATH%\VERSION") do (
        if not defined DOC_VERSION set "DOC_VERSION=%%v"
    )
    call :ok "cmder-nvm version = !DOC_VERSION!"
) else (
    call :warn "VERSION file not found"
)
if exist "%NVM_PATH%\manifest.json" (
    call :ok "manifest.json present"
) else (
    call :fail "manifest.json missing"
)

if not exist "%NVM_PATH%\config\profile.d\cmder-nvm.cmd" (
    call :fail "the first-run hook config\profile.d\cmder-nvm.cmd is missing"
    echo          Run SETUP.cmd.
)

REM An old hook left in user_profile.cmd means the install predates the
REM profile.d approach. It is harmless, but it should be removed by hand.
findstr /c:"cmder-nvm: run install.cmd" "%NVM_PATH%\config\user_profile.cmd" >nul 2>&1
if not errorlevel 1 (
    call :warn "config\user_profile.cmd still carries an old cmder-nvm hook"
    echo          Safe to delete the marked block; see the README.
    set /a WARNINGS+=1
)
echo.

REM ===========================================================================
REM  Summary
REM ===========================================================================
echo   Summary
if %FAILURES% gtr 0 (
    echo     %FAILURES% failed, %WARNINGS% warning^(s^).
    echo     Run install.cmd to repair the environment.
    echo.
    endlocal & exit /b 1
)
if %WARNINGS% gtr 0 (
    echo     All checks passed, with %WARNINGS% warning^(s^).
    echo.
    endlocal & exit /b 0
)
echo     All checks passed.
echo.
endlocal & exit /b 0


REM ===========================================================================
REM  Helpers
REM ===========================================================================

:ok
echo     [OK]   %~1
exit /b 0

:warn
set /a WARNINGS+=1
echo     [WARN] %~1
exit /b 0

:fail
set /a FAILURES+=1
echo     [FAIL] %~1
exit /b 0

:report
if %FAILURES% gtr 0 exit /b 1
exit /b 0

:check_architecture
set "SYS_ARCH=32"
if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "SYS_ARCH=64"
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "SYS_ARCH=64"
if "%SYS_ARCH%"=="64" (
    call :ok "Windows architecture = x64"
) else (
    call :fail "Windows architecture = %SYS_ARCH%"
    echo          nvm-windows is 64-bit only.
)
exit /b 0

:verify_binary
call "%NVM_PATH%\lib\manifest.cmd" verify "%~1" "%~2"
if errorlevel 1 (
    set /a FAILURES+=1
) else (
    echo            %~2
)
exit /b 0

:report_nvm_version
set "NVM_VER=unknown"
for /f "usebackq delims=" %%v in (`"%NVM_EXE%" version 2^>nul`) do (
    if not defined NVM_VER set "NVM_VER=%%v"
)
call :ok "nvm.exe version = %NVM_VER%"
exit /b 0

REM settings.txt is read by nvm-windows, so a malformed one breaks every
REM command. Parsed line by line: a block breaks when the path contains a
REM parenthesis, which is common under Program Files.
:check_settings
set "SEEN_ROOT="
set "SEEN_PATH="
set "SEEN_ARCH="
for /f "usebackq tokens=1,* delims=:" %%k in ("%NVM_SETTINGS%") do (
    set "KEY=%%k"
    set "VAL=%%l"
    set "KEY=!KEY: =!"
    set "VAL=!VAL: =!"
    if /i "!KEY!"=="root" set "SEEN_ROOT=!VAL!"
    if /i "!KEY!"=="path" set "SEEN_PATH=!VAL!"
    if /i "!KEY!"=="arch" set "SEEN_ARCH=!VAL!"
)

if not defined SEEN_ROOT (
    call :fail "settings.txt has no 'root' entry"
) else if /i not "!SEEN_ROOT!"=="%NVM_HOME%" (
    call :fail "settings.txt root does not match this installation"
    echo            expected %NVM_HOME%
    echo            actual   !SEEN_ROOT!
) else (
    call :ok "settings.txt root matches this installation"
)

if not defined SEEN_PATH (
    call :fail "settings.txt has no 'path' entry"
) else if /i not "!SEEN_PATH!"=="%NVM_SYMLINK%" (
    call :fail "settings.txt path does not match this installation"
    echo            expected %NVM_SYMLINK%
    echo            actual   !SEEN_PATH!
) else (
    call :ok "settings.txt path matches this installation"
)

if not defined SEEN_ARCH (
    call :fail "settings.txt has no 'arch' entry"
) else if /i not "!SEEN_ARCH!"=="64" (
    call :fail "settings.txt arch is not 64"
    echo            actual   !SEEN_ARCH!
) else (
    call :ok "settings.txt arch = 64"
)

REM The symlink must not point outside the installation. The root is stripped
REM from the front and what remains must begin with a separator, so
REM "C:\Tools\cmder-nvm-evil" is not mistaken for "C:\Tools\cmder-nvm". When
REM the root is not a prefix at all the substitution is a no-op, the tail still
REM starts with a drive letter, and the path is correctly reported as outside.
if defined SEEN_PATH (
    set "CLEAN_PATH=!SEEN_PATH:\=/!"
    set "CLEAN_ROOT=%NVM_PATH:\=/%"
    set "TAIL=!CLEAN_PATH:%CLEAN_ROOT%=!"
    if "!TAIL:~0,1!"=="/" (
        call :ok "NVM_SYMLINK points inside this installation"
    ) else (
        goto :symlink_outside
    )
)

:symlink_outside
call :fail "NVM_SYMLINK points outside this installation"
echo            actual !SEEN_PATH!
echo          Another nvm installation owns the active version, so
echo          `nvm use` will not change what this Cmder runs.

:symlink_done
exit /b 0
