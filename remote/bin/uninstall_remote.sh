#!/usr/bin/env bash
set -euo pipefail
ROOT="${FACETOOLS_ROOT:-/Users/bigmac/AI/FaceTools}"
KEEP_DATA="${KEEP_DATA:-1}"
if [[ -x "$ROOT/bin/stop_gui.sh" ]]; then "$ROOT/bin/stop_gui.sh" || true; fi
if [[ "$KEEP_DATA" == "1" ]]; then
  echo "Keeping data under $ROOT/data and logs under $ROOT/logs"
  rm -rf "$ROOT/apps" "$ROOT/gui" "$ROOT/static" "$ROOT/bin" "$ROOT/config" "$ROOT/run" "$ROOT/launchagents" "$ROOT/_incoming"
else
  rm -rf "$ROOT"
fi
echo "Uninstall complete."
