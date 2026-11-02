import SwiftUI
import Foundation

struct ApplicationDetailView: View {
    @EnvironmentObject private var app: AppState

    let application: Application

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                statusCard
                resumeCard

                if !application.coverLetter.isEmpty {
                    coverLetterCard
                }

                chatLink
                vacancyLink
            }
            .padding(16)
        }
        .background(VK.screen)
        .navigationTitle("Відгук")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            CompanyAvatar(initials: application.vacancy.company.initials, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(application.vacancy.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)
                    .lineLimit(2)

                Text(application.vacancy.company.name)
                    .font(.system(size: 13))
                    .foregroundStyle(VK.textSecondary)

                Text("Подано \(application.appliedAt.vkRelativeDay.lowercased())")
                    .font(.system(size: 11))
                    .foregroundStyle(VK.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .vkCard()
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(application.status.tint.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: application.status.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(application.status.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(application.status.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)

                Text(statusHint)
                    .font(.system(size: 12))
                    .foregroundStyle(VK.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .vkCard()
    }

    private var statusHint: String {
        switch application.status {
        case .sent:
            return "Відгук надіслано. Роботодавець ще не переглянув його."
        case .viewed:
            return "Роботодавець переглянув ваше резюме. Очікуйте на відповідь."
        case .invited:
            return "Вас запрошено на співбесіду. Напишіть роботодавцю в чаті, щоб узгодити час."
        case .rejected:
            return "На жаль, цього разу відмова. Спробуйте інші вакансії у стрічці."
        }
    }

    private var resumeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Надіслане резюме")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                if application.aiScore > 0 {
                    AIScoreBadge(score: application.aiScore)
                }
            }

            Text(application.resumeText.isEmpty ? "Резюме не додано" : application.resumeText)
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
                counterpartyName: application.vacancy.company.name
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
                    Text("Чат з роботодавцем")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VK.textPrimary)
                    Text("Уточніть деталі співбесіди")
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

    private var vacancyLink: some View {
        NavigationLink {
            VacancyDetailView(vacancy: application.vacancy)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VK.brand)

                Text("Переглянути вакансію")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.brand)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VK.textTertiary)
            }
            .padding(14)
            .background(VK.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(VK.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
