import SwiftUI
import Foundation

enum ApplicationFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case sent
    case viewed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Усі"
        case .sent: return "Надіслано"
        case .viewed: return "Переглянуто"
        }
    }
}

struct ApplicationsView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var router: TabRouter

    @State private var path = NavigationPath()
    @State private var filter: ApplicationFilter = .all

    private var filteredApplications: [Application] {
        switch filter {
        case .all:
            return app.applications
        case .sent:
            return app.applications.filter { $0.status == .sent }
        case .viewed:
            return app.applications.filter { $0.status == .viewed }
        }
    }

    private var viewedCount: Int {
        app.applications.filter { $0.status == .viewed }.count
    }

    private var invitedCount: Int {
        app.applications.filter { $0.status == .invited }.count
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                VK.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        if app.isLoadingApplications && app.applications.isEmpty {
                            stats

                            ForEach(0..<3, id: \.self) { _ in
                                SkeletonApplicationRow()
                            }
                        } else if app.applications.isEmpty {
                            stats
                            emptyState
                        } else {
                            stats
                            filters
                            list
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await app.loadMyApplications()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Vacancy.self) { vacancy in
                VacancyDetailView(vacancy: vacancy)
            }
        }
        .task {
            await app.loadMyApplications()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Відгуки")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(VK.textPrimary)

            Text("Відстежуйте статус ваших відгуків")
                .font(.system(size: 13))
                .foregroundStyle(VK.textSecondary)
        }
        .padding(.top, 4)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(app.applications.count)", label: "Всього", icon: "paperplane.fill", tint: VK.brand)
            StatTile(value: "\(viewedCount)", label: "Переглянуто", icon: "eye.fill", tint: VK.warning)
            StatTile(value: "\(invitedCount)", label: "Запрошення", icon: "checkmark.circle.fill", tint: VK.success)
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ApplicationFilter.allCases) { item in
                    FilterChip(title: item.title, isSelected: filter == item) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            filter = item
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let error = app.lastErrorMessage, !error.isEmpty {
            EmptyStateView(
                icon: "wifi.exclamationmark",
                title: "Не вдалося завантажити",
                message: error,
                actionTitle: "Спробувати ще",
                action: {
                    Task { await app.loadMyApplications() }
                }
            )
            .vkCard()
        } else {
            EmptyStateView(
                icon: "paperplane",
                title: "Відгуків поки немає",
                message: "Знайдіть вакансію до душі у стрічці та надішліть перший відгук.",
                actionTitle: "До стрічки",
                action: { router.selection = 0 }
            )
            .vkCard()
        }
    }

    @ViewBuilder
    private var list: some View {
        if filteredApplications.isEmpty {
            EmptyStateView(
                icon: "tray",
                title: "Тут порожньо",
                message: "Немає відгуків із таким статусом.",
                actionTitle: "Показати всі",
                action: { filter = .all }
            )
            .vkCard()
        } else {
            VStack(spacing: 12) {
                ForEach(filteredApplications) { application in
                    NavigationLink(value: application.vacancy) {
                        ApplicationRow(application: application)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ApplicationRow: View {
    let application: Application

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                CompanyAvatar(initials: application.vacancy.company.initials, size: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(application.vacancy.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VK.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(application.vacancy.company.name)
                            .font(.system(size: 13))
                            .foregroundStyle(VK.textSecondary)
                            .lineLimit(1)

                        if application.vacancy.company.isVerified {
                            VerifiedBadge(compact: true)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            Divider()
                .overlay(VK.hairline)

            HStack(spacing: 8) {
                ApplicationStatusBadge(status: application.status)

                Spacer(minLength: 4)

                Text("Подано \(application.appliedAt.vkRelativeDay.lowercased())")
                    .font(.system(size: 11))
                    .foregroundStyle(VK.textTertiary)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VK.textTertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VK.card)
        .clipShape(RoundedRectangle(cornerRadius: VK.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VK.radius, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
    }
}

struct ApplicationStatusBadge: View {
    let status: ApplicationStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10, weight: .semibold))

            Text(status.title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(status.tint.opacity(0.12), in: Capsule())
    }
}
