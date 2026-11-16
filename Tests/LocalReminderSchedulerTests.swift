import XCTest
@testable import Familjen

@MainActor
final class LocalReminderSchedulerTests: XCTestCase {
    private func makeItem(
        startsAt: Date,
        reminderOffsets: [Int]?
    ) -> FamilyItem {
        FamilyItem(
            id: UUID(),
            familyID: UUID(),
            title: "Testaktivitet",
            details: nil,
            startsAt: startsAt,
            endsAt: nil,
            kind: .appointment,
            memberID: nil,
            isRecurringYearly: false,
            reminderOffsets: reminderOffsets
        )
    }

    func testDuplicateOffsetsProduceOnlyOneCandidatePerReminder() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = makeItem(startsAt: now.addingTimeInterval(3_600), reminderOffsets: [900, 900, 300])

        let candidates = LocalReminderScheduler.makeCandidates(for: [item], now: now)

        XCTAssertEqual(candidates.count, 2)
        XCTAssertEqual(Set(candidates.map(\.offset)), Set([900, 300]))
        XCTAssertEqual(Set(candidates.map(\.id)).count, 2)
    }

    func testPastAndNegativeOffsetRemindersAreExcluded() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = makeItem(
            startsAt: now.addingTimeInterval(3_600),
            reminderOffsets: [7_200, 3_600, 0, -300]
        )

        let candidates = LocalReminderScheduler.makeCandidates(for: [item], now: now)

        XCTAssertEqual(candidates.map(\.offset), [0])
        XCTAssertTrue(candidates.allSatisfy { $0.fireDate > now })
    }

    func testNilOffsetsUseLegacyDefaultReminders() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = makeItem(startsAt: now.addingTimeInterval(3 * 24 * 60 * 60), reminderOffsets: nil)

        let candidates = LocalReminderScheduler.makeCandidates(for: [item], now: now)

        XCTAssertEqual(Set(candidates.map(\.offset)), Set([24 * 60 * 60, 60 * 60]))
        XCTAssertEqual(candidates.count, 2)
    }

    func testOnlySixtySoonestRemindersAreSelected() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let items = (1...70).map { hours in
            makeItem(startsAt: now.addingTimeInterval(TimeInterval(hours * 3_600)), reminderOffsets: [0])
        }

        let candidates = LocalReminderScheduler.makeCandidates(for: items, now: now)

        XCTAssertEqual(candidates.count, 60)
        XCTAssertEqual(candidates.first?.fireDate, now.addingTimeInterval(3_600))
        XCTAssertEqual(candidates.last?.fireDate, now.addingTimeInterval(60 * 3_600))
    }
}
