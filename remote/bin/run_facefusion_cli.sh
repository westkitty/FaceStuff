#!/usr/bin/env bash
set -euo pipefail
ROOT="${FACETOOLS_ROOT:-/Users/bigmac/AI/FaceTools}"
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
