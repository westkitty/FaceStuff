#!/usr/bin/env bash
set -euo pipefail
ROOT="${FACETOOLS_ROOT:-/Users/bigmac/AI/FaceTools}"
export FACETOOLS_EXTERNAL_ROOT="${FACETOOLS_EXTERNAL_ROOT:-/Volumes/wc2tb/AI/FaceTools}"
export HF_HOME="$FACETOOLS_EXTERNAL_ROOT/cache/huggingface"
export HF_HUB_CACHE="$FACETOOLS_EXTERNAL_ROOT/cache/huggingface/hub"
export HF_XET_CACHE="$FACETOOLS_EXTERNAL_ROOT/cache/huggingface/xet"
export XDG_CACHE_HOME="$FACETOOLS_EXTERNAL_ROOT/cache/xdg"
export TORCH_HOME="$FACETOOLS_EXTERNAL_ROOT/cache/torch"
PORT="7865"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) shift; PORT="${1:-7865}" ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done
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
mkdir -p "$ROOT/run" "$ROOT/logs"
PID_FILE="$ROOT/run/gui.pid"
LOG_FILE="$ROOT/logs/gui.log"
if [[ -f "$PID_FILE" ]]; then
  old_pid="$(cat "$PID_FILE" || true)"
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    echo "GUI already running with PID $old_pid"
    exit 0
  fi
fi
cd "$ROOT"
FACETOOLS_ROOT="$ROOT" nohup "$CONDA_BIN" run -n facetools-gui uvicorn gui.app:app --host 127.0.0.1 --port "$PORT" >>"$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
sleep 2
if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "GUI failed to start. See $LOG_FILE" >&2
  exit 1
fi
echo "GUI started on Big Mac: http://127.0.0.1:$PORT"
