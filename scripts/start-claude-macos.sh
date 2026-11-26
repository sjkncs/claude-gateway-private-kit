#!/bin/bash
set +x
set -eu

case "${1-}:$#" in
  :0) collaborative=false ;;
  --collaborative:1) collaborative=true ;;
  *) echo 'Usage: start-claude-macos.sh [--collaborative]' >&2; exit 2 ;;
esac
command -v claude >/dev/null || { echo 'Install Claude Code first.' >&2; exit 1; }
set --
if "$collaborative"; then
  script_dir=$(cd "$(dirname "$0")" && pwd)
  rules=$(cat "$script_dir/../config/collaboration.md")
  set -- --permission-mode auto --append-system-prompt "$rules"
fi
IFS= read -r -p 'HTTPS gateway base URL: ' endpoint
if [[ ! $endpoint =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?(/[^[:space:]?#]*)?$ || $endpoint == *\\* ]]; then
  echo 'Enter an HTTPS gateway URL without credentials, query or fragment.' >&2
  exit 2
fi
IFS= read -r -p 'Gateway model ID: ' model
[[ $model =~ [^[:space:]] ]] || { echo 'Model ID is required.' >&2; exit 2; }
IFS= read -rs -p 'Your gateway token: ' token
printf '\n' >&2
[[ -n $token ]] || { echo 'Token is required.' >&2; exit 2; }
unset ANTHROPIC_API_KEY
export ANTHROPIC_BASE_URL="${endpoint%/}" ANTHROPIC_MODEL="$model" ANTHROPIC_AUTH_TOKEN="$token"
exec claude "$@"
