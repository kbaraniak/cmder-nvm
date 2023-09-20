@echo off
SET NODEVER=v16.18.1
SET SCRIPTPATH=%CD%\nodejs\%NODEVER%\nodevars.bat
SET ERRMSG=[ERROR] You don't have installed version node.js %NODEVER%

echo Using Node.js %NODEVER%
REM Changing PATH using nodevars

IF EXIST %SCRIPTPATH% (
  echo NodeJS enabled: node, npm
  %SCRIPTPATH%>nul
) ELSE (
  echo %ERRMSG%
)

IF ERRORLEVEL 1 ECHO %ERRMSG%