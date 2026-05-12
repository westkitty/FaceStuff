#!/usr/bin/env bash
set -euo pipefail
ROOT="${FACETOOLS_ROOT:-/Users/bigmac/AI/FaceTools}"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"
find "$LOG_DIR" -type f -name '*.log' -size +20M -print -exec gzip -f {} \;
find "$LOG_DIR" -type f -name '*.gz' -mtime +30 -print -delete
