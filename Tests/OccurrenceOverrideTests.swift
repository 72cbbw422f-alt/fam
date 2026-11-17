import XCTest
@testable import Familjen

@MainActor
final class OccurrenceOverrideTests: XCTestCase {
    private func makeStore() throws -> (LocalFamilyStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenOccurrenceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json")), directory)
    }

    func testOccurrenceOverridePersistsByOriginalDateAndReplacesInsteadOfDuplicating() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")

        let originalDate = Date(timeIntervalSince1970: 1_800_000_000)
        store.saveCalendarItem(
            id: nil, title: "Veckomöte", details: nil, startsAt: originalDate,
            kind: .event, memberIDs: [], isForEveryone: true,
            responsibleMemberID: nil, recurring: false, reminderOffsets: [],
            recurrenceFrequency: .weekly
        )
        let series = try XCTUnwrap(store.items.first)
        let movedDate = originalDate.addingTimeInterval(86_400)
        let movedOccurrence = FamilyItem(
            id: series.id, familyID: series.familyID, title: "Veckomöte – flyttat",
            details: "Ny tid", startsAt: movedDate, endsAt: nil, kind: .event,
            memberID: nil, isRecurringYearly: false, reminderOffsets: [3600],
            isForEveryone: true, recurrenceFrequency: .none
        )

        store.saveOccurrenceOverride(
            seriesID: series.id, occurrenceDate: originalDate, item: movedOccurrence
        )

        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.occurrenceOverrides.count, 1)
        XCTAssertEqual(reloaded.occurrenceOverrides.first?.seriesID, series.id)
        XCTAssertEqual(reloaded.occurrenceOverrides.first?.occurrenceDate, originalDate)
        XCTAssertEqual(reloaded.occurrenceOverrides.first?.item.startsAt, movedDate)

        var revisedOccurrence = movedOccurrence
        revisedOccurrence.title = "Veckomöte – ny tid"
        store.saveOccurrenceOverride(
            seriesID: series.id, occurrenceDate: originalDate, item: revisedOccurrence
        )

        XCTAssertEqual(store.occurrenceOverrides.count, 1)
        XCTAssertEqual(store.occurrenceOverrides.first?.item.title, "Veckomöte – ny tid")
    }

    func testFailedOccurrenceOverrideWriteRollsBackWithoutLosingExistingOverrides() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let originalDate = Date(timeIntervalSince1970: 1_800_000_000)
        store.saveCalendarItem(
            id: nil, title: "Veckomöte", details: nil, startsAt: originalDate,
            kind: .event, memberIDs: [], isForEveryone: true,
            responsibleMemberID: nil, recurring: false, reminderOffsets: [],
            recurrenceFrequency: .weekly
        )
        let series = try XCTUnwrap(store.items.first)
        let firstOverride = FamilyItem(
            id: series.id, familyID: series.familyID, title: "Första ändringen",
            details: nil, startsAt: originalDate.addingTimeInterval(3600),
            endsAt: nil, kind: .event, memberID: nil,
            isRecurringYearly: false, reminderOffsets: []
        )
        store.saveOccurrenceOverride(
            seriesID: series.id, occurrenceDate: originalDate, item: firstOverride
        )
        let originalOverrides = store.occurrenceOverrides

        try FileManager.default.removeItem(at: directory)
        try Data("blocking file".utf8).write(to: directory)
        let secondDate = originalDate.addingTimeInterval(7 * 86_400)
        let secondOverride = FamilyItem(
            id: series.id, familyID: series.familyID, title: "Andra ändringen",
            details: nil, startsAt: secondDate.addingTimeInterval(3600),
            endsAt: nil, kind: .event, memberID: nil,
            isRecurringYearly: false, reminderOffsets: []
        )

        store.saveOccurrenceOverride(
            seriesID: series.id, occurrenceDate: secondDate, item: secondOverride
        )

        XCTAssertEqual(store.occurrenceOverrides, originalOverrides)
        XCTAssertNotNil(store.persistenceError)
        XCTAssertEqual(try String(contentsOf: directory, encoding: .utf8), "blocking file")
    }
}
