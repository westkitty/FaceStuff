#!/usr/bin/env bash
set -euo pipefail

SSH_TARGET="${SSH_TARGET:-westcat}"
REMOTE_ROOT="${REMOTE_ROOT:-/Users/bigmac/AI/FaceTools}"
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
REPAIR=0
CLEAN_REINSTALL=0
UNINSTALL=0
SKIP_MODEL_DOWNLOAD=0
FACEFUSION_REF="${FACEFUSION_REF:-latest}"

log() { printf '[facetools install] %s\n' "$*"; }
fail() { printf '[facetools install] ERROR: %s\n' "$*" >&2; exit 1; }
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] %q ' "$@"; printf '\n'
  else
    "$@"
  fi
}

usage() {
  cat <<'EOF'
Usage: ./install_bigmac_facetools.sh [options]

Options:
  --dry-run              Show actions without changing Big Mac.
  --repair               Re-run dependency/env/install checks without deleting data.
  --clean-reinstall      Remove FaceFusion checkout and conda envs, then reinstall. Data kept.
  --uninstall            Run remote uninstaller. Data kept unless remote flag is edited manually.
  --skip-model-download  Do not pre-download FaceFusion models.
  --facefusion-ref REF   Git tag/branch/commit. Default: latest release tag.
  -h, --help             Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --repair) REPAIR=1 ;;
    --clean-reinstall) CLEAN_REINSTALL=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --skip-model-download) SKIP_MODEL_DOWNLOAD=1 ;;
    --facefusion-ref) shift; FACEFUSION_REF="${1:-}"; [[ -n "$FACEFUSION_REF" ]] || fail "--facefusion-ref requires a value" ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
  shift
done

verify_route() {
  log "Verifying SSH route through ${SSH_TARGET} before any state-changing action."
  local out line1 line2
  out="$(ssh "$SSH_TARGET" 'whoami && hostname && pwd && sw_vers' 2>&1)" || {
    printf '%s\n' "$out" >&2
    fail "Cannot reach Big Mac through ssh ${SSH_TARGET}."
  }
  line1="$(printf '%s\n' "$out" | sed -n '1p')"
  line2="$(printf '%s\n' "$out" | sed -n '2p')"
  if [[ "$line1" == "andrew" ]]; then
    printf '%s\n' "$out" >&2
    fail "Wrong SSH route: whoami returned andrew. Stop. Do not continue."
  fi
  if [[ "$line1" != "bigmac" || "$line2" != "bigmac" ]]; then
    printf '%s\n' "$out" >&2
    fail "Route verification failed. Expected first two lines: bigmac / bigmac."
  fi
  log "Route verified: ${SSH_TARGET} -> bigmac@bigmac."
}

make_archive() {
  local archive
  archive="$(mktemp -t bigmac-facetools.XXXXXX.tar.gz)"
  (cd "$LOCAL_DIR" && tar --exclude='.git' --exclude='*.tar.gz' -czf "$archive" remote)
  printf '%s' "$archive"
}

remote_exec() {
  ssh "$SSH_TARGET" "$@"
}

verify_route

if [[ "$UNINSTALL" == "1" ]]; then
  log "Running remote uninstaller. Data is kept by default."
  run ssh "$SSH_TARGET" "if [[ -x '$REMOTE_ROOT/bin/uninstall_remote.sh' ]]; then '$REMOTE_ROOT/bin/uninstall_remote.sh'; else echo 'Remote uninstaller not found.' >&2; exit 1; fi"
  exit 0
fi

ARCHIVE="$(make_archive)"
trap 'rm -f "$ARCHIVE"' EXIT

log "Uploading installer bundle to Big Mac."
run ssh "$SSH_TARGET" "mkdir -p '$REMOTE_ROOT/_incoming'"
if [[ "$DRY_RUN" == "1" ]]; then
  log "Would scp $ARCHIVE to ${SSH_TARGET}:${REMOTE_ROOT}/_incoming/facetools_bundle.tar.gz"
else
  scp "$ARCHIVE" "$SSH_TARGET:$REMOTE_ROOT/_incoming/facetools_bundle.tar.gz" >/dev/null
fi

remote_flags=()
[[ "$DRY_RUN" == "1" ]] && remote_flags+=("--dry-run")
[[ "$REPAIR" == "1" ]] && remote_flags+=("--repair")
[[ "$CLEAN_REINSTALL" == "1" ]] && remote_flags+=("--clean-reinstall")
[[ "$SKIP_MODEL_DOWNLOAD" == "1" ]] && remote_flags+=("--skip-model-download")
remote_flags+=("--facefusion-ref" "$FACEFUSION_REF")

log "Expanding and running remote installer."
if [[ "$DRY_RUN" == "1" ]]; then
  printf '[dry-run] ssh %q %q\n' "$SSH_TARGET" "cd '$REMOTE_ROOT/_incoming' && tar -xzf facetools_bundle.tar.gz && bash remote/install_remote.sh ${remote_flags[*]}"
else
  ssh "$SSH_TARGET" "cd '$REMOTE_ROOT/_incoming' && rm -rf remote && tar -xzf facetools_bundle.tar.gz && bash remote/install_remote.sh ${remote_flags[*]}"
fi

log "Done. Launch with: ./launch_bigmac_facetools_gui.sh"
