#!/bin/bash
set -eu
kit=$(cd "$(dirname "$0")" && pwd)
IFS= read -r -p 'Project folder (full path): ' project
cd -- "$project"
exec /bin/bash "$kit/scripts/start-claude-macos.sh" --collaborative
