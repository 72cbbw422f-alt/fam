import SwiftUI
import Supabase

struct RootView: View {
    @State private var isAuthenticated = false
    @State private var isCheckingSession = true

    private let client = SupabaseClientProvider.makeClient()

    var body: some View {
        Group {
            if isCheckingSession {
                ProgressView()
                    .tint(FamiljenTheme.navy)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(FamiljenTheme.paper.ignoresSafeArea())
            } else if isAuthenticated {
                FamilyOnboardingView()
            } else {
                SignInView()
            }
        }
        .task {
            do {
                _ = try await client.auth.session
                isAuthenticated = true
            } catch {
                isAuthenticated = false
            }
            isCheckingSession = false
        }
    }
}
