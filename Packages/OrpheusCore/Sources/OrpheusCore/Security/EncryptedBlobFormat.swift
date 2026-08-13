import Foundation

/// On-disk header for an ORPHEUS encrypted blob.
///
/// ```text
/// offset  size  field
/// 0       8     magic  "ORPHBLB1"
/// 8       2     version        (UInt16, big endian)
/// 10      2     reserved       (UInt16, must be 0)
/// 12      4     chunkSize      (UInt32, plaintext bytes per chunk)
/// 16      8     chunkCount     (UInt64, number of chunks that follow)
/// 24      ...   chunk frames
/// ```
///
/// Each chunk frame is:
///
/// ```text
/// 4 bytes   sealedLength (UInt32, big endian)
/// n bytes   AES-GCM sealed box (12-byte nonce ‖ ciphertext ‖ 16-byte tag)
/// ```
///
/// The header is included verbatim in every chunk's associated data, so
/// `chunkCount` is authenticated. That is what makes truncation detectable:
/// an attacker cannot lop off the tail and also rewrite the count, because
/// doing so invalidates every remaining chunk's tag.
public struct EncryptedBlobHeader: Sendable, Equatable {

    /// Format marker. The trailing digit is the format generation, bumped only
    /// alongside a migration path.
    public static let magic = Data("ORPHBLB1".utf8)

    /// Serialized size of the header.
    public static let byteCount = 24

    /// Version this build writes.
    public static let currentVersion: UInt16 = 1

    /// Upper bound on an accepted chunk size, so a corrupt or hostile header
    /// cannot induce a huge allocation. 64 MiB is far above any size we write.
    public static let maximumChunkSize: UInt32 = 64 << 20

    public let version: UInt16
    public let chunkSize: UInt32
    public let chunkCount: UInt64

    public init(version: UInt16 = Self.currentVersion, chunkSize: UInt32, chunkCount: UInt64) {
        self.version = version
        self.chunkSize = chunkSize
        self.chunkCount = chunkCount
    }

    /// Serializes the header to its 24-byte representation.
    public var encoded: Data {
        var data = Data(capacity: Self.byteCount)
        data.append(Self.magic)
        data.appendBigEndian(version)
        data.appendBigEndian(UInt16(0)) // reserved
        data.appendBigEndian(chunkSize)
        data.appendBigEndian(chunkCount)
        return data
    }

    /// Parses and validates a header.
    ///
    /// Validation happens here, once, so the cipher body can assume sane values
    /// rather than re-checking them per chunk.
    public init(decoding data: Data) throws {
        guard data.count >= Self.byteCount else {
            throw OrpheusError.malformedBlobHeader
        }

        // Index from startIndex: a Data slice does not necessarily start at 0.
        let base = data.startIndex
        guard data[base ..< base + 8] == Self.magic else {
            throw OrpheusError.notAnOrpheusBlob
        }

        guard
            let version = data.bigEndianUInt16(atOffset: 8),
            let reserved = data.bigEndianUInt16(atOffset: 10),
            let chunkSize = data.bigEndianUInt32(atOffset: 12),
            let chunkCount = data.bigEndianUInt64(atOffset: 16)
        else {
            throw OrpheusError.malformedBlobHeader
        }

        guard version == Self.currentVersion else {
            throw OrpheusError.unsupportedBlobVersion(version)
        }
        guard reserved == 0 else {
            throw OrpheusError.malformedBlobHeader
        }
        guard chunkSize > 0, chunkSize <= Self.maximumChunkSize else {
            throw OrpheusError.malformedBlobHeader
        }

        self.version = version
        self.chunkSize = chunkSize
        self.chunkCount = chunkCount
    }

    /// Associated data binding a chunk to this header and to its position.
    func associatedData(forChunkIndex index: UInt64) -> Data {
        var data = encoded
        data.appendBigEndian(index)
        return data
    }
}

// MARK: - Big-endian helpers

extension Data {

    mutating func appendBigEndian(_ value: UInt16) {
        withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }

    mutating func appendBigEndian(_ value: UInt32) {
        withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }

    mutating func appendBigEndian(_ value: UInt64) {
        withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }

    /// Reads a big-endian integer at a logical offset from `startIndex`.
    ///
    /// Slices of `Data` keep their parent's indices, so every read is expressed
    /// relative to `startIndex` rather than to zero. Getting this wrong is a
    /// classic source of silent corruption when parsing sliced buffers.
    func bigEndianUInt16(atOffset offset: Int) -> UInt16? {
        guard let bytes = byteRange(offset: offset, count: 2) else { return nil }
        return bytes.reduce(UInt16(0)) { ($0 << 8) | UInt16($1) }
    }

    func bigEndianUInt32(atOffset offset: Int) -> UInt32? {
        guard let bytes = byteRange(offset: offset, count: 4) else { return nil }
        return bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    func bigEndianUInt64(atOffset offset: Int) -> UInt64? {
        guard let bytes = byteRange(offset: offset, count: 8) else { return nil }
        return bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    private func byteRange(offset: Int, count: Int) -> [UInt8]? {
        guard offset >= 0, self.count >= offset + count else { return nil }
        let start = index(startIndex, offsetBy: offset)
        return Array(self[start ..< index(start, offsetBy: count)])
    }
}
