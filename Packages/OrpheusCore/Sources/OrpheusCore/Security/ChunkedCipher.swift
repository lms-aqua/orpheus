import CryptoKit
import Foundation

/// Result of writing an encrypted blob.
public struct EncryptedBlobStats: Sendable, Equatable {
    public let chunkCount: UInt64
    public let plaintextByteCount: Int
    public let ciphertextByteCount: Int
    /// Lowercase hex SHA-256 of the complete ciphertext file, header included.
    public let digest: String
}

/// Streaming authenticated encryption for files of any size.
///
/// CryptoKit's `AES.GCM` is one-shot: it wants the whole message in memory. A
/// 4 GB video cannot go through it directly, so blobs are split into chunks and
/// each chunk is sealed independently.
///
/// Chunking naively would introduce three attacks that whole-file AEAD does not
/// have, so each is closed explicitly:
///
/// | Attack | Defense |
/// |---|---|
/// | Reorder chunks | chunk index is in the associated data |
/// | Truncate the tail | `chunkCount` lives in the header, and the header is in every chunk's associated data |
/// | Append extra chunks | after the declared final chunk, any remaining bytes are an error |
///
/// Memory stays bounded to roughly one chunk regardless of file size, which is
/// the point.
public struct ChunkedCipher: Sendable {

    /// 1 MiB of plaintext per chunk. Large enough that per-chunk overhead
    /// (28 bytes) is negligible, small enough to keep peak memory flat.
    public static let defaultChunkSize: Int = 1 << 20

    /// Nonce (12) + tag (16) added to every chunk by AES-GCM.
    static let sealOverhead = 28

    private let engine: CryptoEngine
    private let chunkSize: Int

    public init(engine: CryptoEngine, chunkSize: Int = ChunkedCipher.defaultChunkSize) {
        precondition(
            chunkSize > 0 && chunkSize <= Int(EncryptedBlobHeader.maximumChunkSize),
            "chunkSize must be within the format's supported range"
        )
        self.engine = engine
        self.chunkSize = chunkSize
    }

    // MARK: - Encrypting

    /// Encrypts a file on disk, streaming through it one chunk at a time.
    @discardableResult
    public func encrypt(
        fileAt source: URL,
        to destination: URL,
        for purpose: KeyPurpose
    ) throws -> EncryptedBlobStats {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: source.path) else {
            throw OrpheusError.fileNotFound
        }

        let attributes = try fileManager.attributesOfItem(atPath: source.path)
        let plaintextSize = (attributes[.size] as? NSNumber)?.intValue ?? 0

        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }

        return try writeBlob(
            to: destination,
            plaintextByteCount: plaintextSize,
            for: purpose
        ) {
            let chunk = try input.read(upToCount: self.chunkSize)
            if let chunk, !chunk.isEmpty { return chunk }
            return nil
        }
    }

    /// Encrypts data already held in memory, using the same on-disk format as
    /// ``encrypt(fileAt:to:for:)``.
    ///
    /// One format for every blob, rather than a separate shape for small
    /// payloads, means the reader has exactly one path to get right.
    @discardableResult
    public func encrypt(
        _ data: Data,
        to destination: URL,
        for purpose: KeyPurpose
    ) throws -> EncryptedBlobStats {
        var offset = data.startIndex
        return try writeBlob(
            to: destination,
            plaintextByteCount: data.count,
            for: purpose
        ) {
            guard offset < data.endIndex else { return nil }
            let end = data.index(offset, offsetBy: self.chunkSize, limitedBy: data.endIndex) ?? data.endIndex
            defer { offset = end }
            return data[offset ..< end]
        }
    }

    private func writeBlob(
        to destination: URL,
        plaintextByteCount: Int,
        for purpose: KeyPurpose,
        nextChunk: () throws -> Data?
    ) throws -> EncryptedBlobStats {
        let chunkCount = UInt64((plaintextByteCount + chunkSize - 1) / chunkSize)
        let header = EncryptedBlobHeader(
            chunkSize: UInt32(chunkSize),
            chunkCount: chunkCount
        )
        let headerBytes = header.encoded

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        // `.completeUnlessOpen` rather than `.complete`: a long import must be
        // able to keep writing if the screen locks partway through, while the
        // finished file is still unreadable to anything that reopens it on a
        // locked device.
        guard fileManager.createFile(
            atPath: destination.path,
            contents: nil,
            attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
        ) else {
            throw OrpheusError.couldNotCreateFile
        }

        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }

        var hasher = SHA256()
        try output.write(contentsOf: headerBytes)
        hasher.update(data: headerBytes)

        var written = 0
        var index: UInt64 = 0
        var plaintextSeen = 0

        while let chunk = try nextChunk() {
            // Each iteration drops its buffers before the next read, so peak
            // memory tracks one chunk rather than the whole file.
            try autoreleasepool {
                let sealed = try engine.seal(
                    Data(chunk),
                    for: purpose,
                    authenticating: header.associatedData(forChunkIndex: index)
                )
                var frame = Data(capacity: sealed.count + 4)
                frame.appendBigEndian(UInt32(sealed.count))
                frame.append(sealed)

                try output.write(contentsOf: frame)
                hasher.update(data: frame)
                written += frame.count
                plaintextSeen += chunk.count
            }
            index += 1
        }

        // If the source changed size while we were reading it, the header we
        // already wrote is wrong. Fail rather than leave an unreadable blob.
        guard index == chunkCount else {
            try? fileManager.removeItem(at: destination)
            throw OrpheusError.truncatedBlob(expectedChunks: chunkCount, readChunks: index)
        }

        try output.synchronize()

        return EncryptedBlobStats(
            chunkCount: chunkCount,
            plaintextByteCount: plaintextSeen,
            ciphertextByteCount: headerBytes.count + written,
            digest: Self.hex(hasher.finalize())
        )
    }

    // MARK: - Decrypting

    /// Decrypts a blob to a file, streaming one chunk at a time.
    ///
    /// - Parameter expectedDigest: when supplied, the ciphertext is hashed and
    ///   compared before any decryption begins. AES-GCM would catch corruption
    ///   anyway, but checking first distinguishes "this file rotted on disk"
    ///   from "this file was tampered with", which are different messages to
    ///   show and different things to do about it.
    public func decrypt(
        fileAt source: URL,
        to destination: URL,
        for purpose: KeyPurpose,
        expectedDigest: String? = nil
    ) throws {
        if let expectedDigest {
            guard try Self.digest(ofFileAt: source) == expectedDigest else {
                throw OrpheusError.integrityCheckFailed
            }
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        guard fileManager.createFile(
            atPath: destination.path,
            contents: nil,
            attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
        ) else {
            throw OrpheusError.couldNotCreateFile
        }

        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }

        do {
            try readBlob(fileAt: source, for: purpose) { plaintext in
                try output.write(contentsOf: plaintext)
            }
        } catch {
            // Never leave a partially written plaintext file behind: it would
            // be unencrypted content on disk that nothing owns.
            try? output.close()
            try? fileManager.removeItem(at: destination)
            throw error
        }

        try output.synchronize()
    }

    /// Decrypts a blob into memory. Intended for small payloads such as note
    /// bodies; use ``decrypt(fileAt:to:for:expectedDigest:)`` for media.
    public func decryptToData(
        fileAt source: URL,
        for purpose: KeyPurpose,
        expectedDigest: String? = nil
    ) throws -> Data {
        if let expectedDigest {
            guard try Self.digest(ofFileAt: source) == expectedDigest else {
                throw OrpheusError.integrityCheckFailed
            }
        }

        var result = Data()
        try readBlob(fileAt: source, for: purpose) { plaintext in
            result.append(plaintext)
        }
        return result
    }

    private func readBlob(
        fileAt source: URL,
        for purpose: KeyPurpose,
        consume: (Data) throws -> Void
    ) throws {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw OrpheusError.fileNotFound
        }

        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }

        let headerBytes = try input.readExactly(EncryptedBlobHeader.byteCount)
        guard headerBytes.count == EncryptedBlobHeader.byteCount else {
            throw OrpheusError.malformedBlobHeader
        }
        let header = try EncryptedBlobHeader(decoding: headerBytes)

        // A hostile header could claim a huge frame; cap what we will allocate.
        let maximumFrame = Int(header.chunkSize) + Self.sealOverhead

        var index: UInt64 = 0
        while index < header.chunkCount {
            try autoreleasepool {
                let lengthBytes = try input.readExactly(4)
                guard lengthBytes.count == 4,
                      let sealedLength = lengthBytes.bigEndianUInt32(atOffset: 0)
                else {
                    throw OrpheusError.truncatedBlob(
                        expectedChunks: header.chunkCount,
                        readChunks: index
                    )
                }

                guard sealedLength >= UInt32(Self.sealOverhead),
                      sealedLength <= UInt32(maximumFrame)
                else {
                    throw OrpheusError.malformedBlobHeader
                }

                let sealed = try input.readExactly(Int(sealedLength))
                guard sealed.count == Int(sealedLength) else {
                    throw OrpheusError.truncatedBlob(
                        expectedChunks: header.chunkCount,
                        readChunks: index
                    )
                }

                let plaintext = try engine.open(
                    sealed,
                    for: purpose,
                    authenticating: header.associatedData(forChunkIndex: index)
                )
                try consume(plaintext)
            }
            index += 1
        }

        // Anything past the declared final chunk means the file grew.
        let trailing = try input.readExactly(1)
        guard trailing.isEmpty else {
            throw OrpheusError.trailingBlobData
        }
    }

    // MARK: - Integrity

    /// Streaming SHA-256 of a file, as lowercase hex.
    public static func digest(ofFileAt url: URL, readSize: Int = 1 << 20) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OrpheusError.fileNotFound
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let didFinish = try autoreleasepool { () -> Bool in
                guard let block = try handle.read(upToCount: readSize), !block.isEmpty else {
                    return true
                }
                hasher.update(data: block)
                return false
            }
            if didFinish { break }
        }
        return hex(hasher.finalize())
    }

    static func hex(_ digest: SHA256Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Exact reads

private extension FileHandle {

    /// Reads up to `count` bytes, looping until satisfied or the file ends.
    ///
    /// `read(upToCount:)` is permitted to return fewer bytes than asked for.
    /// Treating a short read as end-of-file is a real bug in framed formats, so
    /// the loop is not optional.
    func readExactly(_ count: Int) throws -> Data {
        var buffer = Data()
        buffer.reserveCapacity(count)
        while buffer.count < count {
            guard let next = try read(upToCount: count - buffer.count), !next.isEmpty else {
                break
            }
            buffer.append(next)
        }
        return buffer
    }
}
