# ORPHEUS

A private personal workspace and encrypted vault for iPhone and iPad.

One place for the things you would rather not scatter across Notes, Photos,
Files, and half a dozen cloud services: notes, documents, photos, videos,
scans, recordings, links, and records — organised into encrypted **Spaces**,
stored locally, encrypted at rest.

ORPHEUS is local-first. It works with no account and no network connection.

---

## Status

**Phase 1 of 6, in progress.** The encryption layer, its test suite, and the
navigation shell are in place. See [CHANGELOG.md](CHANGELOG.md) for what
actually exists, and the roadmap below for what does not yet.

This project is built and verified entirely in CI on GitHub's `macos-26`
runners, because it is authored on a Windows machine where no Apple toolchain
exists. Nothing is claimed to work until the CI badge says it built and its
tests passed.

| Phase | Scope | State |
|---|---|---|
| 1 | Architecture, design system, models, encryption, auth, navigation, Home, Spaces | In progress |
| 2 | Notes and rich text, photos, video, files, scans, audio, links, locations, tags | Not started |
| 3 | Search, Recently Deleted, Activity, privacy shield, auto-lock, import/export, `.orpheus` archives | Not started |
| 4 | Share Extension, App Intents, Shortcuts, widgets, Control Center, iPad enhancements | Not started |
| 5 | On-device intelligence via Foundation Models, with availability gating | Not started |
| 6 | Design review, Liquid Glass audit, accessibility, performance and memory profiling, security review | Not started |

## Requirements

- Xcode 26.x with the iOS 26 SDK
- iOS / iPadOS 26.0 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Building

`ORPHEUS.xcodeproj` is **generated and not committed**, so the target graph
stays reviewable as text in [`project.yml`](project.yml) and never produces a
merge conflict.

```bash
brew install xcodegen
xcodegen generate
open ORPHEUS.xcodeproj
```

Command line:

```bash
xcodebuild build -project ORPHEUS.xcodeproj -scheme ORPHEUS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

## Testing

```bash
xcodebuild test -project ORPHEUS.xcodeproj -scheme ORPHEUS -destination "$(./Scripts/resolve-simulator.sh)"
```

The core test suite is **hostless** — it links `OrpheusCore` directly with no
app host — which keeps the cryptography tests fast and free of simulator
lifecycle flake.

`Scripts/resolve-simulator.sh` asks `simctl` which runtimes are actually
installed instead of hardcoding a device name. Hardcoded destinations are the
most common reason iOS CI breaks: GitHub prunes simulator runtimes for disk
space, and device names change every year.

## Layout

```text
ORPHEUS/
├── ORPHEUS/                    App target — UI only
│   ├── App/                    Entry point, root navigation
│   ├── DesignSystem/           Colour, type, motion tokens
│   ├── Features/               One directory per feature area
│   └── Resources/              Info.plist, entitlements, assets, strings
│
├── Packages/OrpheusCore/       Local Swift package — no UI
│   └── Sources/OrpheusCore/
│       ├── Security/           Encryption, key derivation, key storage
│       ├── Storage/            Encrypted blob storage on disk
│       ├── Models/             SwiftData models
│       └── Support/            Errors, logging
│
├── Tests/OrpheusCoreTests/     Hostless unit tests
├── Scripts/                    Toolchain and asset scripts
└── project.yml                 XcodeGen project definition
```

Security and storage live in a package rather than in the app target on
purpose: it makes the layering enforceable by the compiler instead of by
convention, and it is what allows the crypto tests to run without an app host.

## Security

Summary: content is encrypted at rest with AES-256-GCM via CryptoKit; each item
gets its own HKDF-derived subkey; the vault key lives in the Keychain and never
in settings, the database, or a file.

Read [SECURITY.md](SECURITY.md) for the threat model, what ORPHEUS does *not*
protect against, and the reasoning behind each choice. It states limitations
plainly and avoids terms like "military grade" or "unhackable", which have no
defensible technical meaning.

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — structure and the significant decisions
- [SECURITY.md](SECURITY.md) — threat model, encryption, key storage, limits
- [CHANGELOG.md](CHANGELOG.md) — chronological history

## Licence

Not yet chosen.
