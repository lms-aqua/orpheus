import CryptoKit
import Foundation

/// Authenticated encryption for ORPHEUS content.
///
/// ## Design
///
/// - **Cipher:** AES-256-GCM via CryptoKit. Nothing here invents a construction;
///   it composes primitives Apple ships.
/// - **Key hierarchy:** one 256-bit master key lives in the Keychain. Every
///   individual encryption uses a subkey derived with HKDF-SHA256 from that
///   master, with a ``KeyPurpose`` as the `info` input. See ``KeyPurpose`` for
///   why the separation matters.
/// - **Nonces:** generated randomly by CryptoKit per seal and carried in the
///   sealed box, so callers never manage them. Because keys are per-item, the
///   message count under any one key stays far below AES-GCM's random-nonce
///   birthday bound.
/// - **Associated data:** callers may bind ciphertext to context that is not
///   itself secret (for example a chunk index), so relocating or reordering
///   ciphertext is detected as tampering.
///
/// The engine holds key material in memory. It is created when the vault
/// unlocks and released when it locks; it is deliberately not a singleton and
/// not cached anywhere persistent.
public struct CryptoEngine: Sendable {

    /// Fixed, non-secret HKDF salt. A constant salt is appropriate here: the
    /// input key material is already a full-entropy random key, and the
    /// per-item `info` provides the separation we actually need. It is part of
    /// the on-disk format, so changing it requires a version bump.
    static let hkdfSalt = Data("ORPHEUS.v1.hkdf.salt".utf8)

    /// Size of every key in this system, in bytes.
    public static let keyByteCount = 32

    private let masterKey: SymmetricKey

    public init(masterKey: SymmetricKey) {
        self.masterKey = masterKey
    }

    /// Generates a new random master key using the system CSPRNG.
    public static func generateMasterKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    /// Derives the subkey used for a specific purpose.
    ///
    /// Deterministic: the same master key and purpose always yield the same
    /// subkey, which is what allows content to be decrypted on a later launch
    /// without storing per-item keys anywhere.
    public func derivedKey(for purpose: KeyPurpose) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            salt: Self.hkdfSalt,
            info: purpose.info,
            outputByteCount: Self.keyByteCount
        )
    }

    /// Encrypts `plaintext`, returning nonce + ciphertext + tag as one blob.
    ///
    /// - Parameter associatedData: authenticated but not encrypted. Must be
    ///   supplied identically to ``open(_:for:authenticating:)``.
    public func seal(
        _ plaintext: Data,
        for purpose: KeyPurpose,
        authenticating associatedData: Data = Data()
    ) throws -> Data {
        let box = try AES.GCM.seal(
            plaintext,
            using: derivedKey(for: purpose),
            authenticating: associatedData
        )
        guard let combined = box.combined else {
            throw OrpheusError.sealFailed
        }
        return combined
    }

    /// Decrypts a blob produced by ``seal(_:for:authenticating:)``.
    ///
    /// Throws ``OrpheusError/authenticationFailed`` if the data, the purpose, or
    /// the associated data does not match — CryptoKit's own error is
    /// deliberately not propagated, so callers cannot accidentally surface
    /// cryptographic internals to a person.
    public func open(
        _ combined: Data,
        for purpose: KeyPurpose,
        authenticating associatedData: Data = Data()
    ) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(
                box,
                using: derivedKey(for: purpose),
                authenticating: associatedData
            )
        } catch {
            throw OrpheusError.authenticationFailed
        }
    }
}
