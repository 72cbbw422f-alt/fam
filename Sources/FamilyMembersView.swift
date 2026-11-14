import SwiftUI
import Supabase

struct FamilyMembersView: View {
    @State private var members: [FamilyMember] = []
    @State private var newChildName = ""
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
                        }
                        Spacer()
                        if member.linkedUserID != nil {
                            Image(systemName: "checkmark.icloud")
                                .foregroundStyle(FamiljenTheme.muted)
                                .accessibilityLabel("Har ett konto")
                        }
                    }
                    .padding(.vertical, 3)
                }
            } header: {
                Text("Familjemedlemmar")
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
                Text("Barnprofiler behöver inget eget konto. De kan kopplas till födelsedagar, bokningar och aktiviteter.")
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
        .overlay {
            if isLoading { ProgressView("Hämtar familjen …") }
        }
        .task { await loadMembers() }
        .refreshable { await loadMembers() }
    }

    private func loadMembers() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let session = try await client.auth.session
            let response = try await client
                .from("family_members")
                .select("id,family_id,display_name,role,user_id")
                .eq("user_id", value: session.user.id.uuidString)
                .limit(1)
                .execute()
            let ownMemberships = try JSONDecoder().decode([FamilyMember].self, from: response.data)
            guard let familyID = ownMemberships.first?.familyID else {
                members = []
                return
            }
            let familyResponse = try await client
                .from("family_members")
                .select("id,family_id,display_name,role,user_id")
                .eq("family_id", value: familyID.uuidString)
                .order("created_at", ascending: true)
                .execute()
            members = try JSONDecoder().decode([FamilyMember].self, from: familyResponse.data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addChild() async {
        let name = newChildName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        infoMessage = nil
        defer { isSaving = false }
        do {
            try await client.rpc(
                "create_family_child_profile",
                params: ["child_display_name": name]
            ).execute()
            newChildName = ""
            infoMessage = "Barnprofilen har lagts till."
            await loadMembers()
        } catch {
            errorMessage = error.localizedDescription
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
