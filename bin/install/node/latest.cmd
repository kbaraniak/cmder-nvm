@REM Install Script latest Node.js Current (Non-LTS)
@echo off
set NODE_VER=latest

call nvm install %NODE_VER%

echo Install complete.
echo Change to this version, using: nvm use %NODE_VER%
