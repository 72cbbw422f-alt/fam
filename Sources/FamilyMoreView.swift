import SwiftUI

struct FamilyMoreView: View {
    @StateObject private var store = FamilyStore.shared
    @State private var showingRename = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Mer i Familjen")
                            .font(.system(size: 29, weight: .semibold, design: .serif))
                            .foregroundStyle(FamiljenTheme.ink)
                        Text("Inställningar och genvägar för ert gemensamma utrymme.")
                            .font(.system(size: 15))
                            .foregroundStyle(FamiljenTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)

                    VStack(spacing: 0) {
                        Button { showingRename = true } label: {
                            HStack(spacing: 13) {
                                icon("house.and.flag", color: FamiljenTheme.navy)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(store.family?.name ?? "Er familj")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(FamiljenTheme.ink)
                                    Text("Ändra familjens namn")
                                        .font(.system(size: 13))
                                        .foregroundStyle(FamiljenTheme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(FamiljenTheme.muted)
                            }
                            .padding(15)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(FamiljenTheme.sand).padding(.leading, 60)
                        NavigationLink { FamilyMembersView() } label: {
                            menuRow("person.2", title: "Familjemedlemmar", subtitle: "\(store.members.count) profiler")
                        }
                        Divider().overlay(FamiljenTheme.sand).padding(.leading, 60)
                        NavigationLink { FamilyMessagesView() } label: {
                            menuRow("bubble.left.and.bubble.right", title: "Meddelanden", subtitle: "Familjechatt och privata samtal")
                        }
                        Divider().overlay(FamiljenTheme.sand).padding(.leading, 60)
                        NavigationLink { FamilyCalendarView() } label: {
                            menuRow("calendar", title: "Kalender och påminnelser", subtitle: "Aktiviteter, bokningar och Apple Kalender")
                        }
                        Divider().overlay(FamiljenTheme.sand).padding(.leading, 60)
                        NavigationLink { ShoppingListView() } label: {
                            menuRow("cart", title: "Inköpslista", subtitle: "Det ni behöver handla")
                        }
                        Divider().overlay(FamiljenTheme.sand).padding(.leading, 60)
                        NavigationLink { NotificationsView() } label: {
                            menuRow("bell", title: "Notiser", subtitle: "Aviseringar från Familjen")
                        }
                        Divider().overlay(FamiljenTheme.sand).padding(.leading, 60)
                        NavigationLink { CapabilityDiagnosticsView() } label: {
                            menuRow("checkmark.shield", title: "Behörighetskontroll", subtitle: "Kontrollera iCloud och notiser på enheten")
                        }
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(FamiljenTheme.sand.opacity(0.7), lineWidth: 1))

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(FamiljenTheme.champagneDeep)
                            .frame(width: 42, height: 42)
                            .background(FamiljenTheme.champagne.opacity(0.2), in: Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Era uppgifter stannar här")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(FamiljenTheme.ink)
                            Text("Familjens information sparas lokalt på den här iPhonen. Delning mellan flera telefoner aktiveras först när säker familjesynkronisering är på plats.")
                                .font(.system(size: 13))
                                .lineSpacing(3)
                                .foregroundStyle(FamiljenTheme.muted)
                        }
                    }
                    .padding(16)
                    .background(FamiljenTheme.sand.opacity(0.32), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 36)
            }
            .background(FamiljenTheme.paper.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showingRename) {
                FamilyNameEditor(currentName: store.family?.name ?? "") { newName in
                    store.renameFamily(name: newName)
                }
            }
        }
    }

    private func icon(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 42, height: 42)
            .background(FamiljenTheme.sand.opacity(0.55), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func menuRow(_ symbol: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 13) {
            icon(symbol, color: FamiljenTheme.navy)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(FamiljenTheme.ink)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(FamiljenTheme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(FamiljenTheme.muted)
        }
        .padding(15)
        .contentShape(Rectangle())
    }
}

private struct FamilyNameEditor: View {
    @Environment(\.dismiss) private var dismiss
    let currentName: String
    let onSave: (String) -> Void
    @State private var name: String

    init(currentName: String, onSave: @escaping (String) -> Void) {
        self.currentName = currentName
        self.onSave = onSave
        _name = State(initialValue: currentName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Familjens namn") {
                    TextField("Namn", text: $name)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Ändra familjenamn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 80)
                }
            }
        }
    }
}
