import SwiftUI
import Foundation

struct ChatsView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var router: TabRouter

    var body: some View {
        NavigationStack {
            ZStack {
                VK.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if app.isLoadingConversations && app.conversations.isEmpty {
                            ForEach(0..<4, id: \.self) { _ in
                                SkeletonChatRow()
                            }
                        } else if app.conversations.isEmpty {
                            EmptyStateView(
                                icon: "bubble.left.and.bubble.right",
                                title: "Чатів поки немає",
                                message: "Напишіть роботодавцю з екрана вакансії — листування з'явиться тут.",
                                actionTitle: "До стрічки",
                                action: { router.selection = 0 }
                            )
                            .vkCard()
                            .padding(.top, 24)
                        } else {
                            ForEach(app.conversations) { conversation in
                                NavigationLink {
                                    ChatView(
                                        conversationId: conversation.id,
                                        title: conversation.jobTitle,
                                        counterpartyName: conversation.counterpartyName,
                                        counterpartId: conversation.counterpartId
                                    )
                                } label: {
                                    conversationRow(conversation)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let error = app.lastErrorMessage, app.conversations.isEmpty {
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundStyle(VK.danger)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await app.loadConversations()
                }
            }
            .navigationTitle("Мої чати")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .task {
                await app.loadConversations()
            }
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            CompanyAvatar(initials: initials(conversation), size: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(conversation.counterpartName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VK.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(conversation.lastMessageAt.vkRelativeDay)
                        .font(.system(size: 10))
                        .foregroundStyle(VK.textTertiary)
                }

                Text(conversation.jobTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VK.brand)
                    .lineLimit(1)

                Text(conversation.lastMessage.isEmpty ? "Почніть розмову" : conversation.lastMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(conversation.lastMessage.isEmpty ? VK.textTertiary : VK.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VK.textTertiary)
                .padding(.top, 16)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VK.card, in: RoundedRectangle(cornerRadius: VK.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VK.radius, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
    }

    private func initials(_ conversation: Conversation) -> String {
        let name = conversation.counterpartName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "VK" : String(name.prefix(2)).uppercased()
    }
}

private struct SkeletonChatRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonBlock(width: 48, height: 48, cornerRadius: 24)
            VStack(alignment: .leading, spacing: 7) {
                SkeletonBlock(width: 150, height: 13)
                SkeletonBlock(width: 210, height: 11)
                SkeletonBlock(width: 170, height: 11)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .vkCard()
        .shimmering()
    }
}
