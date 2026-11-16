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
    private let store = LocalFamilyStore.shared

    func load() async {
        isLoading = true
        members = store.members
        items = DashboardViewModel.project(store.items, from: .now)
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
              memberID: UUID?, isRecurringYearly: Bool) async -> Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 160 else {
            errorMessage = "Ange en rubrik på 1–160 tecken."
            return false
        }
        let persistedDate = preservedBirthdayDate(
            id: id, proposedDate: startsAt, kind: kind, recurring: isRecurringYearly
        )
        store.saveItem(id: id, title: clean, details: details, startsAt: persistedDate,
                       kind: kind, memberID: memberID, recurring: isRecurringYearly)
        await load()
        return true
    }

    func delete(_ item: FamilyItem) async {
        store.deleteItem(item)
        await load()
    }

    // The calendar displays a recurring birthday in its next upcoming year.
    // Persist the original birth year when that projected row is edited.
    private func preservedBirthdayDate(id: UUID?, proposedDate: Date,
                                       kind: FamilyItemKind, recurring: Bool) -> Date {
        guard kind == .birthday, recurring, let id,
              let original = store.items.first(where: { $0.id == id }),
              original.kind == .birthday, original.isRecurringYearly else {
            return proposedDate
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let originalParts = calendar.dateComponents([.year, .month, .day], from: original.startsAt)
        var editedParts = calendar.dateComponents([.month, .day, .hour, .minute, .second],
                                                   from: proposedDate)
        guard let birthYear = originalParts.year else { return proposedDate }

        // A 29 February birthday is displayed as 28 February in non-leap years.
        // If the user leaves that projected date unchanged, retain 29 February.
        if originalParts.month == 2, originalParts.day == 29,
           editedParts.month == 2, editedParts.day == 28 {
            editedParts.day = 29
        }
        editedParts.year = birthYear
        return calendar.date(from: editedParts) ?? original.startsAt
    }
}
