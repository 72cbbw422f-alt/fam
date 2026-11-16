import Combine
import EventKit
import Foundation

struct AppleCalendarEntry: Identifiable, Equatable {
    let id: String
    let title: String
    let startsAt: Date
    let endsAt: Date?
    let calendarTitle: String
    let isAllDay: Bool
}

@MainActor
final class AppleCalendarImport: ObservableObject {
    @Published private(set) var entries: [AppleCalendarEntry] = []
    @Published private(set) var isEnabled = false
    @Published private(set) var accessDenied = false
    @Published var errorMessage: String?

    private let store = EKEventStore()

    func enableAndLoad() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            guard granted else {
                accessDenied = true
                errorMessage = "Ge Familjen åtkomst till Kalender i Inställningar för att visa dina händelser."
                return
            }
            isEnabled = true
            loadEvents()
        } catch {
            errorMessage = "Apple Kalender kunde inte öppnas just nu."
        }
    }

    func refresh() {
        guard isEnabled else { return }
        loadEvents()
    }

    private func loadEvents() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        guard let end = calendar.date(byAdding: .month, value: 12, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        entries = store.events(matching: predicate)
            .filter { !$0.isCanceled }
            .sorted { $0.startDate < $1.startDate }
            .map {
                AppleCalendarEntry(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title ?? "Händelse",
                    startsAt: $0.startDate,
                    endsAt: $0.endDate,
                    calendarTitle: $0.calendar.title,
                    isAllDay: $0.isAllDay
                )
            }
    }
}
