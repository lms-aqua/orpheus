# ORPHEUS — Build Status

Progress against [MASTER_PROMPT.md](MASTER_PROMPT.md). Section references (§) point
into that document.

**Last updated:** 2026-08-13
**Repository:** <https://github.com/lms-aqua/orpheus> (public)
**Last verified CI run:** [31732043723](https://github.com/lms-aqua/orpheus/actions/runs/31732043723) — passed

---

## 0. The constraint that shapes everything

This project is authored on **Windows 11**. There is no Xcode, no iOS SDK, no
simulator, and no `xcodebuild` on this machine, and there cannot be — Apple's
toolchain is macOS-only.

Every build, test, and verification therefore runs in **GitHub Actions on
`macos-26` runners**. The consequence worth stating plainly:

> Nothing in this document is described as working unless a CI run compiled it
> and its tests passed. §60 and §75 demand real verification, and CI is the only
> place verification can happen.

This is not a workaround bolted on afterwards; it is the development loop. It
also means §57 (Instruments profiling) and parts of §61/§62 (real-device and
Stage Manager testing) cannot be fully satisfied without Mac hardware — see
[§7 What is needed from you](#7-what-is-needed-from-you).

---

## 1. What was done, in order

1. **Verified the runner facts instead of assuming them.** Confirmed `macos-26`
   is generally available (since 2026-02-26, arm64), and enumerated the Xcode
   versions actually on the image: 26.0.1, 26.1.1, 26.2, 26.3, 26.4.1, 26.5,
   26.6 (default 26.6), with iOS SDKs 26.0–26.5 and simulator runtimes 26.2,
   26.4, 26.5. §2 forbids hallucinating APIs; that starts with not guessing the
   toolchain.
2. **Chose a project-generation strategy.** XcodeGen from a checked-in
   `project.yml`, with the `.xcodeproj` gitignored. A hand-written `.pbxproj`
   authored blind on Windows would be a corruption risk and unreviewable in
   diffs.
3. **Split the codebase into an app target plus a local Swift package**
   (`Packages/OrpheusCore`). This makes §40's layering compiler-enforced rather
   than conventional, and lets the security tests run hostless.
4. **Built the encryption layer** — the foundation everything else stores data
   through.
5. **Wrote the adversarial test suite** for it, before building features on top.
6. **Built the CI workflow** with pinned-but-falling-back Xcode selection and
   runtime simulator resolution.
7. **Wrote the navigation shell, design tokens, and real empty states.**
8. **Generated the app icon** reproducibly from a script.
9. **Wrote the documentation set** required by §69.
10. **Pushed and drove CI to green.** First run failed with 3 errors from one
    cause (`withUnsafeBytes` resolving to `Data`'s instance method inside a
    `Data` extension); fixed with `Swift.` qualification. Second run passed.

---

## 2. Completed and verified

Each item below was compiled by Xcode 26.6 against the iOS 26 SDK, and where
tested, executed on an iPhone 17 Pro simulator running iOS 26.5.

### Encryption (§15, §20, §54)

| Component | What it does |
|---|---|
| `CryptoEngine` | AES-256-GCM via CryptoKit; HKDF-SHA256 subkey derivation |
| `KeyPurpose` | Domain separation — per-entry, per-attachment, per-thumbnail, per-archive |
| `EncryptedBlobHeader` | On-disk format definition, parsing, and validation |
| `ChunkedCipher` | Streaming encryption for files too large to hold in memory |

The design point worth understanding: CryptoKit's AES-GCM is one-shot, so a
large video cannot pass through it without violating §44/§45. Blobs are split
into 1 MiB chunks — but naive chunking *introduces* three attacks whole-file AEAD
does not have, so each is closed explicitly and tested:

| Attack | Defence |
|---|---|
| Reorder chunks | Chunk index is authenticated as associated data |
| Truncate the tail | `chunkCount` lives in the header, and the header is authenticated in *every* chunk |
| Append extra chunks | Bytes after the declared final chunk are an error |

Also implemented: streaming SHA-256 over ciphertext verified before decryption
when a digest is known (so disk corruption is reported distinctly from
tampering), and deletion of partially written output on a failed decrypt (so
half-decrypted plaintext is never left on disk).

### Test suite (§55, §56) — 28 tests, 2 suites, all passing

Written to assert security properties, not merely round-trips:

- ciphertext never contains its plaintext, including across chunk boundaries
- identical plaintext encrypted twice yields different ciphertext
- **every** single-byte mutation of a sealed box is detected — the test walks
  every offset
- cross-item and cross-vault decryption fail
- truncation, partial-frame truncation, append, chunk reordering, and header
  rewriting are each detected
- foreign files, short files, and future format versions are rejected cleanly
- a failed decrypt leaves no plaintext file behind

### CI (§60)

```
✓ Select Xcode 26        pinned 26.6, falls back to newest 26.x, hard-fails without an iOS 26 SDK
✓ Install XcodeGen       2.46.0
✓ Generate Xcode project
✓ Resolve simulator      iPhone 17 Pro / SimRuntime.iOS-26-5, resolved at runtime
✓ Build for testing      0 compiler warnings
✓ Run tests              28 tests in 2 suites passed
✓ Warning summary        counts surfaced to the job summary, not suppressed
✓ Upload artifacts       logs + .xcresult bundles, 7-day retention
```

Three deliberate hardening choices against the common ways iOS CI rots: the
image's default Xcode has rotated repeatedly (16.4 → 26.2 → 26.4.1 → 26.6) so it
is pinned; GitHub prunes simulator runtimes for disk space so destinations are
resolved live rather than hardcoded; and `.gitattributes` forces `eol=lf` because
Windows CRLF makes runner shell scripts fail with `bad interpreter: /bin/bash^M`.

### Distribution — IPA and AltStore

Verified end to end by release
[v0.1.0](https://github.com/lms-aqua/orpheus/releases/tag/v0.1.0):

- Unsigned `.ipa` built in Release configuration against the device SDK
- Published SHA-256 matches the downloaded asset
- Bundle validated: single `Payload/` root, `MinimumOSVersion 26.0`, universal
  iPhone/iPad, `DTSDKName iphoneos26.5`, `DTXcodeBuild 17F113` (Xcode 26.6)
- AltStore source live at `https://lms-aqua.github.io/orpheus/altstore.json`,
  served as `application/json`, with versions derived from release history so it
  cannot advertise an asset that does not exist
- Landing page and icon served from Pages

Unsigned deliberately — AltStore re-signs on-device with the owner's Apple ID, so
storing a certificate in repository secrets would add risk and buy nothing. The
cost is documented in [SIDELOADING.md](SIDELOADING.md#5-what-sideloading-costs-precisely):
an unsigned build loses the app-wide Data Protection default, which leaves content
encryption intact but drops the metadata store to the system default class.

### Shell and design system (partial)

- Adaptive navigation: one `TabView` with `.tabViewStyle(.sidebarAdaptable)` —
  tab bar on iPhone, sidebar on iPad, from a single tree (§6)
- `OrpheusColor` tokens built on system semantic colours, so Dark Mode,
  Increased Contrast, and Smart Invert are handled by the platform (§4)
- Real empty states via native `ContentUnavailableView` (§36, §66)
- Settings with an accurate plain-language security explanation, including stated
  limitations (§50, §68)
- App icon: abstract layered-aperture mark — no padlock, no eye, no shield (§5)
- `OrpheusError` with localised, user-presentable messages that never embed key
  material or decrypted content (§37)
- String Catalogs wired for both the package and the app target (§39)

### Documentation (§69, §70)

`README.md`, `ARCHITECTURE.md`, `SECURITY.md`, `CHANGELOG.md`, plus these two
files. `SECURITY.md` states the threat model *and* what ORPHEUS does not protect
against, and marks unimplemented sections as such rather than describing them as
shipped.

### Confirmed-real iOS 26 APIs

Because §2 forbids hallucinating APIs, these are noted as compiler-verified
rather than assumed: `Tab(_:systemImage:value:role:)`,
`.tabViewStyle(.sidebarAdaptable)`, `.buttonStyle(.glassProminent)`,
`ContentUnavailableView`, `ContentUnavailableView.search(text:)`,
`HKDF<SHA256>.deriveKey`, `.swiftLanguageMode(.v6)`, and Swift Testing's
`@Suite` / `@Test(arguments:)` / `#expect(throws:)`.

---

## 3. Not complete

### Phase 1 — remaining (first save slice awaiting CI verification)

| Missing | Spec |
|---|---|
| `MasterKeyStore` — implementation and hostless tests are present locally; CI compilation and real-device access-control verification remain | §15 |
| Biometric authentication, lock screen, onboarding | §16, §48 |
| `LockController` — auto-lock intervals, scene-phase handling | §16 |
| Complete SwiftData model graph — `Space` and `Entry` are present locally; `Attachment`, `Tag`, and `ActivityRecord` remain | §21 |
| Finish verifying `BlobStore` — encrypted staging writes, reads, replacement, deletion, and hostless tests are present locally | §20 |
| Spaces rename / reorder / customise / archive; create, list, and delete are present locally | §9 |
| Expand Home beyond the local encrypted-note create/read slice to favourites, pinning, and Spaces | §7 |
| Typography and motion tokens; component library | §40 |

**Consequence:** the current working tree now has the first end-to-end path:
create a note, encrypt its body into a blob, persist only its metadata, reopen
it, and search its title. Spaces can also be created and deleted. This path is
not counted as verified until it compiles and its expanded test suite passes in
CI; editing, attachments, full Space assignment, and locking still remain.

### Phases 2–6 — not started

| Phase | Scope | Spec |
|---|---|---|
| 2 — Content | Notes and rich text, photos, video, files, scans, audio, links, locations, tags, favourites, pinning | §10, §26, §27 |
| 3 — Discovery + Privacy | Search, Recently Deleted, Activity, privacy shield, Lock Now, import/export, `.orpheus` archives, QR transfer | §12, §17–19, §23–25, §53 |
| 4 — System Integration | Share Extension, App Intents, Shortcuts, widgets, Control Center, iPad enhancements, drag and drop, keyboard shortcuts | §28–32, §62, §63 |
| 5 — Intelligence | Foundation Models: summaries, titles, tags, Q&A, semantic search, with availability gating | §13, §14 |
| 6 — Production Polish | Design review, Liquid Glass audit, accessibility audit, performance and memory profiling, security review, UI tests | §56, §57, §64, §65 |

### §71 — version 1.0 checklist

| Requirement | State |
|---|---|
| Encrypted local storage | ◐ Cipher verified; first `BlobStore` slice present locally and awaiting CI |
| Onboarding | ○ |
| Biometric / device authentication | ○ |
| Spaces | ◐ Create/list/delete present locally; remaining management pending |
| Notes, rich text | ◐ Basic encrypted plain-text create/read present locally; editing and rich text pending |
| Photos, files, document scanning, audio recording | ○ |
| Links, optional locations | ○ |
| Favourites, pinning, tags | ○ |
| Search | ◐ Local title search present; content/tag indexing pending |
| Recently Deleted | ○ |
| Import, export, ORPHEUS encrypted archive | ○ |
| Privacy screen, auto-lock, Lock Now | ○ |
| Share Extension | ○ |
| Settings | ◐ About and security explanation only |
| iPad adaptive layout | ◐ Adaptive navigation done; iPad-specific work pending |
| Accessibility | ◐ Headers, combined elements, Dynamic Type previews; no audit yet |
| Light / Dark Mode | ● |
| Core automated tests | ◐ Encryption covered; nothing else exists to test |

● complete · ◐ partial · ○ not started

**Roughly 15% of 1.0 by scope** — but the part that is done is the part
everything else is built on top of, and it is the part that is hardest to
retrofit safely.

---

## 4. What is next

In dependency order. Each lands with tests and a green CI run before the next
begins.

1. **Verify the first persistence slice** — compile `MasterKeyStore`, the
   SwiftData `Entry`/`Space` models, `BlobStore`, and the create/read/search UI;
   run all old and new hostless tests in CI. Real-device access-control
   verification remains a later hardware gate (§15, §20, §21, §68).
2. **Complete the model graph and note lifecycle** — add attachments, tags,
   activity records, edit/delete behavior, and Space assignment while keeping
   bodies and binary data out of SwiftData (§9, §20, §21).
3. **Lock and onboarding** — `LockController` with the five auto-lock intervals,
   scene-phase transitions, biometric unlock, three-screen onboarding (§16, §48).
4. **Spaces CRUD + Home wired to real data** — completing Phase 1 (§7, §9).
5. **Phase 1 verification pass** — §60 in full, plus the first UI tests and a
   simulator screenshot artifact so visual regressions are reviewable from
   Windows.

Then Phases 2 → 6 in the order §74 specifies.

### CI work planned alongside

- **UI test job** with `XCUIApplication`, including
  `performAccessibilityAudit()` — this genuinely runs in CI and covers a
  meaningful slice of §38
- **Screenshot artifacts** across the §61 device matrix and both appearances, so
  the §64 design review is possible without a Mac
- **Release-configuration build**, to catch what Debug hides
- **Plaintext-leak check** (§56) asserting no sensitive content in temp
  directories or logs

---

## 5. Deliberate decisions made without asking

Recorded because §74 says to make sound decisions and document them rather than
stopping for approval.

| Decision | Reasoning |
|---|---|
| XcodeGen instead of a committed `.xcodeproj` | A blind-authored `.pbxproj` is a corruption risk and unreviewable; build tooling is not an app dependency, so §43 does not apply |
| Core in a local Swift package | Compiler-enforced layering, hostless crypto tests, and correct actor-isolation defaults per target |
| Per-item HKDF subkeys rather than the master key directly | Domain separation against ciphertext relocation, plus AES-GCM nonce headroom |
| 1 MiB chunked blob format | §44/§45 forbid whole-file in-memory encryption; the header/index authentication closes what chunking opens |
| Fixed HKDF salt | Input key material is already full-entropy random; per-item `info` supplies the separation that matters |
| Metadata unencrypted in SwiftData | Search and sort without decrypting the vault. The cost is recorded as a limitation in `SECURITY.md`, not hidden |
| `.completeUnlessOpen` for blobs, `NSFileProtectionComplete` app-wide | A long import must survive the screen locking mid-write; the downgrade is per-file and explicit, never global |
| Vertical slice to green CI before writing all six phases | Writing ~40 files blind and then facing a wall of errors is how these builds die |
| Public repository | Free macOS runner minutes (10× multiplier on private), and auditable crypto is a defensible posture for a vault |

---

## 6. Open risks

- **API drift.** Even with compiler verification, iOS 26 design conventions are
  young. The Liquid Glass audit (§65) may find surfaces used where system glass
  should be.
- **SwiftData under strict concurrency.** `@Model` types are not `Sendable`;
  background contexts need `ModelActor` care. This is the most likely source of
  concurrency friction ahead.
- **Foundation Models availability.** Phase 5 must degrade cleanly (§14), and
  that path cannot be exercised on a device that lacks Apple Intelligence.
- **Chunk size is unmeasured.** 1 MiB is reasoned, not profiled. Phase 6 should
  test it against large video.
- **Keychain behaviour differs on simulator.** Access-control semantics with
  biometrics are not faithfully reproduced; real-device testing is required
  before the key store can be called verified.

---

## 7. What is needed from you

Nothing blocks the next several phases. These become blockers later, listed with
the point at which they bite.

### Hardware and accounts

| Need | Required for | Blocks at |
|---|---|---|
| **Apple Developer Program** (~$99/yr) | Entitlement validation (Data Protection, App Groups, Keychain sharing), device install, TestFlight, CloudKit container | Phase 4 (Share Extension needs a real App Group); signed builds |
| **A physical iPhone** | Face ID / Touch ID behaviour, Keychain access-control semantics, real Data Protection, app-switcher snapshot | Verifying the key store and §17 privacy screen |
| **Apple Intelligence-capable device** (iPhone 15 Pro+ / M-series iPad) | Foundation Models | Phase 5 |
| **Any Mac** (optional) | Instruments profiling (§57), Stage Manager testing (§62), interactive design review | Phase 6 can be partly done without it, not fully |

CI covers building, unit tests, UI tests, accessibility audits, and screenshots.
It cannot cover biometrics, Instruments, or real Data Protection.

### Decisions I need from you

1. **Licence** — `README` says "not yet chosen". The repo is public with no
   licence, which means default copyright: nobody may reuse it. Fine if
   intentional.
2. **Export compliance** — `ITSAppUsesNonExemptEncryption` is declared `false` on
   the standard-cryptography exemption. Confirm against current Apple guidance
   before submission. A compliance question, not an engineering one.
3. **CloudKit sync in 1.0, or defer?** §22 says architect for it; §71 does not
   require it. My recommendation is defer — it needs a paid account and is the
   highest-risk subsystem to get cryptographically right.
4. **App icon** — the current mark is script-generated and serviceable. Say if
   you want a real design pass in Phase 6 or if it should stay as is.
5. **Priority order** — §73 ranks reliability > privacy > usability > native
   design > performance > accessibility > polish > features. If you would rather
   see visible features sooner at the cost of foundation work, that reorders the
   plan.

### Nothing needed for

Building, testing, iterating on all six phases' code, unit and UI tests,
accessibility audits, simulator screenshots, and every architecture and security
decision. That work continues on CI alone.
