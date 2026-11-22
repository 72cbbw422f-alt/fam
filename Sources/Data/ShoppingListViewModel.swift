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
    func setChecked(_ item: ShoppingItem, checked: Bool) async {
        store.setShoppingItem(item.id, checked: checked)
        await load()
    }
    func delete(_ item: ShoppingItem) async {
        store.deleteShoppingItem(item.id)
        await load()
    }
}
