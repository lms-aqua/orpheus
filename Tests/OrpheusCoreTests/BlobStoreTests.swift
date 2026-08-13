import CryptoKit
import Foundation
import Testing

@testable import OrpheusCore

@Suite("BlobStore")
struct BlobStoreTests {
    @Test("Stores encrypted content and loads the original payload")
    func roundTrip() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }

        let id = UUID()
        let plaintext = Data("private note body".utf8)
        let descriptor = try await fixture.store.store(
            plaintext,
            id: id,
            for: .entryPayload(id)
        )

        #expect(await fixture.store.contains(id: id))
        #expect(descriptor.plaintextByteCount == plaintext.count)
        #expect(descriptor.ciphertextByteCount > plaintext.count)
        #expect(
            try await fixture.store.load(
                id: id,
                for: .entryPayload(id),
                expectedDigest: descriptor.digest
            ) == plaintext
        )

        let raw = try Data(contentsOf: fixture.blobURL(for: id))
        #expect(raw.range(of: plaintext) == nil)
    }

    @Test("Replacing a blob publishes only the replacement")
    func replace() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }

        let id = UUID()
        _ = try await fixture.store.store(
            Data("first".utf8),
            id: id,
            for: .entryPayload(id)
        )
        let replacement = try await fixture.store.store(
            Data("second".utf8),
            id: id,
            for: .entryPayload(id)
        )

        let loaded = try await fixture.store.load(
            id: id,
            for: .entryPayload(id),
            expectedDigest: replacement.digest
        )
        #expect(String(decoding: loaded, as: UTF8.self) == "second")
    }

    @Test("A blob cannot be opened for a different entry")
    func purposeIsolation() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }

        let id = UUID()
        let descriptor = try await fixture.store.store(
            Data("secret".utf8),
            id: id,
            for: .entryPayload(id)
        )

        var rejected = false
        do {
            _ = try await fixture.store.load(
                id: id,
                for: .entryPayload(UUID()),
                expectedDigest: descriptor.digest
            )
        } catch let error as OrpheusError {
            rejected = error == .authenticationFailed
        }
        #expect(rejected)
    }

    @Test("Deleting a blob is idempotent")
    func delete() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }

        let id = UUID()
        _ = try await fixture.store.store(
            Data("delete me".utf8),
            id: id,
            for: .entryPayload(id)
        )

        try await fixture.store.delete(id: id)
        try await fixture.store.delete(id: id)
        #expect(!(await fixture.store.contains(id: id)))
    }

    private struct Fixture: Sendable {
        let root: URL
        let store: BlobStore

        init() throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("orpheus-blob-tests-\(UUID().uuidString)")
            store = BlobStore(
                rootURL: root,
                masterKey: SymmetricKey(size: .bits256)
            )
        }

        func blobURL(for id: UUID) -> URL {
            root.appendingPathComponent(id.uuidString.lowercased())
                .appendingPathExtension("orpheusblob")
        }

        func cleanup() {
            try? FileManager.default.removeItem(at: root)
        }
    }
}
