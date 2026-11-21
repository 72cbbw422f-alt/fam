import XCTest
@testable import Familjen

@MainActor
final class HealthReminderSchedulerTests: XCTestCase {
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
