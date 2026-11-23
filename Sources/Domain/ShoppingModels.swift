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


struct ShoppingItemSuggestion: Identifiable, Equatable {
    let title: String
    let category: ShoppingCategory

    var id: String { title.lowercased() }

    static let catalog: [ShoppingItemSuggestion] = [
        .init(title: "Äpplen", category: .fruitVegetables),
        .init(title: "Bananer", category: .fruitVegetables),
        .init(title: "Apelsiner", category: .fruitVegetables),
        .init(title: "Avokado", category: .fruitVegetables),
        .init(title: "Gurka", category: .fruitVegetables),
        .init(title: "Tomater", category: .fruitVegetables),
        .init(title: "Potatis", category: .fruitVegetables),
        .init(title: "Morötter", category: .fruitVegetables),
        .init(title: "Paprika", category: .fruitVegetables),
        .init(title: "Sallad", category: .fruitVegetables),
        .init(title: "Mjölk", category: .dairy),
        .init(title: "Mellanmjölk", category: .dairy),
        .init(title: "Lättmjölk", category: .dairy),
        .init(title: "Yoghurt", category: .dairy),
        .init(title: "Fil", category: .dairy),
        .init(title: "Smör", category: .dairy),
        .init(title: "Ost", category: .dairy),
        .init(title: "Grädde", category: .dairy),
        .init(title: "Crème fraiche", category: .dairy),
        .init(title: "Ägg", category: .dairy),
        .init(title: "Köttfärs", category: .meatFish),
        .init(title: "Kyckling", category: .meatFish),
        .init(title: "Bacon", category: .meatFish),
        .init(title: "Lax", category: .meatFish),
        .init(title: "Falukorv", category: .meatFish),
        .init(title: "Korv", category: .meatFish),
        .init(title: "Fiskpinnar", category: .frozen),
        .init(title: "Glass", category: .frozen),
        .init(title: "Frysta grönsaker", category: .frozen),
        .init(title: "Bröd", category: .pantry),
        .init(title: "Knäckebröd", category: .pantry),
        .init(title: "Pasta", category: .pantry),
        .init(title: "Ris", category: .pantry),
        .init(title: "Mjöl", category: .pantry),
        .init(title: "Socker", category: .pantry),
        .init(title: "Kaffe", category: .pantry),
        .init(title: "Te", category: .pantry),
        .init(title: "Krossade tomater", category: .pantry),
        .init(title: "Havregryn", category: .pantry),
        .init(title: "Toalettpapper", category: .household),
        .init(title: "Hushållspapper", category: .household),
        .init(title: "Diskmedel", category: .household),
        .init(title: "Tvättmedel", category: .household),
        .init(title: "Diskmaskinstabletter", category: .household),
        .init(title: "Tandkräm", category: .household),
        .init(title: "Schampo", category: .household),
        .init(title: "Soppåsar", category: .household)
    ]

    static func matching(_ query: String, excluding existingTitles: [String] = []) -> [ShoppingItemSuggestion] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 2 else { return [] }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let existing = Set(existingTitles.map { $0.folding(options: options, locale: Locale(identifier: "sv_SE")) })
        return catalog
            .filter { suggestion in
                let candidate = suggestion.title.folding(options: options, locale: Locale(identifier: "sv_SE"))
                return !existing.contains(candidate) && candidate.localizedStandardContains(cleaned.folding(options: options, locale: Locale(identifier: "sv_SE")))
            }
            .sorted { lhs, rhs in
                let query = cleaned.folding(options: options, locale: Locale(identifier: "sv_SE"))
                let left = lhs.title.folding(options: options, locale: Locale(identifier: "sv_SE"))
                let right = rhs.title.folding(options: options, locale: Locale(identifier: "sv_SE"))
                let leftPrefix = left.hasPrefix(query)
                let rightPrefix = right.hasPrefix(query)
                if leftPrefix != rightPrefix { return leftPrefix }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            .prefix(6)
            .map { $0 }
    }
}
