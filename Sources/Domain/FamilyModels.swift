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
    var symbolName: String?

    init(id: UUID, familyID: UUID, displayName: String, role: MemberRole,
         linkedUserID: UUID?, symbolName: String? = nil) {
        self.id = id
        self.familyID = familyID
        self.displayName = displayName
        self.role = role
        self.linkedUserID = linkedUserID
        self.symbolName = symbolName
    }

    var resolvedSymbolName: String {
        symbolName ?? (role == .child ? "face.smiling" : "person.crop.circle")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyID = "family_id"
        case displayName = "display_name"
        case role
        case linkedUserID = "user_id"
        case symbolName = "symbol_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        familyID = try container.decode(UUID.self, forKey: .familyID)
        displayName = try container.decode(String.self, forKey: .displayName)
        role = try container.decode(MemberRole.self, forKey: .role)
        linkedUserID = try container.decodeIfPresent(UUID.self, forKey: .linkedUserID)
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(familyID, forKey: .familyID)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(linkedUserID, forKey: .linkedUserID)
        try container.encodeIfPresent(symbolName, forKey: .symbolName)
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
    var latitude: Double?
    var longitude: Double?
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
         responsibleMemberID: UUID? = nil, location: String? = nil, latitude: Double? = nil, longitude: Double? = nil, recurrenceFrequency: FamilyRecurrenceFrequency? = nil) {
        self.id = id
        self.familyID = familyID
        self.title = title
        self.details = details
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
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
        case location, latitude, longitude
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
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
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
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
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


struct FamilyOccurrenceException: Codable, Equatable, Identifiable {
    var id: String { "\(seriesID.uuidString)-\(Int(occurrenceDate.timeIntervalSince1970))" }
    let seriesID: UUID
    let occurrenceDate: Date
}

enum FamilyConversationKind: String, Codable {
    case family
    case direct
}

struct FamilyMessageAttachment: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case image
    }

    let id: UUID
    var kind: Kind
    var filename: String
    var contentType: String
    var byteCount: Int
    /// Relative to the app's private Application Support directory.
    /// Never store an absolute sandbox URL in a synced message record.
    var relativePath: String
    var createdAt: Date

    var isValid: Bool {
        let allowedTypes = ["public.jpeg", "public.png", "public.heic", "public.heif"]
        let path = relativePath
        return !filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && allowedTypes.contains(contentType)
            && byteCount > 0
            && byteCount <= 10 * 1_024 * 1_024
            && path.hasPrefix("MessageAttachments/")
            && !path.contains("..")
            && !path.hasPrefix("/")
    }
}

struct FamilyMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var conversationID: String
    var kind: FamilyConversationKind
    var senderID: UUID
    var text: String
    var sentAt: Date
    var readAt: Date?
    var attachments: [FamilyMessageAttachment]? = nil

    enum CodingKeys: String, CodingKey {
        case id, text, attachments
        case conversationID = "conversation_id"
        case kind
        case senderID = "sender_id"
        case sentAt = "sent_at"
        case readAt = "read_at"
    }
}


/// A complete replacement for one generated occurrence. The key uses the
/// original scheduled date, so moving the occurrence does not lose its identity.
struct FamilyOccurrenceOverride: Codable, Equatable, Identifiable {
    let seriesID: UUID
    let occurrenceDate: Date
    var item: FamilyItem

    var id: String {
        "\(seriesID.uuidString)-\(Int(occurrenceDate.timeIntervalSince1970))"
    }
}
