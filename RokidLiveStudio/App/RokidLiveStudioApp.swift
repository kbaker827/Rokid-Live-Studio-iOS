import SwiftUI

@main
struct RokidLiveStudioApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            PhoneScreen()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
