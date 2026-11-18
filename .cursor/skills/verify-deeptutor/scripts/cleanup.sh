#!/usr/bin/env bash
# Stop the verification instance and delete its scratch home. Evidence stays.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
verify_load_state

mkdir -p "$EVIDENCE_DIR"
log_file="$HOME_DIR/data/user/runtime/launcher.log"
if [[ -f "$log_file" ]]; then
  tail -n 120 "$log_file" >"$EVIDENCE_DIR/launcher.log.tail.txt"
fi

if [[ -d "/proc/$LAUNCHER_PID" ]]; then
  echo "Stopping launcher pid $LAUNCHER_PID (home $HOME_DIR)"
  if ! "$VERIFY_PYTHON" - "$HOME_DIR" <<'PY'
import sys

from deeptutor.runtime.launcher import stop

home = sys.argv[1]
if not stop(home, timeout=60):
    raise SystemExit(1)
PY
  then
    echo "cleanup: stop did not confirm pid $LAUNCHER_PID exited. Evidence remains at $EVIDENCE_DIR." >&2
    echo "The launcher log is $log_file. This script does not kill by process name." >&2
    exit 1
  fi
else
  echo "Launcher pid $LAUNCHER_PID is already gone."
fi

# stop() can return as soon as the detached state file is cleared, while the
# pid is still a zombie or in its last exit. Wait until /proc drops it.
deadline=$((SECONDS + 15))
while [[ -d "/proc/$LAUNCHER_PID" ]]; do
  state=$(awk '/^State:/{print $2}' "/proc/$LAUNCHER_PID/status" 2>/dev/null || true)
  if [[ "$state" == "Z" ]]; then
    break
  fi
  if (( SECONDS >= deadline )); then
    echo "cleanup: pid $LAUNCHER_PID is still running (state ${state:-unknown}). Scratch home was kept." >&2
    exit 1
  fi
  sleep 0.2
done

if [[ -d "$HOME_DIR" ]]; then
  case "$HOME_DIR" in
    /tmp/deeptutor-verify-*)
      rm -rf "$HOME_DIR"
      ;;
    *)
      echo "cleanup: refusing to delete home outside /tmp/deeptutor-verify-*: $HOME_DIR" >&2
      exit 1
      ;;
  esac
fi

if [[ -f "$VERIFY_STATE" ]]; then
  # shellcheck disable=SC1090
  state_run=$(source "$VERIFY_STATE" && printf '%s' "${RUN_ID:-}")
  if [[ "$state_run" == "$RUN_ID" ]]; then
    rm -f "$VERIFY_STATE"
  fi
fi

if [[ ! -d "$EVIDENCE_DIR" ]]; then
  echo "cleanup: evidence directory disappeared: $EVIDENCE_DIR" >&2
  exit 1
fi

echo "cleanup: instance removed"
echo "  evidence: $EVIDENCE_DIR"
