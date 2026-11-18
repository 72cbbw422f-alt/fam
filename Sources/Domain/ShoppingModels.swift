import Foundation

struct ShoppingList: Identifiable, Codable {
    let id: UUID
    let title: String
}

struct ShoppingItem: Identifiable, Codable, Equatable {
    let id: UUID
    let listID: UUID
    var title: String
    var isChecked: Bool
    let createdAt: Date
    enum CodingKeys: String, CodingKey { case id, title; case listID = "list_id"; case isChecked = "is_checked"; case createdAt = "created_at" }
}


struct GiftIdea: Identifiable, Codable, Equatable {
    let id: UUID
    let memberID: UUID
    let birthdayItemID: UUID
    var title: String
    var note: String?
    var isOrdered: Bool
    let createdAt: Date

    init(id: UUID = UUID(), memberID: UUID, birthdayItemID: UUID,
         title: String, note: String? = nil, isOrdered: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.memberID = memberID
        self.birthdayItemID = birthdayItemID
        self.title = title
        self.note = note
        self.isOrdered = isOrdered
        self.createdAt = createdAt
    }
}
