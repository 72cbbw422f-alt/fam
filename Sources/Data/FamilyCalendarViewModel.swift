import Combine
import Foundation

@MainActor
final class FamilyCalendarViewModel: ObservableObject {
    @Published private(set) var items: [FamilyItem] = []
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var appleCalendarEntries: [AppleCalendarEntry] = []
    @Published private(set) var isAppleCalendarEnabled = false
    @Published var appleCalendarError: String?
    private let appleCalendar = AppleCalendarImport()
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let store: any FamilyRepository

    init(store: (any FamilyRepository)? = nil) {
        self.store = store ?? FamilyRepositoryFactory.makeDefault()
    }

    func load() async {
        isLoading = true
        members = store.members
        items = DashboardViewModel.project(store.items, from: .now, skipping: store.skippedOccurrences)
        isLoading = false
    }

    func enableAppleCalendar() async {
        await appleCalendar.enableAndLoad()
        appleCalendarEntries = appleCalendar.entries
        isAppleCalendarEnabled = appleCalendar.isEnabled
        appleCalendarError = appleCalendar.errorMessage
    }

    func refreshAppleCalendar() {
        appleCalendar.refresh()
        appleCalendarEntries = appleCalendar.entries
        appleCalendarError = appleCalendar.errorMessage
    }

    func startRealtimeIfNeeded() async {}
    func stopRealtime() async {}

    func save(id: UUID?, title: String, details: String?, startsAt: Date, kind: FamilyItemKind,
              memberID: UUID?, isRecurringYearly: Bool, reminderOffsets: [Int]) async -> Bool {
        await save(id: id, title: title, details: details, startsAt: startsAt, kind: kind,
                   memberIDs: memberID.map { [$0] } ?? [], isForEveryone: false,
                   responsibleMemberID: nil, isRecurringYearly: isRecurringYearly,
                   reminderOffsets: reminderOffsets, location: nil)
    }

    func save(id: UUID?, title: String, details: String?, startsAt: Date, kind: FamilyItemKind,
              memberIDs: [UUID], isForEveryone: Bool, responsibleMemberID: UUID?,
              isRecurringYearly: Bool, reminderOffsets: [Int], location: String?, recurrenceFrequency: FamilyRecurrenceFrequency = .none) async -> Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 160 else {
            errorMessage = "Ange en rubrik på 1–160 tecken."
            return false
        }
        let persistedDate = preservedRecurringDate(
            id: id, proposedDate: startsAt, recurring: recurrenceFrequency != .none || isRecurringYearly,
            recurrenceFrequency: recurrenceFrequency
        )
        store.saveCalendarItem(id: id, title: clean, details: details, startsAt: persistedDate,
                               kind: kind, memberIDs: memberIDs, isForEveryone: isForEveryone,
                               responsibleMemberID: responsibleMemberID, recurring: isRecurringYearly,
                               reminderOffsets: reminderOffsets, location: location,
                               recurrenceFrequency: recurrenceFrequency == .none && isRecurringYearly ? .yearly : recurrenceFrequency)
        await load()
        if let persistenceError = store.persistenceError {
            errorMessage = persistenceError
            return false
        }
        errorMessage = nil
        return true
    }

    static func filteredItems(_ items: [FamilyItem], selectedMemberIDs: Set<UUID>) -> [FamilyItem] {
        guard !selectedMemberIDs.isEmpty else { return items }
        return items.filter { item in
            item.isForEveryone || !Set(item.memberIDs).isDisjoint(with: selectedMemberIDs)
        }
    }

    func skipOccurrence(_ item: FamilyItem) async {\n        store.skipOccurrence(of: item)\n        await load()\n        errorMessage = store.persistenceError\n    }\n\n    func delete(_ item: FamilyItem) async {
        store.deleteItem(item)
        await load()
        errorMessage = store.persistenceError
    }

    // Keep the series anchor stable when the user only changes the time
    // on a projected occurrence. A deliberately changed calendar day becomes
    // the new anchor for the series.
    private func preservedRecurringDate(id: UUID?, proposedDate: Date,
                                        recurring: Bool,
                                        recurrenceFrequency: FamilyRecurrenceFrequency) -> Date {
        guard recurring, let id,
              let original = store.items.first(where: { $0.id == id }) else {
            return proposedDate
        }
        let frequency = recurrenceFrequency == .none && original.isRecurringYearly
            ? FamilyRecurrenceFrequency.yearly : recurrenceFrequency
        guard frequency != .none else { return proposedDate }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let projected = DashboardViewModel.project([original], from: .now).first,
              calendar.isDate(proposedDate, inSameDayAs: projected.startsAt) else {
            return proposedDate
        }

        let originalParts = calendar.dateComponents([.year, .month, .day], from: original.startsAt)
        let editedParts = calendar.dateComponents([.hour, .minute, .second], from: proposedDate)
        var components = DateComponents()
        components.hour = editedParts.hour
        components.minute = editedParts.minute
        components.second = editedParts.second

        switch frequency {
        case .none:
            return proposedDate
        case .weekly:
            components.year = originalParts.year
            components.month = originalParts.month
            components.day = originalParts.day
        case .monthly:
            components.year = originalParts.year
            components.month = originalParts.month
            components.day = originalParts.day
        case .yearly:
            components.year = originalParts.year
            components.month = originalParts.month
            components.day = originalParts.day
        }
        return calendar.date(from: components) ?? original.startsAt
    }
}
