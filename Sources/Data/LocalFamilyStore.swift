import Combine
import Foundation

@MainActor
final class LocalFamilyStore: ObservableObject, FamilyRepository {
    static let shared = LocalFamilyStore()

    @Published private(set) var family: Family?
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var items: [FamilyItem] = []
    @Published private(set) var skippedOccurrences: [FamilyOccurrenceException] = []
    @Published private(set) var occurrenceOverrides: [FamilyOccurrenceOverride] = []
    @Published private(set) var shoppingItems: [ShoppingItem] = []
    @Published private(set) var giftIdeas: [GiftIdea] = []
    @Published private(set) var christmasGifts: [ChristmasGift] = []
    @Published private(set) var notifications: [FamilyNotification] = []
    @Published private(set) var healthRecords: [HealthRecord] = []
    @Published private(set) var healthPrescriptions: [HealthPrescription] = []
    @Published private(set) var medicationPickups: [MedicationPickup] = []
    @Published private(set) var healthProfileInformation: [HealthProfileInformation] = []
    @Published private(set) var healthReminders: [HealthReminder] = []
    @Published private(set) var messages: [FamilyMessage] = []
    @Published private(set) var persistenceError: String?

    private let persistenceFailureMessage = "Ändringen kunde inte sparas. Den kan försvinna om appen stängs."

    var changePublisher: AnyPublisher<Void, Never> {
        objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }

    private let fileURL: URL
    private var persistenceBlockedByCorruption = false

    private convenience init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.init(fileURL: directory.appendingPathComponent("familjen-local-data.json"))
    }

    /// Injectable file location keeps persistence tests isolated from the user's real app data.
    init(fileURL: URL) {
        self.fileURL = fileURL
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            persistenceError = persistenceFailureMessage
        }
        loadFromDisk()
    }

    func createFamily(name: String, ownerName: String) {
        let cleanFamilyName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanOwnerName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard family == nil,
              !cleanFamilyName.isEmpty, cleanFamilyName.count <= 80,
              !cleanOwnerName.isEmpty, cleanOwnerName.count <= 80 else { return }
        let family = Family(id: UUID(), name: cleanFamilyName)
        let owner = FamilyMember(id: UUID(), familyID: family.id,
                                 displayName: cleanOwnerName,
                                 role: .owner, linkedUserID: nil)
        self.family = family
        members = [owner]
        items = []
        skippedOccurrences = []
        occurrenceOverrides = []
        shoppingItems = []
        giftIdeas = []
        christmasGifts = []
        notifications = []
        healthRecords = []
        healthPrescriptions = []
        medicationPickups = []
        healthProfileInformation = []
        healthReminders = []
        messages = []
        saveToDisk()
    }

    func renameFamily(name: String) {
        guard let family else { return }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 80 else { return }
        self.family = Family(id: family.id, name: clean)
        saveToDisk()
    }

    func addChild(name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let family, !clean.isEmpty, clean.count <= 80 else { return }
        members.append(FamilyMember(id: UUID(), familyID: family.id,
                                    displayName: clean,
                                    role: .child, linkedUserID: nil))
        saveToDisk()
    }

    func addMember(name: String, role: MemberRole = .member) {
        guard let family else { return }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 80, role != .owner else { return }
        members.append(FamilyMember(id: UUID(), familyID: family.id,
                                    displayName: clean, role: role, linkedUserID: nil))
        saveToDisk()
    }

    func renameMember(id: UUID, name: String) {
        guard let index = members.firstIndex(where: { $0.id == id && $0.role != .owner }) else { return }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 80 else { return }
        let previous = members[index]
        members[index].displayName = clean
        if !saveToDisk() { members[index] = previous }
    }

    func updateMemberSymbol(id: UUID, symbolName: String?) {
        guard let index = members.firstIndex(where: { $0.id == id }) else { return }
        let previous = members[index]
        members[index].symbolName = symbolName
        if !saveToDisk() { members[index] = previous }
    }

    func deleteMember(id: UUID) {
        guard members.contains(where: { $0.id == id && $0.role != .owner }) else { return }
        let previousMembers = members
        let previousItems = items
        members.removeAll { $0.id == id }
        // Keep calendar history when a profile is removed; only clear its assignment.
        for index in items.indices {
            items[index].memberIDs.removeAll { $0 == id }
            if items[index].responsibleMemberID == id {
                items[index].responsibleMemberID = nil
            }
        }
        if !saveToDisk() {
            members = previousMembers
            items = previousItems
        }
    }

    func renameChild(id: UUID, name: String) { renameMember(id: id, name: name) }
    func deleteChild(id: UUID) { deleteMember(id: id) }

    func saveItem(id: UUID?, title: String, details: String?, startsAt: Date,
                  kind: FamilyItemKind, memberID: UUID?, recurring: Bool, reminderOffsets: [Int]) {
        saveCalendarItem(id: id, title: title, details: details, startsAt: startsAt,
                         kind: kind, memberIDs: memberID.map { [$0] } ?? [],
                         isForEveryone: false, responsibleMemberID: nil,
                         recurring: recurring, reminderOffsets: reminderOffsets, location: nil,
                         recurrenceFrequency: recurring ? .yearly : .none)
    }

    func saveCalendarItem(id: UUID?, title: String, details: String?, startsAt: Date,
                          kind: FamilyItemKind, memberIDs: [UUID], isForEveryone: Bool,
                          responsibleMemberID: UUID?, recurring: Bool, reminderOffsets: [Int],
                          location: String? = nil, recurrenceFrequency: FamilyRecurrenceFrequency = .none) {
        guard let family else { return }
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        var seenMemberIDs = Set<UUID>()
        let validMemberIDs = memberIDs.filter { memberID in
            members.contains(where: { $0.id == memberID }) && seenMemberIDs.insert(memberID).inserted
        }
        let validResponsibleID = members.first(where: {
            $0.id == responsibleMemberID && $0.role != .child
        })?.id

        let previousItems = items
        let previousSkippedOccurrences = skippedOccurrences
        let previousOccurrenceOverrides = occurrenceOverrides
        if let id, let index = items.firstIndex(where: { $0.id == id }) {
            let previousSeriesStart = items[index].startsAt
            let previousFrequency = items[index].recurrenceFrequency
            items[index].title = clean
            items[index].details = details
            items[index].location = location
            items[index].startsAt = startsAt
            items[index].kind = kind
            items[index].memberIDs = isForEveryone ? [] : validMemberIDs
            items[index].isForEveryone = isForEveryone
            items[index].responsibleMemberID = validResponsibleID
            items[index].recurrenceFrequency = recurrenceFrequency == .none && recurring ? .yearly : recurrenceFrequency
            items[index].isRecurringYearly = items[index].recurrenceFrequency == .yearly
            items[index].reminderOffsets = reminderOffsets
            if previousSeriesStart != startsAt || previousFrequency != items[index].recurrenceFrequency {
                skippedOccurrences.removeAll { $0.seriesID == id }
                occurrenceOverrides.removeAll { $0.seriesID == id }
            }
        } else {
            items.append(FamilyItem(id: UUID(), familyID: family.id, title: clean,
                                    details: details, startsAt: startsAt, endsAt: nil,
                                    kind: kind, memberID: nil,
                                    isRecurringYearly: recurrenceFrequency == .yearly || (recurrenceFrequency == .none && recurring),
                                    reminderOffsets: reminderOffsets,

                                    memberIDs: isForEveryone ? [] : validMemberIDs,
                                    isForEveryone: isForEveryone,
                                    responsibleMemberID: validResponsibleID,
                                    location: location,
                                    recurrenceFrequency: recurrenceFrequency == .none && recurring ? .yearly : recurrenceFrequency))
        }
        if !saveToDisk() {
            items = previousItems
            skippedOccurrences = previousSkippedOccurrences
            occurrenceOverrides = previousOccurrenceOverrides
        }
    }

    func deleteItem(_ item: FamilyItem) {
        let previousItems = items
        let previousSkippedOccurrences = skippedOccurrences
        let previousOccurrenceOverrides = occurrenceOverrides
        items.removeAll { $0.id == item.id }
        skippedOccurrences.removeAll { $0.seriesID == item.id }
        occurrenceOverrides.removeAll { $0.seriesID == item.id }
        if !saveToDisk() {
            items = previousItems
            skippedOccurrences = previousSkippedOccurrences
            occurrenceOverrides = previousOccurrenceOverrides
        }
    }

    func saveOccurrenceOverride(seriesID: UUID, occurrenceDate: Date, item: FamilyItem) {
        guard items.contains(where: { $0.id == seriesID }) else { return }
        let previousOverrides = occurrenceOverrides
        let previousSkippedOccurrences = skippedOccurrences
        let calendar = Calendar.current

        // Editing a skipped occurrence explicitly restores it. A skip and an
        // override for the same original date must never coexist.
        skippedOccurrences.removeAll {
            $0.seriesID == seriesID && calendar.isDate($0.occurrenceDate, inSameDayAs: occurrenceDate)
        }
        occurrenceOverrides.removeAll {
            $0.seriesID == seriesID && calendar.isDate($0.occurrenceDate, inSameDayAs: occurrenceDate)
        }
        occurrenceOverrides.append(FamilyOccurrenceOverride(
            seriesID: seriesID, occurrenceDate: occurrenceDate, item: item
        ))

        if !saveToDisk() {
            occurrenceOverrides = previousOverrides
            skippedOccurrences = previousSkippedOccurrences
        }
    }

    func skipOccurrence(of item: FamilyItem) {
        guard let series = items.first(where: { $0.id == item.id }),
              series.recurrenceFrequency != .none || series.isRecurringYearly else {
            deleteItem(item)
            return
        }
        guard !skippedOccurrences.contains(where: {
            $0.seriesID == item.id && Calendar.current.isDate($0.occurrenceDate, inSameDayAs: item.startsAt)
        }) else { return }
        let previous = skippedOccurrences
        skippedOccurrences.append(FamilyOccurrenceException(seriesID: item.id, occurrenceDate: item.startsAt))
        if !saveToDisk() { skippedOccurrences = previous }
    }

    func addShoppingItem(_ title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let family, !clean.isEmpty, clean.count <= 160 else { return }
        shoppingItems.append(ShoppingItem(id: UUID(), listID: family.id,
                                          title: clean,
                                          isChecked: false, createdAt: .now))
        saveToDisk()
    }

    func setShoppingItem(_ id: UUID, checked: Bool) {
        guard let index = shoppingItems.firstIndex(where: { $0.id == id }) else { return }
        shoppingItems[index].isChecked = checked
        saveToDisk()
    }

    func deleteShoppingItem(_ id: UUID) {
        shoppingItems.removeAll { $0.id == id }
        saveToDisk()
    }

    func addGiftIdea(memberID: UUID, birthdayItemID: UUID, title: String, note: String?) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard members.contains(where: { $0.id == memberID }),
              items.contains(where: { $0.id == birthdayItemID && $0.kind == .birthday }),
              !clean.isEmpty, clean.count <= 160 else { return }
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        giftIdeas.append(GiftIdea(memberID: memberID, birthdayItemID: birthdayItemID,
                                  title: clean, note: cleanNote?.isEmpty == true ? nil : cleanNote))
        saveToDisk()
    }

    func updateGiftIdea(_ idea: GiftIdea) {
        guard let index = giftIdeas.firstIndex(where: { $0.id == idea.id }),
              members.contains(where: { $0.id == idea.memberID }),
              items.contains(where: { $0.id == idea.birthdayItemID && $0.kind == .birthday }) else { return }
        let clean = idea.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 160 else { return }
        let previous = giftIdeas[index]
        var updated = idea
        updated.title = clean
        let cleanNote = idea.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = cleanNote?.isEmpty == true ? nil : cleanNote
        giftIdeas[index] = updated
        if !saveToDisk() { giftIdeas[index] = previous }
    }

    func deleteGiftIdea(_ id: UUID) {
        let previous = giftIdeas
        giftIdeas.removeAll { $0.id == id }
        if !saveToDisk() { giftIdeas = previous }
    }


    func addChristmasGift(recipient: String, title: String, note: String?, responsibleMemberID: UUID?) {
        let cleanRecipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanRecipient.isEmpty, cleanRecipient.count <= 100,
              !cleanTitle.isEmpty, cleanTitle.count <= 160 else { return }
        let validResponsibleID = members.first(where: { $0.id == responsibleMemberID })?.id
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        christmasGifts.append(ChristmasGift(recipient: cleanRecipient, title: cleanTitle,
            note: cleanNote?.isEmpty == true ? nil : cleanNote, responsibleMemberID: validResponsibleID))
        saveToDisk()
    }

    func updateChristmasGift(_ gift: ChristmasGift) {
        guard let index = christmasGifts.firstIndex(where: { $0.id == gift.id }) else { return }
        let recipient = gift.recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = gift.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipient.isEmpty, recipient.count <= 100, !title.isEmpty, title.count <= 160 else { return }
        let previous = christmasGifts[index]
        var updated = gift
        updated.recipient = recipient
        updated.title = title
        let cleanNote = gift.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = cleanNote?.isEmpty == true ? nil : cleanNote
        updated.responsibleMemberID = members.first(where: { $0.id == gift.responsibleMemberID })?.id
        christmasGifts[index] = updated
        if !saveToDisk() { christmasGifts[index] = previous }
    }

    func deleteChristmasGift(_ id: UUID) {
        let previous = christmasGifts
        christmasGifts.removeAll { $0.id == id }
        if !saveToDisk() { christmasGifts = previous }
    }

    func sendMessage(_ text: String, conversationID: String, kind: FamilyConversationKind) {
        guard let senderID = members.first(where: { $0.role == .owner })?.id else { return }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 4000 else { return }
        messages.append(FamilyMessage(id: UUID(), conversationID: conversationID,
                                      kind: kind, senderID: senderID, text: clean,
                                      sentAt: .now, readAt: nil))
        saveToDisk()
    }

    func markConversationRead(_ conversationID: String) {
        var changed = false
        for index in messages.indices where messages[index].conversationID == conversationID
            && messages[index].readAt == nil {
            messages[index].readAt = .now
            changed = true
        }
        if changed { saveToDisk() }
    }

    func markNotificationRead(_ id: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].readAt = .now
        saveToDisk()
    }


    // MARK: - Health records

    func saveHealthRecord(_ record: HealthRecord) {
        guard let family, record.familyID == family.id,
              members.contains(where: { $0.id == record.memberID }) else { return }
        let title = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 160 else { return }
        var updated = record
        updated.title = title
        updated.provider = Self.cleaned(updated.provider, limit: 120)
        updated.clinic = Self.cleaned(updated.clinic, limit: 160)
        updated.location = Self.cleaned(updated.location, limit: 160)
        updated.address = Self.cleaned(updated.address, limit: 240)
        updated.notes = Self.cleaned(updated.notes, limit: 4000)
        updated.reminderOffsets = Array(Set(updated.reminderOffsets.filter { $0 >= 0 })).sorted(by: >)
        updated.updatedAt = .now
        let previousRecords = healthRecords
        let previousItems = items
        if updated.type == .appointment || updated.type == .followUp {
            let calendarID = updated.calendarItemID ?? UUID()
            updated.calendarItemID = calendarID
            let calendarItem = FamilyItem(
                id: calendarID, familyID: family.id, title: title, details: updated.notes,
                startsAt: updated.startsAt, endsAt: nil, kind: .healthVisit,
                memberID: updated.memberID, isRecurringYearly: false,
                reminderOffsets: updated.reminderOffsets, memberIDs: [updated.memberID],
                isForEveryone: false, responsibleMemberID: nil,
                location: updated.address ?? updated.location,
                recurrenceFrequency: .none
            )
            if let itemIndex = items.firstIndex(where: { $0.id == calendarID }) {
                items[itemIndex] = calendarItem
            } else {
                items.append(calendarItem)
            }
        } else if let calendarID = updated.calendarItemID {
            items.removeAll { $0.id == calendarID }
            updated.calendarItemID = nil
        }
        if let index = healthRecords.firstIndex(where: { $0.id == record.id }) {
            healthRecords[index] = updated
        } else {
            healthRecords.append(updated)
        }
        if !saveToDisk() {
            healthRecords = previousRecords
            items = previousItems
        }
    }

    func deleteHealthRecord(_ id: UUID) {
        let previousRecords = healthRecords
        let previousItems = items
        let linkedCalendarID = healthRecords.first(where: { $0.id == id })?.calendarItemID
        healthRecords.removeAll { $0.id == id }
        if let linkedCalendarID {
            items.removeAll { $0.id == linkedCalendarID }
        }
        if !saveToDisk() {
            healthRecords = previousRecords
            items = previousItems
        }
    }

    func saveHealthPrescription(_ prescription: HealthPrescription) {
        guard let family, prescription.familyID == family.id,
              members.contains(where: { $0.id == prescription.memberID }) else { return }
        let name = prescription.medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 160,
              prescription.remainingRepeats.map({ $0 >= 0 }) ?? true else { return }
        var updated = prescription
        updated.medicationName = name
        updated.notes = Self.cleaned(updated.notes, limit: 2000)
        updated.updatedAt = .now
        let previousPrescriptions = healthPrescriptions
        let previousReminders = healthReminders
        if let index = healthPrescriptions.firstIndex(where: { $0.id == prescription.id }) {
            healthPrescriptions[index] = updated
        } else {
            healthPrescriptions.append(updated)
        }
        let renewalIsActive = updated.renewalStatus == .due || updated.renewalStatus == .requested
        upsertLinkedHealthReminder(
            targetType: .prescriptionRenewal, targetID: updated.id, memberID: updated.memberID,
            title: "Receptförnyelse", firesAt: renewalIsActive ? updated.renewalDueAt : nil,
            visibility: updated.visibility
        )
        if !saveToDisk() {
            healthPrescriptions = previousPrescriptions
            healthReminders = previousReminders
        }
    }

    func deleteHealthPrescription(_ id: UUID) {
        let previousPrescriptions = healthPrescriptions
        let previousPickups = medicationPickups
        let previousReminders = healthReminders
        healthPrescriptions.removeAll { $0.id == id }
        // Preserve pickup history; detach it from the deleted prescription.
        for index in medicationPickups.indices where medicationPickups[index].prescriptionID == id {
            medicationPickups[index].prescriptionID = nil
        }
        healthReminders.removeAll { $0.targetType == .prescriptionRenewal && $0.targetID == id }
        if !saveToDisk() {
            healthPrescriptions = previousPrescriptions
            medicationPickups = previousPickups
            healthReminders = previousReminders
        }
    }

    func saveMedicationPickup(_ pickup: MedicationPickup) {
        guard let family, pickup.familyID == family.id,
              members.contains(where: { $0.id == pickup.memberID }) else { return }
        let name = pickup.medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 160 else { return }
        if let prescriptionID = pickup.prescriptionID {
            guard healthPrescriptions.contains(where: {
                $0.id == prescriptionID && $0.memberID == pickup.memberID
            }) else { return }
        }
        var updated = pickup
        updated.medicationName = name
        updated.updatedAt = .now
        let previousPickups = medicationPickups
        let previousReminders = healthReminders
        if let index = medicationPickups.firstIndex(where: { $0.id == pickup.id }) {
            medicationPickups[index] = updated
        } else {
            medicationPickups.append(updated)
        }
        upsertLinkedHealthReminder(
            targetType: .medicationPickup, targetID: updated.id, memberID: updated.memberID,
            title: "Läkemedel att hämta",
            firesAt: updated.status == .planned ? updated.dueAt : nil,
            visibility: updated.visibility
        )
        if !saveToDisk() {
            medicationPickups = previousPickups
            healthReminders = previousReminders
        }
    }

    func deleteMedicationPickup(_ id: UUID) {
        let previousPickups = medicationPickups
        let previousReminders = healthReminders
        medicationPickups.removeAll { $0.id == id }
        healthReminders.removeAll { $0.targetType == .medicationPickup && $0.targetID == id }
        if !saveToDisk() {
            medicationPickups = previousPickups
            healthReminders = previousReminders
        }
    }

    func saveHealthProfileInformation(_ information: HealthProfileInformation) {
        guard let family, information.familyID == family.id,
              members.contains(where: { $0.id == information.memberID }) else { return }
        let title = information.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 160 else { return }
        var updated = information
        updated.title = title
        updated.details = Self.cleaned(updated.details, limit: 4000)
        updated.updatedAt = .now
        let previous = healthProfileInformation
        if let index = healthProfileInformation.firstIndex(where: { $0.id == information.id }) {
            healthProfileInformation[index] = updated
        } else {
            healthProfileInformation.append(updated)
        }
        if !saveToDisk() { healthProfileInformation = previous }
    }

    func deleteHealthProfileInformation(_ id: UUID) {
        let previous = healthProfileInformation
        healthProfileInformation.removeAll { $0.id == id }
        if !saveToDisk() { healthProfileInformation = previous }
    }

    func saveHealthReminder(_ reminder: HealthReminder) {
        guard let family, reminder.familyID == family.id,
              members.contains(where: { $0.id == reminder.memberID }) else { return }
        let title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 160 else { return }
        var updated = reminder
        updated.title = title
        updated.updatedAt = .now
        let previous = healthReminders
        if let index = healthReminders.firstIndex(where: { $0.id == reminder.id }) {
            healthReminders[index] = updated
        } else {
            healthReminders.append(updated)
        }
        if !saveToDisk() { healthReminders = previous }
    }

    func deleteHealthReminder(_ id: UUID) {
        let previous = healthReminders
        healthReminders.removeAll { $0.id == id }
        if !saveToDisk() { healthReminders = previous }
    }

    private func upsertLinkedHealthReminder(
        targetType: HealthReminderTarget,
        targetID: UUID,
        memberID: UUID,
        title: String,
        firesAt: Date?,
        visibility: HealthVisibility
    ) {
        if let index = healthReminders.firstIndex(where: {
            $0.targetType == targetType && $0.targetID == targetID
        }) {
            guard let firesAt else {
                healthReminders.remove(at: index)
                return
            }
            healthReminders[index].memberID = memberID
            healthReminders[index].title = title
            healthReminders[index].firesAt = firesAt
            healthReminders[index].isEnabled = true
            healthReminders[index].visibility = visibility
            healthReminders[index].updatedAt = .now
        } else if let firesAt {
            healthReminders.append(HealthReminder(
                familyID: family?.id ?? UUID(), memberID: memberID,
                targetType: targetType, targetID: targetID, title: title,
                firesAt: firesAt, isEnabled: true, visibility: visibility
            ))
        }
    }

    private static func cleaned(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(limit))
    }

    private struct Snapshot: Codable {
        var family: Family?
        var members: [FamilyMember]
        var items: [FamilyItem]
        var shoppingItems: [ShoppingItem]
        var notifications: [FamilyNotification]
        var messages: [FamilyMessage]?
        var skippedOccurrences: [FamilyOccurrenceException]? = nil
        var occurrenceOverrides: [FamilyOccurrenceOverride]? = nil
        var giftIdeas: [GiftIdea]? = nil
        var christmasGifts: [ChristmasGift]? = nil
        var healthRecords: [HealthRecord]? = nil
        var healthPrescriptions: [HealthPrescription]? = nil
        var medicationPickups: [MedicationPickup]? = nil
        var healthProfileInformation: [HealthProfileInformation]? = nil
        var healthReminders: [HealthReminder]? = nil
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
            family = snapshot.family
            members = snapshot.members
            items = snapshot.items
            skippedOccurrences = snapshot.skippedOccurrences ?? []
            occurrenceOverrides = snapshot.occurrenceOverrides ?? []
            giftIdeas = snapshot.giftIdeas ?? []
            christmasGifts = snapshot.christmasGifts ?? []
            healthRecords = snapshot.healthRecords ?? []
            healthPrescriptions = snapshot.healthPrescriptions ?? []
            medicationPickups = snapshot.medicationPickups ?? []
            healthProfileInformation = snapshot.healthProfileInformation ?? []
            healthReminders = snapshot.healthReminders ?? []
            shoppingItems = snapshot.shoppingItems
            notifications = snapshot.notifications
            messages = snapshot.messages ?? []
        } catch {
            // Preserve an unreadable snapshot before any later write can replace it.
            let recoveryURL = fileURL.deletingLastPathComponent()
                .appendingPathComponent("\(fileURL.lastPathComponent).corrupt-\(UUID().uuidString)")
            do {
                try FileManager.default.moveItem(at: fileURL, to: recoveryURL)
            } catch {
                // Never overwrite the only copy if recovery preservation failed.
                persistenceBlockedByCorruption = true
                persistenceError = "Befintliga familjedata kunde inte återställas. Skrivningar har spärrats för att skydda originalfilen."
            }
        }
    }

    @discardableResult
    private func saveToDisk() -> Bool {
        guard !persistenceBlockedByCorruption else {
            persistenceError = persistenceError ?? persistenceFailureMessage
            return false
        }
        let snapshot = Snapshot(family: family, members: members, items: items,
                                shoppingItems: shoppingItems, notifications: notifications, messages: messages,
                                skippedOccurrences: skippedOccurrences,
                                occurrenceOverrides: occurrenceOverrides,
                                giftIdeas: giftIdeas, christmasGifts: christmasGifts,
                                healthRecords: healthRecords, healthPrescriptions: healthPrescriptions,
                                medicationPickups: medicationPickups,
                                healthProfileInformation: healthProfileInformation,
                                healthReminders: healthReminders)
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            persistenceError = nil
            return true
        } catch {
            persistenceError = persistenceFailureMessage
            return false
        }
    }
}
