import Combine
import Foundation

@MainActor
final class LocalFamilyStore: ObservableObject, FamilyRepository {
    static let shared = LocalFamilyStore()

    @Published private(set) var family: Family?
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var items: [FamilyItem] = []
    @Published private(set) var shoppingItems: [ShoppingItem] = []
    @Published private(set) var notifications: [FamilyNotification] = []
    @Published private(set) var messages: [FamilyMessage] = []

    var changePublisher: AnyPublisher<Void, Never> {
        objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }

    private let fileURL: URL

    private convenience init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.init(fileURL: directory.appendingPathComponent("familjen-local-data.json"))
    }

    /// Injectable file location keeps persistence tests isolated from the user's real app data.
    init(fileURL: URL) {
        self.fileURL = fileURL
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        loadFromDisk()
    }

    func createFamily(name: String, ownerName: String) {
        let cleanFamilyName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanOwnerName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanFamilyName.isEmpty, cleanFamilyName.count <= 80,
              !cleanOwnerName.isEmpty, cleanOwnerName.count <= 80 else { return }
        let family = Family(id: UUID(), name: cleanFamilyName)
        let owner = FamilyMember(id: UUID(), familyID: family.id,
                                 displayName: cleanOwnerName,
                                 role: .owner, linkedUserID: nil)
        self.family = family
        members = [owner]
        items = []
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
        members.removeAll { $0.id == id }
        items.removeAll { $0.memberID == id }
        saveToDisk()
    }

    func renameChild(id: UUID, name: String) { renameMember(id: id, name: name) }
    func deleteChild(id: UUID) { deleteMember(id: id) }

    func saveItem(id: UUID?, title: String, details: String?, startsAt: Date,
                  kind: FamilyItemKind, memberID: UUID?, recurring: Bool, reminderOffsets: [Int]) {
        guard let family else { return }
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if let id, let index = items.firstIndex(where: { $0.id == id }) {
            items[index].title = clean
            items[index].details = details
            items[index].startsAt = startsAt
            items[index].kind = kind
            items[index].memberID = memberID
            items[index].isRecurringYearly = kind == .birthday && recurring
            items[index].reminderOffsets = reminderOffsets
        } else {
            items.append(FamilyItem(id: UUID(), familyID: family.id, title: clean,
                                    details: details, startsAt: startsAt, endsAt: nil,
                                    kind: kind, memberID: memberID,
                                    isRecurringYearly: kind == .birthday && recurring,
                                    reminderOffsets: reminderOffsets))
        }
        saveToDisk()
    }

    func deleteItem(_ item: FamilyItem) {
        items.removeAll { $0.id == item.id }
        saveToDisk()
    }

    func addShoppingItem(_ title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 160 else { return }
        shoppingItems.append(ShoppingItem(id: UUID(), listID: family?.id ?? UUID(),
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
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        family = snapshot.family
        members = snapshot.members
        items = snapshot.items
        shoppingItems = snapshot.shoppingItems
        notifications = snapshot.notifications
        messages = snapshot.messages ?? []
    }

    private func saveToDisk() {
        let snapshot = Snapshot(family: family, members: members, items: items,
                                shoppingItems: shoppingItems, notifications: notifications, messages: messages)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
