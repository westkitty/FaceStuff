#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/Users/andrew/Library/Mobile Documents/com~apple~CloudDocs/Projects/FaceStuff"
YES="${1:-}"
EXPECTED_SHA256="7224303b3ff7d5896dc1ed010f9d159b2516dde39730692687f9acb7525572dc"

if [[ "${YES}" != "--yes" ]]; then
  echo "This will reconstruct and unpack Big Mac FaceTools into:"
  echo "  ${PROJECT_ROOT}"
  echo
  echo "Run again with --yes to proceed:"
  echo "  bash hydrate_facetools_from_bundle_parts.sh --yes"
  exit 2
fi

if [[ ! -d "${PROJECT_ROOT}" ]]; then
  echo "Project root does not exist: ${PROJECT_ROOT}" >&2
  exit 1
fi

cd "${PROJECT_ROOT}"

if [[ ! -d bundle_parts ]]; then
  echo "Missing bundle_parts directory in ${PROJECT_ROOT}" >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "${TMPDIR}"; }
trap cleanup EXIT

BUNDLE_B64="${TMPDIR}/bigmac_facetools_bundle.b64"
BUNDLE_ZIP="${TMPDIR}/bigmac_facetools_bundle.zip"

cat bundle_parts/part_*.b64 > "${BUNDLE_B64}"
base64 -d "${BUNDLE_B64}" > "${BUNDLE_ZIP}"

ACTUAL_SHA256="$(shasum -a 256 "${BUNDLE_ZIP}" | awk '{print $1}')"
echo "Decoded bundle SHA256: ${ACTUAL_SHA256}"

if [[ "${ACTUAL_SHA256}" != "${EXPECTED_SHA256}" ]]; then
  echo "Bundle SHA256 mismatch." >&2
  echo "Expected: ${EXPECTED_SHA256}" >&2
  echo "Actual:   ${ACTUAL_SHA256}" >&2
  exit 1
fi

unzip -q "${BUNDLE_ZIP}" -d "${TMPDIR}/unpacked"

if [[ -d "${TMPDIR}/unpacked/bigmac_facetools_bundle" ]]; then
  rsync -a "${TMPDIR}/unpacked/bigmac_facetools_bundle/" "${PROJECT_ROOT}/"
else
  rsync -a "${TMPDIR}/unpacked/" "${PROJECT_ROOT}/"
fi

chmod +x ./*.sh 2>/dev/null || true
find remote -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

echo "Materialized FaceTools project in: ${PROJECT_ROOT}"
find . -maxdepth 3 -type f | sort
