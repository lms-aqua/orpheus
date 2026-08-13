import CryptoKit
import Foundation
import Testing

@testable import OrpheusCore

@Suite("ChunkedCipher")
struct ChunkedCipherTests {

    // A deliberately tiny chunk size so tests exercise multi-chunk paths
    // without writing megabytes.
    private let chunkSize = 64
    private let purpose = KeyPurpose.attachment(
        UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    )

    private func makeCipher() -> ChunkedCipher {
        ChunkedCipher(
            engine: CryptoEngine(masterKey: CryptoEngine.generateMasterKey()),
            chunkSize: chunkSize
        )
    }

    /// Scratch directory removed after each test so nothing leaks between runs.
    private func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orpheus-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try body(directory)
    }

    // MARK: - Round trips

    @Test("Round-trips payloads across every chunk boundary", arguments: [
        0, 1, 63, 64, 65, 127, 128, 129, 224, 4096
    ])
    func roundTripsAtChunkBoundaries(size: Int) throws {
        // Off-by-one errors in framed formats hide exactly at these sizes.
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let plaintext = Data((0 ..< size).map { UInt8($0 % 251) })

            let blob = directory.appendingPathComponent("blob.orphblob")
            let stats = try cipher.encrypt(plaintext, to: blob, for: purpose)

            #expect(stats.plaintextByteCount == size)
            #expect(stats.chunkCount == UInt64((size + chunkSize - 1) / chunkSize))

            let recovered = try cipher.decryptToData(fileAt: blob, for: purpose)
            #expect(recovered == plaintext)
        }
    }

    @Test("Round-trips a file through disk")
    func roundTripsFile() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let plaintext = Data((0 ..< 5_000).map { UInt8($0 % 256) })

            let source = directory.appendingPathComponent("source.bin")
            try plaintext.write(to: source)

            let blob = directory.appendingPathComponent("blob.orphblob")
            let stats = try cipher.encrypt(fileAt: source, to: blob, for: purpose)
            #expect(stats.plaintextByteCount == plaintext.count)

            let restored = directory.appendingPathComponent("restored.bin")
            try cipher.decrypt(fileAt: blob, to: restored, for: purpose)

            #expect(try Data(contentsOf: restored) == plaintext)
        }
    }

    @Test("Encrypted blob does not contain the plaintext")
    func blobDoesNotLeakPlaintext() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let marker = Data("SENTINEL-DO-NOT-LEAK-TO-DISK".utf8)
            // Repeat the marker so it spans several chunks.
            var plaintext = Data()
            for _ in 0 ..< 20 { plaintext.append(marker) }

            let blob = directory.appendingPathComponent("blob.orphblob")
            try cipher.encrypt(plaintext, to: blob, for: purpose)

            let onDisk = try Data(contentsOf: blob)
            #expect(onDisk.range(of: marker) == nil)
        }
    }

    @Test("Reported digest matches the file on disk")
    func digestMatches() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let blob = directory.appendingPathComponent("blob.orphblob")
            let stats = try cipher.encrypt(Data(repeating: 7, count: 300), to: blob, for: purpose)

            #expect(try ChunkedCipher.digest(ofFileAt: blob) == stats.digest)
            // Verified decryption should accept the digest it just produced.
            _ = try cipher.decryptToData(fileAt: blob, for: purpose, expectedDigest: stats.digest)
        }
    }

    // MARK: - Tamper detection

    @Test("Truncating the blob is detected")
    func truncationIsDetected() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let blob = directory.appendingPathComponent("blob.orphblob")
            // Four full chunks.
            try cipher.encrypt(Data(repeating: 0x5A, count: chunkSize * 4), to: blob, for: purpose)

            let full = try Data(contentsOf: blob)
            // Drop the final chunk frame entirely.
            let frameSize = 4 + ChunkedCipher.sealOverhead + chunkSize
            try full.prefix(full.count - frameSize).write(to: blob)

            #expect(throws: OrpheusError.truncatedBlob(expectedChunks: 4, readChunks: 3)) {
                _ = try cipher.decryptToData(fileAt: blob, for: purpose)
            }
        }
    }

    @Test("A partially truncated final frame is detected")
    func partialFrameIsDetected() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let blob = directory.appendingPathComponent("blob.orphblob")
            try cipher.encrypt(Data(repeating: 0x5A, count: chunkSize * 2), to: blob, for: purpose)

            let full = try Data(contentsOf: blob)
            try full.prefix(full.count - 10).write(to: blob)

            #expect(throws: OrpheusError.truncatedBlob(expectedChunks: 2, readChunks: 1)) {
                _ = try cipher.decryptToData(fileAt: blob, for: purpose)
            }
        }
    }

    @Test("Appending data after the final chunk is detected")
    func appendedDataIsDetected() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let blob = directory.appendingPathComponent("blob.orphblob")
            try cipher.encrypt(Data(repeating: 0x11, count: 100), to: blob, for: purpose)

            var full = try Data(contentsOf: blob)
            full.append(Data(repeating: 0xFF, count: 32))
            try full.write(to: blob)

            #expect(throws: OrpheusError.trailingBlobData) {
                _ = try cipher.decryptToData(fileAt: blob, for: purpose)
            }
        }
    }

    @Test("Swapping two chunks is detected")
    func reorderingIsDetected() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let blob = directory.appendingPathComponent("blob.orphblob")

            // Two full, equal-length chunks, so the frames are byte-swappable.
            var plaintext = Data(repeating: 0xAA, count: chunkSize)
            plaintext.append(Data(repeating: 0xBB, count: chunkSize))
            try cipher.encrypt(plaintext, to: blob, for: purpose)

            let full = try Data(contentsOf: blob)
            let headerSize = EncryptedBlobHeader.byteCount
            let frameSize = 4 + ChunkedCipher.sealOverhead + chunkSize

            let header = full.prefix(headerSize)
            let firstFrame = full.subdata(in: headerSize ..< headerSize + frameSize)
            let secondFrame = full.subdata(in: headerSize + frameSize ..< headerSize + 2 * frameSize)

            var reordered = Data()
            reordered.append(header)
            reordered.append(secondFrame)
            reordered.append(firstFrame)
            try reordered.write(to: blob)

            // The chunk index lives in the associated data, so a swap breaks
            // the tag rather than silently producing scrambled output.
            #expect(throws: OrpheusError.authenticationFailed) {
                _ = try cipher.decryptToData(fileAt: blob, for: purpose)
            }
        }
    }

    @Test("Rewriting the header chunk count is detected")
    func headerTamperingIsDetected() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let blob = directory.appendingPathComponent("blob.orphblob")
            try cipher.encrypt(Data(repeating: 0x33, count: chunkSize * 3), to: blob, for: purpose)

            var full = try Data(contentsOf: blob)
            // Claim one chunk instead of three, and drop the rest of the file.
            full.replaceSubrange(16 ..< 24, with: {
                var count = Data()
                count.appendBigEndian(UInt64(1))
                return count
            }())
            let frameSize = 4 + ChunkedCipher.sealOverhead + chunkSize
            try full.prefix(EncryptedBlobHeader.byteCount + frameSize).write(to: blob)

            // The header is inside every chunk's associated data, so editing it
            // invalidates the chunks that remain.
            #expect(throws: OrpheusError.authenticationFailed) {
                _ = try cipher.decryptToData(fileAt: blob, for: purpose)
            }
        }
    }

    @Test("A wrong expected digest is rejected before decrypting")
    func digestMismatchIsDetected() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let blob = directory.appendingPathComponent("blob.orphblob")
            try cipher.encrypt(Data(repeating: 0x77, count: 200), to: blob, for: purpose)

            #expect(throws: OrpheusError.integrityCheckFailed) {
                _ = try cipher.decryptToData(
                    fileAt: blob,
                    for: purpose,
                    expectedDigest: String(repeating: "0", count: 64)
                )
            }
        }
    }

    @Test("A blob for one attachment cannot be opened as another")
    func wrongPurposeIsDetected() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let blob = directory.appendingPathComponent("blob.orphblob")
            try cipher.encrypt(Data("attachment payload".utf8), to: blob, for: purpose)

            #expect(throws: OrpheusError.authenticationFailed) {
                _ = try cipher.decryptToData(fileAt: blob, for: .attachment(UUID()))
            }
        }
    }

    // MARK: - Malformed input

    @Test("A file without the ORPHEUS magic is rejected")
    func foreignFileIsRejected() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let notABlob = directory.appendingPathComponent("random.bin")
            try Data(repeating: 0x42, count: 512).write(to: notABlob)

            #expect(throws: OrpheusError.notAnOrpheusBlob) {
                _ = try cipher.decryptToData(fileAt: notABlob, for: purpose)
            }
        }
    }

    @Test("A file shorter than the header is rejected")
    func shortFileIsRejected() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let stub = directory.appendingPathComponent("stub.bin")
            try Data("ORPH".utf8).write(to: stub)

            #expect(throws: OrpheusError.malformedBlobHeader) {
                _ = try cipher.decryptToData(fileAt: stub, for: purpose)
            }
        }
    }

    @Test("A future format version is reported as unsupported")
    func futureVersionIsRejected() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let blob = directory.appendingPathComponent("blob.orphblob")
            try cipher.encrypt(Data("payload".utf8), to: blob, for: purpose)

            var full = try Data(contentsOf: blob)
            full.replaceSubrange(8 ..< 10, with: {
                var version = Data()
                version.appendBigEndian(UInt16(99))
                return version
            }())
            try full.write(to: blob)

            #expect(throws: OrpheusError.unsupportedBlobVersion(99)) {
                _ = try cipher.decryptToData(fileAt: blob, for: purpose)
            }
        }
    }

    @Test("A missing file is reported rather than crashing")
    func missingFileIsReported() throws {
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            #expect(throws: OrpheusError.fileNotFound) {
                _ = try cipher.decryptToData(
                    fileAt: directory.appendingPathComponent("nope.orphblob"),
                    for: purpose
                )
            }
        }
    }

    // MARK: - Failure cleanup

    @Test("A failed decrypt leaves no plaintext file behind")
    func failedDecryptLeavesNoPlaintext() throws {
        // Half-written plaintext on disk would be unencrypted user content that
        // nothing owns or cleans up, which is the leak this guards against.
        try withTemporaryDirectory { directory in
            let cipher = makeCipher()
            let blob = directory.appendingPathComponent("blob.orphblob")
            try cipher.encrypt(Data(repeating: 0x5A, count: chunkSize * 4), to: blob, for: purpose)

            let full = try Data(contentsOf: blob)
            let frameSize = 4 + ChunkedCipher.sealOverhead + chunkSize
            try full.prefix(full.count - frameSize).write(to: blob)

            let destination = directory.appendingPathComponent("leaked.bin")
            #expect(throws: (any Error).self) {
                try cipher.decrypt(fileAt: blob, to: destination, for: purpose)
            }
            #expect(FileManager.default.fileExists(atPath: destination.path) == false)
        }
    }
}
