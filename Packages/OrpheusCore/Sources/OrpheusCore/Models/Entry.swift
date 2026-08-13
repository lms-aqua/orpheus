import Foundation
import SwiftData

/// Queryable metadata for an encrypted entry body.
///
/// The body itself never enters SwiftData; it is stored by ``BlobStore`` under
/// the same identifier and authenticated with ``KeyPurpose/entryPayload(_:)``.
@Model
public final class Entry {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isFavorite: Bool
    public var isPinned: Bool
    public var spaceID: UUID?
    public var blobDigest: String
    public var plaintextByteCount: Int
    public var ciphertextByteCount: Int

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isFavorite: Bool = false,
        isPinned: Bool = false,
        spaceID: UUID? = nil,
        blobDigest: String,
        plaintextByteCount: Int,
        ciphertextByteCount: Int
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isFavorite = isFavorite
        self.isPinned = isPinned
        self.spaceID = spaceID
        self.blobDigest = blobDigest
        self.plaintextByteCount = plaintextByteCount
        self.ciphertextByteCount = ciphertextByteCount
    }
}
