# Changelog

All notable changes to ORPHEUS are recorded here, newest first. This file is
append-only: existing entries are never rewritten or removed.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Working toward **ORPHEUS 1.0**. See the phase table in
[README.md](README.md#status) for scope.

### Added

- **Project foundation.** XcodeGen-generated Xcode project defined in
  `project.yml`, targeting iOS 26.0 with Swift 6 language mode. The generated
  `.xcodeproj` is not committed.
- **`OrpheusCore` package.** Local Swift package holding security, storage, and
  model code with no UI, so layering is enforced by the compiler.
- **AES-256-GCM encryption** (`CryptoEngine`) over CryptoKit, with per-item
  subkeys derived through HKDF-SHA256. Key purposes are domain-separated, so a
  key that opens one entry cannot open another entry, an attachment, or an
  archive.
- **Streaming encrypted blob format** (`ChunkedCipher`, `EncryptedBlobHeader`)
  for files too large to hold in memory. Chunks are individually sealed and
  bound to both the file header and their own index, which makes reordering,
  truncation, and appending detectable rather than silently decodable.
- **Integrity metadata.** Streaming SHA-256 over ciphertext, verified before
  decryption when a digest is known, so on-disk corruption is reported
  distinctly from tampering.
- **Error model** (`OrpheusError`) with user-presentable, localised messages
  that never embed key material or decrypted content.
- **Navigation shell.** Adaptive `TabView` with `.sidebarAdaptable`, giving a
  tab bar on iPhone and a sidebar on iPad from a single tree.
- **Home, Spaces, Search, Settings** with their real empty states, plus a
  plain-language description of the actual security model.
- **App icon.** Abstract layered-aperture mark, generated reproducibly by
  `Scripts/generate-app-icon.py`.
- **CI on `macos-26`.** Pinned Xcode 26.6 with fallback to the newest available
  Xcode 26.x, dynamic simulator resolution via `simctl`, build-for-testing
  followed by test-without-building, warning counts surfaced in the job summary,
  and logs plus result bundles uploaded as artifacts.

### Security

- Files are created with Data Protection. The app defaults to
  `NSFileProtectionComplete`; individual blobs are downgraded explicitly to
  `completeUnlessOpen` only where a write must survive the screen locking
  mid-import.
- A failed decryption removes its partially written output, so plaintext is
  never left on disk unowned.
- Test coverage asserts that ciphertext never contains its plaintext, that every
  single-byte mutation is detected, and that cross-item and cross-vault
  decryption fail.
