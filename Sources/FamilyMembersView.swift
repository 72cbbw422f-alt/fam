import SwiftUI

struct FamilyMembersView: View {
    @State private var members: [FamilyMember] = []
    @State private var birthdays: [UUID: Date] = [:]
    @State private var newChildName = ""
    @State private var editingChild: FamilyMember?
    @State private var showingEditor = false
    @State private var childToDelete: FamilyMember?
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        Image(systemName: member.role == .child ? "face.smiling" : "person.crop.circle")
                            .font(.title2).foregroundStyle(FamiljenTheme.navy).frame(width: 38, height: 38)
                            .background(FamiljenTheme.sand.opacity(0.55), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(member.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(FamiljenTheme.ink)
                            Text(member.role == .child ? "Barnprofil" : (member.role == .owner ? "Familjeägare" : "Vuxen"))
                                .font(.caption).foregroundStyle(FamiljenTheme.muted)
                            if let date = birthdays[member.id] {
                                Text("Födelsedag · " + date.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.caption2).foregroundStyle(FamiljenTheme.muted)
                            }
                        }
                        Spacer()
                        if member.role == .child { Image(systemName: "ellipsis").foregroundStyle(FamiljenTheme.muted) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { if member.role == .child { editingChild = member; showingEditor = true } }
                    .contextMenu {
                        if member.role == .child {
                            Button { editingChild = member; showingEditor = true } label: { Label("Redigera namn", systemImage: "pencil") }
                            Button(role: .destructive) { childToDelete = member; showingDeleteConfirmation = true } label: { Label("Ta bort barnprofil", systemImage: "trash") }
                        }
                    }
                }
            } header: { Text("Familjemedlemmar") }
            Section {
                TextField("Barnets namn", text: $newChildName).textInputAutocapitalization(.words)
                Button { addChild() } label: { Label("Lägg till barnprofil", systemImage: "plus.circle.fill").foregroundStyle(FamiljenTheme.navy) }
                    .disabled(newChildName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Barnprofiler behöver inget eget konto. Koppla dem till födelsedagar, bokningar och aktiviteter.")
                    .font(.caption).foregroundStyle(FamiljenTheme.muted)
            } header: { Text("Lägg till familjemedlem") }
            if let infoMessage { Section { Text(infoMessage).font(.footnote).foregroundStyle(.green) } }
            if let errorMessage { Section { Text(errorMessage).font(.footnote).foregroundStyle(.red) } }
        }
        .scrollContentBackground(.hidden).background(FamiljenTheme.paper)
        .navigationTitle("Familjen").navigationBarTitleDisplayMode(.inline)
        .task { loadMembers() }
        .refreshable { loadMembers() }
        .sheet(isPresented: $showingEditor, onDismiss: { editingChild = nil }) {
            if let editingChild {
                ChildProfileEditor(member: editingChild) { newName in
                    LocalFamilyStore.shared.renameChild(id: editingChild.id, name: newName)
                    loadMembers()
                    return true
                }
            }
        }
        .confirmationDialog("Ta bort barnprofilen?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Ta bort", role: .destructive) {
                if let childToDelete { LocalFamilyStore.shared.deleteChild(id: childToDelete.id); loadMembers() }
            }
            Button("Avbryt", role: .cancel) { childToDelete = nil }
        } message: { Text("Profilen tas bort. Kalenderaktiviteter kopplade till profilen tas också bort.") }
    }

    private func loadMembers() {
        let store = LocalFamilyStore.shared
        members = store.members
        birthdays = Dictionary(store.items.filter { $0.kind == .birthday }.compactMap { item in
            item.memberID.map { ($0, item.startsAt) }
        }, uniquingKeysWith: { first, _ in first })
    }
    private func addChild() {
        let clean = newChildName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 80 else { errorMessage = "Namnet får vara högst 80 tecken."; return }
        LocalFamilyStore.shared.addChild(name: clean)
        newChildName = ""; infoMessage = "Barnprofilen har lagts till."; loadMembers()
    }
}

private struct ChildProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    let member: FamilyMember
    let onSave: (String) async -> Bool
    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    init(member: FamilyMember, onSave: @escaping (String) async -> Bool) {
        self.member = member; self.onSave = onSave; _name = State(initialValue: member.displayName)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Barnprofil") { TextField("Namn", text: $name).textInputAutocapitalization(.words) }
                if let errorMessage { Section { Text(errorMessage).font(.footnote).foregroundStyle(.red) } }
            }
            .navigationTitle("Redigera profil").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Spara") { Task { await save() } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving) }
            }
        }
    }
    private func save() async {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count <= 80 else { errorMessage = "Namnet får vara högst 80 tecken."; return }
        isSaving = true; defer { isSaving = false }
        if await onSave(clean) { dismiss() } else { errorMessage = "Det gick inte att spara ändringen." }
    }
}
