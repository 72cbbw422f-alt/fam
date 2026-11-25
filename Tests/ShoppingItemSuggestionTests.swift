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

        let accentInsensitive = ShoppingItemSuggestion.matching("creme")
        XCTAssertTrue(accentInsensitive.contains { $0.title == "Crème fraiche" })
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
        XCTAssertTrue(ShoppingItemSuggestion.matching("a").isEmpty)
        XCTAssertLessThanOrEqual(ShoppingItemSuggestion.matching("ka").count, 6)
    }

    func testSuggestionCarriesItsCatalogCategory() {
        let milk = ShoppingItemSuggestion.matching("mjölk").first { $0.title == "Mjölk" }
        XCTAssertEqual(milk?.category, .dairy)
    }
    func testAliasesFindCanonicalProductsWithoutCreatingDuplicateSuggestions() {
        let coke = ShoppingItemSuggestion.matching("coke")
        XCTAssertEqual(coke.first?.title, "Coca-Cola")
        XCTAssertEqual(coke.filter { $0.title == "Coca-Cola" }.count, 1)

        let cola = ShoppingItemSuggestion.matching("coca cola")
        XCTAssertTrue(cola.contains { $0.title == "Coca-Cola" })
        XCTAssertTrue(cola.contains { $0.title == "Coca-Cola Zero" })

        let zero = ShoppingItemSuggestion.matching("coke zero")
        XCTAssertEqual(zero.first?.title, "Coca-Cola Zero")
    }

    func testAliasesIgnorePunctuationAndCase() {
        let results = ShoppingItemSuggestion.matching("COCA-COLA")
        XCTAssertTrue(results.contains { $0.title == "Coca-Cola" })
    }

    func testAliasResultsRespectExistingCanonicalItems() {
        let results = ShoppingItemSuggestion.matching("coke", excluding: ["Coca-Cola"])
        XCTAssertFalse(results.contains { $0.title == "Coca-Cola" })
    }

}
