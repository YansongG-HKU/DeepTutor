#!/usr/bin/env bash
# Shared paths for the DeepTutor verification skill. Source this; do not execute it.
set -euo pipefail

_verify_scripts_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VERIFY_SKILL_DIR=$(cd "$_verify_scripts_dir/.." && pwd)
VERIFY_REPO_ROOT=$(cd "$_verify_scripts_dir/../../../.." && pwd)

if [[ -x "$VERIFY_REPO_ROOT/.venv/bin/python" ]]; then
  VERIFY_PYTHON="$VERIFY_REPO_ROOT/.venv/bin/python"
elif command -v python3 >/dev/null 2>&1; then
  VERIFY_PYTHON=$(command -v python3)
else
  echo "python3 is not on PATH. Create a virtualenv and install DeepTutor with:" >&2
  echo "  python3 -m venv .venv && . .venv/bin/activate && python -m pip install -e ." >&2
  exit 1
fi

VERIFY_STATE=${VERIFY_STATE:-$VERIFY_SKILL_DIR/run/current.env}
VERIFY_PLAYWRIGHT="$VERIFY_REPO_ROOT/web/node_modules/.bin/playwright"

verify_load_state() {
  if [[ ! -f "$VERIFY_STATE" ]]; then
    echo "No verification state at $VERIFY_STATE. Run scripts/launch.sh first." >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  set -a
  # shellcheck disable=SC1090
  source "$VERIFY_STATE"
  set +a
  : "${RUN_ID:?}"
  : "${HOME_DIR:?}"
  : "${FRONTEND_URL:?}"
  : "${BACKEND_URL:?}"
  : "${FRONTEND_PORT:?}"
  : "${BACKEND_PORT:?}"
  : "${LAUNCHER_PID:?}"
  : "${EVIDENCE_DIR:?}"
  : "${VERSION:?}"
}

verify_write_env() {
  local dest=$1
  mkdir -p "$(dirname "$dest")"
  cat >"$dest" <<EOF
RUN_ID=$RUN_ID
HOME_DIR=$HOME_DIR
FRONTEND_URL=$FRONTEND_URL
BACKEND_URL=$BACKEND_URL
FRONTEND_PORT=$FRONTEND_PORT
BACKEND_PORT=$BACKEND_PORT
LAUNCHER_PID=$LAUNCHER_PID
EVIDENCE_DIR=$EVIDENCE_DIR
VERSION=$VERSION
REPO_ROOT=$VERIFY_REPO_ROOT
STATE_FILE=$dest
EOF
}

verify_chromium_path() {
  node --input-type=module -e "
    import { createRequire } from 'node:module';
    const require = createRequire(process.argv[1]);
    const { chromium } = require('playwright');
    process.stdout.write(chromium.executablePath());
  " "$VERIFY_REPO_ROOT/web/package.json"
}
