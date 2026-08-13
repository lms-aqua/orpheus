#!/bin/bash
# Resolve a concrete iOS Simulator UDID to build and test against.
#
# Hardcoded destinations like 'name=iPhone 17,OS=26.4' are the most common
# reason these workflows break: GitHub prunes simulator runtimes for disk space
# (they support at most ~3 runtime sets), and device names change every cycle.
# So we ask simctl what actually exists and pick the newest iOS runtime.
set -euo pipefail

echo "--- Available iOS runtimes ---" >&2
xcrun simctl list runtimes ios >&2 || true

DEVICES_JSON="$(xcrun simctl list devices available --json)"

# Newest available iOS runtime, compared as numeric version components rather
# than lexically (so 26.10 would sort above 26.9).
RUNTIME_KEY="$(printf '%s' "$DEVICES_JSON" | jq -r '
  .devices
  | to_entries
  | map(select(.key | test("SimRuntime\\.iOS-")))
  | map(select(.value | map(select(.isAvailable)) | length > 0))
  | map({
      key: .key,
      version: (.key | capture("iOS-(?<v>[0-9-]+)$").v | split("-") | map(tonumber))
    })
  | sort_by(.version)
  | last
  | (.key // empty)
')"

if [[ -z "${RUNTIME_KEY:-}" ]]; then
  echo "error: no iOS simulator runtime with available devices was found." >&2
  echo "hint: 'xcodebuild -downloadPlatform iOS' installs one, at a large time cost." >&2
  exit 1
fi

# Prefer a Pro-class iPhone, then any iPhone, then give up rather than silently
# testing on an iPad when we asked for a phone.
read -r UDID NAME <<<"$(printf '%s' "$DEVICES_JSON" | jq -r --arg rt "$RUNTIME_KEY" '
  [.devices[$rt][] | select(.isAvailable)]
  | (map(select(.name | startswith("iPhone") and contains("Pro")))
     + map(select(.name | startswith("iPhone")))
     + map(select(.name | startswith("iPad"))))
  | (.[0] // empty)
  | "\(.udid) \(.name)"
')"

if [[ -z "${UDID:-}" ]]; then
  echo "error: no available simulator device in runtime ${RUNTIME_KEY}." >&2
  printf '%s' "$DEVICES_JSON" | jq -r --arg rt "$RUNTIME_KEY" '.devices[$rt][]?.name' >&2 || true
  exit 1
fi

DESTINATION="platform=iOS Simulator,id=${UDID}"

echo "Resolved simulator: ${NAME} (${RUNTIME_KEY})" >&2
echo "Destination: ${DESTINATION}" >&2

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "destination=${DESTINATION}"
    echo "udid=${UDID}"
    echo "name=${NAME}"
    echo "runtime=${RUNTIME_KEY}"
  } >>"$GITHUB_OUTPUT"
fi

printf '%s\n' "$DESTINATION"
