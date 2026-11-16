import XCTest
@testable import Familjen

@MainActor
final class LocalFamilyStoreTests: XCTestCase {
    private func makeStore() throws -> (LocalFamilyStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json")), directory)
    }

    func testFamilyProfilesAndShoppingItemsSurviveReload() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.addChild(name: "Barnprofil")
        store.addShoppingItem("Mjölk")
        guard let family = store.family else {
            return XCTFail("Family should be created")
        }

        XCTAssertEqual(family.name, "Familjen")
        XCTAssertEqual(store.members.count, 2)
        XCTAssertEqual(store.shoppingItems.map(\.title), ["Mjölk"])

        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.family, family)
        XCTAssertEqual(reloaded.members, store.members)
        XCTAssertEqual(reloaded.shoppingItems, store.shoppingItems)
    }

    func testCalendarItemCanBeCreatedUpdatedAndDeleted() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        store.saveItem(id: nil, title: "Tandläkare", details: nil, startsAt: date,
                       kind: .dentist, memberID: nil, recurring: false, reminderOffsets: [60])
        XCTAssertEqual(store.items.count, 1)
        let id = try XCTUnwrap(store.items.first?.id)

        store.saveItem(id: id, title: "Tandläkare – ändrad", details: "Kontroll",
                       startsAt: date.addingTimeInterval(3600), kind: .dentist,
                       memberID: nil, recurring: false, reminderOffsets: [15])
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.title, "Tandläkare – ändrad")
        XCTAssertEqual(store.items.first?.details, "Kontroll")

        if let item = store.items.first { store.deleteItem(item) }
        XCTAssertTrue(store.items.isEmpty)
    }

    func testRepositoryFactoryUsesLocalImplementationUntilCloudIsConfigured() {
        let repository = FamilyRepositoryFactory.makeDefault()
        XCTAssertTrue(repository is LocalFamilyStore)
    }

    func testOwnerCannotBeRenamedOrDeletedAndInvalidProfilesAreRejected() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let owner = try XCTUnwrap(store.members.first)
        store.renameMember(id: owner.id, name: "Ändrat namn")
        store.deleteMember(id: owner.id)
        store.addChild(name: "   ")
        store.addChild(name: String(repeating: "x", count: 81))
        store.addMember(name: "   ")
        XCTAssertEqual(store.members.count, 1)
        XCTAssertEqual(store.members.first?.displayName, "Niklas")
        XCTAssertEqual(store.members.first?.role, .owner)
    }

    func testShoppingItemCanBeCheckedAndDeleted() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.addShoppingItem("Mjölk")
        let item = try XCTUnwrap(store.shoppingItems.first)
        store.setShoppingItem(item.id, checked: true)
        XCTAssertEqual(store.shoppingItems.first?.isChecked, true)
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.shoppingItems.first?.isChecked, true)
        store.deleteShoppingItem(item.id)
        XCTAssertTrue(store.shoppingItems.isEmpty)
    }

    func testMessagesPersistAndConversationReadStateUpdates() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.sendMessage("Vi ses klockan fem", conversationID: "family", kind: .family)
        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages.first?.text, "Vi ses klockan fem")
        XCTAssertNil(store.messages.first?.readAt)
        store.markConversationRead("family")
        XCTAssertNotNil(store.messages.first?.readAt)
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.messages.count, 1)
        XCTAssertNotNil(reloaded.messages.first?.readAt)
    }

    func testInvalidFamilyAndOwnerNamesDoNotCreateFamily() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "   ", ownerName: "Niklas")
        XCTAssertNil(store.family)
        store.createFamily(name: "Familjen", ownerName: String(repeating: "x", count: 81))
        XCTAssertNil(store.family)
    }

    func testObservableFamilyStoreFacadeReflectsMutations() throws {
        let (repository, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FamilyStore(repository: repository)
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.addChild(name: "Cleo")
        XCTAssertEqual(store.family?.name, "Familjen")
        XCTAssertEqual(store.members.map(\.displayName), ["Niklas", "Cleo"])
    }


    func testRecurringLeapDayBirthdayProjectsToFebruary28InNonLeapYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let birthDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2000, month: 2, day: 29, hour: 9)))
        let familyID = UUID()
        let birthday = FamilyItem(id: UUID(), familyID: familyID, title: "Födelsedag",
                                  details: nil, startsAt: birthDate, endsAt: nil,
                                  kind: .birthday, memberID: nil, isRecurringYearly: true,
                                  reminderOffsets: [])
        let referenceDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let projected = try XCTUnwrap(DashboardViewModel.project([birthday], from: referenceDate).first)
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: projected.startsAt)
        XCTAssertEqual(parts.year, 2025)
        XCTAssertEqual(parts.month, 2)
        XCTAssertEqual(parts.day, 28)
        XCTAssertEqual(parts.hour, 9)
    }

    func testRecurringBirthdayProjectsIntoNextYearWhenThisYearsDateHasPassed() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let birthDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 1990, month: 3, day: 12, hour: 8)))
        let birthday = FamilyItem(id: UUID(), familyID: UUID(), title: "Födelsedag",
                                  details: nil, startsAt: birthDate, endsAt: nil,
                                  kind: .birthday, memberID: nil, isRecurringYearly: true,
                                  reminderOffsets: [])
        let referenceDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 16)))
        let projected = try XCTUnwrap(DashboardViewModel.project([birthday], from: referenceDate).first)
        let parts = calendar.dateComponents([.year, .month, .day], from: projected.startsAt)
        XCTAssertEqual(parts.year, 2027)
        XCTAssertEqual(parts.month, 3)
        XCTAssertEqual(parts.day, 12)
    }

}
