import Combine
import Foundation

/// Storage boundary for family data. UI and feature logic depend on this
/// contract rather than on a specific persistence or cloud provider.
@MainActor
protocol FamilyRepository: AnyObject {
    var changePublisher: AnyPublisher<Void, Never> { get }
    var family: Family? { get }
    var members: [FamilyMember] { get }
    var items: [FamilyItem] { get }
    var skippedOccurrences: [FamilyOccurrenceException] { get }
    var occurrenceOverrides: [FamilyOccurrenceOverride] { get }
    var shoppingItems: [ShoppingItem] { get }
    var notifications: [FamilyNotification] { get }
    var messages: [FamilyMessage] { get }
    var persistenceError: String? { get }

    func createFamily(name: String, ownerName: String)
    func renameFamily(name: String)
    func addChild(name: String)
    func addMember(name: String, role: MemberRole)
    func renameMember(id: UUID, name: String)
    func updateMemberSymbol(id: UUID, symbolName: String?)
    func deleteMember(id: UUID)
    func renameChild(id: UUID, name: String)
    func deleteChild(id: UUID)
    func saveItem(id: UUID?, title: String, details: String?, startsAt: Date,
                  kind: FamilyItemKind, memberID: UUID?, recurring: Bool, reminderOffsets: [Int])
    func saveCalendarItem(id: UUID?, title: String, details: String?, startsAt: Date,
                         kind: FamilyItemKind, memberIDs: [UUID], isForEveryone: Bool,
                         responsibleMemberID: UUID?, recurring: Bool, reminderOffsets: [Int],
                         location: String?, recurrenceFrequency: FamilyRecurrenceFrequency)
    func deleteItem(_ item: FamilyItem)
    func saveOccurrenceOverride(seriesID: UUID, occurrenceDate: Date, item: FamilyItem)
    func skipOccurrence(of item: FamilyItem)
    func addShoppingItem(_ title: String)
    func setShoppingItem(_ id: UUID, checked: Bool)
    func deleteShoppingItem(_ id: UUID)
    func sendMessage(_ text: String, conversationID: String, kind: FamilyConversationKind)
    func markConversationRead(_ conversationID: String)
    func markNotificationRead(_ id: UUID)
}

extension FamilyRepository {
    var skippedOccurrences: [FamilyOccurrenceException] { [] }
    var occurrenceOverrides: [FamilyOccurrenceOverride] { [] }
    func saveOccurrenceOverride(seriesID: UUID, occurrenceDate: Date, item: FamilyItem) { }
    func skipOccurrence(of item: FamilyItem) { }
    var persistenceError: String? { nil }

    func addMember(name: String) { addMember(name: name, role: .member) }

    /// Compatibility default for repositories not yet supporting the richer calendar assignment.
    func saveCalendarItem(id: UUID?, title: String, details: String?, startsAt: Date,
                          kind: FamilyItemKind, memberIDs: [UUID], isForEveryone: Bool,
                          responsibleMemberID: UUID?, recurring: Bool, reminderOffsets: [Int],
                          location: String?, recurrenceFrequency: FamilyRecurrenceFrequency) {
        saveItem(id: id, title: title, details: details, startsAt: startsAt, kind: kind,
                 memberID: memberIDs.first, recurring: recurring, reminderOffsets: reminderOffsets)
    }
}

/// Provider selection stays centralized; CloudKit can replace the local adapter.
@MainActor
enum FamilyRepositoryFactory {
    static func makeDefault() -> any FamilyRepository {
        LocalFamilyStore.shared
    }
}
