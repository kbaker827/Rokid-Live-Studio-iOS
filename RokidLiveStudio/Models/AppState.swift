import Foundation
import Combine
import Network

@MainActor
class AppState: ObservableObject {

    // MARK: - Connection state
    @Published var isServerRunning = false
    @Published var isConnected = false
    @Published var errorMessage: String? = nil
    @Published var phoneIPAddress: String = "..."

    // MARK: - Stream state
    @Published var isStreamingYouTube = false
    @Published var isStreamingTwitch = false
    @Published var streamingError: String? = nil

    // MARK: - Preview
    @Published var showPreview = true

    // MARK: - YouTube settings
    @Published var youtubeMode: YouTubeMode = .streamKey
    @Published var youtubeStreamKey: String = ""
    @Published var youtubeStreamTitle: String = "Rokid Live Studio"
    @Published var youtubePreset: VideoPreset = .live720p916
    @Published var youtubeBitrateOverride: BitrateOverride = .auto
    @Published var youtubePrivacy: YouTubePrivacy = .public
    @Published var youtubeCategoryId: String = "28"
    @Published var youtubeShowChat = true
    @Published var youtubeChatFontSize: Double = 14
    @Published var youtubeChatMaxMessages: Int = 50
    // OAuth state
    @Published var youtubeAccessToken: String? = nil
    @Published var youtubeRefreshToken: String? = nil
    @Published var youtubeClientId: String = ""
    @Published var youtubeClientSecret: String = ""
    @Published var youtubeDeviceCode: String? = nil
    @Published var youtubeUserCode: String? = nil
    @Published var youtubeVerificationUrl: String? = nil
    @Published var youtubeChannelName: String? = nil
    @Published var youtubeChannelId: String? = nil
    @Published var youtubeLiveBroadcastId: String? = nil
    @Published var youtubeLiveStreamId: String? = nil
    @Published var youtubeLiveChatId: String? = nil
    @Published var youtubeOAuthStatus: String = ""
    // Chat
    @Published var youtubeMessages: [ChatMessage] = []

    // MARK: - Twitch settings
    @Published var twitchStreamKey: String = ""
    @Published var twitchStreamTitle: String = "Rokid Live Studio"
    @Published var twitchPreset: VideoPreset = .live720p916
    @Published var twitchBitrateOverride: BitrateOverride = .auto
    @Published var twitchCategoryId: String = "509672"
    @Published var twitchIngestServerId: String = "auto"
    @Published var twitchShowChat = true
    @Published var twitchChatFontSize: Double = 14
    @Published var twitchChatMaxMessages: Int = 50
    // OAuth state
    @Published var twitchAccessToken: String? = nil
    @Published var twitchClientId: String = ""
    @Published var twitchDeviceCode: String? = nil
    @Published var twitchUserCode: String? = nil
    @Published var twitchVerificationUri: String? = nil
    @Published var twitchUserId: String? = nil
    @Published var twitchLogin: String? = nil
    @Published var twitchDisplayName: String? = nil
    @Published var twitchOAuthStatus: String = ""
    // Chat
    @Published var twitchMessages: [ChatMessage] = []

    // MARK: - RTMP diagnostics
    @Published var rtmpBytesPerSec: Int = 0
    @Published var rtmpBufferSize: Int = 0

    // MARK: - Ingress stats
    @Published var ingressVideoFrameCount: Int = 0
    @Published var ingressAudioFrameCount: Int = 0
    @Published var ingressBytesPerSec: Int = 0

    // MARK: - Services (initialized lazily)
    var mediaIngressServer: MediaIngressServer?
    var rtmpPublisher: RtmpPublisher?
    var youtubeChat: YoutubeChatClient?
    var twitchChat: TwitchChatClient?

    init() {
        loadSecretsFromKeychain()
        refreshPhoneIP()
    }

    func refreshPhoneIP() {
        phoneIPAddress = getLocalIPAddress() ?? "Unknown"
    }

    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = firstAddr
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr
            if flags & (IFF_UP|IFF_RUNNING) != 0 && addr?.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr!.pointee.sa_len),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(cString: hostname)
                    if ip != "127.0.0.1" {
                        address = ip
                        break
                    }
                }
            }
            if let next = ptr.pointee.ifa_next { ptr = next } else { break }
        }
        return address
    }

    // MARK: - Keychain helpers
    func loadSecretsFromKeychain() {
        youtubeStreamKey    = SecretStore.load(key: "yt_stream_key") ?? ""
        youtubeClientId     = SecretStore.load(key: "yt_client_id") ?? ""
        youtubeClientSecret = SecretStore.load(key: "yt_client_secret") ?? ""
        youtubeAccessToken  = SecretStore.load(key: "yt_access_token")
        youtubeRefreshToken = SecretStore.load(key: "yt_refresh_token")
        youtubeChannelName  = SecretStore.load(key: "yt_channel_name")
        youtubeChannelId    = SecretStore.load(key: "yt_channel_id")

        twitchStreamKey   = SecretStore.load(key: "tw_stream_key") ?? ""
        twitchClientId    = SecretStore.load(key: "tw_client_id") ?? ""
        twitchAccessToken = SecretStore.load(key: "tw_access_token")
        twitchLogin       = SecretStore.load(key: "tw_login")
        twitchDisplayName = SecretStore.load(key: "tw_display_name")
        twitchUserId      = SecretStore.load(key: "tw_user_id")
    }

    func saveSecretsToKeychain() {
        SecretStore.save(key: "yt_stream_key",    value: youtubeStreamKey)
        SecretStore.save(key: "yt_client_id",     value: youtubeClientId)
        SecretStore.save(key: "yt_client_secret", value: youtubeClientSecret)
        if let t = youtubeAccessToken  { SecretStore.save(key: "yt_access_token",  value: t) }
        if let t = youtubeRefreshToken { SecretStore.save(key: "yt_refresh_token", value: t) }
        if let n = youtubeChannelName  { SecretStore.save(key: "yt_channel_name",  value: n) }
        if let i = youtubeChannelId    { SecretStore.save(key: "yt_channel_id",    value: i) }

        SecretStore.save(key: "tw_stream_key", value: twitchStreamKey)
        SecretStore.save(key: "tw_client_id",  value: twitchClientId)
        if let t = twitchAccessToken  { SecretStore.save(key: "tw_access_token",   value: t) }
        if let l = twitchLogin        { SecretStore.save(key: "tw_login",          value: l) }
        if let d = twitchDisplayName  { SecretStore.save(key: "tw_display_name",   value: d) }
        if let i = twitchUserId       { SecretStore.save(key: "tw_user_id",        value: i) }
    }

    func clearYoutubeAuth() {
        youtubeAccessToken = nil
        youtubeRefreshToken = nil
        youtubeChannelName = nil
        youtubeChannelId = nil
        SecretStore.delete(key: "yt_access_token")
        SecretStore.delete(key: "yt_refresh_token")
        SecretStore.delete(key: "yt_channel_name")
        SecretStore.delete(key: "yt_channel_id")
    }

    func clearTwitchAuth() {
        twitchAccessToken = nil
        twitchLogin = nil
        twitchDisplayName = nil
        twitchUserId = nil
        twitchStreamKey = ""
        SecretStore.delete(key: "tw_access_token")
        SecretStore.delete(key: "tw_login")
        SecretStore.delete(key: "tw_display_name")
        SecretStore.delete(key: "tw_user_id")
        SecretStore.delete(key: "tw_stream_key")
    }
}

// MARK: - Supporting enums
enum YouTubeMode: String, CaseIterable {
    case streamKey = "Stream key"
    case oauth     = "OAuth account"
}
