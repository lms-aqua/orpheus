import CryptoKit
import Foundation
import Testing

@testable import OrpheusCore

@Suite("MasterKeyStoring")
struct MasterKeyStoreTests {

    @Test("An empty store creates one stable 256-bit key")
    func createsStableKey() async throws {
        let store = InMemoryMasterKeyStore()

        #expect(await store.load() == nil)
        let first = await store.loadOrCreate()
        let second = await store.loadOrCreate()

        #expect(first == second)
        #expect(first.key.bitCount == 256)
        #expect(first.protection == .userPresence)
    }

    @Test("An injected key is returned unchanged")
    func returnsInjectedKey() async {
        let expected = ProtectedMasterKey(
            key: SymmetricKey(data: Data(repeating: 0xA5, count: 32)),
            protection: .unlockedDeviceOnly
        )
        let store = InMemoryMasterKeyStore(key: expected)

        #expect(await store.load() == expected)
        #expect(await store.loadOrCreate() == expected)
    }

    @Test("Deleting removes the key and a later create rotates it")
    func deleteAndRotate() async {
        let store = InMemoryMasterKeyStore()
        let original = await store.loadOrCreate()

        await store.delete()
        #expect(await store.load() == nil)

        let replacement = await store.loadOrCreate()
        #expect(replacement != original)
    }

    @Test("The fallback protection state is reported honestly")
    func reportsFallbackProtection() async {
        let store = InMemoryMasterKeyStore(
            generatedProtection: .unlockedDeviceOnly
        )

        let stored = await store.loadOrCreate()
        #expect(stored.protection == .unlockedDeviceOnly)
        #expect(!stored.protection.requiresUserPresence)
    }
}
