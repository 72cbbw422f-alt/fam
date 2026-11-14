import SwiftUI
import Supabase

struct FamilyMembersView: View {
    @State private var members: [FamilyMember] = []
    @State private var birthdays: [UUID: Date] = [:]
    @State private var newChildName = ""
    @State private var editingChild: FamilyMember?
    @State private var showingEditor = false
    @State private var childToDelete: FamilyMember?
    @State private var showingDeleteConfirmation = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    private let client = SupabaseClientProvider.makeClient()

    var body: some View {
        List {
            Section {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        Image(systemName: member.role == .child ? "face.smiling" : "person.crop.circle")
                            .font(.title2)
                            .foregroundStyle(FamiljenTheme.navy)
                            .frame(width: 38, height: 38)
                            .background(FamiljenTheme.sand.opacity(0.55), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(member.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FamiljenTheme.ink)
                            Text(roleName(member.role))
                                .font(.caption)
                                .foregroundStyle(FamiljenTheme.muted)
                            if let birthday = birthdays[member.id] {
                                Text("Födelsedag · " + birthday.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.caption2)
                                    .foregroundStyle(FamiljenTheme.muted)
                            }
                        }
                        Spacer()
                        if member.linkedUserID != nil {
                            Image(systemName: "checkmark.icloud")
                                .foregroundStyle(FamiljenTheme.muted)
                                .accessibilityLabel("Har ett konto")
                        } else if member.role == .child {
                            Image(systemName: "ellipsis").foregroundStyle(FamiljenTheme.muted)
                        }
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .contextMenu {
                        if member.role == .child {
                            Button {
                                editingChild = member
                                showingEditor = true
                            } label: { Label("Redigera namn", systemImage: "pencil") }
                            Button(role: .destructive) {
                                childToDelete = member
                                showingDeleteConfirmation = true
                            } label: { Label("Ta bort barnprofil", systemImage: "trash") }
                        }
                    }
                    .onTapGesture {
                        if member.role == .child {
                            editingChild = member
                            showingEditor = true
                        }
                    }
                }
            } header: {
                Text("Familjemedlemmar")
            } footer: {
                Text("Tryck på en barnprofil för att ändra namnet. Håll in för fler alternativ.")
            }

            Section {
                TextField("Barnets namn", text: $newChildName)
                    .textInputAutocapitalization(.words)
                Button {
                    Task { await addChild() }
                } label: {
                    HStack {
                        if isSaving { ProgressView() }
                        Label("Lägg till barnprofil", systemImage: "plus.circle.fill")
                    }
                    .foregroundStyle(FamiljenTheme.navy)
                }
                .disabled(isSaving || newChildName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Barnprofiler behöver inget eget konto. Koppla dem till födelsedagar, bokningar och aktiviteter i kalendern.")
                    .font(.caption)
                    .foregroundStyle(FamiljenTheme.muted)
            } header: {
                Text("Lägg till familjemedlem")
            }

            if let infoMessage {
                Section { Text(infoMessage).font(.footnote).foregroundStyle(.green) }
            }
            if let errorMessage {
                Section { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(FamiljenTheme.paper)
        .navigationTitle("Familjen")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if isLoading { ProgressView("Hämtar familjen …") } }
        .task { await loadMembers() }
        .refreshable { await loadMembers() }
        .sheet(isPresented: $showingEditor, onDismiss: { editingChild = nil }) {
            if let editingChild {
                ChildProfileEditor(member: editingChild) { newName in
                    await updateChild(editingChild, name: newName)
                }
            }
        }
        .confirmationDialog("Ta bort barnprofilen?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Ta bort", role: .destructive) {
                if let childToDelete { Task { await deleteChild(childToDelete) } }
            }
            Button("Avbryt", role: .cancel) { childToDelete = nil }
        } message: {
            Text("Profilen tas bort från familjen. Kalenderaktiviteter som är kopplade till profilen blir kvar men kopplas loss.")
        }
    }

    private func loadMembers() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let session = try await client.auth.session
            let response = try await client.from("family_members")
                .select("id,family_id,display_name,role,user_id")
                .eq("user_id", value: session.user.id.uuidString)
                .limit(1).execute()
            let ownMemberships = try JSONDecoder().decode([FamilyMember].self, from: response.data)
            guard let familyID = ownMemberships.first?.familyID else {
                members = []
                return
            }
            let familyResponse = try await client.from("family_members")
                .select("id,family_id,display_name,role,user_id")
                .eq("family_id", value: familyID.uuidString)
                .order("created_at", ascending: true).execute()
            members = try JSONDecoder().decode([FamilyMember].self, from: familyResponse.data)
            let birthdayResponse = try await client.from("family_items")
                .select("member_id,starts_at")
                .eq("family_id", value: familyID.uuidString)
                .eq("kind", value: "birthday")
                .execute()
            let birthdayRows = try JSONDecoder().decode([BirthdayLink].self, from: birthdayResponse.data)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let standardFormatter = ISO8601DateFormatter()
            birthdays = birthdayRows.reduce(into: [UUID: Date]()) { result, row in
                guard let memberID = row.memberID,
                      let date = formatter.date(from: row.startsAt) ?? standardFormatter.date(from: row.startsAt) else { return }
                result[memberID] = date
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func addChild() async {
        let name = newChildName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        infoMessage = nil
        defer { isSaving = false }
        do {
            try await client.rpc("create_family_child_profile", params: ["child_display_name": name]).execute()
            newChildName = ""
            infoMessage = "Barnprofilen har lagts till."
            await loadMembers()
        } catch { errorMessage = error.localizedDescription }
    }

    private func updateChild(_ child: FamilyMember, name: String) async -> Bool {
        do {
            try await client.rpc("update_family_child_profile", params: [
                "target_member_id": child.id.uuidString,
                "new_display_name": name
            ]).execute()
            infoMessage = "Barnprofilen har uppdaterats."
            await loadMembers()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func deleteChild(_ child: FamilyMember) async {
        do {
            try await client.rpc("delete_family_child_profile", params: [
                "target_member_id": child.id.uuidString
            ]).execute()
            infoMessage = "Barnprofilen har tagits bort."
            childToDelete = nil
            await loadMembers()
        } catch { errorMessage = error.localizedDescription }
    }

    private struct BirthdayLink: Decodable {
        let memberID: UUID?
        let startsAt: String
        enum CodingKeys: String, CodingKey {
            case memberID = "member_id"
            case startsAt = "starts_at"
        }
    }

    private func roleName(_ role: MemberRole) -> String {
        switch role {
        case .owner: return "Familjeägare"
        case .member: return "Vuxen"
        case .child: return "Barnprofil"
        }
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
        self.member = member
        self.onSave = onSave
        _name = State(initialValue: member.displayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Barnprofil") {
                    TextField("Namn", text: $name).textInputAutocapitalization(.words)
                }
                if let errorMessage {
                    Section { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Redigera profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanName.count <= 80 else {
            errorMessage = "Namnet får vara högst 80 tecken."
            return
        }
        isSaving = true
        defer { isSaving = false }
        if await onSave(cleanName) { dismiss() }
        else { errorMessage = "Det gick inte att spara ändringen." }
    }
}
