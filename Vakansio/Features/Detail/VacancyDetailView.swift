import SwiftUI
import Foundation
import UIKit

struct VacancyDetailView: View {
    @EnvironmentObject private var app: AppState
    let vacancy: Vacancy

    @State private var showApplySheet = false

    private var isSaved: Bool {
        app.isSaved(vacancy)
    }

    private var appliedApplication: Application? {
        app.application(for: vacancy)
    }

    private var shareText: String {
        "\(vacancy.title) — \(vacancy.company.name), \(vacancy.salaryText). Знайдено у Vakansio."
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                hero
                metaGrid
                descriptionCard
                bulletCard(title: "Обов'язки", icon: "checklist", items: vacancy.responsibilities)
                bulletCard(title: "Вимоги", icon: "checkmark.circle", items: vacancy.requirements)
                bulletCard(title: "Ми пропонуємо", icon: "gift.fill", items: vacancy.benefits)
                contactCard
                disclaimer
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(VK.screen)
        .navigationTitle("Вакансія")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        app.toggleSaved(vacancy)
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(isSaved ? VK.brand : VK.textPrimary)
                    }
                    .accessibilityLabel(isSaved ? "Видалити зі збережених" : "Зберегти")

                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(VK.textPrimary)
                    }
                    .accessibilityLabel("Поділитися")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showApplySheet) {
            ApplySheet(vacancy: vacancy)
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                CompanyAvatar(initials: vacancy.company.initials, size: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text(vacancy.company.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VK.textSecondary)

                    HStack(spacing: 6) {
                        if vacancy.company.isVerified {
                            VerifiedBadge()
                        }
                        if vacancy.isUrgent {
                            TagPill(text: "Терміново", icon: "flame.fill", tint: VK.danger)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            Text(vacancy.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(VK.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(vacancy.salaryText)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(VK.brand)

            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12, weight: .semibold))
                Text(vacancy.locationText)
                    .font(.system(size: 13, weight: .medium))
                Text("·")
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .medium))
                Text(vacancy.postedText)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(VK.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VK.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
    }

    // MARK: Meta

    private var metaGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            metaTile(icon: "briefcase.fill", title: "Тип", value: vacancy.employmentType, tint: VK.brand)
            metaTile(icon: "chart.bar.fill", title: "Досвід", value: vacancy.experience, tint: VK.warning)
            metaTile(icon: "square.grid.2x2.fill", title: "Категорія", value: vacancy.category, tint: Color(hex: 0x5856D6))
            metaTile(
                icon: "mappin.and.ellipse",
                title: "Формат",
                value: vacancy.isRemote ? "Віддалено" : "Офіс",
                tint: VK.success
            )
        }
    }

    private func metaTile(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VK.textTertiary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VK.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
    }

    // MARK: Sections

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Про вакансію", icon: "text.alignleft")

            Text(vacancy.description)
                .font(.system(size: 15))
                .foregroundStyle(VK.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .vkCard(padding: 18)
    }

    @ViewBuilder
    private func bulletCard(title: String, icon: String, items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(title, icon: icon)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(VK.brand)
                                .frame(width: 18, height: 18)
                                .background(VK.brand.opacity(0.12), in: Circle())
                                .padding(.top, 1)

                            Text(item)
                                .font(.system(size: 15))
                                .foregroundStyle(VK.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .vkCard(padding: 18)
        }
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VK.brand)

            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(VK.textPrimary)
        }
    }

    // MARK: Contacts

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Контакти", icon: "phone.fill")

            contactRow(icon: "envelope.fill", value: vacancy.contactEmail)

            if let phone = vacancy.contactPhone {
                contactRow(icon: "phone.fill", value: phone)
            }

            Text("Натисніть, щоб скопіювати контакт")
                .font(.system(size: 11))
                .foregroundStyle(VK.textTertiary)
        }
        .vkCard(padding: 18)
    }

    private func contactRow(icon: String, value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            app.showToast("Скопійовано: \(value)", icon: "doc.on.doc.fill", style: .info)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VK.brand)
                    .frame(width: 32, height: 32)
                    .background(VK.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VK.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13))
                    .foregroundStyle(VK.textTertiary)
            }
            .padding(10)
            .background(VK.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VK.textTertiary)
                .padding(.top, 1)

            Text("Vakansio перевірив компанію та вакансію. Не надсилайте передоплату роботодавцю.")
                .font(.system(size: 11))
                .foregroundStyle(VK.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(VK.hairline)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vacancy.salaryText)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VK.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(vacancy.isRemote ? "Віддалено · \(vacancy.city)" : vacancy.city)
                        .font(.system(size: 11))
                        .foregroundStyle(VK.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if let application = appliedApplication {
                    appliedBadge(for: application)
                } else {
                    Button {
                        showApplySheet = true
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Відгукнутися")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 20)
                        .frame(height: 50)
                        .background(
                            VK.accentGradient,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .background(.regularMaterial)
    }

    private func appliedBadge(for application: Application) -> some View {
        HStack(spacing: 7) {
            Image(systemName: application.status == .invited ? "checkmark.seal.fill" : "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))

            Text(application.status == .invited ? "Вас запрошено" : "Відгук надіслано")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(VK.success)
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(VK.success.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(VK.success.opacity(0.25), lineWidth: 1)
        )
    }
}
