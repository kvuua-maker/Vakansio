import SwiftUI
import Foundation

struct FeedView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var router: TabRouter

    @State private var path = NavigationPath()
    @State private var selectedCategory = "Усі"

    private var categories: [String] {
        var result = ["Усі"]
        var seen = Set<String>()
        let source = app.jobs.isEmpty ? FilterOptions.categories : app.jobs.map { $0.category }

        for category in source where !category.isEmpty && !seen.contains(category) {
            seen.insert(category)
            result.append(category)
        }
        return result
    }

    private var filteredVacancies: [Vacancy] {
        guard selectedCategory != "Усі" else { return app.jobs }
        return app.jobs.filter { $0.category == selectedCategory }
    }

    private var greeting: String {
        guard app.isSignedIn else { return "Привіт! 👋" }
        let name = app.userName.vkTrimmed
        guard !name.isEmpty else { return "Привіт! 👋" }
        let first = name.components(separatedBy: " ").first ?? name
        return "Привіт, \(first) 👋"
    }

    private var avatarInitials: String {
        let name = app.userName.vkTrimmed
        return name.isEmpty ? "VK" : name.vkInitials
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                VK.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        header
                        categoryStrip

                        if app.isLoadingJobs && app.jobs.isEmpty {
                            ForEach(0..<4, id: \.self) { _ in
                                SkeletonVacancyCard()
                            }
                        } else if app.jobs.isEmpty {
                            emptyState
                        } else {
                            resultsHeader

                            if filteredVacancies.isEmpty {
                                EmptyStateView(
                                    icon: "line.3.horizontal.decrease.circle",
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
                    await app.loadJobs()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Vacancy.self) { vacancy in
                VacancyDetailView(vacancy: vacancy)
            }
        }
        .task {
            if app.jobs.isEmpty {
                await app.loadJobs()
            }
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

            Button {
                router.selection = 3
            } label: {
                UserAvatar(
                    base64: app.resume.photoBase64,
                    size: 46,
                    initials: avatarInitials
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Профіль")
        }
        .padding(.top, 4)
    }

    // MARK: Categories

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

    @ViewBuilder
    private var emptyState: some View {
        if let error = app.lastErrorMessage {
            EmptyStateView(
                icon: "wifi.exclamationmark",
                title: "Не вдалося завантажити",
                message: error,
                actionTitle: "Спробувати ще",
                action: {
                    Task { await app.loadJobs() }
                }
            )
            .vkCard()
        } else {
            EmptyStateView(
                icon: "briefcase",
                title: "Вакансій поки немає",
                message: "Роботодавці ще не опублікували активні вакансії. Оновіть стрічку трохи пізніше.",
                actionTitle: "Оновити",
                action: {
                    Task { await app.loadJobs() }
                }
            )
            .vkCard()
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(VK.success)

            Text("Ви переглянули всі вакансії")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(VK.textSecondary)

            Text("Потягніть вниз, щоб оновити")
                .font(.system(size: 11))
                .foregroundStyle(VK.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
