import Foundation

/// Identifies what a derived key is allowed to protect.
///
/// Every encryption operation in ORPHEUS derives a fresh key from the vault
/// master key using HKDF, with the purpose as the `info` parameter. This gives
/// cryptographic domain separation: a key that decrypts one entry's payload
/// cannot decrypt another entry's payload, an attachment, or an archive, even
/// though all of them descend from the same master key.
///
/// Two practical benefits:
/// - Confused-deputy resistance. Ciphertext cannot be moved from one slot to
///   another and still decrypt, so an attacker who can swap files on disk
///   cannot make entry A display entry B's contents.
/// - Nonce-collision headroom. AES-GCM's random-nonce safety margin applies
///   per key. Because each entry gets its own key, the number of messages under
///   any single key stays small.
public enum KeyPurpose: Sendable, Hashable {

    /// The encrypted body of an entry (note text, link metadata, and so on).
    case entryPayload(UUID)

    /// A file attached to an entry: photo, video, document, recording.
    case attachment(UUID)

    /// A generated preview image. Separated from the attachment it derives from
    /// so thumbnail caches can be discarded without touching originals.
    case thumbnail(UUID)

    /// The manifest of a portable `.orpheus` archive.
    case archiveManifest

    /// Stable, versioned label fed to HKDF as `info`.
    ///
    /// These strings are part of the on-disk format. Changing one makes
    /// existing data undecryptable, so a change requires a format version bump
    /// and a migration, never an edit in place.
    var infoLabel: String {
        switch self {
        case .entryPayload(let id):
            "orpheus.v1.entry.payload:\(id.uuidString)"
        case .attachment(let id):
            "orpheus.v1.attachment:\(id.uuidString)"
        case .thumbnail(let id):
            "orpheus.v1.thumbnail:\(id.uuidString)"
        case .archiveManifest:
            "orpheus.v1.archive.manifest"
        }
    }

    var info: Data {
        Data(infoLabel.utf8)
    }
}
