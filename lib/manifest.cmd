@echo off
REM ===========================================================================
REM  cmder-nvm - manifest reader
REM
REM  The only place that knows how to read VERSION and manifest.json.
REM
REM  Usage:
REM
REM    call "%~dp0lib\manifest.cmd" version
REM    call "%~dp0lib\manifest.cmd" get <key>
REM    call "%~dp0lib\manifest.cmd" sha256 <file>
REM    call "%~dp0lib\manifest.cmd" verify <file> <key>
REM
REM  "get", "version" and "sha256" print the value on stdout so it can be
REM  captured with for /f. "verify" reports through errorlevel and prints both
REM  digests on a mismatch.
REM
REM  manifest.json is parsed by literal string substitution rather than by a
REM  real JSON parser. That is deliberate: the file is ours, and constraining
REM  it to flat dotted keys with space-free values keeps this readable and
REM  dependency free. The cost is that a key must not be a substring of another
REM  key, and a value must not contain '": "'.
REM
REM  Control flow avoids nested parenthesised blocks around a for /f, because a
REM  command substitution inside a block is parsed by cmd.exe before the block
REM  runs and the two bracket counts do not line up. Subroutines and goto are
REM  used instead.
REM ===========================================================================
setlocal EnableExtensions

if "%~1" == "" goto :usage
if "%~1" == "/h" goto :usage
if "%~1" == "version" goto :version
if "%~1" == "get" goto :get
if "%~1" == "sha256" goto :sha256
if "%~1" == "verify" goto :verify
goto :usage

REM ---------------------------------------------------------------------------
REM  :version - print the cmder-nvm version recorded in the VERSION file
REM ---------------------------------------------------------------------------
:version
set "MF_VERSION_FILE=%~dp0..\VERSION"
if not exist "%MF_VERSION_FILE%" goto :version_missing
set "MF_VERSION="
for /f "usebackq tokens=* delims=" %%v in ("%MF_VERSION_FILE%") do (
    if not defined MF_VERSION set "MF_VERSION=%%v"
)
if not defined MF_VERSION goto :version_missing
REM Trim the trailing CR a file written with CRLF endings leaves behind.
set "MF_VERSION=%MF_VERSION: =%"
echo(%MF_VERSION%
endlocal & exit /b 0

:version_missing
echo [ERROR] VERSION is missing or empty at "%MF_VERSION_FILE%"
endlocal & exit /b 1

REM ---------------------------------------------------------------------------
REM  :get <key> - print one value from manifest.json
REM ---------------------------------------------------------------------------
:get
if "%~2" == "" goto :get_usage
call :read "%~2"
if not defined MF_VALUE goto :get_missing
echo(%MF_VALUE%
endlocal & exit /b 0

:get_usage
echo [ERROR] Usage: manifest.cmd get ^<key^>
endlocal & exit /b 1

:get_missing
echo [ERROR] manifest.json has no key "%~2"
endlocal & exit /b 1

REM ---------------------------------------------------------------------------
REM  :sha256 <file> - print the lowercase SHA-256 digest of a file
REM ---------------------------------------------------------------------------
:sha256
if "%~2" == "" goto :sha_usage
if not exist "%~2" goto :sha_missing
call :digest "%~2"
if not defined MF_SHA goto :sha_failed
echo(%MF_SHA%
endlocal & exit /b 0

:sha_usage
echo [ERROR] Usage: manifest.cmd sha256 ^<file^>
endlocal & exit /b 1

:sha_missing
echo [ERROR] File not found: "%~2"
endlocal & exit /b 1

:sha_failed
echo [ERROR] Unable to compute a SHA-256 digest for "%~2"
endlocal & exit /b 1

REM ---------------------------------------------------------------------------
REM  :verify <file> <key>
REM
REM  Compares a file against the digest recorded in the manifest. On a mismatch
REM  both digests are printed, so the failure is actionable without re-running
REM  anything by hand.
REM ---------------------------------------------------------------------------
:verify
if "%~2" == "" goto :verify_usage
if "%~3" == "" goto :verify_usage
if not exist "%~2" goto :verify_no_file
call :read "%~3"
if not defined MF_VALUE goto :verify_no_key
call :digest "%~2"
if not defined MF_SHA goto :verify_no_digest
if /i "%MF_SHA%" == "%MF_VALUE%" goto :verify_match
echo [FAIL] %~3 mismatch
echo        expected %MF_VALUE%
echo        actual   %MF_SHA%
endlocal & exit /b 1

:verify_match
echo [OK]   %~3
endlocal & exit /b 0

:verify_usage
echo [ERROR] Usage: manifest.cmd verify ^<file^> ^<key^>
endlocal & exit /b 1

:verify_no_file
echo [FAIL] %~2 is missing
endlocal & exit /b 1

:verify_no_key
echo [FAIL] manifest.json has no key "%~3"
endlocal & exit /b 1

:verify_no_digest
echo [FAIL] Unable to compute a SHA-256 digest for "%~2"
endlocal & exit /b 1

REM ---------------------------------------------------------------------------
REM  :digest <file> - set MF_SHA to the lowercase digest
REM
REM  certutil ships with every supported Windows and needs no PowerShell, so it
REM  is the primary transport. Its output is locale dependent, so the digest is
REM  picked by shape (a bare hex line) rather than by line number.
REM
REM  The PowerShell fallback avoids parentheses in the command text: a command
REM  substitution inside a parenthesised block is parsed before the block runs,
REM  and an unbalanced bracket there breaks the whole script.
REM
REM  Delayed expansion stays off. "!" is a legal character in a Windows path and
REM  must survive this loop untouched.
REM ---------------------------------------------------------------------------
:digest
set "MF_SHA="
set "MF_DIGEST_FILE=%~1"
set "MF_DIGEST_CACHE=%TEMP%\cmder-nvm-digest.tmp"

certutil -hashfile "%MF_DIGEST_FILE%" SHA256 > "%MF_DIGEST_CACHE%" 2>nul
findstr /r /c:"^[0-9a-fA-F][0-9a-fA-F]*$" "%MF_DIGEST_CACHE%" > "%MF_DIGEST_CACHE%.hex" 2>nul
if exist "%MF_DIGEST_CACHE%.hex" goto :digest_certutil
goto :digest_fallback

:digest_certutil
for /f "usebackq tokens=* delims=" %%h in ("%MF_DIGEST_CACHE%.hex") do (
    if not defined MF_SHA set "MF_SHA=%%h"
)
del /q "%MF_DIGEST_CACHE%" >nul 2>&1
del /q "%MF_DIGEST_CACHE%.hex" >nul 2>&1
if defined MF_SHA goto :digest_done

:digest_fallback
REM Get-FileHash is the same algorithm under a different name. The result is
REM assigned to a variable first so no parentheses are needed in the text.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { $d = Get-FileHash -LiteralPath $env:MF_DIGEST_FILE -Algorithm SHA256; $d.Hash.ToLower } catch { exit 1 }" > "%MF_DIGEST_CACHE%" 2>nul
if not exist "%MF_DIGEST_CACHE%" goto :digest_done
for /f "usebackq tokens=* delims=" %%h in ("%MF_DIGEST_CACHE%") do (
    if not defined MF_SHA set "MF_SHA=%%h"
)
del /q "%MF_DIGEST_CACHE%" >nul 2>&1

:digest_done
if not defined MF_SHA exit /b 0
set "MF_SHA=%MF_SHA: =%"
exit /b 0

REM ---------------------------------------------------------------------------
REM  :read <key> - set MF_VALUE to the manifest value for <key>
REM
REM  A manifest line looks like:  "nvm-windows.sha256": "6eef8b67..."
REM  Stripping the literal prefix *"KEY": " leaves the quoted value, so the
REM  quotes are removed afterwards. Literal substitution rather than token
REM  splitting on ":" is what keeps a URL value intact.
REM ---------------------------------------------------------------------------
:read
set "MF_VALUE="
set "MF_KEY=%~1"
set "MF_MANIFEST=%~dp0..\manifest.json"
if not exist "%MF_MANIFEST%" exit /b 1

for /f "usebackq tokens=* delims=" %%l in ("%MF_MANIFEST%") do call :match_line "%%l"
if not defined MF_VALUE exit /b 1

REM Drop the remaining surrounding quotes, then any stray spaces.
set MF_VALUE=%MF_VALUE:"=%
set MF_VALUE=%MF_VALUE: =%
exit /b 0

:match_line
set "MF_LINE=%~1"
if not defined MF_LINE exit /b 0
set MF_CANDIDATE=%MF_LINE:*"%MF_KEY%": "=%
REM An unchanged line means the pattern was absent, so this is not our key.
if "%MF_CANDIDATE%"=="%MF_LINE%" exit /b 0
set "MF_VALUE=%MF_CANDIDATE%"
exit /b 0

:usage
echo Usage:
echo    manifest.cmd version
echo    manifest.cmd get ^<key^>
echo    manifest.cmd sha256 ^<file^>
echo    manifest.cmd verify ^<file^> ^<key^>
endlocal & exit /b 1
