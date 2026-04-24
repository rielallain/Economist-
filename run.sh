#!/usr/bin/env bash
# Wrapper used by the launchd agent — loads .env then runs sync.py
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -f "$DIR/.env" ]]; then
  echo "ERROR: $DIR/.env not found. Run install-macos.sh first." >&2
  exit 1
fi

# Export every variable in .env so sync.py can read them
set -a
# shellcheck source=/dev/null
source "$DIR/.env"
set +a

exec "$DIR/venv/bin/python3" "$DIR/sync.py"
