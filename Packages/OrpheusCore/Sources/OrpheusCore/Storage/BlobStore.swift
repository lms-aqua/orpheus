import CryptoKit
import Foundation

/// Persistent metadata for one encrypted content blob.
public struct BlobDescriptor: Sendable, Equatable {
    public let id: UUID
    public let digest: String
    public let plaintextByteCount: Int
    public let ciphertextByteCount: Int

    public init(
        id: UUID,
        digest: String,
        plaintextByteCount: Int,
        ciphertextByteCount: Int
    ) {
        self.id = id
        self.digest = digest
        self.plaintextByteCount = plaintextByteCount
        self.ciphertextByteCount = ciphertextByteCount
    }
}

/// Owns the encrypted-blob directory and its write/read/delete lifecycle.
///
/// Writes are encrypted to a staging file and moved into place only after the
/// complete ciphertext has been synchronized. A failed encryption therefore
/// never replaces a previously valid blob.
public actor BlobStore {
    private let rootURL: URL
    private let cipher: ChunkedCipher
    private let fileManager: FileManager

    public init(
        rootURL: URL,
        masterKey: SymmetricKey
    ) {
        self.rootURL = rootURL
        cipher = ChunkedCipher(engine: CryptoEngine(masterKey: masterKey))
        fileManager = .default
    }

    /// Encrypts or replaces a small in-memory payload.
    @discardableResult
    public func store(
        _ data: Data,
        id: UUID,
        for purpose: KeyPurpose
    ) throws -> BlobDescriptor {
        try prepareDirectory()

        let destination = blobURL(for: id)
        let staging = rootURL.appendingPathComponent(".\(UUID().uuidString).staging")

        do {
            let stats = try cipher.encrypt(data, to: staging, for: purpose)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: staging)
            } else {
                try fileManager.moveItem(at: staging, to: destination)
            }

            return BlobDescriptor(
                id: id,
                digest: stats.digest,
                plaintextByteCount: stats.plaintextByteCount,
                ciphertextByteCount: stats.ciphertextByteCount
            )
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    /// Encrypts or replaces a file without loading it all into memory.
    @discardableResult
    public func store(
        fileAt source: URL,
        id: UUID,
        for purpose: KeyPurpose
    ) throws -> BlobDescriptor {
        try prepareDirectory()

        let destination = blobURL(for: id)
        let staging = rootURL.appendingPathComponent(".\(UUID().uuidString).staging")

        do {
            let stats = try cipher.encrypt(fileAt: source, to: staging, for: purpose)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: staging)
            } else {
                try fileManager.moveItem(at: staging, to: destination)
            }

            return BlobDescriptor(
                id: id,
                digest: stats.digest,
                plaintextByteCount: stats.plaintextByteCount,
                ciphertextByteCount: stats.ciphertextByteCount
            )
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    /// Opens a small payload and verifies its stored ciphertext digest first.
    public func load(
        id: UUID,
        for purpose: KeyPurpose,
        expectedDigest: String
    ) throws -> Data {
        try cipher.decryptToData(
            fileAt: blobURL(for: id),
            for: purpose,
            expectedDigest: expectedDigest
        )
    }

    /// Opens a large payload into a caller-owned destination file.
    public func load(
        id: UUID,
        to destination: URL,
        for purpose: KeyPurpose,
        expectedDigest: String
    ) throws {
        try cipher.decrypt(
            fileAt: blobURL(for: id),
            to: destination,
            for: purpose,
            expectedDigest: expectedDigest
        )
    }

    public func contains(id: UUID) -> Bool {
        fileManager.fileExists(atPath: blobURL(for: id).path)
    }

    public func delete(id: UUID) throws {
        let url = blobURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
    }

    private func blobURL(for id: UUID) -> URL {
        rootURL.appendingPathComponent(id.uuidString.lowercased())
            .appendingPathExtension("orpheusblob")
    }
}
