import XCTest
@testable import Familjen

@MainActor
final class HealthReminderSchedulerTests: XCTestCase {
    func testCalendarReminderIdentityChangesWhenAppointmentTimeChanges() {
        let familyID = UUID()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let itemID = UUID()
        let original = FamilyItem(
            id: itemID, familyID: familyID, title: "Vårdbesök",
            details: nil, startsAt: now.addingTimeInterval(7_200),
            endsAt: nil, kind: .healthVisit, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [3_600],
            recurrenceFrequency: .none
        )
        let moved = FamilyItem(
            id: itemID, familyID: familyID, title: "Vårdbesök",
            details: nil, startsAt: now.addingTimeInterval(10_800),
            endsAt: nil, kind: .healthVisit, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [3_600],
            recurrenceFrequency: .none
        )

        let originalCandidate = LocalReminderScheduler.makeCandidates(for: [original], now: now).first
        let movedCandidate = LocalReminderScheduler.makeCandidates(for: [moved], now: now).first

        XCTAssertNotNil(originalCandidate)
        XCTAssertNotNil(movedCandidate)
        XCTAssertNotEqual(originalCandidate?.id, movedCandidate?.id)
        XCTAssertEqual(originalCandidate?.fireDate, original.startsAt.addingTimeInterval(-3_600))
        XCTAssertEqual(movedCandidate?.fireDate, moved.startsAt.addingTimeInterval(-3_600))
    }

    func testCalendarReminderCandidatesExcludePastFireDates() {
        let familyID = UUID()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = FamilyItem(
            id: UUID(), familyID: familyID, title: "Snart besök",
            details: nil, startsAt: now.addingTimeInterval(1_800),
            endsAt: nil, kind: .healthVisit, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [3_600, 900],
            recurrenceFrequency: .none
        )

        let candidates = LocalReminderScheduler.makeCandidates(for: [item], now: now)

        XCTAssertEqual(candidates.map(\\.offset), [900])
        XCTAssertTrue(candidates.allSatisfy { $0.fireDate > now })
    }

    func testOnlyEnabledFutureHealthRemindersBecomeCandidates() {
        let familyID = UUID()
        let memberID = UUID()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let future = HealthReminder(
            familyID: familyID, memberID: memberID, targetType: .custom,
            title: "Påminnelse", firesAt: now.addingTimeInterval(600)
        )
        let disabled = HealthReminder(
            familyID: familyID, memberID: memberID, targetType: .custom,
            title: "Avstängd", firesAt: now.addingTimeInterval(300), isEnabled: false
        )
        let past = HealthReminder(
            familyID: familyID, memberID: memberID, targetType: .custom,
            title: "Gammal", firesAt: now.addingTimeInterval(-300)
        )

        let candidates = LocalReminderScheduler.makeHealthCandidates(
            for: [disabled, past, future], now: now
        )

        XCTAssertEqual(candidates.map(\.reminder.id), [future.id])
    }

    func testHealthReminderCandidatesAreOrderedByFireDateAndStableID() {
        let familyID = UUID()
        let memberID = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let later = HealthReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            familyID: familyID, memberID: memberID, targetType: .custom,
            title: "Senare", firesAt: date.addingTimeInterval(900)
        )
        let firstAtSameTime = HealthReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            familyID: familyID, memberID: memberID, targetType: .custom,
            title: "Först", firesAt: date.addingTimeInterval(600)
        )
        let secondAtSameTime = HealthReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            familyID: familyID, memberID: memberID, targetType: .custom,
            title: "Tvåa", firesAt: date.addingTimeInterval(600)
        )

        let candidates = LocalReminderScheduler.makeHealthCandidates(
            for: [later, secondAtSameTime, firstAtSameTime], now: date
        )

        XCTAssertEqual(candidates.map(\.reminder.id), [
            firstAtSameTime.id, secondAtSameTime.id, later.id
        ])
    }

    func testObsoleteHealthReminderCleanupDoesNotRemoveOtherNotificationTypes() {
        let existing = [
            "familjen-item-calendar-1",
            "familjen-health-health-1",
            "familjen-health-health-2",
            "unrelated-notification"
        ]
        let desired: Set<String> = [
            "familjen-item-calendar-1",
            "familjen-health-health-1"
        ]

        let obsolete = LocalReminderScheduler.obsoleteManagedIdentifiers(
            existingIdentifiers: existing, desiredIdentifiers: desired
        )

        XCTAssertEqual(obsolete, ["familjen-health-health-2"])
    }
}
