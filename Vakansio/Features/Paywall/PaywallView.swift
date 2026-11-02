import SwiftUI
import Foundation
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var isModal: Bool = true

    @StateObject private var store = StoreKitService()
    @State private var selected: SubscriptionTier = .pro
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showSuccess = false
    @State private var purchaseError: String?

    private var buttonTitle: String {
        if app.tier == selected {
            return "Ваш поточний тариф"
        }
        if selected == .start {
            return "Старт активний за замовчуванням"
        }
        if StoreKitService.isEnabled && store.products.isEmpty {
            return "Тарифи тимчасово недоступні"
        }
        return "Оформити «\(selected.name)»"
    }

    private var selectedProduct: Product? {
        store.products.first { VakansioStoreProduct(rawValue: $0.id)?.tier == selected }
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
                ToolbarItem(placement: .cancellationAction) {
                    if isModal {
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
                Text("Ваш тариф «\(app.tier.name)» активний. Тепер доступно \(app.tier.vacancyLimit) активних вакансій.")
            }
            .task {
                guard StoreKitService.isEnabled else { return }
                store.startListening()
                await store.loadProducts()
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

    private var legal: some View {
        VStack(spacing: 6) {
            Text("Оплата через App Store. Starter — безкоштовно; Pro та Business — автопоновлювані підписки. Керувати підпискою можна в налаштуваннях Apple ID.")
                .font(.system(size: 10))
                .foregroundStyle(VK.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Link("Умови використання", destination: APIConfig.termsURL)
                Text("·")
                Link("Політика конфіденційності", destination: APIConfig.privacyURL)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(VK.brand)

            if let message = store.errorMessage ?? purchaseError {
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(VK.danger)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: Subscribe

    private var subscribeBar: some View {
        VStack(spacing: 7) {
            Divider().overlay(VK.hairline)

            PrimaryButton(
                title: buttonTitle,
                icon: selected == .start ? "leaf.fill" : "crown.fill",
                isLoading: isPurchasing,
                isEnabled: app.tier != selected && selected != .start && selectedProduct != nil
            ) {
                purchase()
            }

            Button {
                restore()
            } label: {
                Text(isRestoring ? "Відновлюємо…" : "Відновити покупки")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VK.brand)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring || isPurchasing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.regularMaterial)
    }

    private func purchase() {
        guard app.tier != selected, selected != .start, !isPurchasing else { return }
        guard let product = selectedProduct else {
            purchaseError = "Цей тариф ще не налаштований в App Store."
            return
        }

        isPurchasing = true
        purchaseError = nil

        Task { @MainActor in
            await store.purchase(product)
            defer { isPurchasing = false }

            guard let jws = store.latestJWS else {
                purchaseError = store.errorMessage ?? "Не вдалося отримати транзакцію App Store."
                return
            }

            let verified = await app.verifySubscription(jws: jws)
            if verified {
                showSuccess = true
            } else {
                purchaseError = app.lastErrorMessage ?? "Сервер не підтвердив підписку."
            }
        }
    }

    private func restore() {
        guard !isRestoring else { return }
        isRestoring = true
        purchaseError = nil

        Task { @MainActor in
            await store.restorePurchases()
            defer { isRestoring = false }

            guard let jws = store.latestJWS else {
                purchaseError = "Активних підписок не знайдено."
                return
            }

            if await app.verifySubscription(jws: jws) {
                showSuccess = true
            } else {
                purchaseError = app.lastErrorMessage ?? "Не вдалося відновити підписку."
            }
        }
    }
}
