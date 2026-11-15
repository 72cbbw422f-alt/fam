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

enum FamilyItemKind: String, Codable, Hashable, CaseIterable {
    case appointment
    case birthday
    case event
    case healthVisit = "health_visit"
    case dentist
    case medication
    case school
    case activity
    case trip
    case celebration
    case family
    case work

    var displayName: String {
        switch self {
        case .appointment: return "Bokning"
        case .birthday: return "Födelsedag"
        case .event: return "Evenemang"
        case .healthVisit: return "Läkarbesök"
        case .dentist: return "Tandläkare"
        case .medication: return "Medicin"
        case .school: return "Skola"
        case .activity: return "Träning och aktivitet"
        case .trip: return "Resa och utflykt"
        case .celebration: return "Fest och firande"
        case .family: return "Familjehändelse"
        case .work: return "Arbete"
        }
    }

    var symbol: String {
        switch self {
        case .appointment: return "calendar"
        case .birthday: return "gift.fill"
        case .event: return "sparkles"
        case .healthVisit: return "stethoscope"
        case .dentist: return "mouth"
        case .medication: return "pills.fill"
        case .school: return "building.2.fill"
        case .activity: return "dumbbell.fill"
        case .trip: return "car.fill"
        case .celebration: return "party.popper.fill"
        case .family: return "house.fill"
        case .work: return "briefcase.fill"
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
    var isRecurringYearly: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, details, kind
        case familyID = "family_id"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case memberID = "member_id"
        case isRecurringYearly = "is_recurring_yearly"
    }
}
