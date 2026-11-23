import SwiftUI

struct ShoppingListView: View {
    @StateObject private var model = ShoppingListViewModel()
    @State private var completedItemMessage: String?

    private var categoriesWithItems: [ShoppingCategory] {
        ShoppingCategory.allCases.filter { category in
            model.activeItems.contains { ($0.category ?? .other) == category }
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        TextField("Lägg till vara …", text: $model.newItemTitle)
                            .textInputAutocapitalization(.sentences)
                            .submitLabel(.done)
                            .onSubmit { Task { await model.addItem() } }
                        Button {
                            Task { await model.addItem() }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(FamiljenTheme.navy)
                        }
                        .disabled(model.newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSaving)
                        .accessibilityLabel("Lägg till vara")
                    }
                    if !model.suggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(model.suggestions) { suggestion in
                                Button {
                                    Task { await model.addSuggestion(suggestion) }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: suggestion.category.symbol)
                                            .foregroundStyle(FamiljenTheme.champagneDeep)
                                            .frame(width: 22)
                                        Text(suggestion.title)
                                            .foregroundStyle(FamiljenTheme.ink)
                                        Spacer()
                                        Text(suggestion.category.title)
                                            .font(.caption)
                                            .foregroundStyle(FamiljenTheme.muted)
                                        Image(systemName: "plus")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(FamiljenTheme.navy)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 11)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(model.isSaving)
                                if suggestion.id != model.suggestions.last?.id {
                                    Divider().overlay(FamiljenTheme.sand)
                                }
                            }
                        }
                        .background(.white, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(FamiljenTheme.sand, lineWidth: 1))
                        .accessibilityLabel("Varuförslag")
                    }

                    Menu {
                        Picker("Kategori", selection: $model.selectedCategory) {
                            ForEach(ShoppingCategory.allCases) { category in
                                Label(category.title, systemImage: category.symbol).tag(category)
                            }
                        }
                    } label: {
                        Label(model.selectedCategory.title, systemImage: model.selectedCategory.symbol)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(FamiljenTheme.navy)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(FamiljenTheme.sand.opacity(0.45), in: Capsule())
                    }
                    .accessibilityLabel("Välj kategori för ny vara")
                }
                .padding(.vertical, 4)
            }

            if model.activeItems.isEmpty && model.completedItems.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "Listan är tom",
                    systemImage: "basket",
                    description: Text("Lägg till det ni behöver handla. Listan sparas på den här iPhone-enheten tills iCloud-delning är aktiverad.")
                )
                .listRowBackground(Color.clear)
            }

            ForEach(categoriesWithItems) { category in
                Section {
                    ForEach(model.activeItems.filter { ($0.category ?? .other) == category }) { item in
                        itemRow(item)
                    }
                } header: {
                    Label(category.title, systemImage: category.symbol)
                        .font(.system(size: 14, weight: .semibold))
                }
            }

            if !model.completedItems.isEmpty {
                Section {
                    ForEach(model.completedItems) { item in
                        itemRow(item)
                    }
                } header: {
                    HStack {
                        Label("Handlat", systemImage: "checkmark.circle")
                        Spacer()
                        Text("\(model.completedItems.count)")
                            .foregroundStyle(FamiljenTheme.muted)
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
            }

            if let error = model.errorMessage ?? FamilyStore.shared.persistenceError {
                Section {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(FamiljenTheme.paper)
        .navigationTitle(model.listTitle)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if model.isLoading && model.items.isEmpty {
                ProgressView("Hämtar inköpslistan …")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let completedItemMessage {
                HStack(spacing: 10) {
                    Text(completedItemMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(FamiljenTheme.ink)
                    Spacer()
                    Button {
                        self.completedItemMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FamiljenTheme.muted)
                    }
                    .accessibilityLabel("Stäng bekräftelse")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(FamiljenTheme.sand, lineWidth: 1))
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
        }
        .refreshable { await model.load() }
        .task { await model.load() }
        .onDisappear { Task { await model.stopRealtime() } }
    }

    private func itemRow(_ item: ShoppingItem) -> some View {
        Button {
            Task {
                completedItemMessage = item.isChecked
                    ? "\(item.title) tillbaka på listan"
                    : "✓  \(item.title) markerad som handlad"
                await model.setChecked(item, checked: !item.isChecked)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? FamiljenTheme.navy : FamiljenTheme.muted)

                Text(item.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(item.isChecked ? FamiljenTheme.muted : FamiljenTheme.ink)
                    .strikethrough(item.isChecked)
                    .lineLimit(2)
                Spacer(minLength: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.isChecked ? "Lägg tillbaka \(item.title)" : "Markera \(item.title) som handlad")
        .swipeActions {
            Button(role: .destructive) {
                Task { await model.delete(item) }
            } label: {
                Label("Ta bort", systemImage: "trash")
            }
        }
    }
}
