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

        XCTAssertEqual(obsolete, [stale])
        XCTAssertFalse(obsolete.contains(desired))
    }


    func testCalendarCandidateGenerationDoesNotConsumeSharedCapBeforeHealthMerge() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let items = (0..<75).map { index in
            FamilyItem(
                id: UUID(), familyID: UUID(), title: "Aktivitet \(index)",
                details: nil, startsAt: now.addingTimeInterval(TimeInterval(3600 + index * 60)),
                endsAt: nil, kind: .event, memberID: nil,
                isRecurringYearly: false, reminderOffsets: [0]
            )
        }

        let candidates = LocalReminderScheduler.makeCandidates(for: items, now: now)

        // The 60-request limit is shared with health reminders and must be applied
        // only after both candidate types have been merged by fire date.
        XCTAssertEqual(candidates.count, 75)
    }

    func testSharedCapacitySelectionKeepsEarlierHealthReminderAheadOfCalendarBacklog() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendarCandidates = (0..<75).map { index in
            (
                identifier: "familjen-item-\(index)",
                fireDate: now.addingTimeInterval(TimeInterval(3600 + index))
            )
        }
        let healthCandidates = [
            (
                identifier: "familjen-health-urgent",
                fireDate: now.addingTimeInterval(60)
            )
        ]

        let selected = LocalReminderScheduler.selectCandidates(
            calendar: calendarCandidates,
            health: healthCandidates,
            limit: 60,
            fireDate: { $0.fireDate },
            identifier: { $0.identifier }
        )

        XCTAssertEqual(selected.count, 60)
        XCTAssertEqual(selected.first?.identifier, "familjen-health-urgent")
        XCTAssertTrue(selected.contains { $0.identifier == "familjen-health-urgent" })
        XCTAssertEqual(selected.filter { $0.identifier.hasPrefix("familjen-item-") }.count, 59)
    }

    func testSharedCapacitySelectionUsesIdentifierAsDeterministicTieBreaker() {
        let fireDate = Date(timeIntervalSince1970: 1_800_000_060)
        let calendarCandidates = [
            (identifier: "calendar-c", fireDate: fireDate),
            (identifier: "calendar-a", fireDate: fireDate)
        ]
        let healthCandidates = [
            (identifier: "health-b", fireDate: fireDate)
        ]

        let selected = LocalReminderScheduler.selectCandidates(
            calendar: calendarCandidates,
            health: healthCandidates,
            limit: 3,
            fireDate: { $0.fireDate },
            identifier: { $0.identifier }
        )

        XCTAssertEqual(selected.map(\.identifier), ["calendar-a", "calendar-c", "health-b"])
    }

    func testSharedCapacitySelectionKeepsNearestCandidatesRegardlessOfInputOrder() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendarCandidates = (0..<70).reversed().map { index in
            (identifier: "calendar-\(index)", fireDate: now.addingTimeInterval(TimeInterval(index + 10)))
        }
        let selected = LocalReminderScheduler.selectCandidates(
            calendar: calendarCandidates,
            health: [],
            limit: 5,
            fireDate: { $0.fireDate },
            identifier: { $0.identifier }
        )

        XCTAssertEqual(selected.map(\.identifier), [
            "calendar-0", "calendar-1", "calendar-2", "calendar-3", "calendar-4"
        ])
    }

    func testSharedCapacitySelectionReturnsNoCandidatesForZeroLimit() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let candidates = [(identifier: "candidate", fireDate: now.addingTimeInterval(60))]

        let selected = LocalReminderScheduler.selectCandidates(
            calendar: candidates,
            health: [],
            limit: 0,
            fireDate: { $0.fireDate },
            identifier: { $0.identifier }
        )

        XCTAssertTrue(selected.isEmpty)
    }


    func testWeeklyRecurringItemSchedulesMultipleUpcomingOccurrences() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 9)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 8)))
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Veckomöte", details: nil,
            startsAt: anchor, endsAt: nil, kind: .event, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [3600], recurrenceFrequency: .weekly)

        let candidates = LocalReminderScheduler.makeCandidates(for: [item], now: now)

        XCTAssertEqual(candidates.count, 12)
        XCTAssertEqual(Set(candidates.map(\.id)).count, 12)
        let days = candidates.map { calendar.component(.day, from: $0.item.startsAt) }
        XCTAssertEqual(days, [23, 30, 7, 14, 21, 28, 4, 11, 18, 25, 1, 8])
        XCTAssertTrue(candidates.allSatisfy { $0.fireDate > now })
    }


    func testPersonalHealthCalendarItemsAreExcludedFromLocalReminderCandidates() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let privateID = UUID()
        let sharedID = UUID()
        let familyID = UUID()
        let items = [
            FamilyItem(
                id: privateID, familyID: familyID, title: "Privat läkarbesök",
                details: nil, startsAt: now.addingTimeInterval(3_600), endsAt: nil,
                kind: .healthVisit, memberID: nil, isRecurringYearly: false,
                reminderOffsets: [0]
            ),
            FamilyItem(
                id: sharedID, familyID: familyID, title: "Gemensam aktivitet",
                details: nil, startsAt: now.addingTimeInterval(7_200), endsAt: nil,
                kind: .event, memberID: nil, isRecurringYearly: false,
                reminderOffsets: [0]
            )
        ]

        let visible = LocalReminderScheduler.excludingPrivateHealthItems(
            items, privateHealthCalendarIDs: [privateID]
        )
        let candidates = LocalReminderScheduler.makeCandidates(for: visible, now: now)

        XCTAssertEqual(visible.map(\.id), [sharedID])
        XCTAssertEqual(candidates.map(\.item.id), [sharedID])
        XCTAssertFalse(candidates.contains { $0.item.title == "Privat läkarbesök" })
    }

    func testMonthlyRecurringItemReturnsToAnchorDayAfterShortMonths() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 31, hour: 8)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 7)))
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Månadsrutin",
            details: nil, startsAt: anchor, endsAt: nil, kind: .event, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [0], recurrenceFrequency: .monthly)

        let candidates = LocalReminderScheduler.makeCandidates(for: [item], now: now)

        XCTAssertEqual(candidates.count, 12)
        let components = candidates.map {
            calendar.dateComponents([.year, .month, .day], from: $0.item.startsAt)
        }
        XCTAssertEqual(components.map(\.month), Array(1...12))
        XCTAssertEqual(components.map(\.day), [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31])
    }

    func testYearlyLeapDayRecurrenceReturnsToFebruary29InLeapYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 29, hour: 9)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 8)))
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Årsdag",
            details: nil, startsAt: anchor, endsAt: nil, kind: .birthday, memberID: nil,
            isRecurringYearly: true, reminderOffsets: [0], recurrenceFrequency: .yearly)

        let candidates = LocalReminderScheduler.makeCandidates(for: [item], now: now)

        XCTAssertEqual(candidates.count, 2)
        let components = candidates.map {
            calendar.dateComponents([.year, .month, .day], from: $0.item.startsAt)
        }
        XCTAssertEqual(components.map(\.year), [2027, 2028])
        XCTAssertEqual(components.map(\.month), [2, 2])
        XCTAssertEqual(components.map(\.day), [28, 29])
    }

}
