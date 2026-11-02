import SwiftUI
import Foundation

struct CandidatesView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Application?

    private var averageScore: Int {
        guard !app.employerApplications.isEmpty else { return 0 }
        let total = app.employerApplications.reduce(0) { $0 + $1.aiScore }
        return total / app.employerApplications.count
    }

    var body: some View {
        ZStack {
            VK.screen.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if app.isLoadingCandidates && app.employerApplications.isEmpty {
                        summarySkeleton
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonApplicationRow()
                        }
                    } else if app.employerApplications.isEmpty {
                        if let error = app.lastErrorMessage {
                            EmptyStateView(
                                icon: "wifi.exclamationmark",
                                title: "Не вдалося завантажити",
                                message: error,
                                actionTitle: "Спробувати ще",
                                action: {
                                    Task { await app.loadCandidates(markViewed: true) }
                                }
                            )
                            .vkCard()
                        } else {
                            EmptyStateView(
                                icon: "person.2",
                                title: "Кандидатів поки немає",
                                message: "Щойно хтось відгукнеться на вашу вакансію, тут з'явиться профіль, резюме та AI-оцінка.",
                                actionTitle: "До дашборду",
                                action: { dismiss() }
                            )
                            .vkCard()
                        }
                    } else {
                        summary
                        ForEach(app.employerApplications) { application in
                            Button {
                                selected = application
                            } label: {
                                candidateRow(application)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .refreshable {
                await app.loadCandidates(markViewed: true)
            }
        }
        .navigationTitle("Кандидати")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            await app.loadCandidates(markViewed: true)
        }
        .sheet(item: $selected) { application in
            CandidateDetailSheet(application: application)
        }
    }

    private var summary: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(app.employerApplications.count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(VK.textPrimary)
                Text("кандидатів")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VK.textSecondary)
            }

            Rectangle()
                .fill(VK.hairline)
                .frame(width: 1, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(averageScore)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(VK.brand)
                Text("середній AI-score")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VK.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .vkCard()
    }

    private var summarySkeleton: some View {
        HStack(spacing: 16) {
            SkeletonBlock(width: 50, height: 28)
            SkeletonBlock(width: 1, height: 34)
            SkeletonBlock(width: 70, height: 28)
            Spacer(minLength: 0)
        }
        .vkCard()
    }

    private func candidateRow(_ application: Application) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                UserAvatar(
                    base64: application.candidatePhotoBase64,
                    size: 48,
                    initials: application.candidateInitials
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(application.candidateName.isEmpty ? "Кандидат" : application.candidateName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VK.textPrimary)
                        .lineLimit(1)

                    Text(application.vacancy.title)
                        .font(.system(size: 12))
                        .foregroundStyle(VK.textSecondary)
                        .lineLimit(1)

                    Text("Відгук \(application.appliedAt.vkRelativeDay.lowercased())")
                        .font(.system(size: 11))
                        .foregroundStyle(VK.textTertiary)
                }

                Spacer(minLength: 4)
            }

            Divider()
                .overlay(VK.hairline)

            HStack(spacing: 8) {
                AIScoreBadge(score: application.aiScore, compact: true)
                ApplicationStatusBadge(status: application.status)

                Spacer(minLength: 4)

                Text("Резюме")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VK.brand)

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

// MARK: - Detail

struct CandidateDetailSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let application: Application

    @State private var isUpdating = false
    @State private var pendingStatus: ApplicationStatus?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    aiCard
                    resumeCard

                    if !application.coverLetter.isEmpty {
                        coverLetterCard
                    }

                    chatLink
                    actions
                }
                .padding(16)
            }
            .background(VK.screen)
            .navigationTitle("Кандидат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрити") { dismiss() }
                        .foregroundStyle(VK.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var header: some View {
        VStack(spacing: 12) {
            UserAvatar(
                base64: application.candidatePhotoBase64,
                size: 84,
                initials: application.candidateInitials
            )

            VStack(spacing: 4) {
                Text(application.candidateName.isEmpty ? "Кандидат" : application.candidateName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VK.textPrimary)
                    .multilineTextAlignment(.center)

                Text(application.vacancy.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VK.brand)
                    .multilineTextAlignment(.center)
            }

            ApplicationStatusBadge(status: application.status)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(VK.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.brand)

                Text("AI-оцінка відповідності")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                Text("\(application.aiScore)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(VK.brand)
            }

            ProgressView(value: Double(application.aiScore), total: 100)
                .tint(VK.brand)

            Text(application.aiSummary.isEmpty ? "Оцінку сформовано за збігом резюме з вимогами вакансії." : application.aiSummary)
                .font(.system(size: 12))
                .foregroundStyle(VK.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .vkCard()
    }

    private var resumeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Резюме")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(VK.textPrimary)

            Text(application.resumeText.isEmpty ? "Кандидат не заповнив резюме." : application.resumeText)
                .font(.system(size: 13))
                .foregroundStyle(application.resumeText.isEmpty ? VK.textTertiary : VK.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .vkCard()
    }

    private var coverLetterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Супровідний лист")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(VK.textPrimary)

            Text(application.coverLetter)
                .font(.system(size: 13))
                .foregroundStyle(VK.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .vkCard()
    }

    private var chatLink: some View {
        NavigationLink {
            ChatView(
                applicationId: application.id,
                title: application.vacancy.title,
                counterpartyName: application.candidateName.isEmpty ? "Кандидат" : application.candidateName
            )
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(VK.brand)
                        .frame(width: 40, height: 40)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Чат з кандидатом")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VK.textPrimary)
                    Text("Уточніть деталі та домовтеся про співбесіду")
                        .font(.system(size: 11))
                        .foregroundStyle(VK.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VK.textTertiary)
            }
            .vkCard()
        }
        .buttonStyle(.plain)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            PrimaryButton(
                title: "Запросити на співбесіду",
                icon: "checkmark.circle.fill",
                isLoading: isUpdating && pendingStatus == .invited,
                isEnabled: !isUpdating && application.status != .invited
            ) {
                update(.invited)
            }

            SecondaryButton(
                title: "Відмовити",
                icon: "xmark",
                isLoading: isUpdating && pendingStatus == .rejected,
                isEnabled: !isUpdating && application.status != .rejected
            ) {
                update(.rejected)
            }
        }
    }

    private func update(_ status: ApplicationStatus) {
        guard !isUpdating else { return }
        isUpdating = true
        pendingStatus = status

        Task {
            await app.updateApplicationStatus(application, status: status)
            isUpdating = false
            pendingStatus = nil
            dismiss()
        }
    }
}
