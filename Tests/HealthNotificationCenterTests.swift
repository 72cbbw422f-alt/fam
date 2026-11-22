import XCTest
@testable import Familjen

@MainActor
final class HealthNotificationCenterTests: XCTestCase {
    func testNotificationCenterOnlyShowsUpcomingSharedHealthEntries() {
        let familyID = UUID()
        let memberID = UUID()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let member = FamilyMember(
            id: memberID, familyID: familyID, displayName: "Niklas",
            role: .owner, linkedUserID: nil
        )
        let sharedVisit = HealthRecord(
            familyID: familyID, memberID: memberID, type: .appointment,
            title: "Vårdcentral", startsAt: now.addingTimeInterval(3_600),
            visibility: .sharedSummary
        )
        let privateVisit = HealthRecord(
            familyID: familyID, memberID: memberID, type: .appointment,
            title: "Privat besök", startsAt: now.addingTimeInterval(7_200),
            visibility: .personal
        )
        let completedVisit = HealthRecord(
            familyID: familyID, memberID: memberID, type: .appointment,
            title: "Avklarat", startsAt: now.addingTimeInterval(8_000),
            status: .completed, visibility: .sharedSummary
        )
        let awaitingVisit = HealthRecord(
            familyID: familyID, memberID: memberID, type: .appointment,
            title: "Väntar på bekräftelse", startsAt: now.addingTimeInterval(5_400),
            status: .awaiting, visibility: .sharedSummary
        )
        let sharedReminder = HealthReminder(
            familyID: familyID, memberID: memberID, targetType: .custom,
            title: "Privat påminnelsetext", firesAt: now.addingTimeInterval(9_000),
            visibility: .sharedSummary
        )
        let privateReminder = HealthReminder(
            familyID: familyID, memberID: memberID, targetType: .custom,
            title: "Privat", firesAt: now.addingTimeInterval(10_000),
            visibility: .personal
        )
        let disabledReminder = HealthReminder(
            familyID: familyID, memberID: memberID, targetType: .custom,
            title: "Inaktiv", firesAt: now.addingTimeInterval(11_000),
            isEnabled: false, visibility: .sharedSummary
        )
        let pastReminder = HealthReminder(
            familyID: familyID, memberID: memberID, targetType: .custom,
            title: "Gammal", firesAt: now.addingTimeInterval(-60),
            visibility: .sharedSummary
        )

        let entries = NotificationsViewModel.makeUpcomingHealthEntries(
            records: [sharedVisit, privateVisit, completedVisit, awaitingVisit],
            reminders: [sharedReminder, privateReminder, disabledReminder, pastReminder],
            members: [member],
            now: now
        )

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.map(\.title), ["Vårdcentral", "Väntar på bekräftelse", "Hälsopåminnelse"])
        XCTAssertFalse(entries.contains { $0.title == "Privat besök" })
        XCTAssertTrue(entries.contains { $0.title == "Väntar på bekräftelse" })
        XCTAssertFalse(entries.contains { $0.title == "Privat påminnelsetext" })
        XCTAssertTrue(entries.allSatisfy { $0.subtitle.contains("Niklas") })
        XCTAssertEqual(entries.map(\.date), [
            sharedVisit.startsAt, awaitingVisit.startsAt, sharedReminder.firesAt
        ])
    }
}
