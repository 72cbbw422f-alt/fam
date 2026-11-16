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
}
