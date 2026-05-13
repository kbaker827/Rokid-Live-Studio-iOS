import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject var appState: AppState
    private let githubReleasesUrl = "https://github.com/Anezium/Rokid-Live-Studio/releases"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BrandHeader()

                // Package info
                SectionCard(title: "Application") {
                    StatusRow(label: "Bundle ID",  value: "com.anezium.rokidlive.phone.ios")
                    Divider().background(Color.rBorder)
                    StatusRow(label: "Version",    value: appVersion())
                    Divider().background(Color.rBorder)
                    StatusRow(label: "Build",      value: buildNumber())
                    Divider().background(Color.rBorder)
                    StatusRow(label: "Min iOS",    value: "16.0")
                    Divider().background(Color.rBorder)
                    StatusRow(label: "Media Port", value: "TCP 39440")
                }

                // Network info
                SectionCard(title: "Network") {
                    StatusRow(label: "Phone IP", value: appState.phoneIPAddress)
                    Divider().background(Color.rBorder)
                    HStack {
                        Text("Ingress Address")
                            .font(.system(size: 13))
                            .foregroundColor(.rMuted)
                        Spacer()
                        Text("\(appState.phoneIPAddress):39440")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.rGreen)
                        Button(action: {
                            UIPasteboard.general.string = "\(appState.phoneIPAddress):39440"
                        }) {
                            Image(systemName: AppIcon.copy)
                                .foregroundColor(.rMuted)
                                .font(.system(size: 12))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                // Update check
                SectionCard(title: "Updates") {
                    Button(action: {
                        if let url = URL(string: githubReleasesUrl) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: AppIcon.refresh).foregroundColor(.rGreen)
                            Text("Check for Updates on GitHub")
                                .font(.system(size: 14)).foregroundColor(.rText)
                            Spacer()
                            Image(systemName: AppIcon.chevron).foregroundColor(.rMuted)
                                .font(.system(size: 12))
                        }
                        .padding(14)
                    }
                    .buttonStyle(.plain)
                }

                // Licenses
                SectionCard(title: "Open Source") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("This app is an iOS port of Rokid Live Studio (Android).")
                            .font(.system(size: 13)).foregroundColor(.rMuted)
                        Text("Original project: github.com/Anezium/Rokid-Live-Studio")
                            .font(.system(size: 13)).foregroundColor(.rMuted)
                        Button(action: {
                            if let url = URL(string: "https://github.com/Anezium/Rokid-Live-Studio") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Label("View on GitHub", systemImage: AppIcon.link)
                                .font(.system(size: 13)).foregroundColor(.rGreen)
                        }
                    }
                    .padding(14)
                }

                // Clear data
                SectionCard(title: "Data") {
                    Button(action: {
                        appState.clearYoutubeAuth()
                        appState.clearTwitchAuth()
                    }) {
                        HStack {
                            Image(systemName: AppIcon.xmark).foregroundColor(.rRed)
                            Text("Clear All Credentials")
                                .font(.system(size: 14)).foregroundColor(.rRed)
                            Spacer()
                        }
                        .padding(14)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 32)
            }
            .padding(16)
        }
        .background(
            LinearGradient(colors: [.rBackground, .rBackground2],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private func buildNumber() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
