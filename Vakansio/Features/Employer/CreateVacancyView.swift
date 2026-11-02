import SwiftUI
import Foundation

struct CreateVacancyView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var router: TabRouter
    @Environment(\.dismiss) private var dismiss

    var showsCloseButton: Bool = false

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                VK.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        if !app.canCreateVacancy {
                            limitBanner
                        }

                        methodGrid
                        aiTip
                        statsHint
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CreationMethod.self) { method in
                VacancyFormView(method: method)
            }
        }
        .overlay(alignment: .topLeading) {
            if showsCloseButton {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VK.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(VK.card, in: Circle())
                        .overlay(Circle().strokeBorder(VK.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .padding(.top, 8)
                .accessibilityLabel("Закрити")
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Нова вакансія")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(VK.textPrimary)

            Text("Оберіть спосіб створення — решту зробимо ми")
                .font(.system(size: 13))
                .foregroundStyle(VK.textSecondary)
        }
        .padding(.top, showsCloseButton ? 44 : 4)
    }

    // MARK: Methods

    private var methodGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(CreationMethod.allCases) { method in
                NavigationLink(value: method) {
                    methodCard(method)
                }
                .buttonStyle(PressableCardStyle())
            }
        }
    }

    private func methodCard(_ method: CreationMethod) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(method.tint.opacity(0.12))
                        .frame(width: 46, height: 46)

                    Image(systemName: method.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(method.tint)
                }

                Spacer(minLength: 4)

                if let badge = method.badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(method.tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(method.tint.opacity(0.12), in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(method.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)

                Text(method.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(VK.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Text("Обрати")
                    .font(.system(size: 11, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(method.tint)
        }
        .frame(maxWidth: .infinity, minHeight: 164, alignment: .topLeading)
        .padding(14)
        .background(VK.card)
        .clipShape(RoundedRectangle(cornerRadius: VK.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VK.radius, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
    }

    // MARK: Extras

    private var limitBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VK.warning)

            Text("Ліміт тарифу вичерпано. Щоб опублікувати ще одну вакансію, змініть план.")
                .font(.system(size: 12))
                .foregroundStyle(VK.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                router.selection = 2
            } label: {
                Text("Змінити")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VK.warning)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(VK.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(VK.warning.opacity(0.2), lineWidth: 1)
        )
    }

    private var aiTip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VK.warning)

            VStack(alignment: .leading, spacing: 3) {
                Text("Порада")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)

                Text("AI-помічник напише опис вакансії за 30 секунд — достатньо вказати посаду та ключові навички.")
                    .font(.system(size: 12))
                    .foregroundStyle(VK.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .vkCard(padding: 14)
    }

    private var statsHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VK.brand)

            Text("Вакансії з детальним описом отримують у 2,4 раза більше відгуків.")
                .font(.system(size: 12))
                .foregroundStyle(VK.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}
