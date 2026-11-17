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
    @Published private(set) var notifications: [FamilyNotification] = []
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
        notifications = []
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
        members[index].displayName = clean
        saveToDisk()
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
        let previous = occurrenceOverrides
        occurrenceOverrides.removeAll {
            $0.seriesID == seriesID && Calendar.current.isDate($0.occurrenceDate, inSameDayAs: occurrenceDate)
        }
        occurrenceOverrides.append(FamilyOccurrenceOverride(seriesID: seriesID, occurrenceDate: occurrenceDate, item: item))
        if !saveToDisk() { occurrenceOverrides = previous }
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

    private struct Snapshot: Codable {
        var family: Family?
        var members: [FamilyMember]
        var items: [FamilyItem]
        var shoppingItems: [ShoppingItem]
        var notifications: [FamilyNotification]
        var messages: [FamilyMessage]?
        var skippedOccurrences: [FamilyOccurrenceException]? = nil
        var occurrenceOverrides: [FamilyOccurrenceOverride]? = nil
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
                                occurrenceOverrides: occurrenceOverrides)
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
