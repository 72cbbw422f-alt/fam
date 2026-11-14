import Foundation

struct ShoppingList: Identifiable, Decodable {
    let id: UUID
    let title: String
}

struct ShoppingItem: Identifiable, Decodable, Equatable {
    let id: UUID
    let listID: UUID
    var title: String
    var isChecked: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title
        case listID = "list_id"
        case isChecked = "is_checked"
        case createdAt = "created_at"
    }
}
