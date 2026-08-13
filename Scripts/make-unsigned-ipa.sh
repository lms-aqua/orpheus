#!/bin/bash
# Build an UNSIGNED .ipa suitable for sideloading with AltStore or SideStore.
#
# Usage: ./Scripts/make-unsigned-ipa.sh [marketing_version] [build_number]
#
# Why unsigned: signing in CI would require an Apple Developer certificate and
# provisioning profile stored as repository secrets. AltStore and SideStore sign
# on-device with the owner's own Apple ID anyway, so a signed CI build would be
# re-signed immediately and the secrets would buy nothing but risk.
#
# The trade-off this creates is real and documented in docs/SIDELOADING.md:
# entitlements are applied at signing time, so an unsigned build carries none.
# ORPHEUS therefore loses its app-wide `NSFileProtectionComplete` default when
# sideloaded. Encrypted blobs still set their protection class explicitly in
# code, so content protection survives; the SwiftData metadata store falls back
# to the system default class.
set -euo pipefail

SCHEME="ORPHEUS"
PROJECT="ORPHEUS.xcodeproj"
CONFIGURATION="Release"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/ORPHEUS.xcarchive"
IPA_PATH="${BUILD_DIR}/ORPHEUS.ipa"

MARKETING_VERSION="${1:-}"
BUILD_NUMBER="${2:-}"

overrides=()
if [[ -n "$MARKETING_VERSION" ]]; then
  overrides+=("MARKETING_VERSION=${MARKETING_VERSION}")
fi
if [[ -n "$BUILD_NUMBER" ]]; then
  overrides+=("CURRENT_PROJECT_VERSION=${BUILD_NUMBER}")
fi

echo "==> Archiving ${SCHEME} (${CONFIGURATION}) for device, unsigned"
rm -rf "$ARCHIVE_PATH"
mkdir -p "$BUILD_DIR"

# Release configuration on a real device destination: this compiles with
# whole-module optimisation and the device SDK, which catches problems a Debug
# simulator build hides.
set -o pipefail
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "${BUILD_DIR}/DerivedData-Release" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  "${overrides[@]}" \
  2>&1 | tee "${BUILD_DIR}/archive.log"

APP_PATH="${ARCHIVE_PATH}/Products/Applications/${SCHEME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: archived app not found at ${APP_PATH}" >&2
  ls -R "${ARCHIVE_PATH}/Products" >&2 || true
  exit 1
fi

echo "==> Packaging Payload/"
PAYLOAD_DIR="${BUILD_DIR}/Payload"
rm -rf "$PAYLOAD_DIR" "$IPA_PATH"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "${PAYLOAD_DIR}/"

# An unsigned build should not carry a stale signature directory; leaving one
# behind makes some sideloading tools refuse the bundle.
rm -rf "${PAYLOAD_DIR}/${SCHEME}.app/_CodeSignature"

# An .ipa is just a zip with a top-level Payload directory.
( cd "$BUILD_DIR" && zip -qry "$(basename "$IPA_PATH")" Payload )
rm -rf "$PAYLOAD_DIR"

IPA_SIZE=$(stat -f%z "$IPA_PATH")
IPA_SHA=$(shasum -a 256 "$IPA_PATH" | cut -d' ' -f1)

# Read back what actually got built, rather than trusting the arguments.
PLIST="${APP_PATH}/Info.plist"
ACTUAL_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
ACTUAL_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$PLIST" 2>/dev/null || echo "26.0")

echo "==> Built ${IPA_PATH}"
echo "    version    ${ACTUAL_VERSION} (${ACTUAL_BUILD})"
echo "    minimum iOS ${MIN_OS}"
echo "    size       ${IPA_SIZE} bytes"
echo "    sha256     ${IPA_SHA}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "ipa_path=${IPA_PATH}"
    echo "ipa_size=${IPA_SIZE}"
    echo "ipa_sha256=${IPA_SHA}"
    echo "version=${ACTUAL_VERSION}"
    echo "build=${ACTUAL_BUILD}"
    echo "min_os=${MIN_OS}"
  } >>"$GITHUB_OUTPUT"
fi
