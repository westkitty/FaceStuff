#!/usr/bin/env bash
set -euo pipefail
ROOT="${FACETOOLS_ROOT:-/Users/bigmac/AI/FaceTools}"
export FACETOOLS_EXTERNAL_ROOT="${FACETOOLS_EXTERNAL_ROOT:-/Volumes/wc2tb/AI/FaceTools}"
export HF_HOME="$FACETOOLS_EXTERNAL_ROOT/cache/huggingface"
export HF_HUB_CACHE="$FACETOOLS_EXTERNAL_ROOT/cache/huggingface/hub"
export HF_XET_CACHE="$FACETOOLS_EXTERNAL_ROOT/cache/huggingface/xet"
export XDG_CACHE_HOME="$FACETOOLS_EXTERNAL_ROOT/cache/xdg"
export TORCH_HOME="$FACETOOLS_EXTERNAL_ROOT/cache/torch"
CONDA_BIN="${CONDA_BIN:-/opt/homebrew/bin/conda}"
if [[ ! -x "$CONDA_BIN" ]]; then
  if [[ -x "/opt/homebrew/Caskroom/miniconda/base/bin/conda" ]]; then
    CONDA_BIN="/opt/homebrew/Caskroom/miniconda/base/bin/conda"
  elif command -v conda >/dev/null 2>&1; then
    CONDA_BIN="$(command -v conda)"
  else
    echo "conda not found" >&2
    exit 1
  fi
fi
cd "$ROOT/apps/facefusion"
exec "$CONDA_BIN" run -n facefusion python "$ROOT/apps/facefusion/facefusion.py" "$@"
