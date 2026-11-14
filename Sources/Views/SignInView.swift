import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @StateObject private var authentication = AppleAuthenticationService()

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "house")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(FamiljenTheme.navy)

            VStack(spacing: 8) {
                Text("Familjen")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(FamiljenTheme.ink)
                Text("Allt som hör familjen till. Samlat på ett ställe.")
                    .font(.subheadline)
                    .foregroundStyle(FamiljenTheme.muted)
                    .multilineTextAlignment(.center)
            }

            SignInWithAppleButton(.continue) { request in
                authentication.prepare(request)
            } onCompletion: { result in
                Task { await authentication.complete(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 28)

            if let error = authentication.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()
            Text("Säker inloggning med ditt Apple-konto")
                .font(.caption)
                .foregroundStyle(FamiljenTheme.muted)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FamiljenTheme.paper.ignoresSafeArea())
        .fullScreenCover(isPresented: $authentication.isSignedIn) {
            FamilyOnboardingView()
        }
    }
}
