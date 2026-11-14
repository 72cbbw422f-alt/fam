import Foundation

struct Family: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
}

struct FamilyMember: Identifiable, Codable, Equatable {
    let id: UUID
    let familyID: UUID
    var displayName: String
    var role: MemberRole
    var linkedUserID: UUID?
}

enum MemberRole: String, Codable {
    case owner, member, child
}

enum FamilyItemKind: String, Codable {
    case appointment, birthday, event, healthVisit
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
}
