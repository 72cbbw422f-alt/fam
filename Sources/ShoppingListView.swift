import SwiftUI

struct ShoppingListView: View {
    @StateObject private var model = ShoppingListViewModel()
    @State private var completedItemMessage: String?

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
                                Task {
                                    completedItemMessage = "✓  \(item.title) avbockad och borttagen"
                                    await model.setChecked(item, checked: true)
                                }
                            } label: {
                                Image(systemName: "circle")
                                    .font(.title3)
                                    .foregroundStyle(FamiljenTheme.muted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Markera \(item.title) som handlad")

                            Text(item.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(FamiljenTheme.ink)
                                .lineLimit(2)

                            Spacer(minLength: 4)
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
                        .font(.system(size: 14, weight: .semibold))
                }
            }

            if let error = model.errorMessage {
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
}
