import Foundation

/// Storage boundary for family data. UI and feature logic should depend on this
/// contract rather than on a specific persistence or cloud provider.
@MainActor
protocol FamilyRepository: AnyObject {
    var family: Family? { get }
    var members: [FamilyMember] { get }
    var items: [FamilyItem] { get }
    var shoppingItems: [ShoppingItem] { get }
    var notifications: [FamilyNotification] { get }
    var messages: [FamilyMessage] { get }

    func createFamily(name: String, ownerName: String)
    func renameFamily(name: String)
    func addChild(name: String)
    func addMember(name: String, role: MemberRole)
    func renameMember(id: UUID, name: String)
    func deleteMember(id: UUID)
    func renameChild(id: UUID, name: String)
    func deleteChild(id: UUID)
    func saveItem(id: UUID?, title: String, details: String?, startsAt: Date,
                  kind: FamilyItemKind, memberID: UUID?, recurring: Bool, reminderOffsets: [Int])
    func deleteItem(_ item: FamilyItem)
    func addShoppingItem(_ title: String)
    func setShoppingItem(_ id: UUID, checked: Bool)
    func deleteShoppingItem(_ id: UUID)
    func sendMessage(_ text: String, conversationID: String, kind: FamilyConversationKind)
    func markConversationRead(_ conversationID: String)
    func markNotificationRead(_ id: UUID)
}

/// The default provider remains local until CloudKit capabilities are configured.
/// This keeps provider selection in one place and avoids cloud dependencies in views.
@MainActor
enum FamilyRepositoryFactory {
    static func makeDefault() -> any FamilyRepository {
        LocalFamilyStore.shared
    }
}
