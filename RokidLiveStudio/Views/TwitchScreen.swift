import SwiftUI

struct TwitchScreen: View {
    @EnvironmentObject var appState: AppState
    let decoder: VideoDecoder

    @State private var isLinking = false
    @State private var isStarting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                HStack(spacing: 10) {
                    Image(systemName: AppIcon.broadcast)
                        .foregroundColor(.rPurple)
                        .font(.system(size: 24))
                    Text("Twitch Live")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.rText)
                    Spacer()
                    if appState.isStreamingTwitch {
                        LiveBadge()
                    }
                }

                if let err = appState.streamingError {
                    ErrorBanner(message: err) { appState.streamingError = nil }
                }

                // OAuth Section
                oauthSection

                // Settings
                SectionCard(title: "Stream Settings") {
                    VStack(spacing: 14) {
                        LabeledField(label: "Stream Title", placeholder: "Title...",
                                     text: $appState.twitchStreamTitle)
                        presetPicker
                        bitratePicker
                        categoryPicker
                        ingestPicker
                    }
                    .padding(14)
                }

                // Manual stream key (fallback)
                SectionCard(title: "Manual Stream Key") {
                    LabeledField(
                        label: "Twitch Stream Key",
                        placeholder: "live_XXXXXXXXX",
                        text: $appState.twitchStreamKey,
                        isSecure: true
                    )
                    .padding(14)
                }

                // Preview
                PreviewCard(decoder: decoder)
                    .environmentObject(appState)

                // Chat
                chatSection

                RTMPDiagnosticsCard().environmentObject(appState)

                // Action button
                if appState.isStreamingTwitch {
                    PrimaryButton(title: "End Twitch Stream", color: .rRed) {
                        stopTwitch()
                    }
                } else {
                    PrimaryButton(
                        title: appState.twitchAccessToken != nil ? "Start Twitch Stream" : "Start with Stream Key",
                        color: .rPurple,
                        isLoading: isStarting
                    ) {
                        Task { await startTwitch() }
                    }
                    .disabled(isStarting)
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
        .onDisappear { appState.saveSecretsToKeychain() }
    }

    // MARK: - OAuth

    var oauthSection: some View {
        SectionCard(title: "Twitch Account") {
            VStack(spacing: 14) {
                LabeledField(label: "Client ID", placeholder: "Twitch application Client ID",
                             text: $appState.twitchClientId)

                if appState.twitchAccessToken == nil {
                    if let userCode = appState.twitchUserCode,
                       let verUri = appState.twitchVerificationUri {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("1. Visit: \(verUri)")
                                .font(.system(size: 13)).foregroundColor(.rText)
                            HStack {
                                Text("2. Enter code:")
                                    .font(.system(size: 13)).foregroundColor(.rText)
                                Text(userCode)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.rPurple)
                                Button(action: { UIPasteboard.general.string = userCode }) {
                                    Image(systemName: AppIcon.copy).foregroundColor(.rMuted)
                                }
                            }
                            Text("Waiting for authorization...")
                                .font(.system(size: 12)).foregroundColor(.rMuted)
                        }
                        .padding(10)
                        .background(Color.rCard2).cornerRadius(8)
                    }

                    PrimaryButton(
                        title: isLinking ? "Linking..." : "Link Twitch Account",
                        color: .rPurple,
                        isLoading: isLinking
                    ) {
                        Task { await linkTwitch() }
                    }
                    .disabled(appState.twitchClientId.isEmpty || isLinking)
                } else {
                    HStack {
                        Image(systemName: AppIcon.check).foregroundColor(.rGreen)
                        Text("Connected: \(appState.twitchDisplayName ?? appState.twitchLogin ?? "Twitch")")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.rText)
                        Spacer()
                        Button(action: { appState.clearTwitchAuth() }) {
                            Text("Disconnect").font(.system(size: 13)).foregroundColor(.rRed)
                        }
                    }
                    .padding(12)
                    .background(Color.rCard2).cornerRadius(8)
                }
            }
            .padding(14)
        }
    }

    // MARK: - Pickers

    var presetPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Resolution").font(.system(size: 12, weight: .medium)).foregroundColor(.rMuted)
            Picker("Resolution", selection: $appState.twitchPreset) {
                ForEach(VideoPreset.allCases) { p in Text(p.displayName).tag(p) }
            }
            .pickerStyle(.menu).accentColor(.rPurple)
        }
    }

    var bitratePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bitrate Override").font(.system(size: 12, weight: .medium)).foregroundColor(.rMuted)
            Picker("Bitrate", selection: $appState.twitchBitrateOverride) {
                ForEach(BitrateOverride.allCases) { b in Text(b.rawValue).tag(b) }
            }
            .pickerStyle(.menu).accentColor(.rPurple)
        }
    }

    var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Category").font(.system(size: 12, weight: .medium)).foregroundColor(.rMuted)
            Picker("Category", selection: $appState.twitchCategoryId) {
                ForEach(TwitchCategory.allCategories) { c in Text(c.name).tag(c.id) }
            }
            .pickerStyle(.menu).accentColor(.rPurple)
        }
    }

    var ingestPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ingest Server").font(.system(size: 12, weight: .medium)).foregroundColor(.rMuted)
            Picker("Ingest", selection: $appState.twitchIngestServerId) {
                ForEach(TwitchIngestServer.allServers) { s in Text(s.name).tag(s.id) }
            }
            .pickerStyle(.menu).accentColor(.rPurple)
        }
    }

    // MARK: - Chat

    var chatSection: some View {
        SectionCard(title: "Live Chat") {
            VStack(spacing: 0) {
                HStack {
                    Toggle("Show Chat", isOn: $appState.twitchShowChat)
                        .toggleStyle(SwitchToggleStyle(tint: .rPurple))
                        .font(.system(size: 14)).foregroundColor(.rText)
                }
                .padding(14)

                if appState.twitchShowChat && !appState.twitchMessages.isEmpty {
                    Divider().background(Color.rBorder)
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(appState.twitchMessages.suffix(appState.twitchChatMaxMessages)) { msg in
                                    ChatBubble(message: msg)
                                    Divider().background(Color.rBorder.opacity(0.5))
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        .onChange(of: appState.twitchMessages.count) { _ in
                            if let last = appState.twitchMessages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    func linkTwitch() async {
        isLinking = true
        defer { isLinking = false }
        let auth = TwitchDeviceAuth(clientId: appState.twitchClientId)
        do {
            let code = try await auth.requestDeviceCode()
            appState.twitchDeviceCode = code.deviceCode
            appState.twitchUserCode = code.userCode
            appState.twitchVerificationUri = code.verificationUri

            let token = try await auth.pollForToken(deviceCode: code.deviceCode, interval: code.interval)
            appState.twitchAccessToken = token.accessToken
            appState.twitchDeviceCode = nil
            appState.twitchUserCode = nil
            appState.twitchVerificationUri = nil

            // Fetch user info
            if let at = appState.twitchAccessToken {
                let user = try await TwitchApi.getUser(accessToken: at, clientId: appState.twitchClientId)
                appState.twitchUserId = user.id
                appState.twitchLogin = user.login
                appState.twitchDisplayName = user.displayName

                // Fetch stream key
                let key = try await TwitchApi.getStreamKey(
                    accessToken: at, clientId: appState.twitchClientId, broadcasterId: user.id)
                appState.twitchStreamKey = key
                appState.saveSecretsToKeychain()
            }
        } catch {
            appState.streamingError = error.localizedDescription
        }
    }

    func startTwitch() async {
        isStarting = true
        defer { isStarting = false }

        // If OAuth, update channel title/category first
        if let token = appState.twitchAccessToken,
           let uid = appState.twitchUserId {
            try? await TwitchApi.updateChannel(
                accessToken: token,
                clientId: appState.twitchClientId,
                broadcasterId: uid,
                title: appState.twitchStreamTitle,
                gameId: appState.twitchCategoryId
            )
        }

        let key = appState.twitchStreamKey
        guard !key.isEmpty else {
            appState.streamingError = "No stream key. Link account or enter manually."; return
        }

        let server = TwitchIngestServer.allServers.first { $0.id == appState.twitchIngestServerId }
            ?? TwitchIngestServer.allServers[0]
        let rtmpUrl = "\(server.url)/\(key)"
        let preset = appState.twitchPreset
        let bitrate = appState.twitchBitrateOverride.kbps ?? preset.bitrateKbps
        _ = bitrate

        let publisher = RtmpPublisher()
        publisher.onStateChange = { state in
            DispatchQueue.main.async {
                switch state {
                case .publishing:
                    appState.isStreamingTwitch = true
                    appState.streamingError = nil
                case .error(let msg):
                    appState.streamingError = msg
                    appState.isStreamingTwitch = false
                case .idle:
                    appState.isStreamingTwitch = false
                default: break
                }
            }
        }
        publisher.onBytesPerSec = { bps in appState.rtmpBytesPerSec = bps }
        appState.rtmpPublisher = publisher
        publisher.connect(url: rtmpUrl)

        // Start chat
        if appState.twitchShowChat,
           let token = appState.twitchAccessToken,
           let login = appState.twitchLogin {
            let chat = TwitchChatClient()
            chat.onMessage = { msg in appState.twitchMessages.append(msg) }
            appState.twitchChat = chat
            chat.connect(channel: login, token: token, nick: login)
        }
    }

    func stopTwitch() {
        appState.rtmpPublisher?.disconnect()
        appState.rtmpPublisher = nil
        appState.twitchChat?.disconnect()
        appState.twitchChat = nil
        appState.isStreamingTwitch = false
    }
}
