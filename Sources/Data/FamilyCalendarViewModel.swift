import Combine
import Foundation

@MainActor
final class FamilyCalendarViewModel: ObservableObject {
    @Published private(set) var items: [FamilyItem] = []
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let store = LocalFamilyStore.shared

    func load() async {
        isLoading = true
        members = store.members
        items = DashboardViewModel.project(store.items, from: .now)
        isLoading = false
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
        store.saveItem(id: id, title: clean, details: details, startsAt: startsAt,
                       kind: kind, memberID: memberID, recurring: isRecurringYearly)
        await load()
        return true
    }

    func delete(_ item: FamilyItem) async {
        store.deleteItem(item)
        await load()
    }
}
