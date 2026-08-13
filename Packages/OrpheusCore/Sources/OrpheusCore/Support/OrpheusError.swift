import Foundation
import Security

/// Errors surfaced by the ORPHEUS core layer.
///
/// Each case carries a user-presentable description drawn from the package's
/// String Catalog. Internal detail that would be meaningless or alarming to a
/// person reading a dialog stays out of these strings, and no case ever embeds
/// decrypted content or key material.
public enum OrpheusError: Error, LocalizedError, Equatable, Sendable {

    // MARK: Cryptography

    /// AES-GCM could not produce a combined representation. Not expected in
    /// practice; treated as a hard failure rather than silently writing
    /// something unreadable.
    case sealFailed

    /// Authentication failed while opening a sealed box. Either the data was
    /// modified, or it was encrypted for a different purpose or vault.
    case authenticationFailed

    /// The vault is locked, so no key is available to decrypt with.
    case vaultLocked

    /// Keychain Services rejected a vault-key operation. The status is retained
    /// for diagnostics but never interpolated into a user-visible string.
    case keychainFailure(OSStatus)

    /// A Keychain item existed but did not contain a valid 256-bit master key.
    case invalidMasterKey

    /// iOS reported that user-presence protection was available but could not
    /// create the corresponding access-control object.
    case keychainAccessControlUnavailable

    // MARK: Encrypted blob format

    /// The file does not begin with the ORPHEUS blob magic.
    case notAnOrpheusBlob

    /// The blob declares a format version this build cannot read.
    case unsupportedBlobVersion(UInt16)

    /// The blob's header is present but internally inconsistent.
    case malformedBlobHeader

    /// The blob ended earlier than its header said it would, meaning it was
    /// truncated. Detected before any plaintext is written out.
    case truncatedBlob(expectedChunks: UInt64, readChunks: UInt64)

    /// Bytes remained after the declared final chunk, meaning data was appended.
    case trailingBlobData

    /// The stored digest did not match the ciphertext on disk.
    case integrityCheckFailed

    // MARK: Storage

    case fileNotFound
    case couldNotCreateFile
    case couldNotReadFile

    public var errorDescription: String? {
        switch self {
        case .sealFailed:
            Self.string("error.seal_failed")
        case .authenticationFailed:
            Self.string("error.authentication_failed")
        case .vaultLocked:
            Self.string("error.vault_locked")
        case .keychainFailure:
            Self.string("error.keychain_failure")
        case .invalidMasterKey:
            Self.string("error.invalid_master_key")
        case .keychainAccessControlUnavailable:
            Self.string("error.keychain_access_control_unavailable")
        case .notAnOrpheusBlob:
            Self.string("error.not_an_orpheus_blob")
        case .unsupportedBlobVersion(let version):
            String(
                localized: "error.unsupported_blob_version",
                defaultValue: "This content was saved by a newer version of ORPHEUS (format \(version)).",
                bundle: .module
            )
        case .malformedBlobHeader:
            Self.string("error.malformed_blob_header")
        case .truncatedBlob:
            Self.string("error.truncated_blob")
        case .trailingBlobData:
            Self.string("error.trailing_blob_data")
        case .integrityCheckFailed:
            Self.string("error.integrity_check_failed")
        case .fileNotFound:
            Self.string("error.file_not_found")
        case .couldNotCreateFile:
            Self.string("error.could_not_create_file")
        case .couldNotReadFile:
            Self.string("error.could_not_read_file")
        }
    }

    /// What a person can actually do about it, where there is something to do.
    public var recoverySuggestion: String? {
        switch self {
        case .vaultLocked:
            Self.string("error.recovery.unlock")
        case .truncatedBlob, .trailingBlobData, .integrityCheckFailed, .malformedBlobHeader:
            Self.string("error.recovery.restore_from_archive")
        case .unsupportedBlobVersion:
            Self.string("error.recovery.update_app")
        default:
            nil
        }
    }

    private static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }
}
