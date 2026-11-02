import SwiftUI
import Foundation

struct VacancyCard: View {
    let vacancy: Vacancy
    let isSaved: Bool
    let onOpen: () -> Void
    let onToggleSave: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) {
                content
            }
            .buttonStyle(PressableCardStyle())

            Button(action: onToggleSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSaved ? VK.brand : VK.textTertiary)
                    .frame(width: 34, height: 34)
                    .background(VK.elevated.opacity(0.92), in: Circle())
                    .overlay(Circle().strokeBorder(VK.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(12)
            .accessibilityLabel(isSaved ? "Видалити зі збережених" : "Зберегти вакансію")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                CompanyAvatar(initials: vacancy.company.initials, size: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(vacancy.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(VK.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(vacancy.company.name)
                            .font(.system(size: 13))
                            .foregroundStyle(VK.textSecondary)
                            .lineLimit(1)

                        if vacancy.company.isVerified {
                            VerifiedBadge(compact: true)
                        }
                    }

                    if vacancy.company.isVerified,
                       let edrpou = vacancy.company.edrpou,
                       !edrpou.isEmpty {
                        VerifiedEmployerBadge(compact: true)
                    }
                }

                Spacer(minLength: 30)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(vacancy.salaryText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VK.brand)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let score = vacancy.matchScore, score > 70 {
                    MatchBadge(score: score, compact: true)
                }

                Spacer(minLength: 4)

                Text(vacancy.postedText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VK.textTertiary)
                    .lineLimit(1)
            }

            HStack(spacing: 7) {
                TagPill(text: vacancy.city, icon: "mappin.and.ellipse")
                if vacancy.isRemote {
                    TagPill(text: "Віддалено", icon: "wifi", tint: VK.success)
                }
                if vacancy.isUrgent {
                    TagPill(text: "Терміново", icon: "flame.fill", tint: VK.danger)
                }
            }

            Divider()
                .overlay(VK.hairline)

            HStack(spacing: 6) {
                Image(systemName: "briefcase")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VK.textTertiary)

                Text(vacancy.employmentType)
                    .font(.system(size: 12))
                    .foregroundStyle(VK.textSecondary)
                    .lineLimit(1)

                Text("·")
                    .font(.system(size: 12))
                    .foregroundStyle(VK.textTertiary)

                Text(vacancy.experience)
                    .font(.system(size: 12))
                    .foregroundStyle(VK.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                AIVerifiedBadge(compact: true)

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
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
