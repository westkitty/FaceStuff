#!/usr/bin/env bash
set -euo pipefail

ROOT="${FACETOOLS_ROOT:-/Users/bigmac/AI/FaceTools}"
APPS_DIR="$ROOT/apps"
FACEFUSION_DIR="$APPS_DIR/facefusion"
LOG_DIR="$ROOT/logs"
BIN_DIR="$ROOT/bin"
CONFIG_DIR="$ROOT/config"
DATA_DIR="$ROOT/data"
RUN_DIR="$ROOT/run"
DRY_RUN=0
REPAIR=0
CLEAN_REINSTALL=0
SKIP_MODEL_DOWNLOAD=0
FACEFUSION_REF="latest"

log() { printf '[remote install] %s\n' "$*"; }
fail() { printf '[remote install] ERROR: %s\n' "$*" >&2; exit 1; }
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] %q ' "$@"; printf '\n'
  else
    "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --repair) REPAIR=1 ;;
    --clean-reinstall) CLEAN_REINSTALL=1 ;;
    --skip-model-download) SKIP_MODEL_DOWNLOAD=1 ;;
    --facefusion-ref) shift; FACEFUSION_REF="${1:-}"; [[ -n "$FACEFUSION_REF" ]] || fail "--facefusion-ref requires a value" ;;
    *) fail "Unknown option: $1" ;;
  esac
  shift
done

verify_remote_identity() {
  local u h arch
  u="$(whoami)"
  h="$(hostname)"
  arch="$(uname -m)"
  [[ "$u" == "bigmac" ]] || fail "Expected remote user bigmac, got $u. Stop."
  [[ "$h" == "bigmac" ]] || fail "Expected remote hostname bigmac, got $h. Stop."
  [[ "$arch" == "arm64" ]] || fail "Expected Apple Silicon arm64, got $arch."
}

ensure_dirs() {
  run mkdir -p "$ROOT" "$APPS_DIR" "$LOG_DIR/jobs" "$BIN_DIR" "$CONFIG_DIR" "$RUN_DIR" \
    "$DATA_DIR/uploads" "$DATA_DIR/outputs" "$DATA_DIR/jobs" "$DATA_DIR/tmp" "$ROOT/models" "$ROOT/third_party"
}

path_setup() {
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
}

ensure_homebrew() {
  path_setup
  if command -v brew >/dev/null 2>&1; then
    log "Homebrew found: $(brew --prefix)"
    return 0
  fi
  log "Homebrew not found. Attempting official noninteractive Homebrew install."
  if [[ "$DRY_RUN" == "1" ]]; then
    log "Would run Homebrew installer."
    return 0
  fi
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || \
    fail "Homebrew install failed. Install Homebrew on Big Mac manually, then rerun repair."
  path_setup
  command -v brew >/dev/null 2>&1 || fail "Homebrew still not on PATH after install."
}

brew_install_if_missing() {
  local pkg="$1"
  if brew list --versions "$pkg" >/dev/null 2>&1; then
    log "brew package present: $pkg"
  else
    log "Installing brew package: $pkg"
    run brew install "$pkg"
  fi
}

ensure_brew_deps() {
  path_setup
  brew_install_if_missing git
  brew_install_if_missing miniconda
  brew_install_if_missing ffmpeg@7 || brew_install_if_missing ffmpeg
  if brew --prefix ffmpeg@7 >/dev/null 2>&1; then
    export PATH="$(brew --prefix ffmpeg@7)/bin:$PATH"
  fi
  # Accept Conda ToS for Anaconda channels if miniconda was installed
  if [[ -x "/opt/homebrew/bin/conda" ]]; then
    "/opt/homebrew/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
    "/opt/homebrew/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true
  fi
}

find_conda() {
  local candidates=(
    "/opt/homebrew/bin/conda"
    "/opt/homebrew/Caskroom/miniconda/base/bin/conda"
    "$HOME/miniforge3/bin/conda"
    "$HOME/miniconda3/bin/conda"
  )
  local c
  for c in "${candidates[@]}"; do
    if [[ -x "$c" ]]; then
      printf '%s' "$c"
      return 0
    fi
  done
  if command -v conda >/dev/null 2>&1; then
    command -v conda
    return 0
  fi
  return 1
}

conda_run() {
  local conda_bin="$1"; shift
  "$conda_bin" run "$@"
}

ensure_conda_env() {
  local conda_bin="$1" env_name="$2" pyver="$3"
  if "$conda_bin" env list | awk '{print $1}' | grep -Fxq "$env_name"; then
    log "conda env present: $env_name"
  else
    log "Creating conda env: $env_name python=$pyver"
    run "$conda_bin" create -y -n "$env_name" "python=$pyver" "pip=25.0"
  fi
}

latest_facefusion_tag() {
  git ls-remote --tags --sort=-v:refname https://github.com/facefusion/facefusion.git 'refs/tags/[0-9]*' \
    | awk -F/ '{print $3}' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | head -n 1
}

install_facefusion() {
  local conda_bin="$1"
  if [[ "$CLEAN_REINSTALL" == "1" ]]; then
    log "Clean reinstall requested: removing FaceFusion checkout and conda env facefusion. Data stays."
    run rm -rf "$FACEFUSION_DIR"
    if "$conda_bin" env list | awk '{print $1}' | grep -Fxq facefusion; then
      run "$conda_bin" env remove -y -n facefusion
    fi
  fi
  ensure_conda_env "$conda_bin" facefusion 3.12
  if [[ ! -d "$FACEFUSION_DIR/.git" ]]; then
    log "Cloning FaceFusion."
    run git clone https://github.com/facefusion/facefusion.git "$FACEFUSION_DIR"
  else
    log "Updating FaceFusion checkout."
    run git -C "$FACEFUSION_DIR" fetch --tags --prune origin
  fi
  local ref="$FACEFUSION_REF"
  if [[ "$ref" == "latest" ]]; then
    ref="$(latest_facefusion_tag || true)"
    [[ -n "$ref" ]] || ref="master"
  fi
  log "Checking out FaceFusion ref: $ref"
  run git -C "$FACEFUSION_DIR" checkout "$ref"
  # Only pull if we are on a branch
  if git -C "$FACEFUSION_DIR" symbolic-ref -q HEAD >/dev/null; then
    run git -C "$FACEFUSION_DIR" pull --ff-only || true
  fi

  log "Installing FaceFusion using official install.py flow with ONNX Runtime default."
  ( cd "$FACEFUSION_DIR" && run conda_run "$conda_bin" -n facefusion python install.py --onnxruntime default )

  local version_file="$CONFIG_DIR/facefusion_version.txt"
  if [[ "$DRY_RUN" == "0" ]]; then
    {
      echo "ref=$ref"
      echo "git_describe=$(git -C "$FACEFUSION_DIR" describe --tags --always --dirty 2>/dev/null || true)"
      echo "git_commit=$(git -C "$FACEFUSION_DIR" rev-parse HEAD 2>/dev/null || true)"
      ( cd "$FACEFUSION_DIR" && conda_run "$conda_bin" -n facefusion python facefusion.py --version 2>&1 | sed 's/^/facefusion_version_output=/' || true )
      date -u '+installed_utc=%Y-%m-%dT%H:%M:%SZ'
    } > "$version_file"
  fi
}

install_gui_env() {
  local conda_bin="$1"
  ensure_conda_env "$conda_bin" facetools-gui 3.12
  log "Installing GUI Python dependencies."
  run conda_run "$conda_bin" -n facetools-gui python -m pip install --upgrade pip
  run conda_run "$conda_bin" -n facetools-gui python -m pip install \
    fastapi 'uvicorn[standard]' python-multipart pydantic aiofiles
}

copy_runtime_files() {
  local src_dir
  src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  log "Copying GUI and service scripts into $ROOT."
  run mkdir -p "$ROOT/gui" "$ROOT/static" "$BIN_DIR" "$ROOT/launchagents"
  run cp -R "$src_dir/gui/." "$ROOT/gui/"
  run cp -R "$src_dir/static/." "$ROOT/static/"
  run cp "$src_dir/bin/"*.sh "$BIN_DIR/"
  run chmod +x "$BIN_DIR/"*.sh
  run cp "$src_dir/launchagents/ca.westcat.facetools.gui.plist" "$ROOT/launchagents/"
}

write_default_config() {
  local cfg="$CONFIG_DIR/settings.json"
  if [[ ! -f "$cfg" || "$REPAIR" == "1" ]]; then
    log "Writing default settings to $cfg"
    if [[ "$DRY_RUN" == "0" ]]; then
      cat > "$cfg" <<EOF
{
  "host": "127.0.0.1",
  "port": 7865,
  "default_preset": "balanced",
  "default_processors": ["face_swapper", "face_enhancer"],
  "default_execution_provider": "auto",
  "default_face_enhancer_model": "gfpgan_1.4",
  "consent_notice_acknowledged": false
}
EOF
    fi
  fi
}

predownload_models() {
  local conda_bin="$1"
  [[ "$SKIP_MODEL_DOWNLOAD" == "0" ]] || { log "Skipping model pre-download by request."; return 0; }
  log "Attempting FaceFusion model pre-download. If upstream changes flags, diagnostics will report it."
  if [[ "$DRY_RUN" == "1" ]]; then
    log "Would run force-download."
    return 0
  fi
  local help_text
  help_text="$(conda_run "$conda_bin" -n facefusion python "$FACEFUSION_DIR/facefusion.py" force-download --help 2>&1 || true)"
  local args=("$FACEFUSION_DIR/facefusion.py" force-download)
  if grep -q -- '--download-scope' <<<"$help_text"; then
    args+=(--download-scope full)
  fi
  if grep -q -- '--download-providers' <<<"$help_text"; then
    args+=(--download-providers huggingface github)
  fi
  ( cd "$FACEFUSION_DIR" && conda_run "$conda_bin" -n facefusion python "${args[@]}" ) || log "Model pre-download failed. The GUI can still trigger downloads during first run. See logs."
}

smoke_test() {
  local conda_bin="$1"
  log "Running smoke tests."
  if [[ "$DRY_RUN" == "1" ]]; then
    log "Would run smoke tests."
    return 0
  fi
  conda_run "$conda_bin" -n facefusion python --version
  conda_run "$conda_bin" -n facetools-gui python --version
  ffmpeg -version | head -n 1
  ( cd "$FACEFUSION_DIR" && conda_run "$conda_bin" -n facefusion python facefusion.py --version || true )
  ( cd "$FACEFUSION_DIR" && conda_run "$conda_bin" -n facefusion python facefusion.py headless-run --help >/dev/null ) || \
    log "headless-run help failed; GUI diagnostics will expose details."
}

main() {
  verify_remote_identity
  ensure_dirs
  ensure_homebrew
  ensure_brew_deps
  local conda_bin
  conda_bin="$(find_conda)" || fail "conda not found after Homebrew miniconda install."
  log "Using conda: $conda_bin"
  install_facefusion "$conda_bin"
  install_gui_env "$conda_bin"
  copy_runtime_files
  write_default_config
  predownload_models "$conda_bin"
  smoke_test "$conda_bin"
  log "Install complete at $ROOT"
}

main "$@"
