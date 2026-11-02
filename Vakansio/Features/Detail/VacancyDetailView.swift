import SwiftUI
import Foundation
import UIKit

struct VacancyDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let vacancy: Vacancy

    @State private var isApplying = false
    @State private var showReportDialog = false
    @State private var showBlockDialog = false
    @State private var showAppliedAlert = false
    @State private var isStartingChat = false
    @State private var activeConversation: Conversation?

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
                if let score = vacancy.matchScore, score > 0 {
                    matchCard(score: score)
                }
                metaGrid
                descriptionCard
                bulletCard(title: "Обов'язки", icon: "checklist", items: vacancy.responsibilities)
                bulletCard(title: "Вимоги", icon: "checkmark.circle", items: vacancy.requirements)
                bulletCard(title: "Ми пропонуємо", icon: "gift.fill", items: vacancy.benefits)

                if !isOwnVacancy && !vacancy.isExternal {
                    writeButton
                }

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

                    if !isOwnVacancy {
                        actionsMenu
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .alert("Відгук надіслано!", isPresented: $showAppliedAlert) {
            Button("Добре") { }
        } message: {
            Text("Роботодавець отримав ваше збережене резюме та фото.")
        }
        .sheet(item: $activeConversation) { conversation in
            NavigationStack {
                ChatView(
                    conversationId: conversation.id,
                    title: conversation.jobTitle,
                    counterpartyName: conversation.counterpartName,
                    counterpartId: conversation.counterpartId
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрити") { activeConversation = nil }
                            .foregroundStyle(VK.textSecondary)
                    }
                }
            }
        }
        .confirmationDialog(
            "Поскаржитися на вакансію",
            isPresented: $showReportDialog,
            titleVisibility: .visible
        ) {
            Button("Шахрайство") { submitReport(reason: "Шахрайство") }
            Button("Нецензурна лексика") { submitReport(reason: "Нецензурна лексика") }
            Button("Дискримінація") { submitReport(reason: "Дискримінація") }
            Button("Спам") { submitReport(reason: "Спам") }
            Button("Скасувати", role: .cancel) { }
        }
        .confirmationDialog(
            "Заблокувати роботодавця?",
            isPresented: $showBlockDialog,
            titleVisibility: .visible
        ) {
            Button("Заблокувати", role: .destructive) {
                blockEmployer()
            }
            Button("Скасувати", role: .cancel) { }
        } message: {
            Text("Вакансії цього роботодавця та чат з ним зникнуть із вашого акаунта.")
        }
    }

    private var actionsMenu: some View {
        Menu {
            Button("Поскаржитися", systemImage: "flag") {
                showReportDialog = true
            }
            Button("Заблокувати роботодавця", systemImage: "hand.raised", role: .destructive) {
                showBlockDialog = true
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(VK.textPrimary)
        }
        .accessibilityLabel("Більше")
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                CompanyAvatar(initials: vacancy.company.initials, size: 58)

                VStack(alignment: .leading, spacing: 6) {
                    Text(vacancy.company.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VK.textSecondary)

                    HStack(spacing: 6) {
                        if vacancy.company.isVerified,
                           let edrpou = vacancy.company.edrpou,
                           !edrpou.isEmpty {
                            VerifiedEmployerBadge(compact: false)
                        }

                        if vacancy.aiVerified {
                            AIVerifiedBadge(compact: false)
                        }
                    }

                    if vacancy.isUrgent {
                        TagPill(text: "Терміново", icon: "flame.fill", tint: VK.danger)
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

    private func matchCard(score: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.brand)

                Text("AI-матчинг")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                MatchBadge(score: score)
            }

            if let reason = vacancy.matchReason, !reason.isEmpty {
                Text(reason)
                    .font(.system(size: 12))
                    .foregroundStyle(VK.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .vkCard(padding: 14)
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

    // MARK: Contact

    // Contact details are intentionally not exposed; a conversation thread is used instead.


    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VK.textTertiary)
                .padding(.top, 1)

            Text(vacancy.isExternal
                 ? "Це зовнішня вакансія з \(vacancy.sourceLabel). Vakansio не є роботодавцем — перевіряйте умови та оплату на сайті джерела."
                 : "Vakansio перевірив компанію та вакансію. Не надсилайте передоплату роботодавцю.")
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

                if vacancy.isExternal {
                    externalActionButton
                } else if let application = appliedApplication {
                    appliedBadge(for: application)
                } else if vacancy.status == .pending {
                    HStack(spacing: 7) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("На модерації")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(VK.warning)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(VK.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Button {
                        quickApply()
                    } label: {
                        HStack(spacing: 7) {
                            if isApplying {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(Color.white)
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14, weight: .semibold))
                            }

                            Text(isApplying ? "Надсилаємо…" : "Відгукнутися")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 20)
                        .frame(height: 50)
                        .background(
                            VK.accentGradient,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .opacity(isApplying ? 0.75 : 1)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(isApplying)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var externalActionButton: some View {
        if let url = URL(string: vacancy.externalURL) {
            Link(destination: url) {
                HStack(spacing: 7) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Відкрити на \(vacancy.sourceLabel.isEmpty ? "сайті" : vacancy.sourceLabel)")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(VK.accentGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
        } else {
            Text("Джерело недоступне")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VK.textSecondary)
        }
    }

    private var isOwnVacancy: Bool {
        !vacancy.employerId.isEmpty && vacancy.employerId == app.userId
    }

    private var writeButton: some View {
        Button {
            startChat()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(VK.brand)
                        .frame(width: 42, height: 42)

                    if isStartingChat {
                        ProgressView()
                            .tint(Color.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Написати")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VK.textPrimary)

                    Text("Чат з роботодавцем без email")
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
        .disabled(isStartingChat)
    }

    private func submitReport(reason: String) {
        Task { @MainActor in
            _ = await app.report(targetType: "job", targetId: vacancy.id, reason: reason)
        }
    }

    private func blockEmployer() {
        guard !vacancy.employerId.isEmpty else {
            app.showToast("Не вдалося визначити роботодавця", icon: "exclamationmark.triangle.fill", style: .error)
            return
        }
        Task { @MainActor in
            if await app.blockUser(vacancy.employerId) {
                dismiss()
            }
        }
    }

    private func startChat() {
        guard !isStartingChat else { return }
        isStartingChat = true

        Task { @MainActor in
            let conversation = await app.startConversation(jobId: vacancy.id)
            isStartingChat = false
            if let conversation {
                activeConversation = conversation
            }
        }
    }

    private func quickApply() {
        guard !isApplying, !app.hasApplied(to: vacancy) else { return }
        isApplying = true

        Task { @MainActor in
            let success = await app.apply(to: vacancy, coverLetter: "")
            isApplying = false
            if success {
                showAppliedAlert = true
            }
        }
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
