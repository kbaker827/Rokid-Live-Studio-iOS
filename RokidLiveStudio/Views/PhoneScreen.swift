import SwiftUI

/// Root tab bar screen. Owns the VideoDecoder which is shared across all tabs.
struct PhoneScreen: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var decoder = VideoDecoderWrapper()

    var body: some View {
        TabView {
            HomeScreen(decoder: decoder.decoder)
                .environmentObject(appState)
                .tabItem {
                    Label("Home", systemImage: AppIcon.home)
                }

            YoutubeScreen(decoder: decoder.decoder)
                .environmentObject(appState)
                .tabItem {
                    Label("YouTube", systemImage: AppIcon.youtube)
                }

            TwitchScreen(decoder: decoder.decoder)
                .environmentObject(appState)
                .tabItem {
                    Label("Twitch", systemImage: AppIcon.broadcast)
                }

            SettingsScreen()
                .environmentObject(appState)
                .tabItem {
                    Label("Settings", systemImage: AppIcon.settings)
                }
        }
        .accentColor(.rGreen)
        .onAppear {
            // Style the tab bar
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.rCard)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

/// ObservableObject wrapper so VideoDecoder can be created as @StateObject
class VideoDecoderWrapper: ObservableObject {
    let decoder = VideoDecoder()
}
