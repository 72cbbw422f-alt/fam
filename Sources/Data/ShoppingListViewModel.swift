import Combine
import Foundation

@MainActor
final class ShoppingListViewModel: ObservableObject {
    @Published private(set) var items: [ShoppingItem] = []
    @Published private(set) var listTitle = "Inköpslista"
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var newItemTitle = ""
    @Published var selectedCategory: ShoppingCategory = .other
    @Published var errorMessage: String?
    private let store: any FamilyRepository

    init(store: (any FamilyRepository)? = nil) {
        self.store = store ?? FamilyRepositoryFactory.makeDefault()
    }

    func load() async {
        isLoading = true
        items = store.shoppingItems.sorted {
            if $0.isChecked != $1.isChecked { return !$0.isChecked }
            return $0.createdAt < $1.createdAt
        }
        isLoading = false
    }
    var activeItems: [ShoppingItem] { items.filter { !$0.isChecked } }
    var completedItems: [ShoppingItem] { items.filter(\.isChecked) }
    var suggestions: [ShoppingItemSuggestion] {
        ShoppingItemSuggestion.matching(newItemTitle, excluding: items.map(\.title))
    }
    var favoriteSuggestions: [ShoppingItemSuggestion] {
        ShoppingItemSuggestion.catalog.filter { suggestion in
            store.favoriteShoppingItemTitles.contains { $0.caseInsensitiveCompare(suggestion.title) == .orderedSame }
        }
    }

    func startRealtimeIfNeeded() async {}
    func stopRealtime() async {}
    func addItem() async {
        let title = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 160, !isSaving else { return }
        isSaving = true
        store.addShoppingItem(title, category: selectedCategory)
        newItemTitle = ""
        await load()
        isSaving = false
    }
    func addSuggestion(_ suggestion: ShoppingItemSuggestion) async {
        guard !isSaving else { return }
        isSaving = true
        store.addShoppingItem(suggestion.title, category: suggestion.category)
        selectedCategory = suggestion.category
        newItemTitle = ""
        await load()
        isSaving = false
    }

    func setFavorite(_ suggestion: ShoppingItemSuggestion, isFavorite: Bool) async {
        store.setShoppingItemFavorite(suggestion.title, isFavorite: isFavorite)
        await load()
    }

    func setChecked(_ item: ShoppingItem, checked: Bool) async {
        store.setShoppingItem(item.id, checked: checked)
        await load()
    }
    func delete(_ item: ShoppingItem) async {
        store.deleteShoppingItem(item.id)
        await load()
    }

    func clearCompleted() async {
        guard !isSaving else { return }
        isSaving = true
        store.clearCompletedShoppingItems()
        await load()
        isSaving = false
    }

    func clearAll() async {
        guard !isSaving else { return }
        isSaving = true
        store.clearAllShoppingItems()
        await load()
        isSaving = false
    }
}
