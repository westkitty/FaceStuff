#!/usr/bin/env bash
set -euo pipefail
ROOT="${FACETOOLS_ROOT:-/Users/bigmac/AI/FaceTools}"
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
echo
if [[ -d "$ROOT" ]]; then df -h "$ROOT"; fi
echo
if [[ -f "$ROOT/run/gui.pid" ]]; then
  pid=$(cat "$ROOT/run/gui.pid" || true)
  echo "gui_pid=$pid"
  if [[ -n "$pid" ]]; then ps -p "$pid" -o pid,ppid,stat,command || true; fi
else
  echo "gui_pid=none"
fi
