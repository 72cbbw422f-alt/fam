import SwiftUI
import Supabase

struct FamilyOnboardingView: View {
    @State private var familyName = ""
    @State private var displayName = ""
    @State private var inviteCode = ""
    @State private var mode: Mode = .create
    @State private var isWorking = false
    @State private var message: String?
    @State private var createdInviteCode: String?

    private let client = SupabaseClientProvider.makeClient()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Välkommen")
                            .font(.largeTitle.weight(.semibold))
                            .foregroundStyle(FamiljenTheme.ink)
                        Text("Skapa er familj eller anslut med en inbjudningskod.")
                            .foregroundStyle(FamiljenTheme.muted)
                    }

                    Picker("Åtgärd", selection: $mode) {
                        Text("Skapa familj").tag(Mode.create)
                        Text("Jag har en kod").tag(Mode.join)
                    }
                    .pickerStyle(.segmented)

                    field("Ditt namn", text: $displayName, placeholder: "Förnamn")

                    if mode == .create {
                        field("Familjens namn", text: $familyName, placeholder: "Exempelvis Familjen Andersson")
                    } else {
                        field("Inbjudningskod", text: $inviteCode, placeholder: "Ange engångskoden")
                            .textInputAutocapitalization(.characters)
                    }

                    Button(action: submit) {
                        HStack {
                            if isWorking { ProgressView().tint(.white) }
                            Text(mode == .create ? "Skapa familj" : "Gå med i familjen")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(.white)
                        .background(FamiljenTheme.navy, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isWorking || displayName.trimmingCharacters(in: .whitespaces).isEmpty)

                    if let code = createdInviteCode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Er inbjudningskod")
                                .font(.headline)
                            Text(code)
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .tracking(2)
                            Text("Koden gäller i 48 timmar. Dela den med den du vill bjuda in.")
                                .font(.footnote)
                                .foregroundStyle(FamiljenTheme.muted)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(FamiljenTheme.muted)
                    }
                }
                .padding(20)
            }
            .background(FamiljenTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(FamiljenTheme.ink)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(14)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func submit() {
        Task {
            isWorking = true
            message = nil
            defer { isWorking = false }
            do {
                if mode == .create {
                    let familyIDResponse = try await client.rpc(
                        "create_family",
                        params: [
                            "family_name": familyName.trimmingCharacters(in: .whitespacesAndNewlines),
                            "owner_display_name": displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                        ]
                    ).execute()
                    let familyID = try JSONDecoder().decode(UUID.self, from: familyIDResponse.data)
                    let inviteResponse = try await client.rpc(
                        "create_family_invite",
                        params: ["target_family": familyID.uuidString]
                    ).execute()
                    createdInviteCode = try JSONDecoder().decode(String.self, from: inviteResponse.data)
                    message = "Familjen är skapad. Spara koden och dela den med din partner."
                } else {
                    _ = try await client.rpc(
                        "accept_family_invite",
                        params: [
                            "invite_code": inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                            "member_display_name": displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                        ]
                    ).execute()
                    message = "Du är nu ansluten till familjen."
                }
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private enum Mode: Hashable {
        case create
        case join
    }
}
