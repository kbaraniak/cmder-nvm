@REM Install Script latest Node.js LTS
@echo off
set NODE_VER=lts

call nvm install --lts
echo Install complete
echo Change to this version, using: use\node %NODE_VER%
