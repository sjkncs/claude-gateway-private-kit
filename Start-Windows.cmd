@echo off
setlocal DisableDelayedExpansion
set "project="
set /p "project=Project folder (full path): "
if not defined project exit /b 2
pushd "%project:"=%" || (pause & exit /b 2)
powershell.exe -NoProfile -File "%~dp0scripts\start-claude.ps1" -Collaborative
set "result=%errorlevel%"
popd
if not "%result%"=="0" pause
exit /b %result%
