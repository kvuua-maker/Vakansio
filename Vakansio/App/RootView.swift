import SwiftUI
import Foundation

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if app.hasCompletedOnboarding {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    OnboardingView()
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
            if app.hasCompletedOnboarding {
                PushManager.shared.requestAuthorization()
            }
        }
        .onChange(of: app.hasCompletedOnboarding) { _, completed in
            if completed {
                PushManager.shared.requestAuthorization()
            }
        }
        .preferredColorScheme(app.themePreference.colorScheme)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: app.toast?.id)
        .animation(.easeInOut(duration: 0.25), value: app.hasCompletedOnboarding)
    }
}
