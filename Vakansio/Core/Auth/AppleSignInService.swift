import Foundation
import Combine
import AuthenticationServices
import UIKit
import CryptoKit
import Security

/// Real Sign in with Apple implementation, prepared for later activation.
/// Intentionally not used by AppState yet: activating it requires the
/// "Sign in with Apple" capability / entitlement on the App ID.
/// Do not add that entitlement until we enable the feature in App Store Connect.
struct AppleSignInResult {
    let userID: String
    let email: String?
    let fullName: PersonNameComponents?
    let identityToken: String?
    let authorizationCode: String?
}

final class AppleSignInService: NSObject, ObservableObject {
    static let isEnabled = true

    @Published private(set) var isAuthorizing = false
    @Published private(set) var result: AppleSignInResult?
    @Published private(set) var errorMessage: String?

    private var currentNonce: String?

    func start() {
        guard !isAuthorizing else { return }
        isAuthorizing = true
        errorMessage = nil
        result = nil

        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess {
                continue
            }
            if Int(random) < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        isAuthorizing = false

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Apple не повернув очікувані дані."
            return
        }

        let token = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }

        result = AppleSignInResult(
            userID: credential.user,
            email: credential.email,
            fullName: credential.fullName,
            identityToken: token,
            authorizationCode: code
        )
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isAuthorizing = false

        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return
        }
        errorMessage = error.localizedDescription
    }
}

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })

        return keyWindow ?? UIWindow(frame: .zero)
    }
}
