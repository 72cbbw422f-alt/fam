import XCTest
@testable import Familjen

final class ShoppingItemSuggestionTests: XCTestCase {
    func testSuggestionsRequireAtLeastTwoCharacters() {
        XCTAssertTrue(ShoppingItemSuggestion.matching("").isEmpty)
        XCTAssertTrue(ShoppingItemSuggestion.matching(" ").isEmpty)
        XCTAssertTrue(ShoppingItemSuggestion.matching("m").isEmpty)
    }

    func testMatchingIsCaseAndDiacriticInsensitiveForSwedishNames() {
        let results = ShoppingItemSuggestion.matching("APEL")
        XCTAssertTrue(results.contains { $0.title == "Apelsiner" })

        let umlautQuery = ShoppingItemSuggestion.matching("apple")
        XCTAssertTrue(umlautQuery.isEmpty)
    }

    func testPrefixMatchesAreRankedBeforePartialMatches() {
        let results = ShoppingItemSuggestion.matching("tom")
        XCTAssertEqual(results.first?.title, "Tomater")
        XCTAssertTrue(results.contains { $0.title == "Krossade tomater" })
    }

    func testExistingItemsAreExcludedWithoutCaseOrDiacriticSensitivity() {
        let results = ShoppingItemSuggestion.matching("mjölk", excluding: ["MJÖLK"])
        XCTAssertFalse(results.contains { $0.title == "Mjölk" })
        XCTAssertTrue(results.contains { $0.title == "Mellanmjölk" })
        XCTAssertTrue(results.contains { $0.title == "Lättmjölk" })
    }

    func testSuggestionResultsAreLimitedToSix() {
        XCTAssertEqual(ShoppingItemSuggestion.matching("a").count, 0)
        XCTAssertLessThanOrEqual(ShoppingItemSuggestion.matching("a").count, 6)
        XCTAssertLessThanOrEqual(ShoppingItemSuggestion.matching("ka").count, 6)
    }

    func testSuggestionCarriesItsCatalogCategory() {
        let milk = ShoppingItemSuggestion.matching("mjölk").first { $0.title == "Mjölk" }
        XCTAssertEqual(milk?.category, .dairy)
    }
}
