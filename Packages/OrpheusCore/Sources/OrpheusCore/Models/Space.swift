import Foundation
import SwiftData

/// A user-defined organizational container.
@Model
public final class Space {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var createdAt: Date
    public var sortOrder: Int
    public var isArchived: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        sortOrder: Int = 0,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }
}
