import Foundation

struct Family: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String

    enum CodingKeys: String, CodingKey {
        case id, name
    }
}

struct FamilyMember: Identifiable, Codable, Equatable {
    let id: UUID
    let familyID: UUID
    var displayName: String
    var role: MemberRole
    var linkedUserID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case familyID = "family_id"
        case displayName = "display_name"
        case role
        case linkedUserID = "user_id"
    }
}

enum MemberRole: String, Codable {
    case owner, member, child
}

enum FamilyItemKind: String, Codable, Hashable {
    case appointment
    case birthday
    case event
    case healthVisit = "health_visit"

    var displayName: String {
        switch self {
        case .appointment: return "Bokning"
        case .birthday: return "Födelsedag"
        case .event: return "Evenemang"
        case .healthVisit: return "Vårdbesök"
        }
    }

    var symbol: String {
        switch self {
        case .appointment: return "calendar"
        case .birthday: return "gift"
        case .event: return "sparkles"
        case .healthVisit: return "heart.text.square"
        }
    }
}

struct FamilyItem: Identifiable, Codable, Equatable {
    let id: UUID
    let familyID: UUID
    var title: String
    var details: String?
    var startsAt: Date
    var endsAt: Date?
    var kind: FamilyItemKind
    var memberID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, title, details, kind
        case familyID = "family_id"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case memberID = "member_id"
    }
}
