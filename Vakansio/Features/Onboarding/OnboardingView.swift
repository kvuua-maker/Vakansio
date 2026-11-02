import SwiftUI
import Foundation

struct OnboardingView: View {
    @EnvironmentObject private var app: AppState
    @State private var selectedRole: UserRole?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            VK.screen.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero

                    VStack(spacing: 22) {
                        roleSection
                        continueButton
                        legal
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 36)
                }
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 86, height: 86)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    )

                Image(systemName: "briefcase.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)

            VStack(spacing: 8) {
                Text("Vakansio")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("Робота, яка підходить саме тобі")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                feature(icon: "checkmark.seal.fill", title: "Перевірені\nкомпанії")
                feature(icon: "bolt.fill", title: "Відгук\nза 1 хвилину")
                feature(icon: "sparkles", title: "AI-помічник\nдля резюме")
            }
            .padding(.top, 8)
        }
        .padding(.top, 74)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity)
        .background(
            VK.brandGradient
                .clipShape(
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: 34,
                        bottomTrailingRadius: 34,
                        style: .continuous
                    )
                )
                .ignoresSafeArea(edges: .top)
        )
    }

    private func feature(icon: String, title: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Role selection

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Оберіть свою роль")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VK.textPrimary)

                Text("Це налаштує головний екран під ваші задачі")
                    .font(.vkCaption)
                    .foregroundStyle(VK.textSecondary)
            }

            ForEach(UserRole.allCases) { role in
                roleCard(role)
            }
        }
    }

    private func roleCard(_ role: UserRole) -> some View {
        let isSelected = selectedRole == role

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedRole = role
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? VK.brand : VK.brand.opacity(0.10))
                        .frame(width: 52, height: 52)

                    Image(systemName: role.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : VK.brand)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(role.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VK.textPrimary)

                    Text(role.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(VK.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? VK.brand : VK.textTertiary)
            }
            .padding(16)
            .background(VK.card)
            .clipShape(RoundedRectangle(cornerRadius: VK.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VK.radius, style: .continuous)
                    .strokeBorder(isSelected ? VK.brand : VK.hairline, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: CTA

    private var continueButton: some View {
        VStack(spacing: 10) {
            PrimaryButton(
                title: "Продовжити",
                icon: "arrow.right",
                isLoading: isLoading,
                isEnabled: selectedRole != nil
            ) {
                continueWithSelectedRole()
            }

            Text("Ви зможете змінити роль у профілі в будь-який момент")
                .font(.system(size: 11))
                .foregroundStyle(VK.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var legal: some View {
        Text("Продовжуючи, ви приймаєте Умови використання та Політику конфіденційності Vakansio")
            .font(.system(size: 11))
            .foregroundStyle(VK.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    private func continueWithSelectedRole() {
        guard let role = selectedRole, !isLoading else { return }
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isLoading = false
            app.completeOnboarding(role: role)
        }
    }
}
