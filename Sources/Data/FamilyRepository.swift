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
    var favoriteShoppingItemTitles: [String] { get }
    var giftIdeas: [GiftIdea] { get }
    var christmasGifts: [ChristmasGift] { get }
    var notifications: [FamilyNotification] { get }
    var healthRecords: [HealthRecord] { get }
    var healthPrescriptions: [HealthPrescription] { get }
    var medicationPickups: [MedicationPickup] { get }
    var healthProfileInformation: [HealthProfileInformation] { get }
    var healthReminders: [HealthReminder] { get }
    var messages: [FamilyMessage] { get }
    var persistenceError: String? { get }

    func createFamily(name: String, ownerName: String)
    func renameFamily(name: String)
    func addChild(name: String)
    func addMember(name: String, role: MemberRole)
    func renameMember(id: UUID, name: String)
    func updateMemberSymbol(id: UUID, symbolName: String?)
    func updateMemberProfile(id: UUID, name: String, symbolName: String?)
    func deleteMember(id: UUID)
    func renameChild(id: UUID, name: String)
    func deleteChild(id: UUID)
    func saveItem(id: UUID?, title: String, details: String?, startsAt: Date,
                  kind: FamilyItemKind, memberID: UUID?, recurring: Bool, reminderOffsets: [Int])
    func saveCalendarItem(id: UUID?, title: String, details: String?, startsAt: Date,
                         kind: FamilyItemKind, memberIDs: [UUID], isForEveryone: Bool,
                         responsibleMemberID: UUID?, recurring: Bool, reminderOffsets: [Int],
                         location: String?, latitude: Double?, longitude: Double?, recurrenceFrequency: FamilyRecurrenceFrequency)
    func deleteItem(_ item: FamilyItem)
    func saveOccurrenceOverride(seriesID: UUID, occurrenceDate: Date, item: FamilyItem)
    func skipOccurrence(of item: FamilyItem)
    func addShoppingItem(_ title: String)
    func addShoppingItem(_ title: String, category: ShoppingCategory)
    func setShoppingItem(_ id: UUID, checked: Bool)
    func deleteShoppingItem(_ id: UUID)
    func clearCompletedShoppingItems()
    func clearAllShoppingItems()
    func setShoppingItemFavorite(_ title: String, isFavorite: Bool)
    func addGiftIdea(memberID: UUID, birthdayItemID: UUID, title: String, note: String?)
    func updateGiftIdea(_ idea: GiftIdea)
    func addChristmasGift(recipient: String, title: String, note: String?, responsibleMemberID: UUID?)
    func updateChristmasGift(_ gift: ChristmasGift)
    func deleteChristmasGift(_ id: UUID)
    func deleteGiftIdea(_ id: UUID)
    func sendMessage(_ text: String, conversationID: String, kind: FamilyConversationKind)
    func markConversationRead(_ conversationID: String)
    func saveHealthRecord(_ record: HealthRecord)
    func deleteHealthRecord(_ id: UUID)
    func saveHealthPrescription(_ prescription: HealthPrescription)
    func deleteHealthPrescription(_ id: UUID)
    func saveMedicationPickup(_ pickup: MedicationPickup)
    func deleteMedicationPickup(_ id: UUID)
    func saveHealthProfileInformation(_ information: HealthProfileInformation)
    func deleteHealthProfileInformation(_ id: UUID)
    func saveHealthReminder(_ reminder: HealthReminder)
    func deleteHealthReminder(_ id: UUID)
    func markNotificationRead(_ id: UUID)
}

extension FamilyRepository {
    var healthRecords: [HealthRecord] { [] }
    var healthPrescriptions: [HealthPrescription] { [] }
    var medicationPickups: [MedicationPickup] { [] }
    var healthProfileInformation: [HealthProfileInformation] { [] }
    var healthReminders: [HealthReminder] { [] }
    func saveHealthRecord(_ record: HealthRecord) { }
    func deleteHealthRecord(_ id: UUID) { }
    func saveHealthPrescription(_ prescription: HealthPrescription) { }
    func deleteHealthPrescription(_ id: UUID) { }
    func saveMedicationPickup(_ pickup: MedicationPickup) { }
    func deleteMedicationPickup(_ id: UUID) { }
    func saveHealthProfileInformation(_ information: HealthProfileInformation) { }
    func deleteHealthProfileInformation(_ id: UUID) { }
    func saveHealthReminder(_ reminder: HealthReminder) { }
    func deleteHealthReminder(_ id: UUID) { }
    var skippedOccurrences: [FamilyOccurrenceException] { [] }
    var giftIdeas: [GiftIdea] { [] }
    var christmasGifts: [ChristmasGift] { [] }
    func addGiftIdea(memberID: UUID, birthdayItemID: UUID, title: String, note: String?) { }
    func updateGiftIdea(_ idea: GiftIdea) { }
    func deleteGiftIdea(_ id: UUID) { }
    func addChristmasGift(recipient: String, title: String, note: String?, responsibleMemberID: UUID?) { }
    func updateChristmasGift(_ gift: ChristmasGift) { }
    func deleteChristmasGift(_ id: UUID) { }
    var occurrenceOverrides: [FamilyOccurrenceOverride] { [] }
    func saveOccurrenceOverride(seriesID: UUID, occurrenceDate: Date, item: FamilyItem) { }
    func skipOccurrence(of item: FamilyItem) { }
    var persistenceError: String? { nil }
    func updateMemberSymbol(id: UUID, symbolName: String?) { }

    func addShoppingItem(_ title: String, category: ShoppingCategory) { addShoppingItem(title) }
    func clearCompletedShoppingItems() { }
    func clearAllShoppingItems() { }
    var favoriteShoppingItemTitles: [String] { [] }
    func setShoppingItemFavorite(_ title: String, isFavorite: Bool) { }

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
