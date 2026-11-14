import SwiftUI
import Supabase

struct RootView: View {
    @State private var hasSession = false
    @State private var hasFamily = false
    @State private var isCheckingSession = true

    private let client = SupabaseClientProvider.makeClient()

    var body: some View {
        Group {
            if isCheckingSession {
                ProgressView()
                    .tint(FamiljenTheme.navy)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(FamiljenTheme.paper.ignoresSafeArea())
            } else if !hasSession {
                SignInView()
            } else if hasFamily {
                DashboardView()
            } else {
                FamilyOnboardingView()
            }
        }
        .task {
            await restoreSessionAndFamily()
        }
    }

    @MainActor
    private func restoreSessionAndFamily() async {
        defer { isCheckingSession = false }
        do {
            let session = try await client.auth.session
            hasSession = true
            let response = try await client
                .from("family_members")
                .select("id")
                .eq("user_id", value: session.user.id.uuidString)
                .limit(1)
                .execute()
            let members = try JSONDecoder().decode([[String: String]].self, from: response.data)
            hasFamily = !members.isEmpty
        } catch {
            hasSession = false
            hasFamily = false
        }
    }
}
