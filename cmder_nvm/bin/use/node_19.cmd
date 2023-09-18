@echo off
SET NODEVER=v19.1.0

echo Using Node.js %NODEVER%
REM Changing PATH using nodevars
..\%CD%\%NODEVER%\nodevars.cmd>nul
IF ERRORLEVEL 1 ECHO You don't have installed version node.js %NODEVER%