import Combine
import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var family: Family?
    @Published private(set) var upcomingItems: [FamilyItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let store: any FamilyRepository

    init(store: (any FamilyRepository)? = nil) {
        self.store = store ?? FamilyRepositoryFactory.makeDefault()
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
        upcomingItems = Self.project(store.items, from: .now, skipping: store.skippedOccurrences)
        isLoading = false
    }

    static func project(_ source: [FamilyItem], from date: Date, skipping exceptions: [FamilyOccurrenceException] = []) -> [FamilyItem] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        return source.compactMap { item in
            let frequency = item.recurrenceFrequency == .none && item.isRecurringYearly
                ? FamilyRecurrenceFrequency.yearly : item.recurrenceFrequency
            guard frequency != .none else {
                return item.startsAt >= date ? item : nil
            }

            let anchor = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                 from: item.startsAt)
            let hour = anchor.hour ?? 0
            let minute = anchor.minute ?? 0
            let second = anchor.second ?? 0

            func dateInMonth(year: Int, month: Int) -> Date? {
                guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                      let days = calendar.range(of: .day, in: .month, for: first) else { return nil }
                let day = min(anchor.day ?? 1, days.count)
                return calendar.date(from: DateComponents(year: year, month: month, day: day,
                                                          hour: hour, minute: minute, second: second))
            }

            var next: Date?
            switch frequency {
            case .none:
                return item.startsAt >= date ? item : nil
            case .weekly:
                let interval = calendar.dateComponents([.day], from: item.startsAt, to: date).day ?? 0
                let weeks = max(0, (interval + 6) / 7)
                next = calendar.date(byAdding: .day, value: weeks * 7, to: item.startsAt)
                while let candidate = next, candidate < date {
                    next = calendar.date(byAdding: .day, value: 7, to: candidate)
                }
            case .monthly:
                let current = calendar.dateComponents([.year, .month], from: date)
                let anchorMonth = calendar.dateComponents([.year, .month], from: item.startsAt)
                let monthDelta = (current.year! - anchorMonth.year!) * 12
                    + (current.month! - anchorMonth.month!)
                for offset in max(0, monthDelta)...max(0, monthDelta) + 240 {
                    let absoluteMonth = (anchorMonth.year! * 12 + anchorMonth.month! - 1) + offset
                    let year = absoluteMonth / 12
                    let month = absoluteMonth % 12 + 1
                    if let candidate = dateInMonth(year: year, month: month), candidate >= date {
                        next = candidate
                        break
                    }
                }
            case .yearly:
                let currentYear = calendar.component(.year, from: date)
                let anchorYear = anchor.year ?? currentYear
                for year in max(anchorYear, currentYear)...max(anchorYear, currentYear) + 20 {
                    if let candidate = dateInMonth(year: year, month: anchor.month ?? 1), candidate >= date {
                        next = candidate
                        break
                    }
                }
            }

            guard var occurrence = next else { return nil }
            for _ in 0..<400 {
                guard exceptions.contains(where: { $0.seriesID == item.id && calendar.isDate($0.occurrenceDate, inSameDayAs: occurrence) }) else { break }
                let searchDate = calendar.date(byAdding: .day, value: 1, to: occurrence) ?? occurrence.addingTimeInterval(86_400)
                let candidate: Date?
                switch frequency {
                case .weekly:
                    let days = max(0, calendar.dateComponents([.day], from: item.startsAt, to: searchDate).day ?? 0)
                    candidate = calendar.date(byAdding: .day, value: max(0, (days + 6) / 7) * 7, to: item.startsAt)
                case .monthly:
                    let parts = calendar.dateComponents([.year, .month], from: searchDate)
                    candidate = dateInMonth(year: parts.year ?? 2000, month: parts.month ?? 1)
                case .yearly:
                    candidate = dateInMonth(year: calendar.component(.year, from: searchDate), month: anchor.month ?? 1)
                case .none: candidate = nil
                }
                guard let candidate else { return nil }
                occurrence = candidate
            }
            if exceptions.contains(where: { $0.seriesID == item.id && calendar.isDate($0.occurrenceDate, inSameDayAs: occurrence) }) { return nil }
            var projected = item
            projected.startsAt = occurrence
            return projected
        }.sorted { $0.startsAt < $1.startsAt }
    }
}
