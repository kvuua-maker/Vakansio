import SwiftUI
import Foundation

@main
struct VakansioApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var router = TabRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(router)
                .tint(VK.brand)
        }
    }
}
