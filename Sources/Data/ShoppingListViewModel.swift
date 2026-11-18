import Combine
import Foundation

@MainActor
final class ShoppingListViewModel: ObservableObject {
    @Published private(set) var items: [ShoppingItem] = []
    @Published private(set) var listTitle = "Inköpslista"
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var newItemTitle = ""
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
    func startRealtimeIfNeeded() async {}
    func stopRealtime() async {}
    func addItem() async {
        let title = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 160, !isSaving else { return }
        isSaving = true
        store.addShoppingItem(title)
        newItemTitle = ""
        await load()
        isSaving = false
    }
    func setChecked(_ item: ShoppingItem, checked: Bool) async {
        if checked {
            store.deleteShoppingItem(item.id)
        } else {
            store.setShoppingItem(item.id, checked: false)
        }
        await load()
    }
    func delete(_ item: ShoppingItem) async {
        store.deleteShoppingItem(item.id)
        await load()
    }
}
