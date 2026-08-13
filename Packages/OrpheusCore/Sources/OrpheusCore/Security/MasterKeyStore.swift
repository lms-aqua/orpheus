import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// The protection actually applied to the vault master key.
///
/// ORPHEUS surfaces this value instead of claiming biometric protection on a
/// device that cannot enforce it. Both cases remain device-bound and are
/// excluded from iCloud Keychain and backups.
public enum MasterKeyProtection: String, Sendable, Equatable {
    /// Reading the key requires Face ID, Touch ID, or the device passcode.
    case userPresence

    /// No device passcode is configured, so the strongest available fallback
    /// is an unlocked-device, non-migrating Keychain item.
    case unlockedDeviceOnly

    public var requiresUserPresence: Bool {
        self == .userPresence
    }
}

/// A vault key together with the protection the Keychain can enforce for it.
public struct ProtectedMasterKey: Sendable, Equatable {
    public let key: SymmetricKey
    public let protection: MasterKeyProtection

    public init(key: SymmetricKey, protection: MasterKeyProtection) {
        self.key = key
        self.protection = protection
    }
}

/// Persistent storage boundary for the one vault master key.
///
/// The application depends on this protocol, not Keychain Services directly.
/// Tests use ``InMemoryMasterKeyStore`` and therefore never create, retrieve,
/// authenticate, or delete a real Keychain item.
public protocol MasterKeyStoring: Sendable {
    func load() async throws -> ProtectedMasterKey?
    func loadOrCreate() async throws -> ProtectedMasterKey
    func delete() async throws
}

/// Stores the vault key as a device-bound Keychain generic-password item.
///
/// When a device passcode exists, the item uses
/// `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` plus `.userPresence`.
/// Without a passcode, iOS cannot create that access control; ORPHEUS falls
/// back to `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and reports that
/// weaker state through ``ProtectedMasterKey/protection``.
public actor MasterKeyStore: MasterKeyStoring {
    public static let defaultService = "com.lostmediastudios.orpheus.vault"
    public static let defaultAccount = "master-key-v1"

    private let service: String
    private let account: String
    private let authenticationPrompt: String

    public init(
        service: String = MasterKeyStore.defaultService,
        account: String = MasterKeyStore.defaultAccount,
        authenticationPrompt: String = "Unlock ORPHEUS"
    ) {
        self.service = service
        self.account = account
        self.authenticationPrompt = authenticationPrompt
    }

    public func load() async throws -> ProtectedMasterKey? {
        var query = baseQuery
        let context = LAContext()
        context.localizedReason = authenticationPrompt
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw OrpheusError.keychainFailure(status)
        }
        guard
            let attributes = result as? [String: Any],
            let data = attributes[kSecValueData as String] as? Data,
            data.count == CryptoEngine.keyByteCount
        else {
            throw OrpheusError.invalidMasterKey
        }

        let accessibility = attributes[kSecAttrAccessible as String] as? String
        let protection: MasterKeyProtection =
            accessibility == (kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as String)
            ? .userPresence
            : .unlockedDeviceOnly

        return ProtectedMasterKey(key: SymmetricKey(data: data), protection: protection)
    }

    public func loadOrCreate() async throws -> ProtectedMasterKey {
        if let existing = try await load() {
            return existing
        }

        let key = CryptoEngine.generateMasterKey()
        let protection = try availableProtection()
        var query = baseQuery
        query[kSecValueData as String] = key.data

        if protection == .userPresence {
            var error: Unmanaged<CFError>?
            guard let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                .userPresence,
                &error
            ) else {
                throw OrpheusError.keychainAccessControlUnavailable
            }
            query[kSecAttrAccessControl as String] = accessControl
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem, let existing = try await load() {
            return existing
        }
        guard status == errSecSuccess else {
            throw OrpheusError.keychainFailure(status)
        }
        return ProtectedMasterKey(key: key, protection: protection)
    }

    public func delete() async throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw OrpheusError.keychainFailure(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
    }

    private func availableProtection() throws -> MasterKeyProtection {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            return .userPresence
        }
        if
            error?.domain == LAError.errorDomain,
            error?.code == LAError.Code.passcodeNotSet.rawValue
        {
            return .unlockedDeviceOnly
        }

        // Authentication can be temporarily unavailable for reasons other
        // than a missing passcode. Never turn lockout or a system failure into
        // a silent downgrade of the key's protection.
        throw OrpheusError.keychainAccessControlUnavailable
    }
}

/// Deterministic master-key storage for tests, previews, and dependency
/// injection. It deliberately models the same load/create/delete lifecycle as
/// the Keychain store without touching global device state.
public actor InMemoryMasterKeyStore: MasterKeyStoring {
    private var storedKey: ProtectedMasterKey?
    private let generatedProtection: MasterKeyProtection

    public init(
        key: ProtectedMasterKey? = nil,
        generatedProtection: MasterKeyProtection = .userPresence
    ) {
        storedKey = key
        self.generatedProtection = generatedProtection
    }

    public func load() async -> ProtectedMasterKey? {
        storedKey
    }

    public func loadOrCreate() async -> ProtectedMasterKey {
        if let storedKey {
            return storedKey
        }
        let created = ProtectedMasterKey(
            key: CryptoEngine.generateMasterKey(),
            protection: generatedProtection
        )
        storedKey = created
        return created
    }

    public func delete() async {
        storedKey = nil
    }
}

private extension SymmetricKey {
    var data: Data {
        withUnsafeBytes { Data($0) }
    }
}
