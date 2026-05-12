#!/usr/bin/env bash
set -euo pipefail

SSH_TARGET="${SSH_TARGET:-westcat}"
REMOTE_ROOT="${REMOTE_ROOT:-/Users/bigmac/AI/FaceTools}"

fail() { printf '[facetools check] ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '[facetools check] %s\n' "$*"; }

out="$(ssh "$SSH_TARGET" 'whoami && hostname && pwd && sw_vers' 2>&1)" || { printf '%s\n' "$out" >&2; fail "Cannot reach Big Mac."; }
line1="$(printf '%s\n' "$out" | sed -n '1p')"
line2="$(printf '%s\n' "$out" | sed -n '2p')"
[[ "$line1" != "andrew" ]] || fail "Wrong SSH route: whoami returned andrew. Stop."
[[ "$line1" == "bigmac" && "$line2" == "bigmac" ]] || { printf '%s\n' "$out" >&2; fail "Route verification failed."; }
log "Route OK."
ssh "$SSH_TARGET" "if [[ -x '$REMOTE_ROOT/bin/run_diagnostics.sh' ]]; then '$REMOTE_ROOT/bin/run_diagnostics.sh'; else echo 'Facetools not installed at $REMOTE_ROOT'; fi"
