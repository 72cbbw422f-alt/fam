import XCTest
@testable import Familjen

@MainActor
final class OccurrenceOverrideRestorationTests: XCTestCase {
    private func makeStore() throws -> (LocalFamilyStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenOverrideRestore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json")), directory)
    }

    func testEditingPreviouslySkippedOccurrenceRestoresItAndPersistsOverride() throws {
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
        let occurrence = FamilyItem(
            id: series.id, familyID: series.familyID, title: series.title,
            details: nil, startsAt: originalDate, endsAt: nil, kind: .event,
            memberID: nil, isRecurringYearly: false, reminderOffsets: [],
            recurrenceFrequency: .none
        )

        store.skipOccurrence(of: occurrence)
        XCTAssertEqual(store.skippedOccurrences.count, 1)

        let movedDate = originalDate.addingTimeInterval(86_400)
        var edited = occurrence
        edited.title = "Veckomöte – flyttat"
        edited.startsAt = movedDate
        store.saveOccurrenceOverride(
            seriesID: series.id, occurrenceDate: originalDate, item: edited
        )

        XCTAssertTrue(store.skippedOccurrences.isEmpty)
        XCTAssertEqual(store.occurrenceOverrides.count, 1)
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertTrue(reloaded.skippedOccurrences.isEmpty)
        XCTAssertEqual(reloaded.occurrenceOverrides.first?.item.title, "Veckomöte – flyttat")
        XCTAssertEqual(reloaded.occurrenceOverrides.first?.item.startsAt, movedDate)

        let projected = DashboardViewModel.project(
            reloaded.items, from: originalDate,
            skipping: reloaded.skippedOccurrences, overrides: reloaded.occurrenceOverrides
        )
        XCTAssertEqual(projected.first?.title, "Veckomöte – flyttat")
        XCTAssertEqual(projected.first?.startsAt, movedDate)
    }

    func testFailedOverrideSaveRestoresBothExistingSkipAndOverrides() throws {
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
        let occurrence = FamilyItem(
            id: series.id, familyID: series.familyID, title: series.title,
            details: nil, startsAt: originalDate, endsAt: nil, kind: .event,
            memberID: nil, isRecurringYearly: false, reminderOffsets: [],
            recurrenceFrequency: .none
        )
        store.skipOccurrence(of: occurrence)
        let originalSkips = store.skippedOccurrences
        let originalOverrides = store.occurrenceOverrides

        try FileManager.default.removeItem(at: directory)
        try Data("blocking file".utf8).write(to: directory)
        var edited = occurrence
        edited.title = "Ändrad aktivitet"
        edited.startsAt = originalDate.addingTimeInterval(3600)

        store.saveOccurrenceOverride(
            seriesID: series.id, occurrenceDate: originalDate, item: edited
        )

        XCTAssertEqual(store.skippedOccurrences, originalSkips)
        XCTAssertEqual(store.occurrenceOverrides, originalOverrides)
        XCTAssertNotNil(store.persistenceError)
        XCTAssertEqual(try String(contentsOf: directory, encoding: .utf8), "blocking file")
    }
}
