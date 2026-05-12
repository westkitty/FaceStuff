#!/usr/bin/env bash
set -euo pipefail
ROOT="${FACETOOLS_ROOT:-/Users/bigmac/AI/FaceTools}"
export FACETOOLS_EXTERNAL_ROOT="${FACETOOLS_EXTERNAL_ROOT:-/Volumes/wc2tb/AI/FaceTools}"
export HF_HOME="$FACETOOLS_EXTERNAL_ROOT/cache/huggingface"
export HF_HUB_CACHE="$FACETOOLS_EXTERNAL_ROOT/cache/huggingface/hub"
export HF_XET_CACHE="$FACETOOLS_EXTERNAL_ROOT/cache/huggingface/xet"
export XDG_CACHE_HOME="$FACETOOLS_EXTERNAL_ROOT/cache/xdg"
export TORCH_HOME="$FACETOOLS_EXTERNAL_ROOT/cache/torch"
echo "== Big Mac FaceTools diagnostics =="
echo "user=$(whoami)"
echo "host=$(hostname)"
echo "arch=$(uname -m)"
sw_vers || true
echo
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
echo "== tools =="
command -v brew || true
command -v git || true
command -v ffmpeg || true
ffmpeg -version 2>/dev/null | head -n 1 || true
if [[ -x /opt/homebrew/bin/conda ]]; then CONDA=/opt/homebrew/bin/conda; elif [[ -x /opt/homebrew/Caskroom/miniconda/base/bin/conda ]]; then CONDA=/opt/homebrew/Caskroom/miniconda/base/bin/conda; else CONDA=$(command -v conda || true); fi
echo "conda=${CONDA:-missing}"
if [[ -n "${CONDA:-}" ]]; then
  "$CONDA" env list || true
  "$CONDA" run -n facefusion python --version || true
  "$CONDA" run -n facetools-gui python --version || true
fi
echo
if [[ -f "$ROOT/config/facefusion_version.txt" ]]; then cat "$ROOT/config/facefusion_version.txt"; fi
echo
if [[ -f "$ROOT/apps/facefusion/facefusion.py" && -n "${CONDA:-}" ]]; then
  "$CONDA" run -n facefusion python "$ROOT/apps/facefusion/facefusion.py" --version || true
  "$CONDA" run -n facefusion python "$ROOT/apps/facefusion/facefusion.py" headless-run --help 2>&1 | sed -n '1,80p' || true
fi
echo "== environment =="
env | grep -E "FACETOOLS|HF_|XDG_|TORCH_" | sort || true
echo
if [[ -d "$ROOT" ]]; then echo "Internal ($ROOT):"; df -h "$ROOT"; fi
if [[ -d "$FACETOOLS_EXTERNAL_ROOT" ]]; then echo "External ($FACETOOLS_EXTERNAL_ROOT):"; df -h "$FACETOOLS_EXTERNAL_ROOT"; fi
echo
if [[ -f "$ROOT/run/gui.pid" ]]; then
  pid=$(cat "$ROOT/run/gui.pid" || true)
  echo "gui_pid=$pid"
  if [[ -n "$pid" ]]; then ps -p "$pid" -o pid,ppid,stat,command || true; fi
else
  echo "gui_pid=none"
fi
