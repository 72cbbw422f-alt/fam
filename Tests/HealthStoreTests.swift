import XCTest
@testable import Familjen

@MainActor
final class HealthStoreTests: XCTestCase {
    private func makeStore() throws -> (LocalFamilyStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenHealthTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json")), directory)
    }

    func testHealthDataPersistsAcrossStoreReload() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.addChild(name: "Cleo")
        let member = try XCTUnwrap(store.members.first(where: { $0.displayName == "Cleo" }))
        let familyID = try XCTUnwrap(store.family?.id)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let record = HealthRecord(
            familyID: familyID, memberID: member.id, type: .appointment,
            title: "Vårdcentral", startsAt: now, clinic: "Hudiksvalls hälsocentral",
            latitude: 61.7284, longitude: 17.1057, visibility: .sharedSummary
        )
        let prescription = HealthPrescription(
            familyID: familyID, memberID: member.id, medicationName: "Läkemedel A",
            prescriptionValidUntil: now.addingTimeInterval(90 * 86_400),
            remainingRepeats: 2, renewalDueAt: now, renewalStatus: .due
        )
        let pickup = MedicationPickup(
            familyID: familyID, memberID: member.id, prescriptionID: prescription.id,
            medicationName: "Läkemedel A", dueAt: now
        )
        let information = HealthProfileInformation(
            familyID: familyID, memberID: member.id, type: .allergy,
            title: "Pollen", details: "Registrerad uppgift"
        )
        let reminder = HealthReminder(
            familyID: familyID, memberID: member.id, targetType: .custom,
            title: "Egen påminnelse", firesAt: now
        )

        store.saveHealthRecord(record)
        store.saveHealthPrescription(prescription)
        store.saveMedicationPickup(pickup)
        store.saveHealthProfileInformation(information)
        store.saveHealthReminder(reminder)

        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.healthRecords.map(\.id), [record.id])
        XCTAssertEqual(reloaded.healthRecords.first?.title, record.title)
        XCTAssertEqual(reloaded.healthRecords.first?.latitude, 61.7284)
        XCTAssertEqual(reloaded.healthRecords.first?.longitude, 17.1057)
        XCTAssertEqual(reloaded.healthPrescriptions.map(\.id), [prescription.id])
        XCTAssertEqual(reloaded.healthPrescriptions.first?.renewalStatus, .due)
        XCTAssertEqual(reloaded.medicationPickups.map(\.id), [pickup.id])
        XCTAssertEqual(reloaded.medicationPickups.first?.prescriptionID, prescription.id)
        XCTAssertEqual(reloaded.healthProfileInformation.map(\.id), [information.id])
        XCTAssertEqual(reloaded.healthProfileInformation.first?.type, .allergy)
        XCTAssertEqual(reloaded.healthReminders.count, 3)
        XCTAssertTrue(reloaded.healthReminders.contains { $0.id == reminder.id && $0.targetType == .custom })
        XCTAssertTrue(reloaded.healthReminders.contains { $0.targetID == prescription.id && $0.targetType == .prescriptionRenewal })
    }

    func testHealthRecordRejectsIncompleteOrOutOfRangeCoordinates() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let member = try XCTUnwrap(store.members.first)
        let familyID = try XCTUnwrap(store.family?.id)
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        let incomplete = HealthRecord(
            familyID: familyID, memberID: member.id, type: .appointment,
            title: "Ofullständig plats", startsAt: date, latitude: 61.7
        )
        let outOfRange = HealthRecord(
            familyID: familyID, memberID: member.id, type: .appointment,
            title: "Ogiltig plats", startsAt: date, latitude: 120, longitude: 17
        )
        let nonFinite = HealthRecord(
            familyID: familyID, memberID: member.id, type: .appointment,
            title: "Icke ändligt värde", startsAt: date, latitude: .nan, longitude: 17
        )

        store.saveHealthRecord(incomplete)
        store.saveHealthRecord(outOfRange)
        store.saveHealthRecord(nonFinite)

        XCTAssertTrue(store.healthRecords.isEmpty)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNil(store.persistenceError)
    }

    func testPrescriptionRenewalAndMedicationPickupHaveIndependentStatuses() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let member = try XCTUnwrap(store.members.first)
        let familyID = try XCTUnwrap(store.family?.id)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let prescription = HealthPrescription(
            familyID: familyID, memberID: member.id, medicationName: "Läkemedel B",
            renewalStatus: .requested
        )
        let pickup = MedicationPickup(
            familyID: familyID, memberID: member.id, prescriptionID: prescription.id,
            medicationName: "Läkemedel B", dueAt: date, status: .collected
        )

        store.saveHealthPrescription(prescription)
        store.saveMedicationPickup(pickup)

        XCTAssertEqual(store.healthPrescriptions.first?.renewalStatus, .requested)
        XCTAssertEqual(store.medicationPickups.first?.status, .collected)
    }

    func testDeletingHealthRecordRemovesLinkedCalendarItemAndRecordReminder() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let member = try XCTUnwrap(store.members.first)
        let familyID = try XCTUnwrap(store.family?.id)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let record = HealthRecord(
            familyID: familyID, memberID: member.id, type: .appointment,
            title: "Vårdbesök", startsAt: date, visibility: .sharedSummary
        )
        let linkedReminder = HealthReminder(
            familyID: familyID, memberID: member.id, targetType: .record,
            targetID: record.id, title: "Vårdbesök", firesAt: date
        )
        let unrelatedReminder = HealthReminder(
            familyID: familyID, memberID: member.id, targetType: .custom,
            title: "Egen påminnelse", firesAt: date
        )
        store.saveHealthRecord(record)
        store.saveHealthReminder(linkedReminder)
        store.saveHealthReminder(unrelatedReminder)
        XCTAssertEqual(store.items.count, 1)

        store.deleteHealthRecord(record.id)

        XCTAssertTrue(store.healthRecords.isEmpty)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.healthReminders.map(\.id), [unrelatedReminder.id])
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertTrue(reloaded.healthRecords.isEmpty)
        XCTAssertTrue(reloaded.items.isEmpty)
        XCTAssertEqual(reloaded.healthReminders.map(\.id), [unrelatedReminder.id])
    }

    func testDeletingPrescriptionDetachesPickupHistoryAndRemovesRenewalReminder() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let member = try XCTUnwrap(store.members.first)
        let familyID = try XCTUnwrap(store.family?.id)
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        let prescription = HealthPrescription(
            familyID: familyID, memberID: member.id, medicationName: "Läkemedel E",
            renewalDueAt: dueDate, renewalStatus: .due
        )
        store.saveHealthPrescription(prescription)
        let pickup = MedicationPickup(
            familyID: familyID, memberID: member.id, prescriptionID: prescription.id,
            medicationName: "Läkemedel E", dueAt: dueDate.addingTimeInterval(86_400)
        )
        store.saveMedicationPickup(pickup)
        XCTAssertEqual(store.healthReminders.count, 2)

        store.deleteHealthPrescription(prescription.id)

        XCTAssertTrue(store.healthPrescriptions.isEmpty)
        XCTAssertEqual(store.medicationPickups.count, 1)
        XCTAssertNil(store.medicationPickups.first?.prescriptionID)
        XCTAssertEqual(store.healthReminders.count, 1)
        XCTAssertEqual(store.healthReminders.first?.targetType, .medicationPickup)
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertTrue(reloaded.healthPrescriptions.isEmpty)
        XCTAssertNil(reloaded.medicationPickups.first?.prescriptionID)
        XCTAssertEqual(reloaded.healthReminders.count, 1)
    }

    func testPrescriptionAndPickupCreateIndependentLinkedReminders() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let member = try XCTUnwrap(store.members.first)
        let familyID = try XCTUnwrap(store.family?.id)
        let renewalDate = Date(timeIntervalSince1970: 1_800_000_000)
        let pickupDate = renewalDate.addingTimeInterval(86_400)
        let prescription = HealthPrescription(
            familyID: familyID, memberID: member.id, medicationName: "Läkemedel C",
            renewalDueAt: renewalDate, renewalStatus: .due
        )
        store.saveHealthPrescription(prescription)
        let pickup = MedicationPickup(
            familyID: familyID, memberID: member.id, prescriptionID: prescription.id,
            medicationName: "Läkemedel C", dueAt: pickupDate
        )
        store.saveMedicationPickup(pickup)

        XCTAssertEqual(store.healthReminders.count, 2)
        XCTAssertTrue(store.healthReminders.contains {
            $0.targetType == .prescriptionRenewal && $0.targetID == prescription.id && $0.firesAt == renewalDate
        })
        XCTAssertTrue(store.healthReminders.contains {
            $0.targetType == .medicationPickup && $0.targetID == pickup.id && $0.firesAt == pickupDate
        })

        var completedPickup = pickup
        completedPickup.status = .collected
        store.saveMedicationPickup(completedPickup)
        XCTAssertEqual(store.healthReminders.count, 1)
        XCTAssertEqual(store.healthReminders.first?.targetType, .prescriptionRenewal)

        var renewedPrescription = prescription
        renewedPrescription.renewalStatus = .renewed
        store.saveHealthPrescription(renewedPrescription)
        XCTAssertTrue(store.healthReminders.isEmpty)
    }

    func testUpdatingPrescriptionDoesNotDuplicateItsReminder() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let member = try XCTUnwrap(store.members.first)
        let familyID = try XCTUnwrap(store.family?.id)
        let prescription = HealthPrescription(
            familyID: familyID, memberID: member.id, medicationName: "Läkemedel D",
            renewalDueAt: Date(timeIntervalSince1970: 1_800_000_000), renewalStatus: .due
        )
        store.saveHealthPrescription(prescription)
        let originalReminderID = try XCTUnwrap(store.healthReminders.first?.id)

        var updated = prescription
        updated.renewalDueAt = Date(timeIntervalSince1970: 1_800_086_400)
        store.saveHealthPrescription(updated)

        XCTAssertEqual(store.healthReminders.count, 1)
        XCTAssertEqual(store.healthReminders.first?.id, originalReminderID)
        XCTAssertEqual(store.healthReminders.first?.firesAt, updated.renewalDueAt)
    }


    func testHealthDataRejectsUnknownFamilyMember() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let familyID = try XCTUnwrap(store.family?.id)
        let invalidRecord = HealthRecord(
            familyID: familyID, memberID: UUID(), type: .followUp,
            title: "Ogiltig", startsAt: .now
        )

        store.saveHealthRecord(invalidRecord)

        XCTAssertTrue(store.healthRecords.isEmpty)
        XCTAssertNil(store.persistenceError)
    }

    func testHealthAppointmentCreatesUpdatesAndDeletesLinkedCalendarItem() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let member = try XCTUnwrap(store.members.first)
        let familyID = try XCTUnwrap(store.family?.id)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var record = HealthRecord(
            familyID: familyID, memberID: member.id, type: .appointment,
            title: "Vårdcentral", startsAt: start, address: "Storgatan 1",
            latitude: 61.7284, longitude: 17.1057,
            reminderOffsets: [604_800, 86_400]
        )

        store.saveHealthRecord(record)
        let saved = try XCTUnwrap(store.healthRecords.first)
        let linkedID = try XCTUnwrap(saved.calendarItemID)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.id, linkedID)
        XCTAssertEqual(store.items.first?.kind, .healthVisit)
        XCTAssertEqual(store.items.first?.memberIDs, [member.id])
        XCTAssertEqual(store.items.first?.reminderOffsets, [604_800, 86_400])
        XCTAssertEqual(store.items.first?.latitude, record.latitude)
        XCTAssertEqual(store.items.first?.longitude, record.longitude)

        record = saved
        record.title = "Vårdcentral – ändrad"
        record.startsAt = start.addingTimeInterval(3_600)
        store.saveHealthRecord(record)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.id, linkedID)
        XCTAssertEqual(store.items.first?.title, "Vårdcentral – ändrad")

        store.deleteHealthRecord(saved.id)
        XCTAssertTrue(store.healthRecords.isEmpty)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testCalendarEditAndDeleteStayConsistentWithHealthRecord() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let member = try XCTUnwrap(store.members.first)
        let familyID = try XCTUnwrap(store.family?.id)
        let record = HealthRecord(
            familyID: familyID, memberID: member.id, type: .appointment,
            title: "Ursprungligt besök", startsAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        store.saveHealthRecord(record)
        let linkedItem = try XCTUnwrap(store.items.first)
        let movedDate = linkedItem.startsAt.addingTimeInterval(86_400)

        store.saveCalendarItem(
            id: linkedItem.id, title: "Flyttat besök", details: "Ny anteckning",
            startsAt: movedDate, kind: .healthVisit, memberIDs: [member.id],
            isForEveryone: false, responsibleMemberID: nil, recurring: false,
            reminderOffsets: [86_400], location: "Ny mottagning"
        )

        XCTAssertEqual(store.healthRecords.first?.title, "Flyttat besök")
        XCTAssertEqual(store.healthRecords.first?.startsAt, movedDate)
        XCTAssertEqual(store.healthRecords.first?.notes, "Ny anteckning")
        XCTAssertEqual(store.healthRecords.first?.location, "Ny mottagning")
        XCTAssertEqual(store.healthRecords.first?.latitude, linkedItem.latitude)
        XCTAssertEqual(store.healthRecords.first?.longitude, linkedItem.longitude)

        store.deleteItem(try XCTUnwrap(store.items.first))
        XCTAssertEqual(store.healthRecords.count, 1)
        XCTAssertEqual(store.healthRecords.first?.status, .cancelled)
        XCTAssertNil(store.healthRecords.first?.calendarItemID)
        XCTAssertTrue(store.items.isEmpty)
    }


    func testPrivateHealthNoteDoesNotCreateCalendarItem() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let member = try XCTUnwrap(store.members.first)
        let familyID = try XCTUnwrap(store.family?.id)
        let note = HealthRecord(
            familyID: familyID, memberID: member.id, type: .note,
            title: "Privat anteckning", startsAt: .now
        )

        store.saveHealthRecord(note)

        XCTAssertEqual(store.healthRecords.count, 1)
        XCTAssertNil(store.healthRecords.first?.calendarItemID)
        XCTAssertTrue(store.items.isEmpty)
    }


    func testPrivateHealthAppointmentsAreExcludedFromFamilyDashboardAndCalendar() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let member = try XCTUnwrap(store.members.first)
        let familyID = try XCTUnwrap(store.family?.id)
        let privateRecord = HealthRecord(
            familyID: familyID, memberID: member.id, type: .appointment,
            title: "Privat besök", startsAt: Date.now.addingTimeInterval(86_400),
            visibility: .personal
        )
        let sharedRecord = HealthRecord(
            familyID: familyID, memberID: member.id, type: .appointment,
            title: "Delat besök", startsAt: Date.now.addingTimeInterval(172_800),
            visibility: .sharedSummary
        )
        store.saveHealthRecord(privateRecord)
        store.saveHealthRecord(sharedRecord)

        let dashboard = DashboardViewModel(store: store)
        await dashboard.load()
        let calendar = FamilyCalendarViewModel(store: store)
        await calendar.load()

        XCTAssertFalse(dashboard.upcomingItems.contains { $0.title == "Privat besök" })
        XCTAssertTrue(dashboard.upcomingItems.contains { $0.title == "Delat besök" })
        XCTAssertFalse(calendar.sourceItems.contains { $0.title == "Privat besök" })
        XCTAssertTrue(calendar.sourceItems.contains { $0.title == "Delat besök" })
    }


    func testCalendarEventPersistsMapCoordinatesAndDecodesWithoutThem() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let member = try XCTUnwrap(store.members.first)
        store.saveCalendarItem(
            id: nil, title: "Möte", details: "Ta med handlingar",
            startsAt: Date(timeIntervalSince1970: 1_800_000_000), kind: .appointment,
            memberIDs: [member.id], isForEveryone: false, responsibleMemberID: nil,
            recurring: false, reminderOffsets: [3_600], location: "Hudiksvall",
            latitude: 61.7284, longitude: 17.1057
        )

        let saved = try XCTUnwrap(store.items.first)
        XCTAssertEqual(saved.latitude, 61.7284)
        XCTAssertEqual(saved.longitude, 17.1057)
        XCTAssertEqual(saved.details, "Ta med handlingar")

        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.items.first?.latitude, 61.7284)
        XCTAssertEqual(reloaded.items.first?.longitude, 17.1057)

        var legacy = saved
        legacy.latitude = nil
        legacy.longitude = nil
        let decoded = try JSONDecoder().decode(FamilyItem.self, from: JSONEncoder().encode(legacy))
        XCTAssertNil(decoded.latitude)
        XCTAssertNil(decoded.longitude)
    }

    func testHealthRecordDecodesWhenOptionalMapCoordinatesAreAbsent() throws {
        let record = HealthRecord(
            familyID: UUID(), memberID: UUID(), type: .appointment,
            title: "Gammalt besök", startsAt: Date(timeIntervalSince1970: 1_800_000_000),
            address: "Storgatan 1"
        )
        let encoded = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(HealthRecord.self, from: encoded)

        XCTAssertEqual(decoded.address, "Storgatan 1")
        XCTAssertNil(decoded.latitude)
        XCTAssertNil(decoded.longitude)
    }

    func testLegacySnapshotWithoutHealthFieldsLoadsEmptyHealthCollections() throws {
        let (_, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let familyID = UUID()
        let memberID = UUID()
        let legacyJSON = """
        {
          "family": { "id": "\(familyID.uuidString)", "name": "Familjen" },
          "members": [{
            "id": "\(memberID.uuidString)",
            "family_id": "\(familyID.uuidString)",
            "display_name": "Niklas",
            "role": "owner"
          }],
          "items": [],
          "shoppingItems": [],
          "notifications": [],
          "messages": []
        }
        """
        let fileURL = directory.appendingPathComponent("legacy.json")
        try Data(legacyJSON.utf8).write(to: fileURL)

        let reloaded = LocalFamilyStore(fileURL: fileURL)

        XCTAssertEqual(reloaded.family?.name, "Familjen")
        XCTAssertTrue(reloaded.healthRecords.isEmpty)
        XCTAssertTrue(reloaded.healthPrescriptions.isEmpty)
        XCTAssertTrue(reloaded.medicationPickups.isEmpty)
        XCTAssertTrue(reloaded.healthProfileInformation.isEmpty)
        XCTAssertTrue(reloaded.healthReminders.isEmpty)
        XCTAssertNil(reloaded.persistenceError)
    }
}
