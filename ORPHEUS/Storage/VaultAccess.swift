import Foundation
import OrpheusCore

/// Constructs short-lived cryptographic storage sessions after Keychain unlock.
enum VaultAccess {
    static func blobStore() async throws -> BlobStore {
        let protectedKey = try await MasterKeyStore().loadOrCreate()
        return BlobStore(rootURL: blobDirectory, masterKey: protectedKey.key)
    }

    private static var blobDirectory: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return applicationSupport
            .appendingPathComponent("ORPHEUS", isDirectory: true)
            .appendingPathComponent("Blobs", isDirectory: true)
    }
}
