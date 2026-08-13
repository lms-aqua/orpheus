# Installing ORPHEUS with AltStore or SideStore

ORPHEUS is not on the App Store. Builds are distributed as **unsigned `.ipa`**
files that AltStore or SideStore signs on your device with your own Apple ID.

**Source URL:**

```text
https://lms-aqua.github.io/orpheus/altstore.json
```

Landing page with one-tap buttons: <https://lms-aqua.github.io/orpheus/>

---

## 1. Requirements

- iOS or iPadOS **26.0** or later
- [AltStore](https://altstore.io) with AltServer, or
  [SideStore](https://sidestore.io) with its pairing file
- An Apple ID

## 2. Adding the source

1. Open AltStore → **Browse** → **Sources** → **+**
2. Paste `https://lms-aqua.github.io/orpheus/altstore.json`
3. ORPHEUS appears in the source; tap **Free** / **Install**

Or open the landing page on the device and tap **Add to AltStore**, which uses
the `altstore://source?url=…` scheme.

## 3. How long an install lasts

Determined by your Apple ID, not by anything in this repository:

| Apple ID | App works for | Notes |
|---|---|---|
| Free | **7 days** | AltStore must refresh it before it expires, which needs AltServer reachable on the same network (or SideStore's on-device refresh) |
| Paid Developer Program | **1 year** | Also raises the three-app sideloading limit |

An expired app will not open until refreshed. Your data is not deleted by
expiry — but see the warning in §6 about deleting the app.

## 4. Why builds are unsigned

Signing in CI would mean putting an Apple Developer certificate and private key
into repository secrets. AltStore re-signs on-device regardless, so those secrets
would add real risk and buy nothing.

The `.ipa` is produced by `Scripts/make-unsigned-ipa.sh`: a Release-configuration
device archive built with `CODE_SIGNING_ALLOWED=NO`, then packaged as
`Payload/ORPHEUS.app` inside a zip.

## 5. What sideloading costs, precisely

This is a genuine reduction in protection and is not glossed over.

**Entitlements are applied when an app is signed.** An unsigned build carries
none, so a sideloaded ORPHEUS does not get the app-wide
`com.apple.developer.default-data-protection` =
`NSFileProtectionComplete` entitlement declared in
`ORPHEUS/Resources/ORPHEUS.entitlements`.

What that does and does not change:

| | Signed properly | Sideloaded |
|---|---|---|
| Encrypted content blobs | Protected — class set explicitly in code | **Still protected** — same explicit class |
| AES-256-GCM encryption of content | Active | **Still active** |
| Vault key in Keychain | Protected | **Still protected** |
| SwiftData metadata store (titles, tags, dates) | Class A — unreadable while locked | Falls back to the system default class, readable after first unlock |

So content encryption is unaffected, because `ChunkedCipher` sets each blob's
protection class itself rather than relying on the app-wide default. The
metadata database is the part that loses protection, and metadata is already
documented as the weaker half of the model in
[SECURITY.md](../SECURITY.md#1-threat-model).

Additionally, a **free** Apple ID cannot grant App Groups or Keychain Sharing.
The Share Extension planned for Phase 4 needs an App Group, so that feature will
require a paid account to work when sideloaded.

## 6. Before you rely on this

- ORPHEUS is **in development**. At the current commit the encryption layer is
  implemented and tested, but storage and authentication are not finished — these
  builds cannot save anything yet.
- **Deleting a sideloaded app deletes its container**, which includes the
  encrypted store. The Keychain item may also be removed. There is no recovery
  key held anywhere else, so deleting the app while it holds content you care
  about means losing that content. Once the archive format lands (Phase 3),
  export an `.orpheus` archive first.
- Refreshing through AltStore does **not** delete data. Only uninstalling does.

## 7. Publishing a release (maintainer)

```bash
git tag v0.1.0
git push origin v0.1.0
```

The `IPA & AltStore` workflow then:

1. builds the unsigned `.ipa` on `macos-26` with Xcode 26
2. creates a GitHub Release and attaches it, embedding build number, minimum iOS
   version, and SHA-256 in a machine-readable block in the release notes
3. regenerates `altstore.json` from the **full release history** via the GitHub
   API, so the published source can never reference an asset that does not exist
4. validates the JSON, then deploys it to GitHub Pages

Every push to `main` also builds an `.ipa` and uploads it as a 30-day workflow
artifact, without creating a release.

To republish the source without a new build — after editing app metadata in
`AltStore/source-template.json`, for example — run the workflow manually with
**Run workflow** and `publish_source` enabled.

### Verifying a download

Each release records the SHA-256 of its `.ipa`:

```bash
shasum -a 256 ORPHEUS-0.1.0.ipa
```

Compare against the value in the release notes.
