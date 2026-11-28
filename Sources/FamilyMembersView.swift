import SwiftUI

struct FamilyMembersView: View {
    @State private var members: [FamilyMember] = []
    @State private var birthdays: [UUID: Date] = [:]
    @State private var newChildName = ""
    @State private var newAdultName = ""
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
                        Image(systemName: member.resolvedSymbolName)
                            .font(.title2).foregroundStyle(FamiljenTheme.navy).frame(width: 38, height: 38)
                            .background(FamiljenTheme.sand.opacity(0.55), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(member.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(FamiljenTheme.ink)
                            Text(member.role == .child ? "Barnprofil" : (member.role == .owner ? "Familjeägare" : "Vuxenprofil"))
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
                    .onTapGesture { editingChild = member; showingEditor = true }
                    .contextMenu {
                        Button { editingChild = member; showingEditor = true } label: {
                            Label("Redigera profil", systemImage: "pencil")
                        }
                        if member.role != .owner {
                            Button(role: .destructive) { childToDelete = member; showingDeleteConfirmation = true } label: {
                                Label(member.role == .child ? "Ta bort barnprofil" : "Ta bort vuxenprofil", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: { Text("Familjemedlemmar") }
            Section {
                TextField("Vuxens namn", text: $newAdultName).textInputAutocapitalization(.words)
                Button { addAdult() } label: { Label("Lägg till vuxen", systemImage: "person.badge.plus").foregroundStyle(FamiljenTheme.navy) }
                    .disabled(newAdultName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Lägg till en vuxen familjemedlem. Profilen kan senare kopplas till ett eget konto när familjedelning aktiveras.")
                    .font(.caption).foregroundStyle(FamiljenTheme.muted)
            } header: { Text("Vuxna") }
            Section {
                TextField("Barnets namn", text: $newChildName).textInputAutocapitalization(.words)
                Button { addChild() } label: { Label("Lägg till barnprofil", systemImage: "plus.circle.fill").foregroundStyle(FamiljenTheme.navy) }
                    .disabled(newChildName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Barnprofiler behöver inget eget konto. Koppla dem till födelsedagar, bokningar och aktiviteter.")
                    .font(.caption).foregroundStyle(FamiljenTheme.muted)
            } header: { Text("Barn") }
            if let infoMessage { Section { Text(infoMessage).font(.footnote).foregroundStyle(.green) } }
            if let errorMessage { Section { Text(errorMessage).font(.footnote).foregroundStyle(.red) } }
        }
        .scrollContentBackground(.hidden).background(FamiljenTheme.paper)
        .navigationTitle("Familjen").navigationBarTitleDisplayMode(.inline)
        .task { loadMembers() }
        .refreshable { loadMembers() }
        .sheet(isPresented: $showingEditor, onDismiss: { editingChild = nil }) {
            if let editingChild {
                MemberProfileEditor(member: editingChild) { newName, symbolName in
                    let store = FamilyStore.shared
                    store.updateMemberProfile(id: editingChild.id, name: newName, symbolName: symbolName)
                    loadMembers()
                    return store.persistenceError == nil
                }
            }
        }
        .confirmationDialog(childToDelete?.role == .child ? "Ta bort barnprofilen?" : "Ta bort vuxenprofilen?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Ta bort", role: .destructive) {
                if let childToDelete {
                    let store = FamilyStore.shared
                    store.deleteMember(id: childToDelete.id)
                    loadMembers()
                    if let persistenceError = store.persistenceError {
                        errorMessage = persistenceError
                        infoMessage = nil
                    } else {
                        errorMessage = nil
                        infoMessage = "Familjeprofilen har tagits bort."
                    }
                    self.childToDelete = nil
                }
            }
            Button("Avbryt", role: .cancel) { childToDelete = nil }
        } message: { Text("Profilen och dess personliga hälsouppgifter, vårdbesök, recept och läkemedelshämtningar tas bort. Övriga kalenderhändelser finns kvar, men kopplingen till profilen rensas.") }
    }

    private func loadMembers() {
        let store = FamilyStore.shared
        members = store.members
        birthdays = Dictionary(store.items.filter { $0.kind == .birthday }.compactMap { item in
            item.memberID.map { ($0, item.startsAt) }
        }, uniquingKeysWith: { first, _ in first })
    }
    private func addChild() {
        let clean = newChildName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 80 else { errorMessage = "Ange ett namn på högst 80 tecken."; return }
        let store = FamilyStore.shared
        store.addChild(name: clean)
        loadMembers()
        if let persistenceError = store.persistenceError {
            errorMessage = persistenceError
            infoMessage = nil
        } else {
            newChildName = ""
            errorMessage = nil
            infoMessage = "Barnprofilen har lagts till."
        }
    }

    private func addAdult() {
        let clean = newAdultName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 80 else { errorMessage = "Namnet får vara högst 80 tecken."; return }
        let store = FamilyStore.shared
        store.addMember(name: clean, role: .member)
        loadMembers()
        if let persistenceError = store.persistenceError {
            errorMessage = persistenceError
            infoMessage = nil
        } else {
            newAdultName = ""
            errorMessage = nil
            infoMessage = "Vuxenprofilen har lagts till."
        }
    }
}

private struct MemberProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    let member: FamilyMember
    let onSave: (String, String?) async -> Bool
    @State private var name: String
    @State private var symbolSelection: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    private let symbols = ["person.crop.circle", "face.smiling", "person.fill", "person.2.fill", "figure", "figure.child", "pawprint.fill", "heart.fill", "star.fill", "sun.max.fill", "moon.fill", "leaf.fill", "flower.fill", "bolt.fill", "book.fill", "music.note", "basketball.fill", "gamecontroller.fill"]
    init(member: FamilyMember, onSave: @escaping (String, String?) async -> Bool) {
        self.member = member
        self.onSave = onSave
        _name = State(initialValue: member.displayName)
        _symbolSelection = State(initialValue: member.symbolName ?? "default")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section(member.role == .child ? "Barnprofil" : "Vuxenprofil") {
                    TextField("Namn", text: $name).textInputAutocapitalization(.words).disabled(member.role == .owner)
                }
                Section("Profilikon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 54))], spacing: 12) {
                        ForEach(["default"] + symbols, id: \.self) { symbol in
                            Button {
                                symbolSelection = symbol
                            } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: symbol == "default" ? (member.role == .child ? "face.smiling" : "person.crop.circle") : symbol)
                                        .font(.title2)
                                        .foregroundStyle(symbolSelection == symbol ? .white : FamiljenTheme.navy)
                                        .frame(width: 46, height: 46)
                                        .background(symbolSelection == symbol ? FamiljenTheme.navy : FamiljenTheme.sand.opacity(0.55), in: Circle())
                                    if symbol == "default" {
                                        Text("Standard").font(.caption2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbol == "default" ? "Standardikon" : "Välj profilikon")
                            .accessibilityAddTraits(symbolSelection == symbol ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                if let errorMessage { Section { Text(errorMessage).font(.footnote).foregroundStyle(.red) } }
            }
            .navigationTitle("Redigera profil").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Spara") { Task { await save() } }.disabled((member.role != .owner && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || isSaving) }
            }
        }
    }
    private func save() async {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count <= 80 else { errorMessage = "Namnet får vara högst 80 tecken."; return }
        isSaving = true; defer { isSaving = false }
        if await onSave(clean, symbolSelection == "default" ? nil : symbolSelection) {
            dismiss()
        } else {
            errorMessage = "Det gick inte att spara ändringen."
        }
    }
}
