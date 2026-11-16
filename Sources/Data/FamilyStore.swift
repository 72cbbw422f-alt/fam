import Combine
import Foundation

/// Observable UI-facing facade. Views depend on this stable type while the
/// underlying repository can change from local persistence to CloudKit later.
@MainActor
final class FamilyStore: ObservableObject {
    static let shared = FamilyStore(repository: FamilyRepositoryFactory.makeDefault())

    @Published private(set) var family: Family?
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var items: [FamilyItem] = []
    @Published private(set) var shoppingItems: [ShoppingItem] = []
    @Published private(set) var notifications: [FamilyNotification] = []
    @Published private(set) var messages: [FamilyMessage] = []
    @Published private(set) var persistenceError: String?

    private let repository: any FamilyRepository
    private var cancellable: AnyCancellable?

    init(repository: any FamilyRepository) {
        self.repository = repository
        refresh()
        cancellable = repository.changePublisher
            .sink { [weak self] in
                Task { @MainActor [weak self] in self?.refresh() }
            }
    }

    func refresh() {
        family = repository.family
        members = repository.members
        items = repository.items
        shoppingItems = repository.shoppingItems
        notifications = repository.notifications
        messages = repository.messages
        persistenceError = repository.persistenceError
    }

    func createFamily(name: String, ownerName: String) { repository.createFamily(name: name, ownerName: ownerName); refresh() }
    func renameFamily(name: String) { repository.renameFamily(name: name); refresh() }
    func addChild(name: String) { repository.addChild(name: name); refresh() }
    func addMember(name: String, role: MemberRole = .member) { repository.addMember(name: name, role: role); refresh() }
    func renameMember(id: UUID, name: String) { repository.renameMember(id: id, name: name); refresh() }
    func deleteMember(id: UUID) { repository.deleteMember(id: id); refresh() }
    func renameChild(id: UUID, name: String) { repository.renameChild(id: id, name: name); refresh() }
    func deleteChild(id: UUID) { repository.deleteChild(id: id); refresh() }
    func saveItem(id: UUID?, title: String, details: String?, startsAt: Date, kind: FamilyItemKind,
                  memberID: UUID?, recurring: Bool, reminderOffsets: [Int]) {
        repository.saveItem(id: id, title: title, details: details, startsAt: startsAt,
                            kind: kind, memberID: memberID, recurring: recurring,
                            reminderOffsets: reminderOffsets)
        refresh()
    }
    func saveCalendarItem(id: UUID?, title: String, details: String?, startsAt: Date,
                          kind: FamilyItemKind, memberIDs: [UUID], isForEveryone: Bool,
                          responsibleMemberID: UUID?, recurring: Bool, reminderOffsets: [Int],
                          location: String? = nil) {
        repository.saveCalendarItem(id: id, title: title, details: details, startsAt: startsAt,
                                    kind: kind, memberIDs: memberIDs, isForEveryone: isForEveryone,
                                    responsibleMemberID: responsibleMemberID, recurring: recurring,
                                    reminderOffsets: reminderOffsets, location: location)
        refresh()
    }
    func deleteItem(_ item: FamilyItem) { repository.deleteItem(item); refresh() }
    func addShoppingItem(_ title: String) { repository.addShoppingItem(title); refresh() }
    func setShoppingItem(_ id: UUID, checked: Bool) { repository.setShoppingItem(id, checked: checked); refresh() }
    func deleteShoppingItem(_ id: UUID) { repository.deleteShoppingItem(id); refresh() }
    func sendMessage(_ text: String, conversationID: String, kind: FamilyConversationKind) {
        repository.sendMessage(text, conversationID: conversationID, kind: kind); refresh()
    }
    func markConversationRead(_ conversationID: String) { repository.markConversationRead(conversationID); refresh() }
    func markNotificationRead(_ id: UUID) { repository.markNotificationRead(id); refresh() }
}
