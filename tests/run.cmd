@echo off
REM ===========================================================================
REM  cmder-nvm - test runner
REM
REM  Exercises the Windows flow. Each case copies the distribution into a
REM  temporary folder with a deliberately awkward path, runs a script, and
REM  asserts on the result.
REM
REM  Usage:
REM    tests\run.cmd              run every case
REM    tests\run.cmd paths        run only cases whose name contains "paths"
REM
REM  This runner does not touch the checkout it lives in: every case works on
REM  a copy under %TEMP%.
REM ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion

set "TEST_ROOT=%~dp0"
if "%TEST_ROOT:~-1%"=="\" set "TEST_ROOT=%TEST_ROOT:~0,-1%"
set "REPO_ROOT=%TEST_ROOT%\.."
if "%REPO_ROOT:~-1%"=="\" set "REPO_ROOT=%REPO_ROOT:~0,-1%"
set "WORK=%TEMP%\cmder-nvm-tests"

set "FILTER=%~1"
set "PASSED=0"
set "FAILED=0"
set "FAILED_NAMES="

echo.
echo   cmder-nvm tests
echo   ===============
echo.
echo   repo  : %REPO_ROOT%
echo   work  : %WORK%
echo.

if exist "%WORK%" rd /s /q "%WORK%"
mkdir "%WORK%" >nul 2>&1

call :run_case "fresh install"                :case_fresh_install
call :run_case "reinstall is idempotent"      :case_reinstall
call :run_case "missing nvm.exe is fatal"     :case_missing_nvm
call :run_case "corrupt nvm.exe is rejected"  :case_corrupt_nvm
call :run_case "broken settings.txt reported" :case_broken_settings
call :run_case "paths: spaces"                :case_path_spaces
call :run_case "paths: parentheses"           :case_path_parens
call :run_case "paths: exclamation"           :case_path_bang
call :run_case "paths: short name"            :case_path_short
call :run_case "manifest read"                :case_manifest
call :run_case "cmder archive verifies"       :case_cmder_archive
call :run_case "cmder archive tamper check"   :case_cmder_archive_tampered
call :run_case "user_profile.cmd untouched"   :case_profile_untouched
call :run_case "non-interactive install"      :case_noninteractive
call :run_case "offline bootstrap"            :case_offline

echo.
echo   Summary
echo   -------
if %FAILED% gtr 0 (
    echo   %PASSED% passed, %FAILED% failed
    echo   Failed:!FAILED_NAMES!
    echo.
    endlocal & exit /b 1
)
echo   %PASSED% passed, 0 failed
echo.
endlocal & exit /b 0


REM ===========================================================================
REM  Harness
REM ===========================================================================

:run_case
set "CASE_NAME=%~1"
set "CASE_LABEL=%~2"
if defined FILTER (
    echo !CASE_NAME! | findstr /i /c:"!FILTER!" >nul 2>&1
    if errorlevel 1 exit /b 0
)
echo   !CASE_NAME! ...
call %CASE_LABEL%
if errorlevel 1 (
    set /a FAILED+=1
    set "FAILED_NAMES=!FAILED_NAMES! !CASE_NAME!"
) else (
    set /a PASSED+=1
)
exit /b 0

:pass
echo     [PASS]
exit /b 0

REM Usage: call :fail ^<reason^>
:fail
echo     [FAIL] %~1
exit /b 1

:skip
echo     [SKIP] %~1
exit /b 0

REM Copies the distribution into a fresh folder. Usage: call :stage ^<name^>
REM
REM The staged copy mirrors what SETUP.cmd produces: source files, the Cmder
REM archive in lib\, and Cmder unpacked from it. Building that from the
REM archive rather than copying a working tree keeps the tests honest about the
REM fact that Cmder is no longer vendored.
:stage
set "STAGE_DIR=%WORK%\%~1"
if exist "%STAGE_DIR%" rd /s /q "%STAGE_DIR%"
mkdir "%STAGE_DIR%" >nul 2>&1
for %%d in (bin lib src) do (
    if exist "%REPO_ROOT%\%%d" xcopy /e /i /q /y "%REPO_ROOT%\%%d" "%STAGE_DIR%\%%d" >nul 2>&1
)
for %%f in (install.cmd doctor.cmd pack.cmd manifest.json VERSION LICENSE) do (
    if exist "%REPO_ROOT%\%%f" copy /y "%REPO_ROOT%\%%f" "%STAGE_DIR%\" >nul 2>&1
)
if not exist "%STAGE_DIR%\bin\nvm.exe" (
    call :fail "could not stage the distribution"
    exit /b 1
)
call :unpack_cmder "%STAGE_DIR%"
if errorlevel 1 exit /b 1
call :install_hook "%STAGE_DIR%"
if errorlevel 1 exit /b 1
exit /b 0

REM Unpacks the Cmder archive into a staged copy, the way SETUP.cmd does.
:unpack_cmder
set "UC_DIR=%~1"
set "UC_ZIP="
for /f "usebackq delims=" %%a in (`call "%UC_DIR%\lib\manifest.cmd" get "cmder.archive"`) do (
    if not defined UC_ZIP set "UC_ZIP=%%a"
)
if not defined UC_ZIP (
    call :fail "manifest.json declares no Cmder archive"
    exit /b 1
)
if not exist "%UC_DIR%\%UC_ZIP%" (
    call :fail "Cmder archive %UC_ZIP% is not in the staged copy"
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Expand-Archive -Path '%UC_DIR%\%UC_ZIP%' -DestinationPath '%UC_DIR%' -Force; exit 0 } catch { exit 1 }" >nul 2>&1
if not exist "%UC_DIR%\Cmder.exe" (
    call :fail "unpacking the Cmder archive did not produce Cmder.exe"
    exit /b 1
)
exit /b 0

:install_hook
set "IH_DIR=%~1"
if not exist "%IH_DIR%\config\profile.d" mkdir "%IH_DIR%\config\profile.d" >nul 2>&1
copy /y "%IH_DIR%\src\profile.d\cmder-nvm.cmd" "%IH_DIR%\config\profile.d\cmder-nvm.cmd" >nul 2>&1
if not exist "%IH_DIR%\config\profile.d\cmder-nvm.cmd" (
    call :fail "could not install the first-run hook"
    exit /b 1
)
exit /b 0


REM ===========================================================================
REM  Cases
REM ===========================================================================

REM A fresh install must create the version store and a settings.txt that
REM nvm-windows can actually read.
:case_fresh_install
call :stage "fresh"
set "S=%WORK%\fresh"
call "%S%\install.cmd" --node lts --no-activate > "%WORK%\fresh.log" 2>&1
if errorlevel 1 (
    call :fail "install.cmd exited non-zero, see %WORK%\fresh.log"
    exit /b 1
)
if not exist "%S%\nodejs\" (
    call :fail "nodejs\ was not created"
    exit /b 1
)
if not exist "%S%\bin\settings.txt" (
    call :fail "bin\settings.txt was not created; nvm-windows needs it next to nvm.exe"
    exit /b 1
)
findstr /b /c:"root: " "%S%\bin\settings.txt" >nul 2>&1
if errorlevel 1 (
    call :fail "settings.txt has no root entry"
    exit /b 1
)
call :pass
exit /b 0

REM Running the installer twice must not fail and must not duplicate config.
:case_reinstall
call :stage "reinstall"
set "S=%WORK%\reinstall"
call "%S%\install.cmd" --node lts --no-activate > "%WORK%\reinstall1.log" 2>&1
call "%S%\install.cmd" --node lts --no-activate > "%WORK%\reinstall2.log" 2>&1
if errorlevel 1 (
    call :fail "the second install.cmd run failed, see %WORK%\reinstall2.log"
    exit /b 1
)
call :pass
exit /b 0

REM A missing binary is a hard error. The old code tried to download it; there
REM is no download any more, so the message must say so.
:case_missing_nvm
call :stage "missing-nvm"
set "S=%WORK%\missing-nvm"
del /q "%S%\bin\nvm.exe" >nul 2>&1
call "%S%\install.cmd" --node lts --no-activate > "%WORK%\missing-nvm.log" 2>&1
if not errorlevel 1 (
    call :fail "install.cmd succeeded without bin\nvm.exe"
    exit /b 1
)
findstr /i /c:"missing" "%WORK%\missing-nvm.log" >nul 2>&1
if errorlevel 1 (
    call :fail "the error does not explain that the binary is missing"
    exit /b 1
)
call :pass
exit /b 0

REM A tampered binary must be refused before anything is written.
:case_corrupt_nvm
call :stage "corrupt-nvm"
set "S=%WORK%\corrupt-nvm"
REM Overwrite the contents, leaving the file present but wrong.
echo corrupted>"%S%\bin\nvm.exe"
call "%S%\install.cmd" --node lts --no-activate > "%WORK%\corrupt-nvm.log" 2>&1
if not errorlevel 1 (
    call :fail "install.cmd accepted a binary that does not match the manifest"
    exit /b 1
)
findstr /i /c:"mismatch" "%WORK%\corrupt-nvm.log" >nul 2>&1
if errorlevel 1 (
    call :fail "the error does not mention a checksum mismatch"
    exit /b 1
)
if exist "%S%\nodejs\" (
    call :fail "the version store was created despite an unverified binary"
    exit /b 1
)
call :pass
exit /b 0

REM doctor must notice a settings.txt that points somewhere else, which is how
REM a second nvm installation silently takes over.
:case_broken_settings
call :stage "broken-settings"
set "S=%WORK%\broken-settings"
call "%S%\install.cmd" --node lts --no-activate > "%WORK%\broken-settings.log" 2>&1
> "%S%\bin\settings.txt" echo root: C:\somewhere-else\nodejs
>>"%S%\bin\settings.txt" echo path: C:\somewhere-else\node
>>"%S%\bin\settings.txt" echo arch: 32
call "%S%\doctor.cmd" > "%WORK%\doctor-broken.log" 2>&1
if not errorlevel 1 (
    call :fail "doctor.cmd passed a settings.txt that points outside the install"
    exit /b 1
)
findstr /i /c:"FAIL" "%WORK%\doctor-broken.log" >nul 2>&1
if errorlevel 1 (
    call :fail "doctor.cmd did not report any failure"
    exit /b 1
)
call :pass
exit /b 0

REM Awkward paths are the classic batch failure: a space, a parenthesis, an
REM exclamation mark, and an 8.3 short name.
:case_path_spaces
call :stage "path with spaces"
if not exist "%WORK%\path with spaces\bin\nvm.exe" (
    call :fail "could not stage into a path with spaces"
    exit /b 1
)
call "%WORK%\path with spaces\install.cmd" --node lts --no-activate > "%WORK%\path-spaces.log" 2>&1
if errorlevel 1 (
    call :fail "install.cmd failed in a path with spaces, see %WORK%\path-spaces.log"
    exit /b 1
)
findstr /b /c:"root: " "%WORK%\path with spaces\bin\settings.txt" >nul 2>&1
if errorlevel 1 (
    call :fail "settings.txt was not written correctly in a path with spaces"
    exit /b 1
)
call :pass
exit /b 0

:case_path_parens
call :stage "path (with parens)"
call "%WORK%\path (with parens)\install.cmd" --node lts --no-activate > "%WORK%\path-parens.log" 2>&1
if errorlevel 1 (
    call :fail "install.cmd failed in a path with parentheses, see %WORK%\path-parens.log"
    exit /b 1
)
call :pass
exit /b 0

:case_path_bang
call :stage "path!with!bang"
call "%WORK%\path!with!bang\install.cmd" --node lts --no-activate > "%WORK%\path-bang.log" 2>&1
if errorlevel 1 (
    call :fail "install.cmd failed in a path with an exclamation mark, see %WORK%\path-bang.log"
    exit /b 1
)
if not exist "%WORK%\path!with!bang\bin\settings.txt" (
    call :fail "settings.txt was not written in a path with an exclamation mark"
    exit /b 1
)
call :pass
exit /b 0

REM An 8.3 short name is the case that breaks naive %~dp0 handling, because
REM the name is truncated and a "~" appears in it. Skipped where 8.3 name
REM creation is disabled, which is the correct behaviour rather than a pass.
:case_path_short
call :stage "shortnam"
set "SHORTNAME="
for /f "usebackq tokens=1,2" %%a in (`dir /x "%WORK%" 2^>nul`) do (
    if /i "%%b"=="shortnam" set "SHORTNAME=%%a"
)
if not defined SHORTNAME (
    call :skip "8.3 name creation is disabled on this volume"
    exit /b 0
)
if exist "%SHORTNAME%\" rd /s /q "%SHORTNAME%" >nul 2>&1

REM Re-stage through the short name, so every path inside the scripts resolves
REM through an 8.3 name containing a "~".
mkdir "%SHORTNAME%" >nul 2>&1
xcopy /e /i /q /y "%WORK%\shortnam" "%SHORTNAME%\" >nul 2>&1
if not exist "%SHORTNAME%\bin\nvm.exe" (
    call :skip "could not restage through the 8.3 short name"
    exit /b 0
)

call "%SHORTNAME%\install.cmd" --node lts --no-activate > "%WORK%\path-short.log" 2>&1
if errorlevel 1 (
    call :fail "install.cmd failed under an 8.3 short path, see %WORK%\path-short.log"
    exit /b 1
)
call :pass
exit /b 0

REM lib/manifest.cmd is the single reader, so exercise it directly. The
REM expected version is read from VERSION rather than hardcoded, so bumping the
REM version does not require editing this file.
:case_manifest
call :stage "manifest"
set "S=%WORK%\manifest"

set "EXPECTED="
for /f "usebackq tokens=* delims=" %%v in ("%REPO_ROOT%\VERSION") do (
    if not defined EXPECTED set "EXPECTED=%%v"
)
set "EXPECTED=%EXPECTED: =%"
if not defined EXPECTED (
    call :fail "could not read the expected version from VERSION"
    exit /b 1
)

set "OUT="
for /f "usebackq delims=" %%v in (`call "%S%\lib\manifest.cmd" version`) do set "OUT=%%v"
if not defined OUT (
    call :fail "manifest.cmd version printed nothing"
    exit /b 1
)
if not "%OUT%"=="%EXPECTED%" (
    call :fail "manifest.cmd version returned %OUT%, expected %EXPECTED%"
    exit /b 1
)

set "SHA="
for /f "usebackq delims=" %%v in (`call "%S%\lib\manifest.cmd" sha256 "%S%\bin\nvm.exe"`) do set "SHA=%%v"
if not defined SHA (
    call :fail "manifest.cmd sha256 printed nothing"
    exit /b 1
)

set "PINNED="
for /f "usebackq delims=" %%v in (`call "%S%\lib\manifest.cmd" get "nvm-windows.sha256"`) do set "PINNED=%%v"
if not defined PINNED (
    call :fail "manifest.cmd could not read nvm-windows.sha256"
    exit /b 1
)
if not "%SHA%"=="%PINNED%" (
    call :fail "sha256 of the bundled nvm.exe is %SHA%, manifest says %PINNED%"
    exit /b 1
)

REM A URL value must survive parsing: it contains a colon, which is what a
REM naive split on ":" would truncate.
set "MIRROR="
for /f "usebackq delims=" %%v in (`call "%S%\lib\manifest.cmd" get "nvm-windows.node-mirror"`) do set "MIRROR=%%v"
if not "%MIRROR%"=="https://nodejs.org/dist" (
    call :fail "a URL value was mangled by the parser: got %MIRROR%"
    exit /b 1
)

call "%S%\lib\manifest.cmd" verify "%S%\bin\nvm.exe" "nvm-windows.sha256" >nul 2>&1
if errorlevel 1 (
    call :fail "verify rejected the bundled nvm.exe"
    exit /b 1
)
call "%S%\lib\manifest.cmd" get "does-not-exist" >nul 2>&1
if not errorlevel 1 (
    call :fail "get returned success for a key that does not exist"
    exit /b 1
)
call :pass
exit /b 0

REM Cmder must arrive only as a verified archive: unpacking it is SETUP.cmd's
REM job, and both the archive and the binary inside it are pinned.
:case_cmder_archive
call :stage "cmder-archive"
set "S=%WORK%\cmder-archive"
if not exist "%S%\Cmder.exe" (
    call :fail "the staged copy has no unpacked Cmder.exe"
    exit /b 1
)
set "ARC="
for /f "usebackq delims=" %%a in (`call "%S%\lib\manifest.cmd" get "cmder.archive"`) do set "ARC=%%a"
if not defined ARC (
    call :fail "manifest.json declares no Cmder archive"
    exit /b 1
)
call "%S%\lib\manifest.cmd" verify "%S%\%ARC%" "cmder.archive.sha256" >nul 2>&1
if errorlevel 1 (
    call :fail "the Cmder archive does not match manifest.json"
    exit /b 1
)
call "%S%\lib\manifest.cmd" verify "%S%\Cmder.exe" "cmder.sha256" >nul 2>&1
if errorlevel 1 (
    call :fail "the unpacked Cmder.exe does not match manifest.json"
    exit /b 1
)
call :pass
exit /b 0

REM A tampered Cmder archive must fail verification, which is what stops a
REM corrupted download from being unpacked and executed.
:case_cmder_archive_tampered
call :stage "cmder-tampered"
set "S=%WORK%\cmder-tampered"
set "TAMPERED=%WORK%\cmder-tampered\lib\tampered.zip"
copy /y "%S%\lib\cmder-1.3.24.236.zip" "%TAMPERED%" >nul 2>&1
REM Flip one byte in the middle of the archive without changing its length.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$b=[IO.File]::ReadAllBytes('%TAMPERED%'); $b[1024] = $b[1024] -bxor 255; [IO.File]::WriteAllBytes('%TAMPERED%',$b)" >nul 2>&1
call "%S%\lib\manifest.cmd" verify "%TAMPERED%" "cmder.archive.sha256" >nul 2>&1
if not errorlevel 1 (
    call :fail "verify accepted a tampered Cmder archive"
    exit /b 1
)
call :pass
exit /b 0

REM The point of the profile.d hook: installing must not modify any tracked
REM file, so `git status` stays clean after an install in a checkout.
:case_profile_untouched
call :stage "profile"
set "S=%WORK%\profile"
set "BEFORE="
for /f "usebackq delims=" %%v in (`certutil -hashfile "%S%\config\user_profile.cmd" SHA256 2^>nul ^| findstr /r /c:"^[0-9a-fA-F][0-9a-fA-F]*$"`) do (
    if not defined BEFORE set "BEFORE=%%v"
)
if not defined BEFORE (
    call :fail "could not hash user_profile.cmd"
    exit /b 1
)
call "%S%\install.cmd" --node lts --no-activate > "%WORK%\profile.log" 2>&1
set "AFTER="
for /f "usebackq delims=" %%v in (`certutil -hashfile "%S%\config\user_profile.cmd" SHA256 2^>nul ^| findstr /r /c:"^[0-9a-fA-F][0-9a-fA-F]*$"`) do (
    if not defined AFTER set "AFTER=%%v"
)
if not "%BEFORE%"=="%AFTER%" (
    call :fail "user_profile.cmd changed during install"
    exit /b 1
)
if not exist "%S%\config\profile.d\cmder-nvm.cmd" (
    call :fail "the first-run hook config\profile.d\cmder-nvm.cmd is missing"
    exit /b 1
)

REM The hook must be byte-identical to its tracked source in src\, so the file
REM that runs is the file that is reviewed.
certutil -hashfile "%S%\src\profile.d\cmder-nvm.cmd" SHA256 2>nul | findstr /r /c:"^[0-9a-fA-F][0-9a-fA-F]*$" > "%WORK%\hook-src.hash"
certutil -hashfile "%S%\config\profile.d\cmder-nvm.cmd" SHA256 2>nul | findstr /r /c:"^[0-9a-fA-F][0-9a-fA-F]*$" > "%WORK%\hook-dst.hash"
fc /b "%WORK%\hook-src.hash" "%WORK%\hook-dst.hash" >nul 2>&1
if errorlevel 1 (
    call :fail "the installed hook differs from src\profile.d\cmder-nvm.cmd"
    exit /b 1
)
call :pass
exit /b 0

REM --node with --yes must not prompt, so it can run unattended in CI.
:case_noninteractive
call :stage "noninteractive"
set "S=%WORK%\noninteractive"
call "%S%\install.cmd" --yes > "%WORK%\noninteractive.log" 2>&1
if not errorlevel 1 (
    call :fail "--yes without a version was accepted; it must be an error"
    exit /b 1
)
call :pass
exit /b 0

REM The bootstrap must not need the network. Downloading anything to decide
REM whether to install would make an offline machine fail, so the first-run
REM hook and the installer must contain no download path at all.
:case_offline
call :stage "offline"
set "S=%WORK%\offline"
findstr /i /c:"curl" /c:"Invoke-WebRequest" "%S%\config\profile.d\cmder-nvm.cmd" >nul 2>&1
if not errorlevel 1 (
    call :fail "the first-run hook performs a download; the bootstrap must be offline"
    exit /b 1
)
findstr /i /c:"curl" /c:"Invoke-WebRequest" "%S%\install.cmd" >nul 2>&1
if not errorlevel 1 (
    call :fail "install.cmd still contains a download path"
    exit /b 1
)
call :pass
exit /b 0
