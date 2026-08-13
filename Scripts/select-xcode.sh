#!/bin/bash
# Select an Xcode 26 toolchain and export DEVELOPER_DIR for later steps.
#
# We pin a preferred version rather than trusting the runner's default, because
# the macos-26 image default has been rotated repeatedly (16.4 -> 26.2 ->
# 26.4.1 -> 26.6). We still fall back to the newest available Xcode 26 so the
# build survives the pinned version being pruned from the image.
set -euo pipefail

PREFERRED="${ORPHEUS_XCODE_VERSION:-26.6}"

pick_xcode() {
  local preferred_path="/Applications/Xcode_${PREFERRED}.app"
  if [[ -d "$preferred_path" ]]; then
    echo "$preferred_path"
    return 0
  fi

  echo "note: Xcode ${PREFERRED} not present; falling back to newest Xcode 26.x" >&2

  # Sort available Xcode 26.x installs by version and take the highest.
  local newest
  newest="$(ls -d /Applications/Xcode_26*.app 2>/dev/null \
    | sed -E 's#.*/Xcode_([0-9.]+)\.app#\1 &#' \
    | sort -V -k1,1 \
    | tail -n 1 \
    | cut -d' ' -f2- || true)"

  if [[ -n "$newest" && -d "$newest" ]]; then
    echo "$newest"
    return 0
  fi

  echo "error: no Xcode 26.x found in /Applications." >&2
  ls -d /Applications/Xcode*.app 2>/dev/null >&2 || true
  return 1
}

XCODE_APP="$(pick_xcode)"
DEVELOPER_DIR="${XCODE_APP}/Contents/Developer"

echo "DEVELOPER_DIR=${DEVELOPER_DIR}" >>"${GITHUB_ENV:-/dev/null}"
export DEVELOPER_DIR

echo "Selected: ${XCODE_APP}"
"${DEVELOPER_DIR}/usr/bin/xcodebuild" -version

# Fail loudly if this toolchain cannot target iOS 26 at all, rather than
# discovering it halfway through a build.
if ! "${DEVELOPER_DIR}/usr/bin/xcodebuild" -showsdks 2>/dev/null | grep -q "iphoneos26"; then
  echo "error: selected Xcode has no iOS 26 SDK." >&2
  "${DEVELOPER_DIR}/usr/bin/xcodebuild" -showsdks >&2 || true
  exit 1
fi
