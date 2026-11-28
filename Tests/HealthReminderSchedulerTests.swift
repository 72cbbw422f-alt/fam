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


    func testPrescriptionRenewalUpsertDeduplicatesAndClearsAllLinkedReminders() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenPrescriptionReminder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let familyID = try XCTUnwrap(store.family?.id)
        let memberID = try XCTUnwrap(store.members.first?.id)
        let prescriptionID = UUID()
        let prescription = HealthPrescription(
            id: prescriptionID, familyID: familyID, memberID: memberID,
            medicationName: "Läkemedel", renewalDueAt: Date().addingTimeInterval(86_400),
            renewalStatus: .due
        )
        store.saveHealthPrescription(prescription)
        XCTAssertEqual(store.healthReminders.filter {
            $0.targetType == .prescriptionRenewal && $0.targetID == prescriptionID
        }.count, 1)

        let duplicate = HealthReminder(
            familyID: familyID, memberID: memberID, targetType: .prescriptionRenewal,
            targetID: prescriptionID, title: "Gammal dubblett",
            firesAt: Date().addingTimeInterval(172_800)
        )
        store.saveHealthReminder(duplicate)
        XCTAssertEqual(store.healthReminders.filter {
            $0.targetType == .prescriptionRenewal && $0.targetID == prescriptionID
        }.count, 2)

        var rescheduled = try XCTUnwrap(store.healthPrescriptions.first)
        rescheduled.renewalDueAt = Date().addingTimeInterval(259_200)
        store.saveHealthPrescription(rescheduled)
        let linked = store.healthReminders.filter {
            $0.targetType == .prescriptionRenewal && $0.targetID == prescriptionID
        }
        XCTAssertEqual(linked.count, 1)
        XCTAssertEqual(linked.first?.firesAt, rescheduled.renewalDueAt)

        rescheduled.renewalStatus = .renewed
        store.saveHealthPrescription(rescheduled)
        XCTAssertFalse(store.healthReminders.contains {
            $0.targetType == .prescriptionRenewal && $0.targetID == prescriptionID
        })
    }


    func testCompletedOrCancelledMedicationPickupRemovesLinkedReminder() throws {
        for status in [MedicationPickupStatus.collected, .cancelled] {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("FamiljenPickupStatus-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
            store.createFamily(name: "Familjen", ownerName: "Niklas")
            let familyID = try XCTUnwrap(store.family?.id)
            let memberID = try XCTUnwrap(store.members.first?.id)
            let pickup = MedicationPickup(
                familyID: familyID, memberID: memberID, medicationName: "Läkemedel",
                dueAt: Date().addingTimeInterval(86_400)
            )
            store.saveMedicationPickup(pickup)
            let reminder = try XCTUnwrap(store.healthReminders.first {
                $0.targetType == .medicationPickup && $0.targetID == pickup.id
            })
            var updated = try XCTUnwrap(store.medicationPickups.first)
            updated.status = status
            store.saveMedicationPickup(updated)

            XCTAssertFalse(store.healthReminders.contains { $0.id == reminder.id })
            XCTAssertEqual(store.medicationPickups.first?.status, status)
            let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
            XCTAssertFalse(reloaded.healthReminders.contains { $0.id == reminder.id })
        }
    }

    func testDeletingMedicationPickupRemovesLinkedReminder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenPickupDelete-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let familyID = try XCTUnwrap(store.family?.id)
        let memberID = try XCTUnwrap(store.members.first?.id)
        let pickup = MedicationPickup(
            familyID: familyID, memberID: memberID, medicationName: "Läkemedel",
            dueAt: Date().addingTimeInterval(86_400)
        )
        store.saveMedicationPickup(pickup)
        let reminder = try XCTUnwrap(store.healthReminders.first {
            $0.targetType == .medicationPickup && $0.targetID == pickup.id
        })

        store.deleteMedicationPickup(pickup.id)

        XCTAssertFalse(store.healthReminders.contains { $0.id == reminder.id })
        XCTAssertFalse(store.medicationPickups.contains { $0.id == pickup.id })
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertFalse(reloaded.healthReminders.contains { $0.id == reminder.id })
    }

    func testDeletingPrescriptionPreservesPickupHistoryAndRemovesRenewalReminder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenPrescriptionDelete-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let familyID = try XCTUnwrap(store.family?.id)
        let memberID = try XCTUnwrap(store.members.first?.id)
        let prescription = HealthPrescription(
            familyID: familyID, memberID: memberID, medicationName: "Läkemedel",
            renewalDueAt: Date().addingTimeInterval(86_400), renewalStatus: .due
        )
        store.saveHealthPrescription(prescription)
        let pickup = MedicationPickup(
            familyID: familyID, memberID: memberID, prescriptionID: prescription.id,
            medicationName: "Läkemedel", dueAt: Date().addingTimeInterval(172_800)
        )
        store.saveMedicationPickup(pickup)
        let renewalReminder = try XCTUnwrap(store.healthReminders.first {
            $0.targetType == .prescriptionRenewal && $0.targetID == prescription.id
        })
        let pickupReminder = try XCTUnwrap(store.healthReminders.first {
            $0.targetType == .medicationPickup && $0.targetID == pickup.id
        })

        store.deleteHealthPrescription(prescription.id)

        XCTAssertFalse(store.healthReminders.contains { $0.id == renewalReminder.id })
        XCTAssertTrue(store.healthReminders.contains { $0.id == pickupReminder.id })
        XCTAssertEqual(store.medicationPickups.first?.id, pickup.id)
        XCTAssertNil(store.medicationPickups.first?.prescriptionID)
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.medicationPickups.first?.id, pickup.id)
        XCTAssertNil(reloaded.medicationPickups.first?.prescriptionID)
        XCTAssertFalse(reloaded.healthReminders.contains { $0.id == renewalReminder.id })
        XCTAssertTrue(reloaded.healthReminders.contains { $0.id == pickupReminder.id })
    }


    func testInactiveHealthTargetsCannotReceiveNewLinkedReminders() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenInactiveTargets-\\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let familyID = try XCTUnwrap(store.family?.id)
        let memberID = try XCTUnwrap(store.members.first?.id)
        let future = Date().addingTimeInterval(86_400)

        let record = HealthRecord(
            familyID: familyID, memberID: memberID, type: .appointment,
            title: "Avslutat besök", startsAt: future, status: .completed
        )
        store.saveHealthRecord(record)
        let prescription = HealthPrescription(
            familyID: familyID, memberID: memberID, medicationName: "Förnyat recept",
            renewalDueAt: future, renewalStatus: .renewed
        )
        store.saveHealthPrescription(prescription)
        let pickup = MedicationPickup(
            familyID: familyID, memberID: memberID, medicationName: "Redan uthämtat",
            dueAt: future, status: .collected
        )
        store.saveMedicationPickup(pickup)

        let invalidReminders = [
            HealthReminder(
                familyID: familyID, memberID: memberID, targetType: .record,
                targetID: record.id, title: "Ska inte läggas till", firesAt: future
            ),
            HealthReminder(
                familyID: familyID, memberID: memberID, targetType: .prescriptionRenewal,
                targetID: prescription.id, title: "Ska inte läggas till", firesAt: future
            ),
            HealthReminder(
                familyID: familyID, memberID: memberID, targetType: .medicationPickup,
                targetID: pickup.id, title: "Ska inte läggas till", firesAt: future
            )
        ]

        for reminder in invalidReminders {
            store.saveHealthReminder(reminder)
        }

        XCTAssertTrue(store.healthReminders.isEmpty)
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertTrue(reloaded.healthReminders.isEmpty)
    }

}
