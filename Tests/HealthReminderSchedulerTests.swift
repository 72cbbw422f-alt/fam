import XCTest
@testable import Familjen

@MainActor
final class HealthReminderSchedulerTests: XCTestCase {
    func testCompletingHealthRecordRemovesItsRecordReminder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenHealthReminder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let familyID = try XCTUnwrap(store.family?.id)
        let memberID = try XCTUnwrap(store.members.first?.id)
        let record = HealthRecord(
            familyID: familyID, memberID: memberID, type: .appointment,
            title: "Läkarbesök", startsAt: Date().addingTimeInterval(86_400)
        )
        store.saveHealthRecord(record)
        let saved = try XCTUnwrap(store.healthRecords.first)
        let reminder = HealthReminder(
            familyID: familyID, memberID: memberID, targetType: .record,
            targetID: saved.id, title: "Läkarbesök", firesAt: Date().addingTimeInterval(3_600)
        )
        store.saveHealthReminder(reminder)
        XCTAssertTrue(store.healthReminders.contains(where: { $0.id == reminder.id }))

        var completed = saved
        completed.status = .completed
        store.saveHealthRecord(completed)

        XCTAssertFalse(store.healthReminders.contains(where: { $0.id == reminder.id }))
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertFalse(reloaded.healthReminders.contains(where: { $0.id == reminder.id }))
    }

    func testCompletedOrCancelledAppointmentIsRemovedFromCalendar() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenHealthStatus-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let familyID = try XCTUnwrap(store.family?.id)
        let memberID = try XCTUnwrap(store.members.first?.id)
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        let record = HealthRecord(
            familyID: familyID, memberID: memberID, type: .appointment,
            title: "Vårdbesök", startsAt: date, status: .planned,
            reminderOffsets: [3600]
        )
        store.saveHealthRecord(record)
        let linkedCalendarID = try XCTUnwrap(store.healthRecords.first?.calendarItemID)
        XCTAssertTrue(store.items.contains(where: { $0.id == linkedCalendarID }))

        var completed = try XCTUnwrap(store.healthRecords.first)
        completed.status = .completed
        store.saveHealthRecord(completed)
        XCTAssertFalse(store.items.contains(where: { $0.id == linkedCalendarID }))
        XCTAssertEqual(store.healthRecords.first?.status, .completed)
        XCTAssertNil(store.healthRecords.first?.calendarItemID)

        var cancelled = try XCTUnwrap(store.healthRecords.first)
        cancelled.status = .cancelled
        store.saveHealthRecord(cancelled)
        XCTAssertFalse(store.items.contains(where: { $0.id == linkedCalendarID }))
        XCTAssertNil(store.healthRecords.first?.calendarItemID)
    }

    func testFailedReminderAddPreservesObsoleteNotificationsForRetry() {
        XCTAssertFalse(LocalReminderScheduler.shouldRemoveObsoleteReminders(afterSuccessfulAdds: false))
        XCTAssertTrue(LocalReminderScheduler.shouldRemoveObsoleteReminders(afterSuccessfulAdds: true))
    }

    func testCalendarReminderIdentityChangesWhenAppointmentTimeChanges() {
        let familyID = UUID()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let itemID = UUID()
        let original = FamilyItem(
            id: itemID, familyID: familyID, title: "Vårdbesök",
            details: nil, startsAt: now.addingTimeInterval(7_200),
            endsAt: nil, kind: .healthVisit, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [3_600],
            recurrenceFrequency: FamilyRecurrenceFrequency.none
        )
        let moved = FamilyItem(
            id: itemID, familyID: familyID, title: "Vårdbesök",
            details: nil, startsAt: now.addingTimeInterval(10_800),
            endsAt: nil, kind: .healthVisit, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [3_600],
            recurrenceFrequency: FamilyRecurrenceFrequency.none
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
            recurrenceFrequency: FamilyRecurrenceFrequency.none
        )

        let candidates = LocalReminderScheduler.makeCandidates(for: [item], now: now)

        XCTAssertEqual(candidates.map(\.offset), [900])
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

    func testReminderReconciliationRequiresSuccessfulPersistence() {
        XCTAssertTrue(FamilyStore.shouldRescheduleReminders(afterPersistenceError: nil))
        XCTAssertFalse(FamilyStore.shouldRescheduleReminders(
            afterPersistenceError: "Ändringen kunde inte sparas."
        ))
    }


    func testDeletingLinkedCalendarItemRemovesRecordReminder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenHealthDelete-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let familyID = try XCTUnwrap(store.family?.id)
        let memberID = try XCTUnwrap(store.members.first?.id)
        let record = HealthRecord(
            familyID: familyID, memberID: memberID, type: .appointment,
            title: "Läkarbesök", startsAt: Date().addingTimeInterval(86_400)
        )
        store.saveHealthRecord(record)
        let saved = try XCTUnwrap(store.healthRecords.first)
        let calendarID = try XCTUnwrap(saved.calendarItemID)
        let reminder = HealthReminder(
            familyID: familyID, memberID: memberID, targetType: .record,
            targetID: saved.id, title: "Läkarbesök", firesAt: Date().addingTimeInterval(3_600)
        )
        store.saveHealthReminder(reminder)

        let calendarItem = try XCTUnwrap(store.items.first(where: { $0.id == calendarID }))
        store.deleteItem(calendarItem)

        XCTAssertEqual(store.healthRecords.first?.status, .cancelled)
        XCTAssertNil(store.healthRecords.first?.calendarItemID)
        XCTAssertFalse(store.healthReminders.contains(where: { $0.id == reminder.id }))
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertFalse(reloaded.healthReminders.contains(where: { $0.id == reminder.id }))
    }

    func testChangingLinkedAppointmentToOrdinaryEventRemovesRecordReminder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenHealthEdit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let familyID = try XCTUnwrap(store.family?.id)
        let memberID = try XCTUnwrap(store.members.first?.id)
        let record = HealthRecord(
            familyID: familyID, memberID: memberID, type: .appointment,
            title: "Läkarbesök", startsAt: Date().addingTimeInterval(86_400)
        )
        store.saveHealthRecord(record)
        let saved = try XCTUnwrap(store.healthRecords.first)
        let calendarID = try XCTUnwrap(saved.calendarItemID)
        let reminder = HealthReminder(
            familyID: familyID, memberID: memberID, targetType: .record,
            targetID: saved.id, title: "Läkarbesök", firesAt: Date().addingTimeInterval(3_600)
        )
        store.saveHealthReminder(reminder)

        store.saveCalendarItem(
            id: calendarID, title: "Privat händelse", details: nil,
            startsAt: Date().addingTimeInterval(172_800), kind: .event,
            memberIDs: [], isForEveryone: true, responsibleMemberID: nil,
            recurring: false, reminderOffsets: []
        )

        XCTAssertEqual(store.healthRecords.first?.status, .cancelled)
        XCTAssertNil(store.healthRecords.first?.calendarItemID)
        XCTAssertFalse(store.healthReminders.contains(where: { $0.id == reminder.id }))
    }

}
