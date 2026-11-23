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

    func testPersistenceFailureIsExposedInsteadOfSilentlyIgnored() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenPersistenceFailure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let blockingFile = directory.appendingPathComponent("not-a-directory")
        try Data("keep this file".utf8).write(to: blockingFile)
        let snapshotURL = blockingFile.appendingPathComponent("snapshot.json")
        let store = LocalFamilyStore(fileURL: snapshotURL)

        XCTAssertNotNil(store.persistenceError)
        store.createFamily(name: "Familjen", ownerName: "Niklas")

        XCTAssertNotNil(store.persistenceError)
        XCTAssertEqual(try String(contentsOf: blockingFile, encoding: .utf8), "keep this file")
        XCTAssertFalse(FileManager.default.fileExists(atPath: snapshotURL.path))
    }

    func testFamilyMemberProfileIconIsBackwardCompatibleAndPersists() throws {
        let familyID = UUID()
        let memberID = UUID()
        let legacyJSON = """
        {
          "id": "\(memberID.uuidString)",
          "family_id": "\(familyID.uuidString)",
          "display_name": "Villemo",
          "role": "member"
        }
        """
        let legacy = try JSONDecoder().decode(FamilyMember.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(legacy.symbolName)
        XCTAssertEqual(legacy.resolvedSymbolName, "person.crop.circle")

        var updated = legacy
        updated.symbolName = "heart.fill"
        let encoded = try JSONEncoder().encode(updated)
        let decoded = try JSONDecoder().decode(FamilyMember.self, from: encoded)
        XCTAssertEqual(decoded.symbolName, "heart.fill")
        XCTAssertEqual(decoded.resolvedSymbolName, "heart.fill")
    }

    func testFamilyProfilesAndShoppingItemsSurviveReload() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.addChild(name: "Barnprofil")
        let child = try XCTUnwrap(store.members.first(where: { $0.role == .child }))
        store.updateMemberSymbol(id: child.id, symbolName: "heart.fill")
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
        XCTAssertEqual(reloaded.members.first(where: { $0.id == child.id })?.symbolName, "heart.fill")
        XCTAssertEqual(reloaded.shoppingItems, store.shoppingItems)
    }


    func testDeletingMemberPreservesCalendarItemsAndClearsAssignment() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.addChild(name: "Cleo")
        let child = try XCTUnwrap(store.members.first(where: { $0.role == .child }))
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        store.saveItem(id: nil, title: "Tandläkare", details: "Årlig kontroll", startsAt: date,
                       kind: .dentist, memberID: child.id, recurring: false, reminderOffsets: [3600])
        let originalItem = try XCTUnwrap(store.items.first)

        store.deleteMember(id: child.id)

        XCTAssertFalse(store.members.contains(where: { $0.id == child.id }))
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.id, originalItem.id)
        XCTAssertEqual(store.items.first?.title, "Tandläkare")
        XCTAssertNil(store.items.first?.memberID)

        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.id, originalItem.id)
        XCTAssertNil(reloaded.items.first?.memberID)
    }

    func testSkippingOneMonthlyOccurrencePersistsWithoutDeletingSeries() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let anchorDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 31, hour: 9)))
        store.saveCalendarItem(
            id: nil, title: "Månadsmöte", details: nil, startsAt: anchorDate,
            kind: .event, memberIDs: [], isForEveryone: true, responsibleMemberID: nil,
            recurring: false, reminderOffsets: [], location: nil, recurrenceFrequency: .monthly
        )
        let series = try XCTUnwrap(store.items.first)
        let firstOccurrence = try XCTUnwrap(DashboardViewModel.project([series], from: calendar.startOfDay(for: anchorDate)).first)

        store.skipOccurrence(of: firstOccurrence)

        XCTAssertEqual(store.items.count, 1, "The recurring series must remain stored")
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.skippedOccurrences.count, 1)
        let next = try XCTUnwrap(DashboardViewModel.project(reloaded.items, from: calendar.startOfDay(for: anchorDate), skipping: reloaded.skippedOccurrences).first)
        let expectedNext = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 2, day: 28, hour: 9)))
        XCTAssertTrue(calendar.isDate(next.startsAt, inSameDayAs: expectedNext))
    }

    func testSkippingWeeklyOccurrenceProjectsFollowingWeek() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 9)))
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Veckomöte",
                              details: nil, startsAt: anchor, endsAt: nil, kind: .event,
                              memberID: nil, isRecurringYearly: false, reminderOffsets: [],
                              recurrenceFrequency: .weekly)
        let exception = FamilyOccurrenceException(seriesID: item.id, occurrenceDate: anchor)
        let projected = try XCTUnwrap(DashboardViewModel.project([item], from: anchor, skipping: [exception]).first)
        XCTAssertTrue(calendar.isDate(projected.startsAt, inSameDayAs: calendar.date(byAdding: .day, value: 7, to: anchor)!))
    }

    func testSkippingYearlyLeapDayAdvancesToNextValidYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 29, hour: 9)))
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Årsdag",
                              details: nil, startsAt: anchor, endsAt: nil, kind: .birthday,
                              memberID: nil, isRecurringYearly: true, reminderOffsets: [])
        let exception = FamilyOccurrenceException(seriesID: item.id, occurrenceDate: anchor)
        let projected = try XCTUnwrap(DashboardViewModel.project([item], from: anchor, skipping: [exception]).first)
        let parts = calendar.dateComponents([.year, .month, .day], from: projected.startsAt)
        XCTAssertEqual(parts.year, 2025)
        XCTAssertEqual(parts.month, 2)
        XCTAssertEqual(parts.day, 28)
    }

    func testDeletingRecurringSeriesAlsoDeletesItsExceptions() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        store.saveCalendarItem(id: nil, title: "Möte", details: nil, startsAt: start,
                               kind: .event, memberIDs: [], isForEveryone: true,
                               responsibleMemberID: nil, recurring: false, reminderOffsets: [],
                               location: nil, recurrenceFrequency: .weekly)
        let series = try XCTUnwrap(store.items.first)
        store.skipOccurrence(of: series)
        XCTAssertEqual(store.skippedOccurrences.count, 1)
        store.deleteItem(series)
        XCTAssertTrue(store.skippedOccurrences.isEmpty)
    }

    func testConsecutiveMonthlySkipsAdvanceAcrossShortMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 31, hour: 9)))
        let february = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 2, day: 28, hour: 9)))
        let march = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 3, day: 31, hour: 9)))
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Månadsrutin",
                              details: nil, startsAt: anchor, endsAt: nil, kind: .event,
                              memberID: nil, isRecurringYearly: false, reminderOffsets: [],
                              recurrenceFrequency: .monthly)
        let exceptions = [
            FamilyOccurrenceException(seriesID: item.id, occurrenceDate: anchor),
            FamilyOccurrenceException(seriesID: item.id, occurrenceDate: february)
        ]

        let projected = try XCTUnwrap(DashboardViewModel.project([item], from: anchor, skipping: exceptions).first)
        XCTAssertTrue(calendar.isDate(projected.startsAt, inSameDayAs: march))
    }

    func testCalendarItemCanBeCreatedUpdatedAndDeleted() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        store.saveItem(id: nil, title: "Tandläkare", details: nil, startsAt: date,
                       kind: .dentist, memberID: nil, recurring: false, reminderOffsets: [60])
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.reminderOffsets, [60])
        let id = try XCTUnwrap(store.items.first?.id)

        store.saveItem(id: id, title: "Tandläkare – ändrad", details: "Kontroll",
                       startsAt: date.addingTimeInterval(3600), kind: .dentist,
                       memberID: nil, recurring: false, reminderOffsets: [15])
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.title, "Tandläkare – ändrad")
        XCTAssertEqual(store.items.first?.details, "Kontroll")
        XCTAssertEqual(store.items.first?.reminderOffsets, [15])
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.items.first?.reminderOffsets, [15])

        if let item = store.items.first { store.deleteItem(item) }
        XCTAssertTrue(store.items.isEmpty)
    }

    func testFailedCalendarWritesRollBackCreateUpdateAndDeleteInMemoryChanges() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        store.saveItem(id: nil, title: "Tandläkare", details: nil, startsAt: date,
                       kind: .dentist, memberID: nil, recurring: false, reminderOffsets: [60])
        let originalItems = store.items
        let originalItem = try XCTUnwrap(originalItems.first)

        try FileManager.default.removeItem(at: directory)
        try Data("blocking file".utf8).write(to: directory)

        store.saveItem(id: originalItem.id, title: "Ändrad titel", details: nil,
                       startsAt: date.addingTimeInterval(3600), kind: .dentist,
                       memberID: nil, recurring: false, reminderOffsets: [15])
        XCTAssertEqual(store.items, originalItems)
        XCTAssertNotNil(store.persistenceError)

        store.deleteItem(originalItem)
        XCTAssertEqual(store.items, originalItems)
        XCTAssertEqual(try String(contentsOf: directory, encoding: .utf8), "blocking file")
    }

    func testFailedProfileDeletionRollsBackCalendarAssignments() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.addChild(name: "Cleo")
        let child = try XCTUnwrap(store.members.first(where: { $0.role == .child }))
        store.saveItem(id: nil, title: "Tandläkare", details: nil,
                       startsAt: Date(timeIntervalSince1970: 1_800_000_000),
                       kind: .dentist, memberID: child.id, recurring: false, reminderOffsets: [])
        let originalMembers = store.members
        let originalItems = store.items

        try FileManager.default.removeItem(at: directory)
        try Data("blocking file".utf8).write(to: directory)

        store.deleteMember(id: child.id)

        XCTAssertEqual(store.members, originalMembers)
        XCTAssertEqual(store.items, originalItems)
        XCTAssertNotNil(store.persistenceError)
        XCTAssertEqual(try String(contentsOf: directory, encoding: .utf8), "blocking file")
    }

    func testCalendarLocationPersistsAndOlderItemsRemainCompatible() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.saveCalendarItem(
            id: nil, title: "Läkarbesök", details: "Ta med legitimation",
            startsAt: Date(timeIntervalSince1970: 1_800_000_000), kind: .healthVisit,
            memberIDs: [], isForEveryone: false, responsibleMemberID: nil,
            recurring: false, reminderOffsets: [], location: "Hudiksvalls sjukhus"
        )

        let saved = try XCTUnwrap(store.items.first)
        XCTAssertEqual(saved.location, "Hudiksvalls sjukhus")
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.items.first?.location, "Hudiksvalls sjukhus")

        let legacyJSON = """
        {
          "id": "\(UUID().uuidString)",
          "family_id": "\(UUID().uuidString)",
          "title": "Äldre bokning",
          "starts_at": 0,
          "kind": "appointment"
        }
        """
        let legacyItem = try JSONDecoder().decode(FamilyItem.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(legacyItem.location)
    }

    func testCalendarViewModelReportsFailedSaveAndDeleteWithoutClosingEditor() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let futureDate = Date(timeIntervalSince1970: 1_900_000_000)
        store.saveItem(id: nil, title: "Tandläkare", details: nil, startsAt: futureDate,
                       kind: .dentist, memberID: nil, recurring: false, reminderOffsets: [])
        let originalItem = try XCTUnwrap(store.items.first)

        try FileManager.default.removeItem(at: directory)
        try Data("blocking file".utf8).write(to: directory)

        let viewModel = FamilyCalendarViewModel(store: store)
        let saved = await viewModel.save(
            id: originalItem.id, title: "Ändrad bokning", details: nil,
            startsAt: futureDate.addingTimeInterval(3600), kind: .dentist,
            memberIDs: [], isForEveryone: false, responsibleMemberID: nil,
            isRecurringYearly: false, reminderOffsets: [], location: "Hudiksvall"
        )
        XCTAssertFalse(saved)
        XCTAssertEqual(store.items, [originalItem])
        XCTAssertNotNil(viewModel.errorMessage)

        await viewModel.delete(originalItem)
        XCTAssertEqual(store.items, [originalItem])
        XCTAssertEqual(viewModel.items, [originalItem])
        XCTAssertNotNil(viewModel.errorMessage)
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


    func testYearlyRecurringEventProjectsAndKeepsOriginalAnchorYearWhenEdited() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let originalDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 6, day: 12, hour: 18)))
        store.saveItem(id: nil, title: "Sommarfest", details: nil, startsAt: originalDate,
                       kind: .event, memberID: nil, recurring: true, reminderOffsets: [])
        let originalItem = try XCTUnwrap(store.items.first)
        let referenceDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 16)))
        let projected = try XCTUnwrap(DashboardViewModel.project([originalItem], from: referenceDate).first)
        let projectedParts = calendar.dateComponents([.year, .month, .day], from: projected.startsAt)
        XCTAssertEqual(projectedParts.year, 2027)
        XCTAssertEqual(projectedParts.month, 6)
        XCTAssertEqual(projectedParts.day, 12)

        let editedDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 6, day: 12, hour: 19)))
        let viewModel = FamilyCalendarViewModel(store: store)
        let saved = await viewModel.save(id: originalItem.id, title: originalItem.title, details: nil,
                                         startsAt: editedDate, kind: .event, memberID: nil,
                                         isRecurringYearly: true, reminderOffsets: [])

        XCTAssertTrue(saved)
        let persisted = try XCTUnwrap(store.items.first?.startsAt)
        let persistedParts = calendar.dateComponents([.year, .month, .day, .hour], from: persisted)
        XCTAssertEqual(persistedParts.year, 2024)
        XCTAssertEqual(persistedParts.month, 6)
        XCTAssertEqual(persistedParts.day, 12)
        XCTAssertEqual(persistedParts.hour, 19)
    }

    func testWeeklyAndMonthlySeriesKeepTheirOriginalAnchorWhenTimeIsEdited() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        for frequency in [FamilyRecurrenceFrequency.weekly, .monthly] {
            let (store, directory) = try makeStore()
            defer { try? FileManager.default.removeItem(at: directory) }
            store.createFamily(name: "Familjen", ownerName: "Niklas")

            let anchor = try XCTUnwrap(calendar.date(from: DateComponents(
                year: 2030, month: frequency == .weekly ? 4 : 1,
                day: frequency == .weekly ? 3 : 31, hour: 9
            )))
            store.saveCalendarItem(
                id: nil, title: "Återkommande aktivitet", details: nil, startsAt: anchor,
                kind: .event, memberIDs: [], isForEveryone: true, responsibleMemberID: nil,
                recurring: false, reminderOffsets: [], location: nil, recurrenceFrequency: frequency
            )
            let series = try XCTUnwrap(store.items.first)
            let editedDate = try XCTUnwrap(calendar.date(bySettingHour: 11, minute: 30, second: 0, of: anchor))
            let viewModel = FamilyCalendarViewModel(store: store)

            let saved = await viewModel.save(
                id: series.id, title: series.title, details: nil, startsAt: editedDate,
                kind: .event, memberIDs: [], isForEveryone: true, responsibleMemberID: nil,
                isRecurringYearly: false, reminderOffsets: [], location: nil,
                recurrenceFrequency: frequency
            )

            XCTAssertTrue(saved, "Expected \(frequency.rawValue) series edit to save")
            let persisted = try XCTUnwrap(store.items.first)
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: persisted.startsAt)
            XCTAssertEqual(parts.year, 2030)
            XCTAssertEqual(parts.month, frequency == .weekly ? 4 : 1)
            XCTAssertEqual(parts.day, frequency == .weekly ? 3 : 31)
            XCTAssertEqual(parts.hour, 11)
            XCTAssertEqual(parts.minute, 30)
            XCTAssertEqual(persisted.recurrenceFrequency, frequency)
        }
    }

    func testEditingOneWeeklyOccurrenceDoesNotChangeTheSeriesOrNextOccurrence() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2030, month: 4, day: 3, hour: 9)))
        let nextWeek = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: anchor))
        let series = FamilyItem(
            id: UUID(), familyID: UUID(), title: "Veckomöte", details: nil,
            startsAt: anchor, endsAt: nil, kind: .event, memberID: nil,
            isRecurringYearly: false, reminderOffsets: [], recurrenceFrequency: .weekly
        )
        let changedOccurrence = FamilyItem(
            id: series.id, familyID: series.familyID, title: "Veckomöte – flyttat",
            details: "Gäller bara detta tillfälle", startsAt: anchor.addingTimeInterval(2 * 60 * 60),
            endsAt: nil, kind: .event, memberID: nil, isRecurringYearly: false,
            reminderOffsets: [], recurrenceFrequency: FamilyRecurrenceFrequency.none
        )
        let override = FamilyOccurrenceOverride(
            seriesID: series.id, occurrenceDate: anchor, item: changedOccurrence
        )

        let edited = try XCTUnwrap(DashboardViewModel.project(
            [series], from: anchor, overrides: [override]
        ).first)
        XCTAssertEqual(edited.title, "Veckomöte – flyttat")
        XCTAssertEqual(edited.startsAt, changedOccurrence.startsAt)

        let following = try XCTUnwrap(DashboardViewModel.project(
            [series], from: nextWeek, overrides: [override]
        ).first)
        XCTAssertEqual(following.title, "Veckomöte")
        XCTAssertEqual(following.startsAt, nextWeek)
        XCTAssertEqual(series.startsAt, anchor)
        XCTAssertEqual(series.recurrenceFrequency, .weekly)
    }

    func testCorruptedSnapshotIsPreservedForRecovery() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenCorruptTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("snapshot.json")
        try Data("not valid json".utf8).write(to: fileURL)
        _ = LocalFamilyStore(fileURL: fileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].hasPrefix("snapshot.json.corrupt-"))
        let recoveredData = try Data(contentsOf: directory.appendingPathComponent(files[0]))
        XCTAssertEqual(String(data: recoveredData, encoding: .utf8), "not valid json")
    }


    func testShoppingItemsCannotBeCreatedWithoutAFamily() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.addShoppingItem("Mjölk")
        XCTAssertTrue(store.shoppingItems.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("snapshot.json").path))
    }


    func testCreatingFamilyAgainDoesNotEraseExistingData() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.addChild(name: "Cleo")
        store.addShoppingItem("Mjölk")
        let originalFamily = store.family
        let originalMembers = store.members
        let originalShoppingItems = store.shoppingItems
        store.createFamily(name: "En annan familj", ownerName: "Villemo")
        XCTAssertEqual(store.family, originalFamily)
        XCTAssertEqual(store.members, originalMembers)
        XCTAssertEqual(store.shoppingItems, originalShoppingItems)
    }


    func testLegacySnapshotWithoutMessagesLoadsAsEmptyConversationHistory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenLegacyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("snapshot.json")
        let legacySnapshot = """
        {
          "family": null,
          "members": [],
          "items": [],
          "shoppingItems": [],
          "notifications": []
        }
        """
        try Data(legacySnapshot.utf8).write(to: fileURL)

        let store = LocalFamilyStore(fileURL: fileURL)

        XCTAssertNil(store.family)
        XCTAssertTrue(store.members.isEmpty)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.shoppingItems.isEmpty)
        XCTAssertTrue(store.notifications.isEmpty)
        XCTAssertTrue(store.messages.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }


    func testEditingProjectedBirthdayKeepsOriginalBirthYear() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let birthDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 1990, month: 3, day: 12, hour: 8)))
        store.saveItem(id: nil, title: "Födelsedag", details: nil, startsAt: birthDate,
                       kind: .birthday, memberID: nil, recurring: true, reminderOffsets: [])
        let item = try XCTUnwrap(store.items.first)
        let projectedDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 3, day: 12, hour: 9)))

        let viewModel = FamilyCalendarViewModel(store: store)
        let saved = await viewModel.save(id: item.id, title: item.title, details: nil,
                                         startsAt: projectedDate, kind: .birthday, memberID: nil,
                                         isRecurringYearly: true, reminderOffsets: [])

        XCTAssertTrue(saved)
        let persisted = try XCTUnwrap(store.items.first?.startsAt)
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: persisted)
        XCTAssertEqual(parts.year, 1990)
        XCTAssertEqual(parts.month, 3)
        XCTAssertEqual(parts.day, 12)
        XCTAssertEqual(parts.hour, 9)
    }

    func testSavingUnchangedProjectedLeapDayKeepsFebruary29BirthDate() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let birthDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2000, month: 2, day: 29, hour: 9)))
        store.saveItem(id: nil, title: "Födelsedag", details: nil, startsAt: birthDate,
                       kind: .birthday, memberID: nil, recurring: true, reminderOffsets: [])
        let item = try XCTUnwrap(store.items.first)
        let projectedDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 2, day: 28, hour: 9)))

        let viewModel = FamilyCalendarViewModel(store: store)
        let saved = await viewModel.save(id: item.id, title: item.title, details: nil,
                                         startsAt: projectedDate, kind: .birthday, memberID: nil,
                                         isRecurringYearly: true, reminderOffsets: [])

        XCTAssertTrue(saved)
        let persisted = try XCTUnwrap(store.items.first?.startsAt)
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: persisted)
        XCTAssertEqual(parts.year, 2000)
        XCTAssertEqual(parts.month, 2)
        XCTAssertEqual(parts.day, 29)
        XCTAssertEqual(parts.hour, 9)
    }


    func testFamilyItemDecodesLegacySingleMemberAndRoundTripsMultipleMembers() throws {
        let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let familyID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let itemID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let legacyJSON = """
        {
          "id": "\(itemID.uuidString)",
          "family_id": "\(familyID.uuidString)",
          "title": "Tandläkare",
          "starts_at": 0,
          "kind": "dentist",
          "member_id": "\(firstID.uuidString)",
          "is_recurring_yearly": false,
          "reminder_offsets": []
        }
        """
        let decoder = JSONDecoder()
        let legacyItem = try decoder.decode(FamilyItem.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(legacyItem.memberIDs, [firstID])
        XCTAssertEqual(legacyItem.memberID, firstID)
        XCTAssertFalse(legacyItem.isForEveryone)
        XCTAssertNil(legacyItem.responsibleMemberID)

        let multiMemberItem = FamilyItem(
            id: itemID, familyID: familyID, title: "Skolavslutning",
            details: nil, startsAt: Date(timeIntervalSince1970: 0), endsAt: nil,
            kind: .event, memberID: nil, isRecurringYearly: false,
            reminderOffsets: [], memberIDs: [firstID, secondID],
            isForEveryone: false, responsibleMemberID: firstID
        )
        let encoded = try JSONEncoder().encode(multiMemberItem)
        let decoded = try decoder.decode(FamilyItem.self, from: encoded)
        XCTAssertEqual(decoded.memberIDs, [firstID, secondID])
        XCTAssertEqual(decoded.memberID, firstID)
        XCTAssertEqual(decoded.responsibleMemberID, firstID)
        XCTAssertFalse(decoded.isForEveryone)
    }

    func testFamilyWideCalendarItemIsDistinctFromUnassignedItem() throws {
        let familyID = UUID()
        let date = Date(timeIntervalSince1970: 0)
        let unassigned = FamilyItem(
            id: UUID(), familyID: familyID, title: "Preliminärt",
            details: nil, startsAt: date, endsAt: nil, kind: .appointment,
            memberID: nil, isRecurringYearly: false, reminderOffsets: []
        )
        let familyWide = FamilyItem(
            id: UUID(), familyID: familyID, title: "Familjemiddag",
            details: nil, startsAt: date, endsAt: nil, kind: .event,
            memberID: nil, isRecurringYearly: false, reminderOffsets: [],
            isForEveryone: true
        )
        XCTAssertTrue(unassigned.memberIDs.isEmpty)
        XCTAssertFalse(unassigned.isForEveryone)
        XCTAssertTrue(familyWide.memberIDs.isEmpty)
        XCTAssertTrue(familyWide.isForEveryone)
    }



    func testSavingMultipleCalendarParticipantsAndResponsibleAdultPersists() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.addChild(name: "Cleo")
        store.addMember(name: "Villemo", role: .member)
        let child = try XCTUnwrap(store.members.first(where: { $0.role == .child }))
        let adult = try XCTUnwrap(store.members.first(where: { $0.displayName == "Villemo" }))

        store.saveCalendarItem(
            id: nil, title: "Skolavslutning", details: nil,
            startsAt: Date(timeIntervalSince1970: 1_800_000_000), kind: .event,
            memberIDs: [child.id, adult.id, child.id], isForEveryone: false,
            responsibleMemberID: adult.id, recurring: false, reminderOffsets: []
        )

        let saved = try XCTUnwrap(store.items.first)
        XCTAssertEqual(saved.memberIDs, [child.id, adult.id])
        XCTAssertEqual(saved.responsibleMemberID, adult.id)
        XCTAssertFalse(saved.isForEveryone)

        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.items.first?.memberIDs, [child.id, adult.id])
        XCTAssertEqual(reloaded.items.first?.responsibleMemberID, adult.id)
    }

    func testFamilyWideAssignmentClearsParticipantsButKeepsResponsibleAdult() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.addChild(name: "Cleo")
        let child = try XCTUnwrap(store.members.first(where: { $0.role == .child }))
        let owner = try XCTUnwrap(store.members.first(where: { $0.role == .owner }))

        store.saveCalendarItem(
            id: nil, title: "Utflykt", details: nil,
            startsAt: Date(timeIntervalSince1970: 1_800_000_000), kind: .trip,
            memberIDs: [child.id], isForEveryone: true,
            responsibleMemberID: owner.id, recurring: false, reminderOffsets: []
        )

        let saved = try XCTUnwrap(store.items.first)
        XCTAssertTrue(saved.memberIDs.isEmpty)
        XCTAssertTrue(saved.isForEveryone)
        XCTAssertEqual(saved.responsibleMemberID, owner.id)
    }

    func testCalendarPersonFilterMatchesAnySelectedPersonAndFamilyWideItems() throws {
        let familyID = UUID()
        let firstID = UUID()
        let secondID = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let forFirst = FamilyItem(
            id: UUID(), familyID: familyID, title: "Besök",
            details: nil, startsAt: date, endsAt: nil, kind: .healthVisit,
            memberID: nil, isRecurringYearly: false, reminderOffsets: [],
            memberIDs: [firstID]
        )
        let forSecond = FamilyItem(
            id: UUID(), familyID: familyID, title: "Träning",
            details: nil, startsAt: date, endsAt: nil, kind: .activity,
            memberID: nil, isRecurringYearly: false, reminderOffsets: [],
            memberIDs: [secondID]
        )
        let forEveryone = FamilyItem(
            id: UUID(), familyID: familyID, title: "Middag",
            details: nil, startsAt: date, endsAt: nil, kind: .event,
            memberID: nil, isRecurringYearly: false, reminderOffsets: [],
            isForEveryone: true
        )
        let unassigned = FamilyItem(
            id: UUID(), familyID: familyID, title: "Preliminärt",
            details: nil, startsAt: date, endsAt: nil, kind: .appointment,
            memberID: nil, isRecurringYearly: false, reminderOffsets: []
        )

        let filtered = FamilyCalendarViewModel.filteredItems(
            [forFirst, forSecond, forEveryone, unassigned],
            selectedMemberIDs: [secondID]
        )
        XCTAssertEqual(Set(filtered.map(\.id)), Set([forSecond.id, forEveryone.id]))
        XCTAssertEqual(
            FamilyCalendarViewModel.filteredItems(
                [forFirst, forSecond, forEveryone, unassigned], selectedMemberIDs: []
            ).count,
            4
        )
    }



    func testDeletingMemberRemovesOnlyTheirCalendarAssignmentAndResponsibility() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.addChild(name: "Cleo")
        store.addMember(name: "Villemo", role: .member)
        let child = try XCTUnwrap(store.members.first(where: { $0.role == .child }))
        let adult = try XCTUnwrap(store.members.first(where: { $0.displayName == "Villemo" }))

        store.saveCalendarItem(
            id: nil, title: "Familjeaktivitet", details: nil,
            startsAt: Date(timeIntervalSince1970: 1_800_000_000), kind: .event,
            memberIDs: [child.id, adult.id], isForEveryone: false,
            responsibleMemberID: child.id, recurring: false, reminderOffsets: []
        )
        store.deleteMember(id: child.id)

        let saved = try XCTUnwrap(store.items.first)
        XCTAssertEqual(saved.memberIDs, [adult.id])
        XCTAssertNil(saved.responsibleMemberID)
        XCTAssertEqual(saved.title, "Familjeaktivitet")

        store.deleteMember(id: adult.id)
        let afterSecondRemoval = try XCTUnwrap(store.items.first)
        XCTAssertTrue(afterSecondRemoval.memberIDs.isEmpty)
        XCTAssertNil(afterSecondRemoval.responsibleMemberID)

        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertTrue(reloaded.items.first?.memberIDs.isEmpty == true)
        XCTAssertNil(reloaded.items.first?.responsibleMemberID)
    }


    func testWeeklyRecurrenceProjectsNextWeekAndKeepsTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 9, minute: 30)))
        let reference = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 12)))
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Veckomöte",
                              details: nil, startsAt: anchor, endsAt: nil, kind: .event,
                              memberID: nil, isRecurringYearly: false, reminderOffsets: [],
                              recurrenceFrequency: .weekly)
        let projected = try XCTUnwrap(DashboardViewModel.project([item], from: reference).first)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: projected.startsAt)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 11)
        XCTAssertEqual(parts.day, 23)
        XCTAssertEqual(parts.hour, 9)
        XCTAssertEqual(parts.minute, 30)
    }

    func testMonthlyRecurrenceClampsDayToLastDayOfShortMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 8)))
        let reference = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 2, day: 1)))
        let item = FamilyItem(id: UUID(), familyID: UUID(), title: "Månadsrutin",
                              details: nil, startsAt: anchor, endsAt: nil, kind: .event,
                              memberID: nil, isRecurringYearly: false, reminderOffsets: [],
                              recurrenceFrequency: .monthly)
        let projected = try XCTUnwrap(DashboardViewModel.project([item], from: reference).first)
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: projected.startsAt)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 2)
        XCTAssertEqual(parts.day, 28)
        XCTAssertEqual(parts.hour, 8)
    }

    func testMonthlyRecurrenceFrequencyPersistsAcrossReload() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.saveCalendarItem(
            id: nil, title: "Månadsrutin", details: nil,
            startsAt: Date(timeIntervalSince1970: 1_800_000_000), kind: .event,
            memberIDs: [], isForEveryone: false, responsibleMemberID: nil,
            recurring: false, reminderOffsets: [], location: nil,
            recurrenceFrequency: .monthly
        )
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.items.first?.recurrenceFrequency, .monthly)
        XCTAssertFalse(reloaded.items.first?.isRecurringYearly ?? true)
    }


    func testBirthdayGiftIdeasPersistAndSupportUpdateAndDelete() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let member = try XCTUnwrap(store.members.first)
        store.saveItem(id: nil, title: "Födelsedag", details: nil,
                       startsAt: Date(timeIntervalSince1970: 1_800_000_000),
                       kind: .birthday, memberID: member.id, recurring: true,
                       reminderOffsets: [])
        let birthday = try XCTUnwrap(store.items.first)

        store.addGiftIdea(memberID: member.id, birthdayItemID: birthday.id,
                          title: "  Hörlurar  ", note: "  Svarta  ")
        var idea = try XCTUnwrap(store.giftIdeas.first)
        XCTAssertEqual(idea.title, "Hörlurar")
        XCTAssertEqual(idea.note, "Svarta")

        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.giftIdeas, store.giftIdeas)

        idea.isOrdered = true
        idea.note = "Önskar sig trådlösa"
        store.updateGiftIdea(idea)
        let updatedStore = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(updatedStore.giftIdeas.first?.isOrdered, true)
        XCTAssertEqual(updatedStore.giftIdeas.first?.note, "Önskar sig trådlösa")

        store.deleteGiftIdea(idea.id)
        let deletedStore = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertTrue(deletedStore.giftIdeas.isEmpty)
    }

    func testGiftIdeasRejectBlankTitlesAndNonBirthdayItems() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let member = try XCTUnwrap(store.members.first)
        store.saveItem(id: nil, title: "Möte", details: nil,
                       startsAt: Date(timeIntervalSince1970: 1_800_000_000),
                       kind: .event, memberID: member.id, recurring: false,
                       reminderOffsets: [])
        let event = try XCTUnwrap(store.items.first)

        store.addGiftIdea(memberID: member.id, birthdayItemID: event.id,
                          title: "Present", note: nil)
        store.addGiftIdea(memberID: member.id, birthdayItemID: event.id,
                          title: "   ", note: nil)
        XCTAssertTrue(store.giftIdeas.isEmpty)
    }


    func testChristmasGiftListPersistsAndSupportsUpdateAndDelete() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let owner = try XCTUnwrap(store.members.first)
        store.addChristmasGift(recipient: "Cleo", title: "  Hörlurar  ",
                               note: "  Rosa  ", responsibleMemberID: owner.id)
        var gift = try XCTUnwrap(store.christmasGifts.first)
        XCTAssertEqual(gift.title, "Hörlurar")
        XCTAssertEqual(gift.note, "Rosa")
        XCTAssertEqual(gift.responsibleMemberID, owner.id)

        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.christmasGifts, store.christmasGifts)

        gift.status = .purchased
        gift.note = "Svarta"
        store.updateChristmasGift(gift)
        let updated = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(updated.christmasGifts.first?.status, .purchased)
        XCTAssertEqual(updated.christmasGifts.first?.note, "Svarta")

        store.deleteChristmasGift(gift.id)
        let deleted = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertTrue(deleted.christmasGifts.isEmpty)
    }

    func testChristmasGiftListRejectsBlankRecipientAndTitle() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        let owner = try XCTUnwrap(store.members.first)
        store.addChristmasGift(recipient: "Cleo", title: "   ", note: nil, responsibleMemberID: owner.id)
        store.addChristmasGift(recipient: "   ", title: "Bok", note: nil, responsibleMemberID: owner.id)
        XCTAssertTrue(store.christmasGifts.isEmpty)
    }



    func testShoppingCategoriesAndCheckedItemsPersistAndLegacyItemsDecode() throws {
        let familyID = UUID()
        let itemID = UUID()
        let legacyJSON = """
        {
          "id": "\(itemID.uuidString)",
          "list_id": "\(familyID.uuidString)",
          "title": "Mjölk",
          "is_checked": false,
          "created_at": 1767261600
        }
        """
        let legacyItem = try JSONDecoder().decode(ShoppingItem.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(legacyItem.category)
        XCTAssertEqual(legacyItem.title, "Mjölk")

        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.createFamily(name: "Familjen", ownerName: "Niklas")
        store.addShoppingItem("Äpplen", category: .fruitVegetables)
        let item = try XCTUnwrap(store.shoppingItems.first)
        XCTAssertEqual(item.category, .fruitVegetables)

        store.setShoppingItem(item.id, checked: true)
        let reloaded = LocalFamilyStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        XCTAssertEqual(reloaded.shoppingItems.first?.category, .fruitVegetables)
        XCTAssertEqual(reloaded.shoppingItems.first?.isChecked, true)
    }

    func testShoppingSuggestionsMatchSwedishTextAndAssignCategory() {
        let suggestions = ShoppingItemSuggestion.matching("mjöl")
        XCTAssertTrue(suggestions.contains { $0.title == "Mjölk" && $0.category == .dairy })
        XCTAssertTrue(suggestions.contains { $0.title == "Mjöl" && $0.category == .pantry })
    }

    func testShoppingSuggestionsExcludeExistingItemsAndIgnoreCase() {
        let suggestions = ShoppingItemSuggestion.matching("MJÖL", excluding: ["mjölk"])
        XCTAssertFalse(suggestions.contains { $0.title == "Mjölk" })
        XCTAssertTrue(suggestions.contains { $0.title == "Mjöl" })
    }

    func testSeasonalSceneResolverCoversSeasonAndHolidayBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        }

        XCTAssertTrue(SeasonalSceneResolver.scene(for: date(2026, 11, 28), calendar: calendar) == .winter)
        XCTAssertTrue(SeasonalSceneResolver.scene(for: date(2026, 11, 29), calendar: calendar) == .advent)
        XCTAssertTrue(SeasonalSceneResolver.scene(for: date(2026, 12, 13), calendar: calendar) == .lucia)
        XCTAssertTrue(SeasonalSceneResolver.scene(for: date(2026, 12, 24), calendar: calendar) == .christmas)
        XCTAssertTrue(SeasonalSceneResolver.scene(for: date(2027, 1, 6), calendar: calendar) == .christmas)
        XCTAssertTrue(SeasonalSceneResolver.scene(for: date(2027, 1, 7), calendar: calendar) == .winter)
        XCTAssertTrue(SeasonalSceneResolver.scene(for: date(2027, 3, 1), calendar: calendar) == .spring)
        XCTAssertTrue(SeasonalSceneResolver.scene(for: date(2027, 6, 1), calendar: calendar) == .summer)
        XCTAssertTrue(SeasonalSceneResolver.scene(for: date(2027, 9, 1), calendar: calendar) == .autumn)
    }

    func testAdventCandleCountAdvancesOnEachSunday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        }

        XCTAssertEqual(SeasonalSceneResolver.adventLitCount(for: date(2026, 11, 28), calendar: calendar), 0)
        XCTAssertEqual(SeasonalSceneResolver.adventLitCount(for: date(2026, 11, 29), calendar: calendar), 1)
        XCTAssertEqual(SeasonalSceneResolver.adventLitCount(for: date(2026, 12, 5), calendar: calendar), 1)
        XCTAssertEqual(SeasonalSceneResolver.adventLitCount(for: date(2026, 12, 6), calendar: calendar), 2)
        XCTAssertEqual(SeasonalSceneResolver.adventLitCount(for: date(2026, 12, 13), calendar: calendar), 3)
        XCTAssertEqual(SeasonalSceneResolver.adventLitCount(for: date(2026, 12, 20), calendar: calendar), 4)
    }

}
