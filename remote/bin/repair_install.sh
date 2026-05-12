#!/usr/bin/env bash
set -euo pipefail
ROOT="${FACETOOLS_ROOT:-/Users/bigmac/AI/FaceTools}"
cd "$ROOT/_incoming"
bash remote/install_remote.sh --repair "$@"
