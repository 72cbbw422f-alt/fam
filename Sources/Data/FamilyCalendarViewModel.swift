import Combine
import Foundation

@MainActor
final class FamilyCalendarViewModel: ObservableObject {
    @Published private(set) var items: [FamilyItem] = []
    @Published private(set) var sourceItems: [FamilyItem] = []
    @Published private(set) var skippedOccurrences: [FamilyOccurrenceException] = []
    @Published private(set) var occurrenceOverrides: [FamilyOccurrenceOverride] = []
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let store: any FamilyRepository

    init(store: (any FamilyRepository)? = nil) {
        self.store = store ?? FamilyRepositoryFactory.makeDefault()
    }

    func load() async {
        isLoading = true
        members = store.members
        skippedOccurrences = store.skippedOccurrences
        occurrenceOverrides = store.occurrenceOverrides
        let privateHealthCalendarIDs = Set(
            store.healthRecords
                .filter { $0.visibility == .personal }
                .compactMap(\.calendarItemID)
        )
        sourceItems = store.items.filter { !privateHealthCalendarIDs.contains($0.id) }
        items = DashboardViewModel.project(sourceItems, from: .now, skipping: skippedOccurrences, overrides: occurrenceOverrides)
        isLoading = false
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
              isRecurringYearly: Bool, reminderOffsets: [Int], location: String?, latitude: Double? = nil, longitude: Double? = nil, recurrenceFrequency: FamilyRecurrenceFrequency = .none) async -> Bool {
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
                               latitude: latitude, longitude: longitude,
                               recurrenceFrequency: recurrenceFrequency == FamilyRecurrenceFrequency.none && isRecurringYearly ? .yearly : recurrenceFrequency)
        await load()
        if let persistenceError = store.persistenceError {
            errorMessage = persistenceError
            return false
        }
        errorMessage = nil
        await rescheduleLocalRemindersIfEnabled()
        return true
    }

    func saveOccurrenceOverride(seriesID: UUID, occurrenceDate: Date, title: String,
                                 details: String?, location: String?, latitude: Double? = nil, longitude: Double? = nil, startsAt: Date,
                                 kind: FamilyItemKind, memberIDs: [UUID], isForEveryone: Bool,
                                 responsibleMemberID: UUID?, reminderOffsets: [Int]) async -> Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 160,
              let series = store.items.first(where: { $0.id == seriesID }) else {
            errorMessage = "Aktiviteten kunde inte hittas."
            return false
        }
        let validIDs = memberIDs.filter { id in store.members.contains(where: { $0.id == id }) }
        let override = FamilyItem(
            id: series.id, familyID: series.familyID, title: clean,
            details: details, startsAt: startsAt, endsAt: nil, kind: kind,
            memberID: nil, isRecurringYearly: false, reminderOffsets: reminderOffsets,
            memberIDs: isForEveryone ? [] : validIDs, isForEveryone: isForEveryone,
            responsibleMemberID: responsibleMemberID, location: location,
            latitude: latitude, longitude: longitude,
            recurrenceFrequency: FamilyRecurrenceFrequency.none
        )
        store.saveOccurrenceOverride(seriesID: seriesID, occurrenceDate: occurrenceDate, item: override)
        await load()
        if let persistenceError = store.persistenceError {
            errorMessage = persistenceError
            return false
        }
        errorMessage = nil
        await rescheduleLocalRemindersIfEnabled()
        return true
    }

    static func filteredItems(_ items: [FamilyItem], selectedMemberIDs: Set<UUID>) -> [FamilyItem] {
        guard !selectedMemberIDs.isEmpty else { return items }
        return items.filter { item in
            item.isForEveryone || !Set(item.memberIDs).isDisjoint(with: selectedMemberIDs)
        }
    }

    func skipOccurrence(_ item: FamilyItem) async {
        store.skipOccurrence(of: item)
        await load()
        errorMessage = store.persistenceError
        guard store.persistenceError == nil else { return }
        await rescheduleLocalRemindersIfEnabled()
    }

    func delete(_ item: FamilyItem) async {
        store.deleteItem(item)
        await load()
        errorMessage = store.persistenceError
        guard store.persistenceError == nil else { return }
        await rescheduleLocalRemindersIfEnabled()
    }

    /// Occurrence edits and exceptions are written directly through the repository,
    /// so they must explicitly refresh the device's pending local reminders.
    private func rescheduleLocalRemindersIfEnabled() async {
        guard UserDefaults.standard.bool(forKey: "familjen.localRemindersEnabled") else { return }
        await LocalReminderScheduler.schedule(
            for: store.items,
            skipping: store.skippedOccurrences,
            overrides: store.occurrenceOverrides,
            healthReminders: store.healthReminders
        )
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
