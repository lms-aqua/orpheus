import CryptoKit
import Foundation
import Testing

@testable import OrpheusCore

@Suite("CryptoEngine")
struct CryptoEngineTests {

    private let purposeA = KeyPurpose.entryPayload(
        UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    )
    private let purposeB = KeyPurpose.entryPayload(
        UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    )

    @Test("Round-trips data unchanged")
    func roundTrip() throws {
        let engine = CryptoEngine(masterKey: CryptoEngine.generateMasterKey())
        let plaintext = Data("A private note about nothing in particular.".utf8)

        let sealed = try engine.seal(plaintext, for: purposeA)
        #expect(sealed != plaintext)

        let opened = try engine.open(sealed, for: purposeA)
        #expect(opened == plaintext)
    }

    @Test("Ciphertext does not contain the plaintext")
    func ciphertextDoesNotLeakPlaintext() throws {
        let engine = CryptoEngine(masterKey: CryptoEngine.generateMasterKey())
        let marker = Data("SENTINEL-VALUE-DO-NOT-LEAK".utf8)

        let sealed = try engine.seal(marker, for: purposeA)
        #expect(sealed.range(of: marker) == nil)
    }

    @Test("Encrypting the same plaintext twice yields different ciphertext")
    func nonDeterministicCiphertext() throws {
        // Random nonces mean identical notes must not produce identical blobs;
        // otherwise an observer could tell that two entries match.
        let engine = CryptoEngine(masterKey: CryptoEngine.generateMasterKey())
        let plaintext = Data("same input".utf8)

        let first = try engine.seal(plaintext, for: purposeA)
        let second = try engine.seal(plaintext, for: purposeA)

        #expect(first != second)
        #expect(try engine.open(first, for: purposeA) == plaintext)
        #expect(try engine.open(second, for: purposeA) == plaintext)
    }

    @Test("Key derivation is deterministic for the same purpose")
    func derivationIsDeterministic() {
        // Content saved today must still open after a relaunch, which requires
        // derivation to be stable rather than random.
        let master = CryptoEngine.generateMasterKey()
        let engine = CryptoEngine(masterKey: master)

        let first = engine.derivedKey(for: purposeA)
        let second = engine.derivedKey(for: purposeA)

        #expect(first == second)
    }

    @Test("Different purposes derive different keys")
    func purposesAreSeparated() {
        let engine = CryptoEngine(masterKey: CryptoEngine.generateMasterKey())

        let entry = engine.derivedKey(for: purposeA)
        let otherEntry = engine.derivedKey(for: purposeB)
        let attachment = engine.derivedKey(for: .attachment(UUID()))
        let archive = engine.derivedKey(for: .archiveManifest)

        #expect(entry != otherEntry)
        #expect(entry != attachment)
        #expect(entry != archive)
    }

    @Test("Derived keys are 256-bit")
    func derivedKeySize() {
        let engine = CryptoEngine(masterKey: CryptoEngine.generateMasterKey())
        #expect(engine.derivedKey(for: purposeA).bitCount == 256)
    }

    @Test("Content sealed for one entry cannot be opened as another")
    func crossEntryDecryptionFails() throws {
        // This is the confused-deputy case: swapping blobs on disk must not
        // make one entry render another's contents.
        let engine = CryptoEngine(masterKey: CryptoEngine.generateMasterKey())
        let sealed = try engine.seal(Data("belongs to A".utf8), for: purposeA)

        #expect(throws: OrpheusError.authenticationFailed) {
            _ = try engine.open(sealed, for: purposeB)
        }
    }

    @Test("A different master key cannot open the data")
    func wrongMasterKeyFails() throws {
        let sealed = try CryptoEngine(masterKey: CryptoEngine.generateMasterKey())
            .seal(Data("private".utf8), for: purposeA)

        let attacker = CryptoEngine(masterKey: CryptoEngine.generateMasterKey())
        #expect(throws: OrpheusError.authenticationFailed) {
            _ = try attacker.open(sealed, for: purposeA)
        }
    }

    @Test("Flipping any single byte of ciphertext is detected")
    func tamperingIsDetected() throws {
        let engine = CryptoEngine(masterKey: CryptoEngine.generateMasterKey())
        let sealed = try engine.seal(Data("integrity matters".utf8), for: purposeA)

        // Every byte is covered by the tag: nonce, ciphertext, and tag alike.
        for offset in sealed.indices {
            var tampered = sealed
            tampered[offset] ^= 0x01
            #expect(throws: OrpheusError.authenticationFailed) {
                _ = try engine.open(tampered, for: purposeA)
            }
        }
    }

    @Test("Associated data is enforced")
    func associatedDataMismatchFails() throws {
        let engine = CryptoEngine(masterKey: CryptoEngine.generateMasterKey())
        let sealed = try engine.seal(
            Data("bound to context".utf8),
            for: purposeA,
            authenticating: Data("chunk-0".utf8)
        )

        #expect(throws: OrpheusError.authenticationFailed) {
            _ = try engine.open(sealed, for: purposeA, authenticating: Data("chunk-1".utf8))
        }
        #expect(throws: OrpheusError.authenticationFailed) {
            _ = try engine.open(sealed, for: purposeA)
        }
    }

    @Test("Empty and large payloads both round-trip")
    func edgeSizedPayloads() throws {
        let engine = CryptoEngine(masterKey: CryptoEngine.generateMasterKey())

        for size in [0, 1, 15, 16, 17, 4096, 1_000_000] {
            let plaintext = Data(repeating: 0xAB, count: size)
            let sealed = try engine.seal(plaintext, for: purposeA)
            #expect(try engine.open(sealed, for: purposeA) == plaintext, "size \(size)")
        }
    }

    @Test("Garbage input is rejected rather than crashing")
    func garbageInputThrows() {
        let engine = CryptoEngine(masterKey: CryptoEngine.generateMasterKey())

        for bytes in [Data(), Data([0x00]), Data(repeating: 0xFF, count: 27), Data(repeating: 0x11, count: 512)] {
            #expect(throws: OrpheusError.authenticationFailed) {
                _ = try engine.open(bytes, for: purposeA)
            }
        }
    }
}
