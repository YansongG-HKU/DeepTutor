#!/usr/bin/env bash
# Start one isolated DeepTutor web app for verification.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

cd "$VERIFY_REPO_ROOT"

if ! "$VERIFY_PYTHON" -c 'import deeptutor_cli.main, deeptutor' >/dev/null 2>&1; then
  echo "DeepTutor is not installed for $VERIFY_PYTHON." >&2
  echo "From the repository root, run:" >&2
  echo "  python3 -m venv .venv && . .venv/bin/activate && python -m pip install -e ." >&2
  exit 1
fi

if [[ ! -d "$VERIFY_REPO_ROOT/web/node_modules/next" ]]; then
  echo "Installing web dependencies with npm ci --legacy-peer-deps ..."
  (cd "$VERIFY_REPO_ROOT/web" && npm ci --legacy-peer-deps)
fi

if [[ ! -x "$VERIFY_PLAYWRIGHT" ]]; then
  echo "Playwright is missing from web/node_modules. Run npm ci --legacy-peer-deps in web/." >&2
  exit 1
fi

chromium=$(verify_chromium_path || true)
if [[ -z "$chromium" || ! -x "$chromium" ]]; then
  echo "Installing the Playwright Chromium build used by scripts/drive.mjs ..."
  "$VERIFY_PLAYWRIGHT" install chromium
  chromium=$(verify_chromium_path)
fi
if [[ ! -x "$chromium" ]]; then
  echo "Playwright Chromium is not executable at ${chromium:-<unknown>}." >&2
  exit 1
fi

RUN_ID=${VERIFY_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}
HOME_DIR=${VERIFY_HOME:-/tmp/deeptutor-verify-$RUN_ID}
EVIDENCE_DIR=${VERIFY_EVIDENCE:-$VERIFY_SKILL_DIR/artifacts/$RUN_ID}
VERSION=$("$VERIFY_PYTHON" -c 'from deeptutor.__version__ import __version__; print(__version__)')

if [[ -f "$VERIFY_SKILL_DIR/run/current.env" && "${VERIFY_ALLOW_CONCURRENT:-}" != "1" ]]; then
  existing_pid=$(
    # shellcheck disable=SC1091
    source "$VERIFY_SKILL_DIR/run/current.env"
    printf '%s' "${LAUNCHER_PID:-}"
  )
  if [[ -n "$existing_pid" && -d "/proc/$existing_pid" ]]; then
    echo "A verification instance is already running (pid $existing_pid)." >&2
    echo "Run scripts/cleanup.sh before launching another, or set VERIFY_ALLOW_CONCURRENT=1 and a distinct VERIFY_STATE." >&2
    exit 1
  fi
fi

if [[ "${VERIFY_ALLOW_CONCURRENT:-}" == "1" && -n "${VERIFY_STATE:-}" && "$VERIFY_STATE" != "$VERIFY_SKILL_DIR/run/current.env" ]]; then
  STATE_DEST=$VERIFY_STATE
else
  STATE_DEST=$VERIFY_SKILL_DIR/run/current.env
fi

mkdir -p "$HOME_DIR" "$EVIDENCE_DIR" "$(dirname "$STATE_DEST")"

# Drop deployment overrides so this home's system.json owns the ports.
unset BACKEND_PORT FRONTEND_PORT PORT NEXT_PUBLIC_API_BASE NEXT_PUBLIC_API_BASE_EXTERNAL \
  DEEPTUTOR_API_BASE_URL DEEPTUTOR_HOME UI_LANGUAGE || true

read -r BACKEND_PORT FRONTEND_PORT < <("$VERIFY_PYTHON" - <<'PY'
import socket
ports = []
sockets = []
for _ in range(2):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.bind(("127.0.0.1", 0))
    ports.append(str(sock.getsockname()[1]))
    sockets.append(sock)
for sock in sockets:
    sock.close()
print(" ".join(ports))
PY
)

"$VERIFY_PYTHON" - "$HOME_DIR" "$BACKEND_PORT" "$FRONTEND_PORT" <<'PY'
import json
import sys
from pathlib import Path

from deeptutor.services.config.runtime_settings import (
    DEFAULT_SYSTEM_SETTINGS,
    RuntimeSettingsService,
)

home, backend, frontend = sys.argv[1:]
settings = Path(home) / "data" / "user" / "settings"
settings.mkdir(parents=True, exist_ok=True)
service = RuntimeSettingsService(settings)
system = dict(DEFAULT_SYSTEM_SETTINGS)
system["backend_port"] = int(backend)
system["frontend_port"] = int(frontend)
service.save_system(system)
interface = {
    "theme": "snow",
    "language": "en",
    "response_language": "en",
}
(settings / "interface.json").write_text(json.dumps(interface, indent=2) + "\n", encoding="utf-8")
PY

export DEEPTUTOR_BACKEND_READY_TIMEOUT="${DEEPTUTOR_BACKEND_READY_TIMEOUT:-180}"
export DEEPTUTOR_FRONTEND_READY_TIMEOUT="${DEEPTUTOR_FRONTEND_READY_TIMEOUT:-300}"

echo "Starting DeepTutor $VERSION"
echo "  home: $HOME_DIR"
echo "  backend: http://127.0.0.1:$BACKEND_PORT"
echo "  frontend: http://127.0.0.1:$FRONTEND_PORT"

# The port variables stay unexported so they cannot override system.json.
"$VERIFY_PYTHON" -m deeptutor_cli.main start \
  --home "$HOME_DIR" \
  --dev \
  --no-browser \
  --detach

LAUNCHER_JSON="$HOME_DIR/data/user/runtime/launcher.json"
set +e
READY_JSON=$("$VERIFY_PYTHON" - "$LAUNCHER_JSON" "${DEEPTUTOR_FRONTEND_READY_TIMEOUT}" <<'PY'
import json
import sys
import time
from pathlib import Path

path = Path(sys.argv[1])
deadline = time.time() + int(sys.argv[2]) + 30
last = ""
while time.time() < deadline:
    if path.is_file():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            data = {}
        status = data.get("status")
        pid = data.get("pid")
        if status == "ready" and pid:
            print(json.dumps({"pid": pid, "frontend_port": data.get("frontend_port"), "backend_port": data.get("backend_port")}))
            sys.exit(0)
        if pid and not Path(f"/proc/{pid}").exists():
            print(f"launcher pid {pid} exited before ready", file=sys.stderr)
            sys.exit(1)
        last = status or "missing-status"
    time.sleep(1)
print(f"timed out waiting for {path} (last status: {last or 'absent'})", file=sys.stderr)
sys.exit(1)
PY
)
ready_status=$?
set -e
if [[ "$ready_status" -ne 0 ]]; then
  echo "DeepTutor did not become ready. Log: $HOME_DIR/data/user/runtime/launcher.log" >&2
  exit 1
fi

LAUNCHER_PID=$("$VERIFY_PYTHON" -c 'import json,sys; print(json.load(sys.stdin)["pid"])' <<<"$READY_JSON")
READY_BACKEND=$("$VERIFY_PYTHON" -c 'import json,sys; print(json.load(sys.stdin)["backend_port"])' <<<"$READY_JSON")
READY_FRONTEND=$("$VERIFY_PYTHON" -c 'import json,sys; print(json.load(sys.stdin)["frontend_port"])' <<<"$READY_JSON")
BACKEND_PORT=$READY_BACKEND
FRONTEND_PORT=$READY_FRONTEND
BACKEND_URL="http://127.0.0.1:$BACKEND_PORT"
FRONTEND_URL="http://127.0.0.1:$FRONTEND_PORT"

verify_write_env "$STATE_DEST"
cp "$STATE_DEST" "$EVIDENCE_DIR/instance.txt"

echo "Ready: $FRONTEND_URL (pid $LAUNCHER_PID)"
echo "State: $STATE_DEST"
echo "Evidence: $EVIDENCE_DIR"
