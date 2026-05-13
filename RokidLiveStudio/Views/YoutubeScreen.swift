import SwiftUI

struct YoutubeScreen: View {
    @EnvironmentObject var appState: AppState
    let decoder: VideoDecoder

    @State private var isLinking = false
    @State private var isStarting = false
    @State private var showCopyConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                HStack(spacing: 10) {
                    Image(systemName: AppIcon.youtube)
                        .foregroundColor(.red)
                        .font(.system(size: 24))
                    Text("YouTube Live")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.rText)
                    Spacer()
                    if appState.isStreamingYouTube {
                        LiveBadge()
                    }
                }

                // Error
                if let err = appState.streamingError {
                    ErrorBanner(message: err) { appState.streamingError = nil }
                }

                // Mode picker
                SegmentedPicker(options: YouTubeMode.allCases, selection: $appState.youtubeMode)

                // Stream Key mode
                if appState.youtubeMode == .streamKey {
                    SectionCard(title: "Stream Key") {
                        VStack(spacing: 0) {
                            HStack(spacing: 8) {
                                LabeledField(
                                    label: "YouTube Stream Key",
                                    placeholder: "xxxx-xxxx-xxxx-xxxx",
                                    text: $appState.youtubeStreamKey,
                                    isSecure: true
                                )
                            }
                            .padding(14)
                            Divider().background(Color.rBorder)
                            HStack {
                                Text("Copy")
                                    .font(.system(size: 13))
                                    .foregroundColor(.rMuted)
                                Spacer()
                                Button(action: {
                                    UIPasteboard.general.string = appState.youtubeStreamKey
                                    showCopyConfirm = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showCopyConfirm = false
                                    }
                                }) {
                                    Image(systemName: showCopyConfirm ? AppIcon.check : AppIcon.copy)
                                        .foregroundColor(showCopyConfirm ? .rGreen : .rMuted)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                }

                // OAuth mode
                if appState.youtubeMode == .oauth {
                    oauthSection
                }

                // Common settings
                SectionCard(title: "Stream Settings") {
                    VStack(spacing: 14) {
                        if appState.youtubeMode == .oauth {
                            LabeledField(
                                label: "Stream Title",
                                placeholder: "Enter stream title...",
                                text: $appState.youtubeStreamTitle
                            )
                        }
                        presetPicker
                        bitratePicker
                        privacyPicker
                        categoryPicker
                    }
                    .padding(14)
                }

                // Preview
                PreviewCard(decoder: decoder)
                    .environmentObject(appState)

                // Chat
                chatSection

                // Diagnostics
                RTMPDiagnosticsCard()
                    .environmentObject(appState)

                // Action button
                if appState.isStreamingYouTube {
                    PrimaryButton(title: "End YouTube Live", color: .rRed) {
                        stopYouTube()
                    }
                } else {
                    if appState.youtubeMode == .streamKey {
                        PrimaryButton(
                            title: "Start Stream with Key",
                            color: .rGreen,
                            isLoading: isStarting
                        ) {
                            Task { await startStreamKey() }
                        }
                        .disabled(appState.youtubeStreamKey.isEmpty || isStarting)
                    } else {
                        PrimaryButton(
                            title: "Create Live & Start",
                            color: .rGreen,
                            isLoading: isStarting
                        ) {
                            Task { await startOAuth() }
                        }
                        .disabled(appState.youtubeAccessToken == nil || isStarting)
                    }
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
        .onDisappear {
            appState.saveSecretsToKeychain()
        }
    }

    // MARK: - OAuth Section

    var oauthSection: some View {
        SectionCard(title: "YouTube Account") {
            VStack(spacing: 14) {
                LabeledField(label: "Client ID",     placeholder: "OAuth 2.0 Client ID",
                             text: $appState.youtubeClientId)
                LabeledField(label: "Client Secret", placeholder: "OAuth 2.0 Client Secret",
                             text: $appState.youtubeClientSecret, isSecure: true)

                if appState.youtubeAccessToken == nil {
                    // Show link button
                    if let userCode = appState.youtubeUserCode,
                       let verUrl   = appState.youtubeVerificationUrl {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("1. Visit: \(verUrl)")
                                .font(.system(size: 13)).foregroundColor(.rText)
                            HStack {
                                Text("2. Enter code:")
                                    .font(.system(size: 13)).foregroundColor(.rText)
                                Text(userCode)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.rGreen)
                                Button(action: { UIPasteboard.general.string = userCode }) {
                                    Image(systemName: AppIcon.copy).foregroundColor(.rMuted)
                                }
                            }
                            Text("Waiting for authorization...")
                                .font(.system(size: 12)).foregroundColor(.rMuted)
                        }
                        .padding(10)
                        .background(Color.rCard2)
                        .cornerRadius(8)
                    }

                    PrimaryButton(
                        title: isLinking ? "Linking..." : "Link with Device Code",
                        color: .red,
                        isLoading: isLinking
                    ) {
                        Task { await linkYouTube() }
                    }
                    .disabled(appState.youtubeClientId.isEmpty ||
                              appState.youtubeClientSecret.isEmpty || isLinking)
                } else {
                    // Connected
                    HStack {
                        Image(systemName: AppIcon.check).foregroundColor(.rGreen)
                        Text("Connected: \(appState.youtubeChannelName ?? "YouTube")")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.rText)
                        Spacer()
                        Button(action: { appState.clearYoutubeAuth() }) {
                            Text("Disconnect")
                                .font(.system(size: 13)).foregroundColor(.rRed)
                        }
                    }
                    .padding(12)
                    .background(Color.rCard2).cornerRadius(8)

                    Button(action: { Task { await refreshChannel() } }) {
                        Label("Refresh Channel", systemImage: AppIcon.refresh)
                            .font(.system(size: 13)).foregroundColor(.rMuted)
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: - Pickers

    var presetPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Resolution").font(.system(size: 12, weight: .medium)).foregroundColor(.rMuted)
            Picker("Resolution", selection: $appState.youtubePreset) {
                ForEach(VideoPreset.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.menu)
            .accentColor(.rGreen)
        }
    }

    var bitratePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bitrate Override").font(.system(size: 12, weight: .medium)).foregroundColor(.rMuted)
            Picker("Bitrate", selection: $appState.youtubeBitrateOverride) {
                ForEach(BitrateOverride.allCases) { b in
                    Text(b.rawValue).tag(b)
                }
            }
            .pickerStyle(.menu)
            .accentColor(.rGreen)
        }
    }

    var privacyPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Privacy").font(.system(size: 12, weight: .medium)).foregroundColor(.rMuted)
            Picker("Privacy", selection: $appState.youtubePrivacy) {
                ForEach(YouTubePrivacy.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Category").font(.system(size: 12, weight: .medium)).foregroundColor(.rMuted)
            Picker("Category", selection: $appState.youtubeCategoryId) {
                ForEach(YouTubeCategory.allCategories) { c in
                    Text(c.name).tag(c.id)
                }
            }
            .pickerStyle(.menu)
            .accentColor(.rGreen)
        }
    }

    // MARK: - Chat Section

    var chatSection: some View {
        SectionCard(title: "Live Chat") {
            VStack(spacing: 0) {
                HStack {
                    Toggle("Show Chat", isOn: $appState.youtubeShowChat)
                        .toggleStyle(SwitchToggleStyle(tint: .rGreen))
                        .font(.system(size: 14)).foregroundColor(.rText)
                }
                .padding(14)

                if appState.youtubeShowChat && !appState.youtubeMessages.isEmpty {
                    Divider().background(Color.rBorder)
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(appState.youtubeMessages.suffix(appState.youtubeChatMaxMessages)) { msg in
                                    ChatBubble(message: msg)
                                    Divider().background(Color.rBorder.opacity(0.5))
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        .onChange(of: appState.youtubeMessages.count) { _ in
                            if let last = appState.youtubeMessages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    func linkYouTube() async {
        isLinking = true
        defer { isLinking = false }
        let auth = YouTubeDeviceAuth(clientId: appState.youtubeClientId,
                                     clientSecret: appState.youtubeClientSecret)
        do {
            let code = try await auth.requestDeviceCode()
            appState.youtubeDeviceCode = code.deviceCode
            appState.youtubeUserCode = code.userCode
            appState.youtubeVerificationUrl = code.verificationUrl

            let token = try await auth.pollForToken(deviceCode: code.deviceCode,
                                                    interval: code.interval)
            appState.youtubeAccessToken = token.accessToken
            appState.youtubeRefreshToken = token.refreshToken
            appState.youtubeDeviceCode = nil
            appState.youtubeUserCode = nil
            appState.youtubeVerificationUrl = nil
            await refreshChannel()
            appState.saveSecretsToKeychain()
        } catch {
            appState.streamingError = error.localizedDescription
        }
    }

    func refreshChannel() async {
        guard let token = appState.youtubeAccessToken else { return }
        do {
            let ch = try await YouTubeApi.fetchChannel(accessToken: token)
            appState.youtubeChannelName = ch.snippet.title
            appState.youtubeChannelId = ch.id
            appState.saveSecretsToKeychain()
        } catch {
            appState.streamingError = "Could not fetch channel: \(error.localizedDescription)"
        }
    }

    func startStreamKey() async {
        isStarting = true
        defer { isStarting = false }
        let preset = appState.youtubePreset
        let bitrate = appState.youtubeBitrateOverride.kbps ?? preset.bitrateKbps
        let rtmpUrl = "rtmp://a.rtmp.youtube.com/live2/\(appState.youtubeStreamKey)"
        startRTMP(url: rtmpUrl, bitrate: bitrate)
    }

    func startOAuth() async {
        isStarting = true
        defer { isStarting = false }
        guard let token = appState.youtubeAccessToken else {
            appState.streamingError = "Not linked to YouTube"; return
        }
        do {
            let preset = appState.youtubePreset
            let broadcast = try await YouTubeApi.createLiveBroadcast(
                accessToken: token,
                title: appState.youtubeStreamTitle,
                privacy: appState.youtubePrivacy,
                categoryId: appState.youtubeCategoryId
            )
            let stream = try await YouTubeApi.createLiveStream(
                accessToken: token,
                title: appState.youtubeStreamTitle,
                width: preset.width, height: preset.height
            )
            let bound = try await YouTubeApi.bindBroadcastToStream(
                accessToken: token,
                broadcastId: broadcast.id,
                streamId: stream.id
            )
            appState.youtubeLiveBroadcastId = bound.id
            appState.youtubeLiveStreamId = stream.id
            appState.youtubeLiveChatId = bound.snippet?.liveChatId

            let streamKey = stream.cdn?.ingestionInfo?.streamName ?? ""
            let ingestUrl = stream.cdn?.ingestionInfo?.ingestionAddress ?? "rtmp://a.rtmp.youtube.com/live2"
            let rtmpUrl = "\(ingestUrl)/\(streamKey)"
            let bitrate = appState.youtubeBitrateOverride.kbps ?? preset.bitrateKbps
            startRTMP(url: rtmpUrl, bitrate: bitrate)

            // Start chat if enabled
            if appState.youtubeShowChat, let chatId = appState.youtubeLiveChatId {
                let chat = YoutubeChatClient()
                chat.onMessage = { msg in appState.youtubeMessages.append(msg) }
                appState.youtubeChat = chat
                chat.start(accessToken: token, liveChatId: chatId)
            }
        } catch {
            appState.streamingError = error.localizedDescription
        }
    }

    private func startRTMP(url: String, bitrate: Int) {
        _ = bitrate
        let publisher = RtmpPublisher()
        publisher.onStateChange = { state in
            DispatchQueue.main.async {
                switch state {
                case .publishing:
                    appState.isStreamingYouTube = true
                    appState.streamingError = nil
                case .error(let msg):
                    appState.streamingError = msg
                    appState.isStreamingYouTube = false
                case .idle:
                    appState.isStreamingYouTube = false
                default: break
                }
            }
        }
        publisher.onBytesPerSec = { bps in
            appState.rtmpBytesPerSec = bps
        }
        appState.rtmpPublisher = publisher
        publisher.connect(url: url)
    }

    func stopYouTube() {
        appState.rtmpPublisher?.disconnect()
        appState.rtmpPublisher = nil
        appState.youtubeChat?.stop()
        appState.youtubeChat = nil
        appState.isStreamingYouTube = false

        // Transition broadcast to complete
        if let token = appState.youtubeAccessToken,
           let bId = appState.youtubeLiveBroadcastId {
            Task {
                try? await YouTubeApi.transitionBroadcast(
                    accessToken: token, broadcastId: bId, status: "complete")
                appState.youtubeLiveBroadcastId = nil
                appState.youtubeLiveStreamId = nil
            }
        }
    }
}

// MARK: - Live Badge

struct LiveBadge: View {
    var body: some View {
        Text("LIVE")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.rRed)
            .cornerRadius(4)
    }
}
