import Foundation

struct ShoppingList: Identifiable, Codable {
    let id: UUID
    let title: String
}

enum ShoppingCategory: String, Codable, CaseIterable, Identifiable {
    case fruitVegetables, dairy, meatFish, pantry, frozen, household, other

    var id: String { rawValue }
    var title: String {
        switch self {
        case .fruitVegetables: return "Frukt & grönt"
        case .dairy: return "Mejeri"
        case .meatFish: return "Kött & fisk"
        case .pantry: return "Skafferi"
        case .frozen: return "Frys"
        case .household: return "Hushåll"
        case .other: return "Övrigt"
        }
    }
    var symbol: String {
        switch self {
        case .fruitVegetables: return "carrot"
        case .dairy: return "drop"
        case .meatFish: return "fish"
        case .pantry: return "basket"
        case .frozen: return "snowflake"
        case .household: return "sparkles"
        case .other: return "square.grid.2x2"
        }
    }
}

struct ShoppingItem: Identifiable, Codable, Equatable {
    let id: UUID
    let listID: UUID
    var title: String
    var isChecked: Bool
    let createdAt: Date
    var category: ShoppingCategory? = nil
    enum CodingKeys: String, CodingKey { case id, title, category; case listID = "list_id"; case isChecked = "is_checked"; case createdAt = "created_at" }
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


enum ChristmasGiftStatus: String, Codable, CaseIterable, Identifiable {
    case idea, planned, purchased
    var id: String { rawValue }
    var title: String {
        switch self {
        case .idea: return "Idé"
        case .planned: return "Planerad"
        case .purchased: return "Inköpt"
        }
    }
}

struct ChristmasGift: Identifiable, Codable, Equatable {
    let id: UUID
    var recipient: String
    var title: String
    var note: String?
    var responsibleMemberID: UUID?
    var status: ChristmasGiftStatus
    let createdAt: Date

    init(id: UUID = UUID(), recipient: String, title: String, note: String? = nil,
         responsibleMemberID: UUID? = nil, status: ChristmasGiftStatus = .idea, createdAt: Date = .now) {
        self.id = id
        self.recipient = recipient
        self.title = title
        self.note = note
        self.responsibleMemberID = responsibleMemberID
        self.status = status
        self.createdAt = createdAt
    }
}
