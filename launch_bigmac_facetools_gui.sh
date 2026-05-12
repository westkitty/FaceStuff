#!/usr/bin/env bash
set -euo pipefail

SSH_TARGET="${SSH_TARGET:-westcat}"
REMOTE_ROOT="${REMOTE_ROOT:-/Users/bigmac/AI/FaceTools}"
REMOTE_PORT="${REMOTE_PORT:-7865}"
LOCAL_PORT="${LOCAL_PORT:-7865}"
TUNNEL_PID_FILE="${TMPDIR:-/tmp}/bigmac_facetools_gui_tunnel_${LOCAL_PORT}.pid"

log() { printf '[facetools launch] %s\n' "$*"; }
fail() { printf '[facetools launch] ERROR: %s\n' "$*" >&2; exit 1; }

verify_route() {
  local out line1 line2
  out="$(ssh "$SSH_TARGET" 'whoami && hostname && pwd && sw_vers' 2>&1)" || { printf '%s\n' "$out" >&2; fail "Cannot reach Big Mac."; }
  line1="$(printf '%s\n' "$out" | sed -n '1p')"
  line2="$(printf '%s\n' "$out" | sed -n '2p')"
  [[ "$line1" != "andrew" ]] || fail "Wrong SSH route: whoami returned andrew. Stop."
  [[ "$line1" == "bigmac" && "$line2" == "bigmac" ]] || { printf '%s\n' "$out" >&2; fail "Route verification failed."; }
}

port_in_use() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1
  else
    nc -z 127.0.0.1 "$LOCAL_PORT" >/dev/null 2>&1
  fi
}

verify_route
log "Starting GUI service on Big Mac."
ssh "$SSH_TARGET" "'$REMOTE_ROOT/bin/start_gui.sh' --port '$REMOTE_PORT'"

if port_in_use; then
  log "Local port ${LOCAL_PORT} is already listening. Assuming an existing tunnel or local service."
else
  log "Opening SSH tunnel 127.0.0.1:${LOCAL_PORT} -> Big Mac 127.0.0.1:${REMOTE_PORT}."
  ssh -fN -L "127.0.0.1:${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" -o ExitOnForwardFailure=yes "$SSH_TARGET"
  if command -v pgrep >/dev/null 2>&1; then
    pgrep -f "ssh.*127.0.0.1:${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" | tail -n 1 > "$TUNNEL_PID_FILE" || true
  fi
fi

URL="http://127.0.0.1:${LOCAL_PORT}"
log "GUI URL: ${URL}"
if command -v open >/dev/null 2>&1; then
  open "$URL" || true
fi
printf '%s\n' "$URL"
