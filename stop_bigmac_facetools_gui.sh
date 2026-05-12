#!/usr/bin/env bash
set -euo pipefail

SSH_TARGET="${SSH_TARGET:-westcat}"
REMOTE_ROOT="${REMOTE_ROOT:-/Users/bigmac/AI/FaceTools}"
LOCAL_PORT="${LOCAL_PORT:-7865}"
TUNNEL_PID_FILE="${TMPDIR:-/tmp}/bigmac_facetools_gui_tunnel_${LOCAL_PORT}.pid"

log() { printf '[facetools stop] %s\n' "$*"; }
fail() { printf '[facetools stop] ERROR: %s\n' "$*" >&2; exit 1; }

verify_route() {
  local out line1 line2
  out="$(ssh "$SSH_TARGET" 'whoami && hostname && pwd && sw_vers' 2>&1)" || { printf '%s\n' "$out" >&2; fail "Cannot reach Big Mac."; }
  line1="$(printf '%s\n' "$out" | sed -n '1p')"
  line2="$(printf '%s\n' "$out" | sed -n '2p')"
  [[ "$line1" != "andrew" ]] || fail "Wrong SSH route: whoami returned andrew. Stop."
  [[ "$line1" == "bigmac" && "$line2" == "bigmac" ]] || fail "Route verification failed."
}

verify_route
log "Stopping remote GUI service."
ssh "$SSH_TARGET" "if [[ -x '$REMOTE_ROOT/bin/stop_gui.sh' ]]; then '$REMOTE_ROOT/bin/stop_gui.sh'; fi"

if [[ -f "$TUNNEL_PID_FILE" ]]; then
  pid="$(cat "$TUNNEL_PID_FILE" || true)"
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
    log "Stopping local SSH tunnel PID $pid."
    kill "$pid" || true
  fi
  rm -f "$TUNNEL_PID_FILE"
fi

if command -v pkill >/dev/null 2>&1; then
  pkill -f "ssh.*127.0.0.1:${LOCAL_PORT}:127.0.0.1:" 2>/dev/null || true
fi
log "Stopped."
