#!/usr/bin/env bash
# Read-only check: is the verification instance worth driving?
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"
verify_load_state

fail() {
  echo "doctor: $*" >&2
  exit 1
}

[[ -d "/proc/$LAUNCHER_PID" ]] || fail "launcher pid $LAUNCHER_PID is not running"
cmdline=$(tr '\0' ' ' <"/proc/$LAUNCHER_PID/cmdline")
[[ "$cmdline" == *"deeptutor_cli.main"* ]] || fail "pid $LAUNCHER_PID is not deeptutor start ($cmdline)"
[[ "$cmdline" == *"$HOME_DIR"* ]] || fail "pid $LAUNCHER_PID does not use home $HOME_DIR"

installed=$("$VERIFY_PYTHON" -c 'from deeptutor.__version__ import __version__; print(__version__)')
[[ "$installed" == "$VERSION" ]] || fail "installed deeptutor $installed does not match state version $VERSION"

launcher_json="$HOME_DIR/data/user/runtime/launcher.json"
"$VERIFY_PYTHON" - "$launcher_json" "$LAUNCHER_PID" "$BACKEND_PORT" "$FRONTEND_PORT" <<'PY' || fail "launcher.json does not match this run"
import json
import sys
from pathlib import Path

path, pid, backend, frontend = sys.argv[1:]
data = json.loads(Path(path).read_text(encoding="utf-8"))
if data.get("status") != "ready":
    raise SystemExit(f"status is {data.get('status')!r}, expected ready")
if str(data.get("pid")) != pid:
    raise SystemExit(f"launcher pid {data.get('pid')} != {pid}")
if int(data.get("backend_port")) != int(backend) or int(data.get("frontend_port")) != int(frontend):
    raise SystemExit(
        f"ports {data.get('backend_port')}/{data.get('frontend_port')} != {backend}/{frontend}"
    )
PY

auth_file="$HOME_DIR/data/user/settings/auth.json"
interface_file="$HOME_DIR/data/user/settings/interface.json"
"$VERIFY_PYTHON" - "$auth_file" "$interface_file" <<'PY' || fail "auth or language is not the verification baseline"
import json
import sys
from pathlib import Path

auth = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
interface = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
if auth.get("enabled") is not False:
    raise SystemExit(f"auth.enabled is {auth.get('enabled')!r}; journeys have no credentials")
if interface.get("language") != "en":
    raise SystemExit(f"interface language is {interface.get('language')!r}; selectors are English")
PY

frontend_html=$(curl -fsSL --max-time 20 "$FRONTEND_URL/") || fail "frontend $FRONTEND_URL did not return a page"
[[ "$frontend_html" == *"DeepTutor"* ]] || fail "frontend HTML does not identify DeepTutor"

status_json=$(curl -fsS --max-time 10 "$BACKEND_URL/api/system/status") || fail "backend status request failed"
"$VERIFY_PYTHON" -c 'import json,sys; data=json.load(sys.stdin); assert data["backend"]["status"]=="online", data' <<<"$status_json" \
  || fail "backend status is not online: $status_json"

"$VERIFY_PYTHON" - "$LAUNCHER_PID" "$BACKEND_PORT" "$FRONTEND_PORT" <<'PY' || fail "a verification port is not owned by the launcher process tree"
import os
import sys
from pathlib import Path

launcher = int(sys.argv[1])
ports = {int(sys.argv[2]), int(sys.argv[3])}

def ppid(pid: int) -> int | None:
    status = Path(f"/proc/{pid}/status")
    if not status.exists():
        return None
    for line in status.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("PPid:"):
            return int(line.split()[1])
    return None

def descendants(root: int) -> set[int]:
    found = {root}
    changed = True
    while changed:
        changed = False
        for entry in Path("/proc").iterdir():
            if not entry.name.isdigit():
                continue
            pid = int(entry.name)
            if pid in found:
                continue
            parent = ppid(pid)
            if parent in found:
                found.add(pid)
                changed = True
    return found

owned = descendants(launcher)

def listeners(port: int) -> set[int]:
    hex_port = f"{port:04X}"
    pids: set[int] = set()
    inodes: set[str] = set()
    for table in ("/proc/net/tcp", "/proc/net/tcp6"):
        path = Path(table)
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines()[1:]:
            fields = line.split()
            local, state, inode = fields[1], fields[3], fields[9]
            if state != "0A":
                continue
            host_port = local.rsplit(":", 1)[-1]
            if host_port.upper() != hex_port:
                continue
            inodes.add(inode)
    if not inodes:
        return pids
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        fd_dir = entry / "fd"
        if not fd_dir.is_dir():
            continue
        try:
            fds = list(fd_dir.iterdir())
        except OSError:
            continue
        for fd in fds:
            try:
                target = os.readlink(fd)
            except OSError:
                continue
            if target.startswith("socket:[") and target[8:-1] in inodes:
                pids.add(int(entry.name))
                break
    return pids

for port in sorted(ports):
    found = listeners(port)
    if not found:
        raise SystemExit(f"nothing is listening on 127.0.0.1:{port}")
    if found.isdisjoint(owned):
        raise SystemExit(f"port {port} listeners {sorted(found)} are outside launcher tree {launcher}")
PY

chromium=$(verify_chromium_path || true)
[[ -n "$chromium" && -x "$chromium" ]] || fail "Playwright Chromium is not installed ($chromium). Run: $VERIFY_PLAYWRIGHT install chromium"

echo "doctor: ok"
echo "  version: $VERSION"
echo "  pid: $LAUNCHER_PID"
echo "  frontend: $FRONTEND_URL"
echo "  backend: $BACKEND_URL"
echo "  home: $HOME_DIR"
echo "  auth: disabled"
echo "  language: en"
echo "  chromium: $chromium"
