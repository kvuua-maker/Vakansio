import SwiftUI
import Foundation

struct MainTabView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var router: TabRouter

    var body: some View {
        TabView(selection: $router.selection) {
            if app.role == .employer {
                EmployerDashboardView()
                    .tabItem { Label("Дашборд", systemImage: "chart.bar.xaxis") }
                    .tag(0)

                CreateVacancyView()
                    .tabItem { Label("Створити", systemImage: "plus.circle.fill") }
                    .tag(1)

                PaywallView(isModal: false)
                    .tabItem { Label("Тарифи", systemImage: "crown.fill") }
                    .tag(2)

                ProfileView()
                    .tabItem { Label("Профіль", systemImage: "person.crop.circle.fill") }
                    .tag(3)
            } else {
                FeedView()
                    .tabItem { Label("Стрічка", systemImage: "rectangle.stack.fill") }
                    .tag(0)

                SearchView()
                    .tabItem { Label("Пошук", systemImage: "magnifyingglass") }
                    .tag(1)

                ApplicationsView()
                    .tabItem { Label("Відгуки", systemImage: "paperplane.fill") }
                    .badge(app.applications.count)
                    .tag(2)

                ProfileView()
                    .tabItem { Label("Профіль", systemImage: "person.crop.circle.fill") }
                    .tag(3)
            }
        }
        .tint(VK.brand)
        .onChange(of: app.role) { _, _ in
            router.selection = 0
        }
    }
}
