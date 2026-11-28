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
    // Startsidan visar idag och imorgon i närtidsöversikten. De separata
    // listorna börjar därför först dagen efter, så samma aktivitet inte upprepas.
    private var startOfDayAfterTomorrow: Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: .now))
        return tomorrow ?? .now
    }

    // Bokade tider och vårdbesök hålls separerade från familjens kalenderhändelser.
    var upcomingAppointments: [FamilyItem] {
        upcomingItems.filter {
            $0.startsAt >= startOfDayAfterTomorrow
                && [.appointment, .healthVisit, .dentist, .medication].contains($0.kind)
        }
        .prefix(3).map { $0 }
    }

    var upcomingEvents: [FamilyItem] {
        upcomingItems.filter {
            $0.startsAt >= startOfDayAfterTomorrow
                && [.event, .school, .activity, .trip, .celebration, .family, .work].contains($0.kind)
        }
        .prefix(4).map { $0 }
    }

    var upcomingBirthdays: [FamilyItem] {
        let limit = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
        return upcomingItems.filter {
            $0.kind == .birthday && $0.startsAt >= startOfDayAfterTomorrow && $0.startsAt <= limit
        }
        .prefix(1).map { $0 }
    }

    func load() async {
        isLoading = true
        family = store.family
        let privateHealthCalendarIDs = Set(
            store.healthRecords
                .filter { $0.visibility == .personal }
                .compactMap(\.calendarItemID)
        )
        let dashboardItems = store.items.filter { !privateHealthCalendarIDs.contains($0.id) }
        upcomingItems = Self.project(dashboardItems, from: .now, skipping: store.skippedOccurrences, overrides: store.occurrenceOverrides)
        isLoading = false
    }

    static func project(_ source: [FamilyItem], from date: Date, skipping exceptions: [FamilyOccurrenceException] = [],
                        overrides: [FamilyOccurrenceOverride] = [],
                        timeZone: TimeZone = .current) -> [FamilyItem] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

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
                var weeks = max(0, (interval + 6) / 7)
                next = calendar.date(byAdding: .day, value: weeks * 7, to: item.startsAt)
                while let candidate = next, candidate < date {
                    weeks += 1
                    next = calendar.date(byAdding: .day, value: weeks * 7, to: item.startsAt)
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

            func nextOccurrence(after occurrence: Date) -> Date? {
                switch frequency {
                case .none:
                    return nil
                case .weekly:
                    // Always derive the next week from the series anchor. Adding
                    // seven days to a normalized DST-gap occurrence (for example
                    // 02:30 becoming 03:30) would otherwise preserve the drift.
                    let elapsedDays = calendar.dateComponents([.day], from: item.startsAt, to: occurrence).day ?? 0
                    let nextWeek = max(0, elapsedDays / 7 + 1)
                    return calendar.date(byAdding: .day, value: nextWeek * 7, to: item.startsAt)
                case .monthly:
                    guard let firstOfNextMonth = calendar.date(byAdding: .month, value: 1,
                                                                 to: calendar.dateInterval(of: .month, for: occurrence)?.start ?? occurrence) else {
                        return nil
                    }
                    let parts = calendar.dateComponents([.year, .month], from: firstOfNextMonth)
                    return dateInMonth(year: parts.year ?? 2000, month: parts.month ?? 1)
                case .yearly:
                    let year = calendar.component(.year, from: occurrence) + 1
                    return dateInMonth(year: year, month: anchor.month ?? 1)
                }
            }

            guard var occurrence = next else { return nil }
            var attempts = 0
            var projectedCandidates: [FamilyItem] = []
            while true {
                let isSkipped = exceptions.contains {
                    $0.seriesID == item.id && calendar.isDate($0.occurrenceDate, inSameDayAs: occurrence)
                }
                let matchingOverride = overrides.first {
                    $0.seriesID == item.id && calendar.isDate($0.occurrenceDate, inSameDayAs: occurrence)
                }

                if let matchingOverride {
                    if matchingOverride.item.startsAt >= date {
                        var projectedOverride = matchingOverride.item
                        projectedOverride.recurrenceFrequency = frequency
                        projectedOverride.isRecurringYearly = frequency == .yearly
                        projectedOverride.recurrenceOccurrenceDate = matchingOverride.occurrenceDate
                        projectedCandidates.append(projectedOverride)
                    }
                } else if !isSkipped {
                    var projected = item
                    projected.startsAt = occurrence
                    projected.recurrenceFrequency = frequency
                    projected.isRecurringYearly = frequency == .yearly
                    projected.recurrenceOccurrenceDate = occurrence
                    projectedCandidates.append(projected)
                    break
                }

                guard attempts < 400, let candidate = nextOccurrence(after: occurrence),
                      candidate > occurrence else { break }
                occurrence = candidate
                attempts += 1
            }

            // An override can belong to an older original date but be moved into
            // the future. Include it when choosing the next effective occurrence.
            projectedCandidates.append(contentsOf: overrides.compactMap { override in
                guard override.seriesID == item.id,
                      override.item.startsAt >= date else { return nil }
                var projectedOverride = override.item
                projectedOverride.recurrenceFrequency = frequency
                projectedOverride.isRecurringYearly = frequency == .yearly
                projectedOverride.recurrenceOccurrenceDate = override.occurrenceDate
                return projectedOverride
            })
            return projectedCandidates.min { $0.startsAt < $1.startsAt }
        }.sorted { $0.startsAt < $1.startsAt }
    }
}
