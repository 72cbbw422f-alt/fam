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
            visibility: .sharedSummary
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
            familyID: familyID, memberID: member.id, targetType: .prescriptionRenewal,
            targetID: prescription.id, title: "Påminnelse om recept", firesAt: now
        )

        store.saveHealthRecord(record)
        store.saveHealthPrescription(prescription)
        store.saveMedicationPickup(pickup)
        store.saveHealthProfileInformation(information)
        store.saveHealthReminder(reminder)

        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.healthRecords.map(\.id), [record.id])
        XCTAssertEqual(reloaded.healthRecords.first?.title, record.title)
        XCTAssertEqual(reloaded.healthPrescriptions.map(\.id), [prescription.id])
        XCTAssertEqual(reloaded.healthPrescriptions.first?.renewalStatus, .due)
        XCTAssertEqual(reloaded.medicationPickups.map(\.id), [pickup.id])
        XCTAssertEqual(reloaded.medicationPickups.first?.prescriptionID, prescription.id)
        XCTAssertEqual(reloaded.healthProfileInformation.map(\.id), [information.id])
        XCTAssertEqual(reloaded.healthProfileInformation.first?.type, .allergy)
        XCTAssertEqual(reloaded.healthReminders.map(\.id), [reminder.id])
        XCTAssertEqual(reloaded.healthReminders.first?.targetType, .prescriptionRenewal)
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

    func testLegacySnapshotWithoutHealthFieldsLoadsEmptyHealthCollections() throws {
        let (store, directory) = try makeStore()
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
