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
    case shopping

    static var calendarKinds: [FamilyItemKind] { allCases.filter { $0 != .shopping } }

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
        case .shopping: return "Inköp"
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
        case .shopping: return "cart.fill"
        }
    }
}

enum FamilyRecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case none, weekly, monthly, yearly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "Upprepa inte"
        case .weekly: return "Varje vecka"
        case .monthly: return "Varje månad"
        case .yearly: return "Varje år"
        }
    }
}

struct FamilyItem: Identifiable, Codable, Equatable {
    let id: UUID
    let familyID: UUID
    var title: String
    var details: String?
    var location: String?
    var startsAt: Date
    var endsAt: Date?
    var kind: FamilyItemKind

    /// Multiple people may be affected by one calendar item.
    /// An empty array means no person has been assigned.
    var memberIDs: [UUID]
    /// Explicit family-wide scope; deliberately distinct from no assignment.
    var isForEveryone: Bool
    /// Optional adult responsible for coordinating the event.
    var responsibleMemberID: UUID?
    var isRecurringYearly: Bool
    var recurrenceFrequency: FamilyRecurrenceFrequency
    var reminderOffsets: [Int]?

    /// Compatibility accessor for older call sites and legacy snapshots.
    /// Setting this property replaces the full participant selection with one person.
    var memberID: UUID? {
        get { memberIDs.first }
        set { memberIDs = newValue.map { [$0] } ?? [] }
    }

    init(id: UUID, familyID: UUID, title: String, details: String?, startsAt: Date,
         endsAt: Date?, kind: FamilyItemKind, memberID: UUID?,
         isRecurringYearly: Bool, reminderOffsets: [Int]?,
         memberIDs: [UUID]? = nil, isForEveryone: Bool = false,
         responsibleMemberID: UUID? = nil, location: String? = nil, recurrenceFrequency: FamilyRecurrenceFrequency? = nil) {
        self.id = id
        self.familyID = familyID
        self.title = title
        self.details = details
        self.location = location
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.kind = kind
        self.memberIDs = memberIDs ?? memberID.map { [$0] } ?? []
        self.isForEveryone = isForEveryone
        self.responsibleMemberID = responsibleMemberID
        self.recurrenceFrequency = recurrenceFrequency ?? (isRecurringYearly ? .yearly : .none)
        self.isRecurringYearly = self.recurrenceFrequency == .yearly
        self.reminderOffsets = reminderOffsets
    }

    enum CodingKeys: String, CodingKey {
        case id, title, details, kind
        case location
        case familyID = "family_id"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case memberID = "member_id"
        case memberIDs = "member_ids"
        case isForEveryone = "is_for_everyone"
        case responsibleMemberID = "responsible_member_id"
        case isRecurringYearly = "is_recurring_yearly"
        case recurrenceFrequency = "recurrence_frequency"
        case reminderOffsets = "reminder_offsets"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        familyID = try container.decode(UUID.self, forKey: .familyID)
        title = try container.decode(String.self, forKey: .title)
        details = try container.decodeIfPresent(String.self, forKey: .details)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        startsAt = try container.decode(Date.self, forKey: .startsAt)
        endsAt = try container.decodeIfPresent(Date.self, forKey: .endsAt)
        kind = try container.decode(FamilyItemKind.self, forKey: .kind)
        if container.contains(.memberIDs) {
            memberIDs = try container.decode([UUID].self, forKey: .memberIDs)
        } else {
            memberIDs = try container.decodeIfPresent(UUID.self, forKey: .memberID).map { [$0] } ?? []
        }
        isForEveryone = try container.decodeIfPresent(Bool.self, forKey: .isForEveryone) ?? false
        responsibleMemberID = try container.decodeIfPresent(UUID.self, forKey: .responsibleMemberID)
        isRecurringYearly = try container.decodeIfPresent(Bool.self, forKey: .isRecurringYearly) ?? false
        recurrenceFrequency = try container.decodeIfPresent(FamilyRecurrenceFrequency.self, forKey: .recurrenceFrequency) ?? (isRecurringYearly ? .yearly : .none)
        isRecurringYearly = recurrenceFrequency == .yearly
        reminderOffsets = try container.decodeIfPresent([Int].self, forKey: .reminderOffsets)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(familyID, forKey: .familyID)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(details, forKey: .details)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(startsAt, forKey: .startsAt)
        try container.encodeIfPresent(endsAt, forKey: .endsAt)
        try container.encode(kind, forKey: .kind)
        try container.encode(memberIDs, forKey: .memberIDs)
        // Retain the legacy key for downgrade/read compatibility.
        try container.encodeIfPresent(memberIDs.first, forKey: .memberID)
        try container.encode(isForEveryone, forKey: .isForEveryone)
        try container.encodeIfPresent(responsibleMemberID, forKey: .responsibleMemberID)
        try container.encode(isRecurringYearly, forKey: .isRecurringYearly)
        try container.encode(recurrenceFrequency, forKey: .recurrenceFrequency)
        try container.encodeIfPresent(reminderOffsets, forKey: .reminderOffsets)
    }
}


enum FamilyConversationKind: String, Codable {
    case family
    case direct
}

struct FamilyMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var conversationID: String
    var kind: FamilyConversationKind
    var senderID: UUID
    var text: String
    var sentAt: Date
    var readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, text
        case conversationID = "conversation_id"
        case kind
        case senderID = "sender_id"
        case sentAt = "sent_at"
        case readAt = "read_at"
    }
}
