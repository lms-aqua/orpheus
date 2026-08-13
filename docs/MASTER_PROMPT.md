# ORPHEUS — Master Build Prompt

The original specification for this project, recorded verbatim in structure and
intent so it can be checked against the implementation. This is the acceptance
criteria document; [BUILD_STATUS.md](BUILD_STATUS.md) tracks progress against it.

Section numbers are preserved from the original brief and are referenced
throughout the codebase and commit messages (e.g. "§44 forbids decrypting large
files on the main actor").

---

## Role

Act as a principal Apple-platform engineer, senior Swift/SwiftUI architect,
product designer, UX designer, application-security engineer, accessibility
specialist, performance engineer, and QA lead.

Design and build a complete production-quality iPhone/iPad application named
**ORPHEUS**.

ORPHEUS is a private personal workspace and encrypted digital vault.
**It is NOT a spy app.**

### Do not use

- spy terminology
- classified-document aesthetics
- fake government interfaces
- hacker terminals
- Matrix effects
- "missions"
- "operatives"
- "intel"
- "dead drops"
- fake military/security language
- tactical imagery
- fake hacking screens
- gimmicky cyberpunk UI

### The product should feel

private · quiet · premium · intelligent · highly polished · personal · secure ·
modern · unmistakably native to Apple platforms

Imagine Apple designed a private combination of Notes, Files, Journal, Photos,
Voice Memos, password-style vault security, intelligent local search, and a
personal archive — but ORPHEUS must have its own identity rather than looking
like a clone of any Apple app.

---

## 1. Primary product idea

ORPHEUS gives someone one private place for information they don't necessarily
want scattered across Notes, Photos, Files, Messages, cloud services, and other
applications.

A user can privately store: notes, rich-text documents, photographs, videos,
files, PDFs, scans, voice recordings, links, locations, personal records,
important documents, ideas, project information, memories, and miscellaneous
private information.

Everything is organized into encrypted **Spaces** — for example Personal, Work,
Family, Projects, Documents, Ideas, Memories. Users can create unlimited custom
Spaces.

Each Space may have its own name, icon, visual accent, description, sort order,
favorites, security preferences, and archive status.

Terminology throughout must be simple and human: **Space, Entry, Note, File,
Collection, Archive, Private, Locked.** Do not invent unnecessary
fantasy/security terminology.

## 2. Development target

Build with the Xcode 26 generation of Apple development tools:

- Xcode 26.x
- iOS 26 SDK / iPadOS 26 SDK
- modern Swift, strict Swift concurrency
- SwiftUI-first architecture
- Swift Package Manager where packages are genuinely needed

**Deployment target: iOS 26.0 / iPadOS 26.0.** Do not maintain compatibility
with older iOS versions if doing so prevents fully embracing the iOS 26 design
and APIs. This is a modern iOS 26 application, not an old application with a
compatibility layer.

Use current APIs from the SDK actually installed with Xcode 26. **Do not
hallucinate framework methods or API signatures.** If an API name has changed,
inspect the installed SDK/documentation and implement the correct version.

## 3. Use the new Apple design system

Use native **Liquid Glass** intentionally. Prefer system-provided glass behavior
through navigation, toolbars, tab bars, sheets, menus, buttons, contextual
controls, and floating action surfaces.

Use custom glass effects only where they improve hierarchy or interaction. Do
not cover every surface in glass. Content should remain visually dominant.

Glass should primarily represent controls, navigation, transient interfaces,
floating actions, and selected interactive surfaces. Avoid the amateur mistake
of turning the entire application into translucent rectangles.

## 4. Visual identity

A restrained visual system based around charcoal, graphite, black, off-white,
subtle indigo / blue-violet accents, and adaptive system materials.

Support Light Mode, Dark Mode, Increased Contrast, Reduce Transparency, Reduce
Motion, and Dynamic Type. Dark Mode should look particularly good, but the app
must not require it.

Avoid: neon hacker colors, excessive gradients, excessive glow, oversized cards
everywhere, giant empty spacing, tiny text, arbitrary corner radii, Android-style
UI, web-dashboard styling, excessive borders.

## 5. App icon

Abstract, simple, recognizable at small sizes, premium. **Not** a security
cliché, not a padlock, not an eye, not a hacker logo.

Explore an abstract O / aperture / layered-circle / folded-space concept. Where
supported by the Xcode 26 toolchain, build the icon using Apple's current layered
icon workflow. Must remain identifiable across standard, dark, and tinted
appearances, and at Home Screen, Spotlight, and Settings sizes.

## 6. Navigation architecture

Adaptive SwiftUI navigation.

**iPhone** primary destinations: Home, Spaces, Search, Settings. Search should
use the modern iOS 26 search presentation.

**iPad**: an adaptive `NavigationSplitView`-style experience. The iPad app must
not simply stretch the iPhone UI. Take advantage of sidebar navigation, larger
canvas, multiple columns, resizable windows, keyboard navigation, pointer
interaction, menus, commands, and drag and drop. Do not assume a fixed screen
size.

## 7. Home

Home should immediately feel useful: greeting / contextual heading, recent
entries, favorite Spaces, pinned entries, recently added items, quick actions
(New Note, Add Photo, Scan Document, Import File, Record Audio).

Do not turn Home into an analytics dashboard. This is a personal application,
not enterprise BI software.

## 8. Quick capture

One of ORPHEUS's most important interactions. Adding something must have minimal
friction. Provide a beautiful floating or toolbar-based Add interaction using
native iOS 26 components, offering: Note, Photo, Video, Document Scan, File,
Audio Recording, Link, Location.

Use context-sensitive menus rather than a giant form. After capture, allow
selecting a Space, adding tags, favoriting, pinning, adding a title, adding
notes — but none of these are mandatory. Fast capture stays fast.

## 9. Spaces

The primary organizational system. Each Space gets a polished detail page
showing name, icon, optional description, recent content, pinned content, item
count, and sorting/filtering controls.

Display items intelligently by content type; support grid and list where
appropriate. Users can create, rename, reorder, customize, archive, and delete
Spaces. Deleting a Space containing data must require appropriate confirmation.

## 10. Entry types

A shared **Entry** abstraction with specialized content payloads.

**Note** — plain text, rich text, headings, bold, italic, underline, lists,
links, checklists, inline attachments where practical. Use modern SwiftUI
rich-text capabilities available in iOS 26 rather than building a web-based
editor.

**Photo** — PhotosPicker, camera capture, image preview, captions, tags, date,
optional private location, metadata inspection, metadata removal during export.
Avoid requesting full Photos access when PhotosPicker suffices.

**Video** — import, capture where appropriate, thumbnail generation, playback,
metadata, encrypted local storage.

**File** — PDF, text, Markdown, Office documents where Quick Look supports them,
images, archives, miscellaneous documents. Use document picker, Quick Look, and
native file APIs.

**Scan** — high-quality document scanning: multiple pages, page reordering,
cropping, rotation, PDF generation, title, tags, Space assignment.

**Audio** — a polished private recorder with waveform, elapsed time, pause,
resume, playback, seeking, rename, and optional transcription where supported.
Use AVFoundation appropriately.

**Link** — URL, title, notes, preview information where available. No invasive
tracking or unnecessary remote scraping.

**Location** — optionally saved as part of an Entry. Do not continuously track
location. Only request permission when the user explicitly uses a
location-related feature.

## 11. Entry viewer

Every Entry opens into a beautiful content-focused viewer. Avoid embedding
everything into generic cards; the actual content should dominate the screen.

Floating/system controls for Edit, Favorite, Pin, Move, Share, Export, Delete,
More. Use context menus where appropriate. Support natural transitions from
thumbnails/list entries into full content. Animations subtle and physical.

## 12. Search

Search must be excellent: instant text search, title search, body search, tag
search, Space filters, content-type filters, date filters, favorites, pinned
status.

Results update quickly and remain performant with thousands of Entries. Use
modern SwiftUI search behavior.

## 13. On-device intelligence

An optional feature named **ORPHEUS Intelligence**, using Apple's Foundation
Models framework where supported by the device and OS. Privacy-first: do not
automatically upload private ORPHEUS content to external AI APIs.

Capabilities: Summarize · Ask ORPHEUS (questions about selected content) ·
Automatic Tags · Smart Titles · Semantic Search · Document Understanding.

Example asks: "Summarize this." / "What dates are mentioned?" / "Turn this into
a checklist." / "Find the important parts." / "Give this a better title."

## 14. AI availability

AI must never be required for the app to work. Before presenting AI
functionality, determine whether the device/model/service is available.

If unavailable: don't crash, don't show broken buttons, don't endlessly load,
don't pretend a response exists. Display an appropriate explanation. ORPHEUS
must remain excellent where Apple Intelligence is unavailable.

## 15. Security architecture

Security is a real product requirement. Do not implement theatrical security.
Use actual Apple security frameworks: CryptoKit, Keychain Services,
LocalAuthentication, Data Protection, appropriate file protection, secure random
generation.

Sensitive Entry payloads encrypted at rest with authenticated encryption such as
AES-GCM through CryptoKit. **Do not invent custom encryption algorithms.**

Do not store encryption keys in UserDefaults, SwiftData, source code,
configuration files, or plaintext files. Protect keys using Keychain security
appropriate to the threat model.

## 16. Application lock

Automatic locking with options: Immediately, After 30 seconds, After 1 minute,
After 5 minutes, After 15 minutes.

Authentication with Face ID, Touch ID where applicable, and device
authentication/passcode based on user preference and supported APIs. When locked,
immediately protect sensitive UI.

## 17. Privacy screen

When ORPHEUS is no longer active, sensitive information must not remain visible
in the app switcher snapshot. Display a neutral ORPHEUS privacy surface when
necessary. Observe screen capture / recording state where supported.

If the OS does not provide a true method for preventing screenshots, **do not
pretend that it does.** Use only real platform capabilities.

## 18. Emergency lock

A **Lock Now** action that immediately closes sensitive Entry presentation,
obscures private content, and requires authentication again. Expose through
Settings, contextual action, and optional Control Center/Shortcut integration if
supported. Do not call it a panic button.

## 19. Clipboard privacy

Minimize clipboard lifetime when practical, provide explicit copy actions, avoid
automatically copying sensitive information, and clear application-controlled
temporary data when appropriate. Do not interfere with normal system behavior in
surprising ways.

## 20. Data storage

- **Metadata** — SwiftData where appropriate
- **Encrypted content** — encrypted files/blobs in application-controlled storage
- **Credentials/keys** — Keychain
- **Large files** — do not load entirely into memory; use streaming/file-based
  processing

Mark sensitive files with appropriate Data Protection classes.

## 21. Data model

At minimum consider: `Space`, `Entry`, `Attachment`, `Tag`, `Favorite`,
`SecuritySettings`, `AppSettings`, `ActivityRecord`.

Entry should include: `id`, `spaceID`, `type`, `title`, `createdAt`, `updatedAt`,
`favorite`, `pinned`, `tags`, `encryptedPayloadReference`, `thumbnailReference`.

Do not put huge binary blobs directly into the primary SwiftData model unless
there is a compelling architectural reason.

## 22. Optional private sync

Architect so private sync can be introduced cleanly. If implementing now, prefer
**CloudKit + client-side encryption**. Private information encrypted locally
before upload where architecture permits; cloud storage should not need plaintext
Entry content just to synchronize it.

Conflict handling must be deterministic and tested. Provide clear states: Synced,
Syncing, Offline, Conflict, Error. Internet connectivity must not be mandatory —
ORPHEUS remains local-first.

## 23. Secure export

**Standard Export** for content the user explicitly wants to share normally —
PDF, image, text, file.

**ORPHEUS Archive** — an encrypted portable archive format such as
`filename.orpheus`, containing encrypted data, encrypted attachments, manifest,
version information, checksums, and cryptographic metadata. Design the format to
allow future migration. **Never silently downgrade encrypted content to
plaintext.**

## 24. QR transfer

Allow transferring small encrypted payloads or credentials via QR codes where
practical. Do not stuff giant files into QR codes. For larger transfers, QR
should establish or identify the transfer rather than contain the entire payload.
Use standard cryptographic primitives.

## 25. Activity

A simple private Activity screen showing meaningful local events: Entry created,
Entry edited, Entry moved, Space created, archive exported, authentication/security
changes. This is a personal history log — do not frame it as surveillance or
monitoring. Make it optional and configurable.

## 26. Favorites / pinning

**Favorite** — something personally important. **Pinned** — something that should
remain easily accessible. Behave consistently throughout the application.

## 27. Tags

User-created tags with suggestions, autocomplete, filtering, tag management,
rename, merge, delete. Do not overcomplicate tagging.

## 28. App Intents + Shortcuts

Integrate intelligently: Create ORPHEUS Note, Add File to ORPHEUS, Open ORPHEUS,
Lock ORPHEUS, Start Audio Note.

Never expose private Entry contents to Siri/Shortcuts unless the user has
explicitly enabled such behavior. **Security overrides convenience.**

## 29. Widgets

Optional privacy-safe widgets.

**Quick Capture** — buttons for note, scan, audio, photo.

**ORPHEUS** — non-sensitive information only, e.g. `27 Entries` / `4 Spaces`.

Do not display private note bodies, private photos, filenames, or sensitive
titles unless the user explicitly chooses a less-private widget mode.

## 30. Control Center

If appropriate APIs are available in the Xcode 26/iOS 26 SDK, provide a Control
Center control for **Lock ORPHEUS** and potentially **Quick Capture**. Do not
force this feature if the platform API is inappropriate.

## 31. Share Extension

So a user can send content into ORPHEUS from another application — webpage,
photo, PDF, text, file.

```text
Share → Save to ORPHEUS → Choose Space → Save
```

Keep it extremely fast. Security must be preserved between the extension and
main application. Use a correctly secured App Group only where necessary.

## 32. Import experience

Support importing from Files, Photos, Camera, Share Sheet, Scanner, and Drag and
Drop on iPad. Handle duplicate names and duplicate content gracefully. **Do not
overwrite existing content silently.**

## 33. Haptics

Use Apple haptics deliberately: successful unlock, successful save, favorite/pin,
destructive confirmation, recording start/stop. Do not fire haptics for every tap.

## 34. Animation

Modern SwiftUI animation and transitions focused on continuity, physicality,
hierarchy, and responsive interaction. Use matched/morphing transitions when
appropriate. Respect **Reduce Motion**. Avoid long cinematic animations. No
splash-screen movie.

## 35. Microinteractions

- **Locking** — sensitive content smoothly obscures, lock surface appears, haptic
  confirms state
- **Favoriting** — symbol responds naturally, subtle haptic, no giant animation
- **Adding an Entry** — newly created content transitions naturally into the
  collection
- **Opening content** — preserve spatial continuity

This level of polish is required.

## 36. Empty states

Every empty state intentional, with an obvious action. Example:

```text
Nothing here yet.

Add a note, file, photo, recording, or scan.
```

Never show an empty giant white screen with no explanation.

## 37. Error states

Handle: missing files, corrupt encrypted payload, incorrect archive password,
biometric failure, authentication cancellation, storage full, permissions denied,
sync failure, unsupported file, interrupted import, interrupted export, AI
unavailable, AI generation failure.

Errors should be understandable. Never expose internal stack traces to normal
users.

## 38. Accessibility

Mandatory: VoiceOver labels, Dynamic Type, accessible hit targets, high
contrast, Reduce Motion, Reduce Transparency, Differentiate Without Color,
logical focus order, keyboard navigation, meaningful accessibility actions.

Do not sacrifice accessibility for visual styling. Test at extremely large
Dynamic Type sizes.

## 39. Localization

Use String Catalogs. Do not scatter hard-coded user-facing strings throughout
views. Start with English, structured correctly so additional languages can be
added later.

## 40. Architecture

A professional feature-oriented structure:

```text
ORPHEUS/
├── App/
├── Core/
│   ├── Security/
│   ├── Storage/
│   ├── Database/
│   ├── AI/
│   ├── Search/
│   ├── Import/
│   ├── Export/
│   └── Utilities/
├── Features/
│   ├── Authentication/
│   ├── Home/
│   ├── Spaces/
│   ├── Entries/
│   ├── Capture/
│   ├── Search/
│   ├── Activity/
│   └── Settings/
├── DesignSystem/
│   ├── Components/
│   ├── Materials/
│   ├── Typography/
│   ├── Motion/
│   └── Icons/
├── Models/
├── Resources/
└── Tests/
```

Do not create hundreds of meaningless files. Keep responsibilities clear.

## 41. Swift concurrency

Prefer async/await, actors, structured concurrency, Sendable correctness, and
task cancellation. Avoid callback pyramids and unnecessary Combine pipelines.

Enable strict concurrency checking appropriate for the Swift toolchain. Resolve
concurrency warnings properly. **Do not silence legitimate safety warnings
globally.**

## 42. State management

SwiftUI-native observation/state patterns. Keep view state, persistent state,
security state, and service state properly separated. Do not install a giant
third-party state-management framework without concrete reason.

## 43. Dependencies

Prefer Apple's frameworks. Use third-party dependencies only when they provide
substantial value. Before adding a package ask: *can this be implemented safely
and reasonably using Apple's frameworks?* If yes, use Apple frameworks. Avoid
dependency bloat.

## 44. Performance

Remain responsive with thousands of Entries, hundreds of images, large PDFs,
large videos, and many encrypted attachments.

Do not synchronously decrypt huge files, generate thumbnails, parse giant
documents, or load full-resolution images unnecessarily on the main actor.

Use thumbnail caching, lazy loading, background work, task cancellation, and
pagination/batched fetches.

## 45. Memory management

Test large media libraries. Use autorelease pools or streaming where applicable.
Avoid retaining full-resolution images, complete videos, or large decrypted files
longer than necessary. Delete temporary decrypted files as soon as they are no
longer required.

## 46. Privacy by default

No third-party analytics SDKs by default. No advertising, behavioral analytics,
tracking pixels, fingerprinting, or unnecessary telemetry. If crash reporting is
later added, it must never include decrypted user content.

## 47. Permissions

Request contextually; never request everything at first launch.

- **Camera** — when the user selects Take Photo
- **Microphone** — when they select Record Audio
- **Location** — when they select Add Location
- **Photos** — prefer picker-based access

Provide clear purpose strings.

## 48. Onboarding

Short — maximum roughly 3 useful screens before the user can begin:

1. **Welcome to ORPHEUS** — a private place for what matters to you
2. **Your information stays yours** — explain local encryption and privacy
   accurately
3. **Protect ORPHEUS** — offer Face ID setup

Then enter Home. Do not force users through a marketing slideshow.

## 49. First-run Space

An optional starter Space: **Personal**. Include no fake sample private data.
Potentially show instructional placeholders until the user creates something.

## 50. Settings

- **ORPHEUS** — Appearance, App Icon where supported
- **Security** — Face ID, Auto-Lock, Lock Now, Clipboard behavior, Screen privacy
- **Storage** — storage usage, cached thumbnails, temporary files, local archives
- **Sync** — status, enable/disable, last successful sync
- **Intelligence** — availability, enable/disable, local intelligence explanation
- **Data** — Export, Import ORPHEUS Archive, Delete All Data
- **About** — version, build, privacy information, licenses

## 51. Storage management

Show actual disk usage broken down by Photos, Videos, Audio, Documents, Other,
Cache. **Do not show invented numbers.** Allow cache cleanup without deleting
source content.

## 52. Destructive operations

Delete Entry, Delete Space, Delete All Data, Reset Encryption, and Remove Sync
Data must require appropriate confirmation. For catastrophic actions, make the
consequence unmistakable.

## 53. Recently Deleted

Default retention **30 days**. Users may restore or permanently delete. Sensitive
files remain encrypted while waiting for deletion.

## 54. File integrity

Maintain integrity metadata for encrypted files. Verify files before
importing/restoring encrypted archives. If corruption is detected: don't crash,
preserve whatever can safely be preserved, and clearly report which item failed.

## 55. Testing

**Unit tests** — encryption/decryption, key management, Entry creation, Space
management, tags, search, export/import, archive validation, timeout logic, sync
conflict handling, AI availability handling.

**UI tests** — onboarding, unlock, create note, create Space, import photo,
import document, search, settings, delete/restore Entry, accessibility flows.

Use current Swift Testing capabilities where appropriate; XCTest/UI testing where
required.

## 56. Security testing

Specifically attempt to detect: plaintext sensitive files, plaintext temporary
files, keys in logs, decrypted data in UserDefaults, private content in crash
logs, private content in widgets, app-switcher exposure, unprotected temporary
export files.

**No private Entry body should ever be logged.**

## 57. Performance testing

Profile using Instruments: SwiftUI update performance, launch time, CPU, memory,
hangs, disk activity, encryption/decryption, image loading, scrolling, file
imports. Fix serious issues rather than merely documenting them.

## 58. Xcode previews

Useful SwiftUI previews for major components, including states: empty,
populated, loading, error, locked, long text, large Dynamic Type, Light Mode,
Dark Mode. Previews use mock data and never require production credentials.

## 59. Debugging

The project must compile without errors, broken references, invalid assets,
missing package dependencies, or unresolved symbols. Review warnings. Fix
legitimate warnings. **Do not simply disable warnings globally to make the build
appear clean.**

## 60. Build verification

Before declaring a phase complete:

1. Resolve packages
2. Clean build
3. Build the app
4. Build extensions
5. Run unit tests
6. Run applicable UI tests
7. Review compiler warnings
8. Review concurrency diagnostics
9. Launch in simulator
10. Exercise the implemented feature manually
11. Inspect for visual regressions
12. Fix discovered defects

**Do not say something works unless it has actually been implemented and
validated.**

## 61. iPhone test matrix

At minimum: a smaller iPhone, a standard modern iPhone, a large Pro Max-class
iPhone. Test portrait, landscape where supported, Dark Mode, Light Mode, large
text, reduced motion, reduced transparency.

## 62. iPad

Must be first class. Test portrait, landscape, split screen, Stage
Manager/window resizing, external keyboard, pointer, drag and drop. Use the
additional screen real estate intelligently.

## 63. Keyboard shortcuts

```text
⌘N    New Note
⌘F    Search
⌘L    Lock ORPHEUS
⌘,    Settings
```

Use standard platform conventions where possible.

## 64. Design review

After the application works, perform a dedicated visual-design pass reviewing
every screen for alignment, spacing, typography, material usage, hierarchy,
animation, navigation consistency, awkward empty areas, clipping, safe areas,
accessibility, and excessive visual decoration.

**Do not accept "functional developer UI" as final.**

## 65. Liquid Glass review

Audit every glass surface: *is this an interactive/navigation layer that benefits
from glass?* If not, remove it. Use Apple's automatic system glass wherever
possible. Custom glass reserved for genuinely custom controls.

## 66. No web-app look

Do not build a SwiftUI interface that looks like a website stuffed into an
iPhone. Avoid endless:

```swift
RoundedRectangle
    .background(...)
    .overlay(...)
    .shadow(...)
```

Use native Lists, Forms, Navigation, Toolbars, Menus, Sheets, Inspectors,
transitions, context menus, and swipe actions when they are the appropriate Apple
interaction.

## 67. No placeholders

Do not stop with `Text("Coming Soon")`. Do not leave core functionality
represented by dummy buttons. If a feature is in the current implementation
phase, implement it. If a feature genuinely requires an external dependency not
available in the project, isolate it cleanly and document exactly what is
missing.

## 68. No fake security

Never use marketing claims such as *military grade, unhackable, impossible to
access, anonymous, zero trace, completely secure* unless there is a specific
defensible technical meaning. Describe security accurately.

## 69. Documentation

Maintain `README.md`, `ARCHITECTURE.md`, `SECURITY.md`, `CHANGELOG.md`.

The security document should explain threat model, encryption architecture, key
storage, file protection, local authentication, export behavior, sync model, and
known limitations. Do not publish secrets in documentation.

## 70. Changelog

Never overwrite previous changelog history. Add new releases chronologically. Use
semantic versioning where practical. Initial release: **ORPHEUS 1.0**.

## 71. Version 1.0 definition

Not complete until it supports at minimum: onboarding · biometric/device
authentication · encrypted local storage · Spaces · notes · rich text · photos ·
files · document scanning · audio recording · links · optional locations ·
favorites · pinning · tags · search · Recently Deleted · import · export ·
ORPHEUS encrypted archive · privacy screen · auto-lock · Lock Now · Share
Extension · settings · iPad adaptive layout · accessibility · Light/Dark Mode ·
core automated tests.

ORPHEUS Intelligence may be enabled on devices where the required Apple
functionality is available.

## 72. Version 1.1+ candidates

Encrypted CloudKit sync · cross-device handoff · more intelligent search ·
improved local document understanding · duplicate detection · OCR · automatic
organization suggestions · advanced archive recovery · collaborative encrypted
Spaces only if a sound cryptographic design can be implemented · macOS companion
app · Apple Watch quick capture.

Do not destabilize 1.0 by cramming experimental features into the first release.

## 73. Quality bar

The application must feel as though the team cared about every interaction. A
successful result should make someone say *"This feels like a real Apple app."* —
not *"This looks like an AI-generated SwiftUI project."*

Priority order:

1. reliability
2. privacy
3. usability
4. native design
5. performance
6. accessibility
7. visual polish
8. additional features

## 74. Implementation method

**Do not simply explain how ORPHEUS could be built. Build it.** Start by
inspecting the existing repository if one exists. Do not destroy functioning code
unnecessarily.

| Phase | Scope |
|---|---|
| **1 — Foundation** | project architecture, design system, models, encryption, authentication, navigation, persistent storage, Home, Spaces |
| **2 — Content** | notes, rich text, photos, videos, files, scans, audio, links, locations, tags, favorites, pinned items |
| **3 — Discovery + Privacy** | Search, Recently Deleted, Activity, privacy shield, auto-lock, Lock Now, import/export, encrypted ORPHEUS archives |
| **4 — System Integration** | Share Extension, App Intents, Shortcuts, privacy-safe widgets, Control Center integration, iPad enhancements, drag and drop, keyboard shortcuts |
| **5 — Intelligence** | Foundation Models integration: summaries, title suggestions, tag suggestions, selected-content Q&A, intelligent local search. Do not make cloud AI a silent fallback |
| **6 — Production Polish** | visual-design review, Liquid Glass audit, accessibility audit, performance profiling, memory profiling, security review, edge-case testing, warning cleanup, concurrency review, UI testing, final simulator testing |

Compile and test after each phase.

## 75. Final acceptance

Do not stop because the application launches. Completion means: clean build ·
functioning features · polished UI · functioning encryption · correct locking ·
persistent data · functional import/export · no obvious plaintext leakage ·
tested recovery/error states · polished iPhone UI · polished iPad UI ·
accessibility · responsive performance · useful tests · updated documentation ·
updated changelog.

If you discover an architectural flaw while building, correct it instead of
building more code on top of a bad foundation. Do not ask for approval after
every minor decision. Make sound senior-engineering decisions, document
significant choices, and continue.

---

## Final product vision

ORPHEUS should feel like a quiet private layer of the iPhone. It isn't trying to
make privacy look dangerous or secret-agent themed. It should simply feel like:

> **This space belongs to me.**

The interface should disappear when the user is reading or creating content and
become beautifully visible when interaction is needed.

Use Xcode 26 and the iOS 26 generation of Apple technologies to make ORPHEUS feel
like an application designed specifically for this generation of iPhone and iPad
— not an older app that was merely recompiled.

**Build the real product.**
