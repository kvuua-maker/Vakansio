import SwiftUI
import Foundation

struct PaywallView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var isModal: Bool = true

    @State private var selected: SubscriptionTier = .pro
    @State private var isPurchasing = false
    @State private var showSuccess = false

    private var buttonTitle: String {
        if app.tier == selected {
            return "Ваш поточний тариф"
        }
        if selected.price == 0 {
            return "Перейти на Старт"
        }
        return "Підписатися за \(selected.priceText)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VK.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        hero
                        currentTierNote
                        plans
                        featuresCard
                        restoreButton
                        legal
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle(isModal ? "" : "Тарифи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isModal {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(VK.textPrimary)
                        }
                        .accessibilityLabel("Закрити")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                subscribeBar
            }
            .alert("Тариф активовано", isPresented: $showSuccess) {
                Button("Добре") {
                    if isModal { dismiss() }
                }
            } message: {
                Text("Ваш тариф «\(selected.name)» активний. Тепер доступно \(selected.vacancyLimit) активних вакансій.")
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 72, height: 72)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))

                Image(systemName: "crown.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.white)
            }

            Text("Більше вакансій — більше талантів")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Оберіть тариф, який відповідає масштабу вашого найму")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
        .background(
            VK.brandGradient,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: VK.brand.opacity(0.2), radius: 18, x: 0, y: 10)
    }

    private var currentTierNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VK.success)

            Text("Поточний тариф: \(app.tier.name)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VK.textSecondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Plans

    private var plans: some View {
        VStack(spacing: 12) {
            ForEach(SubscriptionTier.allCases) { tier in
                planCard(tier)
            }
        }
    }

    private func planCard(_ tier: SubscriptionTier) -> some View {
        let isSelected = selected == tier
        let isCurrent = app.tier == tier

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                selected = tier
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: tier.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tier.accent)

                        Text(tier.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(VK.textPrimary)

                        if tier.isPopular {
                            Text("Популярний")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(VK.brand, in: Capsule())
                        }

                        if isCurrent {
                            Text("Активний")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(VK.success)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(VK.success.opacity(0.12), in: Capsule())
                        }
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 0) {
                        Text(tier.priceText)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(VK.textPrimary)

                        Text(tier.periodText)
                            .font(.system(size: 10))
                            .foregroundStyle(VK.textSecondary)
                    }
                }

                Text(tier.tagline)
                    .font(.system(size: 12))
                    .foregroundStyle(VK.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(tier.features.prefix(3)), id: \.self) { feature in
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(tier.accent)
                                .frame(width: 15, height: 15)
                                .background(tier.accent.opacity(0.12), in: Circle())

                            Text(feature)
                                .font(.system(size: 12))
                                .foregroundStyle(VK.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VK.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? VK.brand : VK.hairline,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: Features

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Що входить у «\(selected.name)»")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(VK.textPrimary)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(selected.features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VK.success)
                            .padding(.top, 1)

                        Text(feature)
                            .font(.system(size: 13))
                            .foregroundStyle(VK.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .vkCard()
    }

    private var restoreButton: some View {
        Button {
            app.showToast("Активних покупок не знайдено", icon: "arrow.clockwise", style: .info)
        } label: {
            Text("Відновити покупки")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VK.brand)
        }
        .buttonStyle(.plain)
    }

    private var legal: some View {
        Text("Підписка автоматично поновлюється щомісяця. Скасувати можна в налаштуваннях Apple ID не пізніше ніж за 24 години до кінця періоду.")
            .font(.system(size: 10))
            .foregroundStyle(VK.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Subscribe

    private var subscribeBar: some View {
        VStack(spacing: 7) {
            Divider().overlay(VK.hairline)

            PrimaryButton(
                title: buttonTitle,
                icon: selected.price == 0 ? "leaf.fill" : "crown.fill",
                isLoading: isPurchasing,
                isEnabled: app.tier != selected
            ) {
                purchase()
            }

            Text("Оплата з вашого Apple ID. Скасувати можна в будь-який момент.")
                .font(.system(size: 10))
                .foregroundStyle(VK.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.regularMaterial)
    }

    private func purchase() {
        guard app.tier != selected, !isPurchasing else { return }

        isPurchasing = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            app.activate(selected)
            isPurchasing = false
            showSuccess = true
        }
    }
}
