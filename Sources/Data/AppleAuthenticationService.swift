import AuthenticationServices
import CryptoKit
import Foundation
import Combine
import Security
import Supabase

@MainActor
final class AppleAuthenticationService: ObservableObject {
    @Published var isSignedIn = false
    @Published var errorMessage: String?

    private let client: SupabaseClient
    private var currentNonce: String?

    init(client: SupabaseClient = SupabaseClientProvider.makeClient()) {
        self.client = client
    }

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func complete(_ result: Result<ASAuthorization, Error>) async {
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw SignInError.invalidCredential
            }
            guard let nonce = currentNonce else {
                throw SignInError.missingNonce
            }
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                throw SignInError.missingIdentityToken
            }

            try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )

            if let fullName = credential.fullName {
                let parts = [fullName.givenName, fullName.middleName, fullName.familyName]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                if !parts.isEmpty {
                    _ = try? await client.auth.update(
                        user: UserAttributes(data: ["full_name": .string(parts.joined(separator: " "))])
                    )
                }
            }

            currentNonce = nil
            errorMessage = nil
            isSignedIn = true
        } catch {
            currentNonce = nil
            errorMessage = error.localizedDescription
        }
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonce(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else {
                fatalError("Unable to generate a secure sign-in nonce.")
            }
            if Int(random) < characters.count {
                result.append(characters[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private enum SignInError: LocalizedError {
        case invalidCredential
        case missingNonce
        case missingIdentityToken

        var errorDescription: String? {
            switch self {
            case .invalidCredential: return "Apple returnerade en ogiltig inloggningsuppgift."
            case .missingNonce: return "Säkerhetskontrollen kunde inte slutföras. Försök igen."
            case .missingIdentityToken: return "Apple returnerade ingen identitetstoken."
            }
        }
    }
}
