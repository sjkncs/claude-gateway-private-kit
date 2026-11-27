#!/bin/bash
set -eu
echo '启动前请连接 VPN 的美国节点，并开启智能代理模式。'
kit=$(cd "$(dirname "$0")" && pwd)
IFS= read -r -p 'Desktop gateway setup [D] or terminal [T]? ' mode
case "$mode" in ''|d|D) exec /bin/bash "$kit/scripts/desktop-macos.sh" ;; t|T) ;; *) exit 2 ;; esac
export PATH="$PATH:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin"
if ! command -v claude >/dev/null; then
  if command -v brew >/dev/null; then
    IFS= read -r -p 'Install Claude Code using Homebrew? [y/N] ' answer
    case "$answer" in y|Y) brew install --cask claude-code ;; *) exit 1 ;; esac
  else
    open 'https://code.claude.com/docs/en/setup'
    echo 'Complete the official macOS installation, then reopen this launcher.'
    exit 1
  fi
fi
IFS= read -r -p 'Project folder (full path): ' project
cd -- "$project"
exec /bin/bash "$kit/scripts/start-claude-macos.sh" --collaborative
