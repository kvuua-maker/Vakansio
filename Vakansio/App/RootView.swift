import SwiftUI
import Foundation

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @State private var deepLinkConversation: Conversation?

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if !app.hasCompletedOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                } else if !app.isSignedIn {
                    AuthView()
                        .transition(.opacity)
                } else {
                    MainTabView()
                        .transition(.opacity)
                }
            }

            if let toast = app.toast {
                ToastView(toast: toast)
                    .padding(.horizontal, 16)
                    .padding(.bottom, app.hasCompletedOnboarding ? 72 : 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .background(VK.screen.ignoresSafeArea())
        .task {
            await app.bootstrap()
            if app.isSignedIn {
                PushManager.shared.requestAuthorization()
                await openPendingChatIfNeeded()
            }
        }
        .onChange(of: app.isSignedIn) { _, signedIn in
            if signedIn {
                PushManager.shared.requestAuthorization()
                Task { await openPendingChatIfNeeded() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vakansioOpenChat)) { notification in
            guard let conversationId = notification.object as? String else { return }
            Task { await openChat(conversationId) }
        }
        .sheet(item: $deepLinkConversation) { conversation in
            NavigationStack {
                ChatView(
                    conversationId: conversation.id,
                    title: conversation.jobTitle,
                    counterpartyName: conversation.counterpartName,
                    counterpartId: conversation.counterpartId
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрити") { deepLinkConversation = nil }
                            .foregroundStyle(VK.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(app.themePreference.colorScheme)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: app.toast?.id)
        .animation(.easeInOut(duration: 0.25), value: app.hasCompletedOnboarding)
    }

    @MainActor
    private func openPendingChatIfNeeded() async {
        guard app.isSignedIn else { return }
        guard let pending = UserDefaults.standard.string(forKey: "vk.pendingConversationId"),
              !pending.isEmpty else { return }
        await openChat(pending)
    }

    @MainActor
    private func openChat(_ id: String) async {
        guard app.isSignedIn else { return }
        if let conversation = await app.openConversation(id: id) {
            deepLinkConversation = conversation
            UserDefaults.standard.removeObject(forKey: "vk.pendingConversationId")
        }
    }

}
