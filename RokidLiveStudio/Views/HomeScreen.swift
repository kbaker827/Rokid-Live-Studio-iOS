import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject var appState: AppState
    let decoder: VideoDecoder

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BrandHeader()

                // Error banner
                if let err = appState.errorMessage {
                    ErrorBanner(message: err) { appState.errorMessage = nil }
                }

                // Connection status card
                SectionCard(title: "Connection Status") {
                    StatusRow(
                        label: "Server",
                        value: appState.isServerRunning ? "Running" : "Stopped",
                        valueColor: appState.isServerRunning ? .rGreen : .rMuted
                    )
                    Divider().background(Color.rBorder)
                    StatusRow(
                        label: "Glasses Connected",
                        value: appState.isConnected ? "Yes" : "No",
                        valueColor: appState.isConnected ? .rGreen : .rMuted
                    )
                    Divider().background(Color.rBorder)
                    StatusRow(label: "Phone IP", value: "\(appState.phoneIPAddress):39440")
                }

                // Action cards
                VStack(spacing: 8) {
                    ActionCard(
                        icon: AppIcon.glasses,
                        title: "Rokid AR Glasses",
                        subtitle: "iOS does not support the CXR SDK. Configure the glasses helper app to stream to this phone's IP and port 39440.",
                        accentColor: .rGreen
                    )

                    ActionCard(
                        icon: AppIcon.wifi,
                        title: "Glasses Helper IP Configuration",
                        subtitle: "Set the helper app's destination to: \(appState.phoneIPAddress):39440 (TCP)",
                        accentColor: .rGreen
                    ) {
                        UIPasteboard.general.string = "\(appState.phoneIPAddress):39440"
                    }
                }

                // Start/Stop buttons
                HStack(spacing: 10) {
                    if !appState.isServerRunning {
                        PrimaryButton(title: "Start Receiving", color: .rGreen) {
                            startServer()
                        }
                    } else {
                        PrimaryButton(title: "Stop Server", color: .rRed) {
                            stopServer()
                        }
                    }
                    Button(action: { appState.refreshPhoneIP() }) {
                        Image(systemName: AppIcon.refresh)
                            .foregroundColor(.rMuted)
                            .padding(14)
                            .background(Color.rCard)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rBorder))
                    }
                }

                // Preview
                PreviewCard(decoder: decoder)
                    .environmentObject(appState)

                // Ingress stats
                SectionCard(title: "Ingress") {
                    StatusRow(label: "Video Frames", value: "\(appState.ingressVideoFrameCount)")
                    Divider().background(Color.rBorder)
                    StatusRow(label: "Audio Packets", value: "\(appState.ingressAudioFrameCount)")
                    Divider().background(Color.rBorder)
                    StatusRow(label: "Throughput", value: formatBps(appState.ingressBytesPerSec))
                }
            }
            .padding(16)
        }
        .background(
            LinearGradient(colors: [.rBackground, .rBackground2],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .onAppear {
            appState.refreshPhoneIP()
        }
    }

    private func startServer() {
        let server = MediaIngressServer()
        appState.mediaIngressServer = server

        server.onConnected = {
            appState.isConnected = true
            appState.errorMessage = nil
        }
        server.onDisconnected = {
            appState.isConnected = false
        }
        server.onError = { msg in
            appState.errorMessage = msg
        }
        server.onVideoConfig = { sps, pps in
            decoder.configure(sps: sps, pps: pps)
            // Forward to RTMP publishers if streaming
            appState.rtmpPublisher?.sendVideoConfig(sps: sps, pps: pps)
        }
        server.onVideoFrame = { pkt in
            decoder.decodeFrame(pkt)
            appState.ingressVideoFrameCount += 1
            appState.rtmpPublisher?.sendVideoFrame(pkt)
        }
        server.onAudioConfig = { cfg in
            appState.rtmpPublisher?.sendAudioConfig(cfg)
        }
        server.onAudioFrame = { pkt in
            appState.ingressAudioFrameCount += 1
            appState.rtmpPublisher?.sendAudioFrame(pkt)
        }

        server.start()
        appState.isServerRunning = true
    }

    private func stopServer() {
        appState.mediaIngressServer?.stop()
        appState.mediaIngressServer = nil
        appState.isServerRunning = false
        appState.isConnected = false
        appState.ingressVideoFrameCount = 0
        appState.ingressAudioFrameCount = 0
    }

    private func formatBps(_ n: Int) -> String {
        if n > 1_000_000 { return String(format: "%.1f MB/s", Double(n) / 1_000_000) }
        if n > 1_000 { return String(format: "%.0f KB/s", Double(n) / 1_000) }
        return "\(n) B/s"
    }
}
