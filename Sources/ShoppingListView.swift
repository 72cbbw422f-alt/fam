import SwiftUI

struct ShoppingListView: View {
    @StateObject private var model = ShoppingListViewModel()

    var body: some View {
        List {
            Section {
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
                .padding(.vertical, 4)
            }

            if model.items.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "Listan är tom",
                    systemImage: "basket",
                    description: Text("Lägg till det ni behöver handla. Listan sparas bara på den här iPhone-enheten tills iCloud-delning är aktiverad.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(model.items) { item in
                        HStack(spacing: 12) {
                            Button {
                                Task { await model.setChecked(item, checked: !item.isChecked) }
                            } label: {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(item.isChecked ? FamiljenTheme.champagne : FamiljenTheme.muted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.isChecked ? "Markera som ej handlad" : "Markera som handlad")

                            Text(item.title)
                                .foregroundStyle(item.isChecked ? FamiljenTheme.muted : FamiljenTheme.ink)
                                .strikethrough(item.isChecked)

                            Spacer()
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await model.delete(item) }
                            } label: {
                                Label("Ta bort", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Att handla")
                }
            }

            if let error = model.errorMessage {
                Section {
                    Text(error)
                        .font(.footnote)
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
        .refreshable { await model.load() }
        .task { await model.load() }
        .onDisappear { Task { await model.stopRealtime() } }
    }
}
