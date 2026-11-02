import SwiftUI
import Foundation
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var apple = AppleSignInService()
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            VK.screen.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    hero
                    benefits

                    if app.isRestoringSession {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Відновлюємо сесію…")
                                .font(.system(size: 12))
                                .foregroundStyle(VK.textSecondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        AppleSignInButton(isLoading: app.isAuthLoading || apple.isAuthorizing) {
                            errorMessage = nil
                            apple.start()
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(VK.danger)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Email використовується лише для акаунта та сервісних листів. Спілкування з роботодавцями — тільки у внутрішньому чаті.")
                        .font(.system(size: 11))
                        .foregroundStyle(VK.textTertiary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Продовжуючи, ви приймаєте Умови використання та Політику конфіденційності.")
                        .font(.system(size: 10))
                        .foregroundStyle(VK.textTertiary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 4) {
                        Link("Умови", destination: APIConfig.termsURL)
                        Text("·")
                        Link("Конфіденційність", destination: APIConfig.privacyURL)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VK.brand)
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 28)
            }
        }
        .onChange(of: apple.result?.userID) { _, _ in
            handleAppleResult()
        }
        .onChange(of: apple.errorMessage) { _, message in
            if let message, !message.isEmpty {
                errorMessage = message
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )

                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color.white)
            }

            Text("Один акаунт —\nусі можливості")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)

            Text(app.role == .employer
                 ? "Увійдіть, щоб керувати вакансіями, кандидатами та тарифом."
                 : "Увійдіть, щоб зберігати резюме, відгуки та спілкуватися з роботодавцями.")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(
            VK.brandGradient,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: VK.brand.opacity(0.2), radius: 18, x: 0, y: 10)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit(icon: "lock.shield.fill", title: "Захищена сесія", subtitle: "JWT-сесія зберігається в Keychain")
            benefit(icon: "checkmark.seal.fill", title: "Перевірені роботодавці", subtitle: "ЄДРПОУ через Overit")
            benefit(icon: "sparkles", title: "AI-резюме та матчинг", subtitle: "DeepSeek для всіх професій")
        }
        .vkCard()
    }

    private func benefit(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(VK.brand.opacity(0.1))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.brand)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(VK.textSecondary)
            }

            Spacer(minLength: 0)
        }
    }

    private func handleAppleResult() {
        guard let result = apple.result else { return }
        guard let identityToken = result.identityToken, !identityToken.isEmpty else {
            errorMessage = "Apple не повернув identityToken. Спробуйте ще раз."
            return
        }

        let name = formattedName(result.fullName)
        Task { @MainActor in
            await app.authenticateWithApple(identityToken: identityToken, fullName: name)
        }
    }

    private func formattedName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        let value = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
