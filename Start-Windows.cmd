@echo off
setlocal DisableDelayedExpansion
echo Before starting, connect your VPN to a US server and enable Smart Proxy mode.
where claude >nul 2>&1
if errorlevel 1 (
  choice /m "Claude Code was not found. Install it using WinGet"
  if errorlevel 2 exit /b 1
  where winget >nul 2>&1 || (start "" "https://code.claude.com/docs/en/setup" & exit /b 1)
  winget install --id Anthropic.ClaudeCode --exact --source winget || (pause & exit /b 1)
)
set "PATH=%PATH%;%LOCALAPPDATA%\Microsoft\WinGet\Links"
set "project="
set /p "project=Project folder (full path): "
if not defined project exit /b 2
pushd "%project:"=%" || (pause & exit /b 2)
powershell.exe -NoProfile -File "%~dp0scripts\start-claude.ps1" -Collaborative
set "result=%errorlevel%"
popd
if not "%result%"=="0" pause
exit /b %result%
