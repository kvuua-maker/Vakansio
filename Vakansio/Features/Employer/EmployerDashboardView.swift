import SwiftUI
import Foundation

struct EmployerDashboardView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var router: TabRouter

    @State private var isLoading = true
    @State private var hasLoaded = false
    @State private var showPaywall = false

    private let totalViews = 1_248
    private let totalResponses = 32
    private let conversion = "2,6%"

    var body: some View {
        NavigationStack {
            ZStack {
                VK.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        header
                        subscriptionCard

                        if isLoading {
                            SkeletonStatRow()
                            ForEach(0..<2, id: \.self) { _ in
                                SkeletonVacancyCard()
                            }
                        } else {
                            stats
                            vacanciesSection
                            createButton
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isModal: true)
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            isLoading = true
            try? await Task.sleep(nanoseconds: 800_000_000)
            isLoading = false
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Дашборд")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VK.textSecondary)

                Text("Привіт, \(app.company.name) 👋")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(VK.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            CompanyAvatar(initials: app.company.initials, size: 44)
        }
        .padding(.top, 4)
    }

    // MARK: Subscription

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 34, height: 34)

                    Image(systemName: app.tier.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Тариф \(app.tier.name)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text("\(app.tier.priceText) · \(app.tier.periodText)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.8))
                }

                Spacer(minLength: 4)

                Button {
                    showPaywall = true
                } label: {
                    Text("Змінити")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            LimitProgressView(
                used: app.employerVacancies.count,
                limit: app.tier.vacancyLimit,
                tint: Color.white,
                track: Color.white.opacity(0.22),
                showLabels: false
            )

            HStack(spacing: 8) {
                Text("Використано \(app.employerVacancies.count) з \(app.tier.vacancyLimit) вакансій")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))

                Spacer(minLength: 0)

                Text("Залишилось \(app.vacanciesRemaining)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
        }
        .padding(18)
        .background(
            VK.premiumGradient,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: VK.brand.opacity(0.2), radius: 18, x: 0, y: 10)
    }

    // MARK: Stats

    private var stats: some View {
        HStack(spacing: 10) {
            StatTile(value: vkFormatMoney(totalViews), label: "Перегляди", icon: "eye.fill", tint: VK.brand)
            StatTile(value: "\(totalResponses)", label: "Відгуки", icon: "paperplane.fill", tint: VK.warning)
            StatTile(value: conversion, label: "Конверсія", icon: "chart.line.uptrend.xyaxis", tint: VK.success)
        }
    }

    // MARK: Vacancies

    private var vacanciesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Мої вакансії")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                Text("\(app.employerVacancies.count) активних")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VK.textSecondary)
            }
            .padding(.top, 4)

            if app.employerVacancies.isEmpty {
                EmptyStateView(
                    icon: "briefcase",
                    title: "Ще немає вакансій",
                    message: "Створіть першу вакансію — і кандидати зможуть вас знайти.",
                    actionTitle: "Створити",
                    action: { router.selection = 1 }
                )
                .vkCard()
            } else {
                ForEach(app.employerVacancies) { vacancy in
                    employerVacancyRow(vacancy)
                }
            }
        }
    }

    private func employerVacancyRow(_ vacancy: Vacancy) -> some View {
        HStack(spacing: 12) {
            CompanyAvatar(initials: vacancy.company.initials, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(vacancy.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(VK.success)
                            .frame(width: 6, height: 6)
                        Text("Активна")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VK.success)
                    }

                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(VK.textTertiary)

                    Text(vacancy.city)
                        .font(.system(size: 11))
                        .foregroundStyle(VK.textSecondary)

                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(VK.textTertiary)

                    Text(vacancy.postedText)
                        .font(.system(size: 11))
                        .foregroundStyle(VK.textSecondary)
                }
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text("128")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VK.textPrimary)
                Text("переглядів")
                    .font(.system(size: 10))
                    .foregroundStyle(VK.textTertiary)
            }
        }
        .vkCard(padding: 14)
    }

    // MARK: CTA

    private var createButton: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Створити вакансію", icon: "plus") {
                router.selection = 1
            }

            if !app.canCreateVacancy {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Ліміт тарифу вичерпано — покращити план")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(VK.warning)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}
