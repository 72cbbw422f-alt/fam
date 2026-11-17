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
}
