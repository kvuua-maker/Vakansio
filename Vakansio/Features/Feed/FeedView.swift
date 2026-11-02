import SwiftUI
import Foundation

struct FeedView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var router: TabRouter

    @State private var path = NavigationPath()
    @State private var isLoading = true
    @State private var hasLoaded = false
    @State private var selectedCategory = "Усі"
    @State private var showNotifications = false

    private var categories: [String] {
        var result = ["Усі"]
        var seen = Set<String>()
        for vacancy in app.vacancies where !seen.contains(vacancy.category) {
            seen.insert(vacancy.category)
            result.append(vacancy.category)
        }
        return result
    }

    private var filteredVacancies: [Vacancy] {
        guard selectedCategory != "Усі" else { return app.vacancies }
        return app.vacancies.filter { $0.category == selectedCategory }
    }

    private var greeting: String {
        guard app.isSignedIn else { return "Привіт! 👋" }
        let name = app.userName.vkTrimmed
        guard !name.isEmpty else { return "Привіт! 👋" }
        let first = name.components(separatedBy: " ").first ?? name
        return "Привіт, \(first) 👋"
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                VK.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        header
                        categoryStrip

                        if isLoading {
                            ForEach(0..<4, id: \.self) { _ in
                                SkeletonVacancyCard()
                            }
                        } else {
                            resultsHeader

                            if filteredVacancies.isEmpty {
                                EmptyStateView(
                                    icon: "magnifyingglass",
                                    title: "Немає вакансій",
                                    message: "У цій категорії поки що порожньо. Спробуйте інший напрям.",
                                    actionTitle: "Показати всі",
                                    action: { selectedCategory = "Усі" }
                                )
                                .vkCard()
                            } else {
                                ForEach(filteredVacancies) { vacancy in
                                    VacancyCard(
                                        vacancy: vacancy,
                                        isSaved: app.isSaved(vacancy),
                                        onOpen: { path.append(vacancy) },
                                        onToggleSave: { app.toggleSaved(vacancy) }
                                    )
                                }

                                footer
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await load(showSkeleton: false)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Vacancy.self) { vacancy in
                VacancyDetailView(vacancy: vacancy)
            }
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await load(showSkeleton: true)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsSheet()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(greeting)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VK.textSecondary)

                Text("Знайди роботу\nдо душі")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(VK.textPrimary)
                    .lineSpacing(2)
            }

            Spacer(minLength: 8)

            IconCircleButton(icon: "bell", tint: VK.textPrimary) {
                showNotifications = true
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(VK.danger)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().strokeBorder(VK.screen, lineWidth: 2))
                    .offset(x: -1, y: 1)
            }
            .accessibilityLabel("Сповіщення")

            Button {
                router.selection = 3
            } label: {
                ZStack {
                    Circle()
                        .fill(VK.brandGradient)
                        .frame(width: 44, height: 44)

                    Text(app.isSignedIn && !app.userName.isEmpty ? app.userName.vkInitials : "VK")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white)
                }
                .overlay(Circle().strokeBorder(VK.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Профіль")
        }
        .padding(.top, 4)
    }

    // MARK: Category strip

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    FilterChip(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var resultsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(selectedCategory == "Усі" ? "Рекомендуємо" : selectedCategory)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VK.textPrimary)

            Spacer()

            Text("\(filteredVacancies.count) вакансій")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VK.textSecondary)
        }
        .padding(.top, 4)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(VK.success)

            Text("Ви переглянули всі вакансії")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(VK.textSecondary)

            Text("Нові з'являться тут автоматично")
                .font(.system(size: 11))
                .foregroundStyle(VK.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: Loading

    private func load(showSkeleton: Bool) async {
        if showSkeleton {
            isLoading = true
        }

        try? await Task.sleep(nanoseconds: 750_000_000)
        isLoading = false
    }
}

// MARK: - Notifications

private struct FeedNotification: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let time: String
    let tint: Color
}

struct NotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let items: [FeedNotification] = [
        FeedNotification(
            icon: "eye.fill",
            title: "Ваш відгук переглянули",
            message: "Nova Tech відкрила ваш відгук на Senior iOS Developer.",
            time: "12 хв тому",
            tint: VK.brand
        ),
        FeedNotification(
            icon: "envelope.fill",
            title: "Запрошення на співбесіду",
            message: "Orbita Analytics хоче познайомитися найближчим часом.",
            time: "2 год тому",
            tint: VK.success
        ),
        FeedNotification(
            icon: "sparkles",
            title: "AI підготував резюме",
            message: "Ми оновили опис вашого досвіду — перегляньте зміни.",
            time: "Вчора",
            tint: VK.warning
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(item.tint.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: item.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(item.tint)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(VK.textPrimary)
                            Text(item.message)
                                .font(.system(size: 13))
                                .foregroundStyle(VK.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(item.time)
                                .font(.system(size: 11))
                                .foregroundStyle(VK.textTertiary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(VK.card)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(VK.screen)
            .navigationTitle("Сповіщення")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                        .foregroundStyle(VK.brand)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
