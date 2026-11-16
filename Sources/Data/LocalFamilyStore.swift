import Combine
import Foundation

@MainActor
final class LocalFamilyStore: ObservableObject {
    static let shared = LocalFamilyStore()

    @Published private(set) var family: Family?
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var items: [FamilyItem] = []
    @Published private(set) var shoppingItems: [ShoppingItem] = []
    @Published private(set) var notifications: [FamilyNotification] = []

    private let fileURL: URL

    private init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("familjen-local-data.json")
        loadFromDisk()
    }

    func createFamily(name: String, ownerName: String) {
        let family = Family(id: UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        let owner = FamilyMember(id: UUID(), familyID: family.id,
                                 displayName: ownerName.trimmingCharacters(in: .whitespacesAndNewlines),
                                 role: .owner, linkedUserID: nil)
        self.family = family
        members = [owner]
        items = []
        shoppingItems = []
        notifications = []
        saveToDisk()
    }

    func addChild(name: String) {
        guard let family, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        members.append(FamilyMember(id: UUID(), familyID: family.id,
                                    displayName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                    role: .child, linkedUserID: nil))
        saveToDisk()
    }

    func renameChild(id: UUID, name: String) {
        guard let index = members.firstIndex(where: { $0.id == id && $0.role == .child }) else { return }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        members[index].displayName = clean
        saveToDisk()
    }

    func deleteChild(id: UUID) {
        members.removeAll { $0.id == id && $0.role == .child }
        items.removeAll { $0.memberID == id }
        saveToDisk()
    }

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
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        shoppingItems.append(ShoppingItem(id: UUID(), listID: family?.id ?? UUID(),
                                          title: title.trimmingCharacters(in: .whitespacesAndNewlines),
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
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        family = snapshot.family
        members = snapshot.members
        items = snapshot.items
        shoppingItems = snapshot.shoppingItems
        notifications = snapshot.notifications
    }

    private func saveToDisk() {
        let snapshot = Snapshot(family: family, members: members, items: items,
                                shoppingItems: shoppingItems, notifications: notifications)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
