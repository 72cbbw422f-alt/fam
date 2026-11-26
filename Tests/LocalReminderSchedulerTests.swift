import XCTest
@testable import Familjen

@MainActor
final class LocalReminderSchedulerTests: XCTestCase {
    func testWeeklyRecurringItemSchedulesReminderForNextOccurrence() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 9, minute: 30)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 12)))
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Veckomöte",
            details: nil, startsAt: anchor, endsAt: nil, kind: .event, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [3600], recurrenceFrequency: .weekly)

        let candidate = try XCTUnwrap(LocalReminderScheduler.makeCandidates(for: [item], now: now).first)
        let occurrence = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidate.item.startsAt)
        XCTAssertEqual(occurrence.year, 2026)
        XCTAssertEqual(occurrence.month, 11)
        XCTAssertEqual(occurrence.day, 23)
        XCTAssertEqual(occurrence.hour, 9)
        XCTAssertEqual(occurrence.minute, 30)
        XCTAssertEqual(candidate.fireDate, candidate.item.startsAt.addingTimeInterval(-3600))
        XCTAssertGreaterThan(candidate.fireDate, now)
    }

    func testMonthlyRecurringItemSchedulesReminderForClampedDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 8)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 7)))
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Månadsrutin",
            details: nil, startsAt: anchor, endsAt: nil, kind: .event, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [3600], recurrenceFrequency: .monthly)

        let candidate = try XCTUnwrap(LocalReminderScheduler.makeCandidates(for: [item], now: now).first)
        let occurrence = calendar.dateComponents([.year, .month, .day, .hour], from: candidate.item.startsAt)
        XCTAssertEqual(occurrence.year, 2026)
        XCTAssertEqual(occurrence.month, 2)
        XCTAssertEqual(occurrence.day, 28)
        XCTAssertEqual(occurrence.hour, 8)
        XCTAssertGreaterThan(candidate.fireDate, now)
    }

    func testPastNonRecurringItemDoesNotCreateReminder() {
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Gammal bokning",
            details: nil, startsAt: Date(timeIntervalSince1970: 1_700_000_000),
            endsAt: nil, kind: .appointment, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [0])
        XCTAssertTrue(LocalReminderScheduler.makeCandidates(for: [item], now: .now).isEmpty)
    }
    func testSkippedRecurringOccurrenceDoesNotScheduleReminder() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 9)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 8)))
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Veckomöte", details: nil,
            startsAt: anchor, endsAt: nil, kind: .event, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [3600], recurrenceFrequency: .weekly)
        let nextOccurrence = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 9)))
        let exception = FamilyOccurrenceException(seriesID: item.id, occurrenceDate: nextOccurrence)

        let candidates = LocalReminderScheduler.makeCandidates(for: [item], now: now, skipping: [exception])
        let candidate = try XCTUnwrap(candidates.first)
        XCTAssertEqual(calendar.component(.day, from: candidate.item.startsAt), 30)
    }

    func testMovedOccurrenceOverrideSchedulesReminderAtNewDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 9)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 8)))
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Veckomöte", details: nil,
            startsAt: anchor, endsAt: nil, kind: .event, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [3600], recurrenceFrequency: .weekly)
        let originalOccurrence = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 9)))
        let movedDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 11)))
        var overrideItem = item
        overrideItem.title = "Veckomöte – flyttat"
        overrideItem.startsAt = movedDate
        let override = FamilyOccurrenceOverride(seriesID: item.id, occurrenceDate: originalOccurrence, item: overrideItem)

        let candidate = try XCTUnwrap(LocalReminderScheduler.makeCandidates(
            for: [item], now: now, overrides: [override]
        ).first)
        XCTAssertEqual(candidate.item.title, "Veckomöte – flyttat")
        XCTAssertEqual(candidate.item.startsAt, movedDate)
        XCTAssertEqual(candidate.fireDate, movedDate.addingTimeInterval(-3600))
    }


    func testMovedPastOccurrenceStillSchedulesReminderFromOriginalSeries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 9)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 8)))
        let originalOccurrence = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 9)))
        let movedDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 11)))
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Veckomöte", details: nil,
            startsAt: anchor, endsAt: nil, kind: .event, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [3600], recurrenceFrequency: .weekly)
        var movedItem = item
        movedItem.title = "Veckomöte – flyttat"
        movedItem.startsAt = movedDate
        let override = FamilyOccurrenceOverride(seriesID: item.id, occurrenceDate: originalOccurrence, item: movedItem)

        let candidate = try XCTUnwrap(LocalReminderScheduler.makeCandidates(
            for: [item], now: now, overrides: [override]
        ).first)
        XCTAssertEqual(candidate.item.title, "Veckomöte – flyttat")
        XCTAssertEqual(candidate.item.startsAt, movedDate)
        XCTAssertEqual(candidate.fireDate, movedDate.addingTimeInterval(-3600))
    }


    func testDuplicateReminderOffsetsProduceOnlyOneCandidatePerOffset() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Dubbeltest",
            details: nil, startsAt: now.addingTimeInterval(3 * 60 * 60), endsAt: nil,
            kind: .event, memberID: nil, isRecurringYearly: false,
            reminderOffsets: [3600, 3600, 900, 900])

        let candidates = LocalReminderScheduler.makeCandidates(for: [item], now: now)

        XCTAssertEqual(candidates.count, 2)
        XCTAssertEqual(Set(candidates.map(\.offset)), Set([3600, 900]))
        XCTAssertEqual(Set(candidates.map(\.id)).count, candidates.count)
    }

    func testObsoleteCleanupOnlySelectsStaleFamiljenIdentifiers() {
        let staleCalendar = "familjen-item-old-calendar"
        let staleHealth = "familjen-health-old-health"
        let desiredCalendar = "familjen-item-current"
        let unrelated = ["other-app-reminder", "calendar-event-123"]

        let obsolete = LocalReminderScheduler.obsoleteManagedIdentifiers(
            existingIdentifiers: [staleCalendar, desiredCalendar, staleHealth] + unrelated,
            desiredIdentifiers: [desiredCalendar]
        )

        XCTAssertEqual(obsolete, [staleCalendar, staleHealth])
    }

    func testObsoleteCleanupIsStableAndDoesNotRemoveDesiredHealthReminder() {
        let stale = "familjen-health-stale"
        let desired = "familjen-health-current"

        let obsolete = LocalReminderScheduler.obsoleteManagedIdentifiers(
            existingIdentifiers: [desired, stale, stale],
            desiredIdentifiers: [desired]
        )

        XCTAssertEqual(obsolete, [stale, stale])
        XCTAssertFalse(obsolete.contains(desired))
    }

}
