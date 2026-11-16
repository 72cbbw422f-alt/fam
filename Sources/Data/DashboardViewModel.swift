import Combine
import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var family: Family?
    @Published private(set) var upcomingItems: [FamilyItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let store: any FamilyRepository

    init(store: any FamilyRepository = FamilyRepositoryFactory.makeDefault()) {
        self.store = store
    }

    var nextItem: FamilyItem? { upcomingItems.first }
    var thisWeekItems: [FamilyItem] {
        let end = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        return upcomingItems.filter { $0.startsAt < end }
    }
    var todayItems: [FamilyItem] { upcomingItems.filter { Calendar.current.isDateInToday($0.startsAt) } }
    var tomorrowItems: [FamilyItem] { upcomingItems.filter { Calendar.current.isDateInTomorrow($0.startsAt) } }
    // Bokade tider och vårdbesök hålls separerade från familjens kalenderhändelser.
    var upcomingAppointments: [FamilyItem] {
        upcomingItems.filter { [.appointment, .healthVisit, .dentist, .medication].contains($0.kind) }
            .prefix(3).map { $0 }
    }

    var upcomingEvents: [FamilyItem] {
        upcomingItems.filter { [.event, .school, .activity, .trip, .celebration, .family, .work].contains($0.kind) }
            .prefix(4).map { $0 }
    }

    var upcomingBirthdays: [FamilyItem] {
        let limit = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
        return upcomingItems.filter { $0.kind == .birthday && $0.startsAt <= limit }
            .prefix(1).map { $0 }
    }

    func load() async {
        isLoading = true
        family = store.family
        upcomingItems = Self.project(store.items, from: .now)
        isLoading = false
    }

    static func project(_ source: [FamilyItem], from date: Date) -> [FamilyItem] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return source.compactMap { item in
            guard item.kind == .birthday && item.isRecurringYearly else {
                return item.startsAt >= date ? item : nil
            }
            let parts = calendar.dateComponents([.month, .day, .hour, .minute], from: item.startsAt)
            let today = calendar.startOfDay(for: date)
            var year = calendar.component(.year, from: date)
            func occurrence(_ year: Int) -> Date? {
                var c = DateComponents()
                c.year = year; c.month = parts.month; c.day = parts.day
                c.hour = parts.hour; c.minute = parts.minute
                if parts.month == 2 && parts.day == 29 {
                    let feb = calendar.date(from: DateComponents(year: year, month: 2, day: 1))!
                    if !calendar.range(of: .day, in: .month, for: feb)!.contains(29) { c.day = 28 }
                }
                return calendar.date(from: c)
            }
            var next = occurrence(year) ?? item.startsAt
            if next < today { year += 1; next = occurrence(year) ?? item.startsAt }
            var projected = item
            projected.startsAt = next
            return projected
        }.sorted { $0.startsAt < $1.startsAt }
    }
}
