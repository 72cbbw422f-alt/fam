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
        skippedOccurrences = repository.skippedOccurrences
        occurrenceOverrides = repository.occurrenceOverrides
        shoppingItems = repository.shoppingItems
        giftIdeas = repository.giftIdeas
        christmasGifts = repository.christmasGifts
        notifications = repository.notifications
        healthRecords = repository.healthRecords
        healthPrescriptions = repository.healthPrescriptions
        medicationPickups = repository.medicationPickups
        healthProfileInformation = repository.healthProfileInformation
        healthReminders = repository.healthReminders
        messages = repository.messages
        persistenceError = repository.persistenceError
    }

    func createFamily(name: String, ownerName: String) { repository.createFamily(name: name, ownerName: ownerName); refresh() }
    func renameFamily(name: String) { repository.renameFamily(name: name); refresh() }
    func addChild(name: String) { repository.addChild(name: name); refresh() }
    func addMember(name: String, role: MemberRole = .member) { repository.addMember(name: name, role: role); refresh() }
    func renameMember(id: UUID, name: String) { repository.renameMember(id: id, name: name); refresh() }
    func updateMemberSymbol(id: UUID, symbolName: String?) { repository.updateMemberSymbol(id: id, symbolName: symbolName); refresh() }
    func deleteMember(id: UUID) { repository.deleteMember(id: id); refresh() }
    func renameChild(id: UUID, name: String) { repository.renameChild(id: id, name: name); refresh() }
    func deleteChild(id: UUID) { repository.deleteChild(id: id); refresh() }
    func saveItem(id: UUID?, title: String, details: String?, startsAt: Date, kind: FamilyItemKind,
                  memberID: UUID?, recurring: Bool, reminderOffsets: [Int]) {
        repository.saveItem(id: id, title: title, details: details, startsAt: startsAt,
                            kind: kind, memberID: memberID, recurring: recurring,
                            reminderOffsets: reminderOffsets)
        refresh()
        rescheduleHealthReminders()
    }
    func saveCalendarItem(id: UUID?, title: String, details: String?, startsAt: Date,
                          kind: FamilyItemKind, memberIDs: [UUID], isForEveryone: Bool,
                          responsibleMemberID: UUID?, recurring: Bool, reminderOffsets: [Int],
                          location: String? = nil, latitude: Double? = nil, longitude: Double? = nil, recurrenceFrequency: FamilyRecurrenceFrequency = .none) {
        repository.saveCalendarItem(id: id, title: title, details: details, startsAt: startsAt,
                                    kind: kind, memberIDs: memberIDs, isForEveryone: isForEveryone,
                                    responsibleMemberID: responsibleMemberID, recurring: recurring,
                                    reminderOffsets: reminderOffsets, location: location, latitude: latitude, longitude: longitude, recurrenceFrequency: recurrenceFrequency)
        refresh()
        rescheduleHealthReminders()
    }
    func deleteItem(_ item: FamilyItem) {
        repository.deleteItem(item)
        refresh()
        rescheduleHealthReminders()
    }
    func addShoppingItem(_ title: String) { repository.addShoppingItem(title); refresh() }
    func addShoppingItem(_ title: String, category: ShoppingCategory) { repository.addShoppingItem(title, category: category); refresh() }
    func setShoppingItem(_ id: UUID, checked: Bool) { repository.setShoppingItem(id, checked: checked); refresh() }
    func deleteShoppingItem(_ id: UUID) { repository.deleteShoppingItem(id); refresh() }
    func addGiftIdea(memberID: UUID, birthdayItemID: UUID, title: String, note: String?) {
        repository.addGiftIdea(memberID: memberID, birthdayItemID: birthdayItemID, title: title, note: note)
        refresh()
    }
    func updateGiftIdea(_ idea: GiftIdea) { repository.updateGiftIdea(idea); refresh() }
    func deleteGiftIdea(_ id: UUID) { repository.deleteGiftIdea(id); refresh() }
    func addChristmasGift(recipient: String, title: String, note: String?, responsibleMemberID: UUID?) { repository.addChristmasGift(recipient: recipient, title: title, note: note, responsibleMemberID: responsibleMemberID); refresh() }
    func updateChristmasGift(_ gift: ChristmasGift) { repository.updateChristmasGift(gift); refresh() }
    func deleteChristmasGift(_ id: UUID) { repository.deleteChristmasGift(id); refresh() }
    func sendMessage(_ text: String, conversationID: String, kind: FamilyConversationKind) {
        repository.sendMessage(text, conversationID: conversationID, kind: kind); refresh()
    }
    func markConversationRead(_ conversationID: String) { repository.markConversationRead(conversationID); refresh() }
    func saveHealthRecord(_ record: HealthRecord) {
        repository.saveHealthRecord(record)
        refresh()
        rescheduleHealthReminders()
    }
    func deleteHealthRecord(_ id: UUID) {
        repository.deleteHealthRecord(id)
        refresh()
        rescheduleHealthReminders()
    }
    func saveHealthPrescription(_ prescription: HealthPrescription) {
        repository.saveHealthPrescription(prescription)
        refresh()
        rescheduleHealthReminders()
    }
    func deleteHealthPrescription(_ id: UUID) {
        repository.deleteHealthPrescription(id)
        refresh()
        rescheduleHealthReminders()
    }
    func saveMedicationPickup(_ pickup: MedicationPickup) {
        repository.saveMedicationPickup(pickup)
        refresh()
        rescheduleHealthReminders()
    }
    func deleteMedicationPickup(_ id: UUID) {
        repository.deleteMedicationPickup(id)
        refresh()
        rescheduleHealthReminders()
    }
    func saveHealthProfileInformation(_ information: HealthProfileInformation) { repository.saveHealthProfileInformation(information); refresh() }
    func deleteHealthProfileInformation(_ id: UUID) { repository.deleteHealthProfileInformation(id); refresh() }
    func saveHealthReminder(_ reminder: HealthReminder) {
        repository.saveHealthReminder(reminder)
        refresh()
        rescheduleHealthReminders()
    }
    func deleteHealthReminder(_ id: UUID) {
        repository.deleteHealthReminder(id)
        refresh()
        rescheduleHealthReminders()
    }

    static func shouldRescheduleReminders(afterPersistenceError error: String?) -> Bool {
        error == nil
    }

    private func rescheduleHealthReminders() {
        guard Self.shouldRescheduleReminders(afterPersistenceError: persistenceError) else { return }
        guard UserDefaults.standard.bool(forKey: "familjen.localRemindersEnabled") else { return }
        Task {
            await LocalReminderScheduler.schedule(
                for: items,
                skipping: skippedOccurrences,
                overrides: occurrenceOverrides,
                healthReminders: healthReminders
            )
        }
    }
    func markNotificationRead(_ id: UUID) { repository.markNotificationRead(id); refresh() }
}
