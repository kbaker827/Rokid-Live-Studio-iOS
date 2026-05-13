import Foundation

// MARK: - Twitch OAuth & API Models

struct TwitchDeviceCodeResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode      = "device_code"
        case userCode        = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn       = "expires_in"
        case interval
    }
}

struct TwitchTokenResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?
    let error: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn    = "expires_in"
        case tokenType    = "token_type"
        case error
        case message
    }
}

struct TwitchUser: Codable, Identifiable {
    let id: String
    let login: String
    let displayName: String
    let profileImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case displayName    = "display_name"
        case profileImageUrl = "profile_image_url"
    }
}

struct TwitchUsersResponse: Codable {
    let data: [TwitchUser]
}

struct TwitchStreamKeyResponse: Codable {
    let data: [StreamKeyEntry]
    struct StreamKeyEntry: Codable {
        let streamKey: String
        enum CodingKeys: String, CodingKey {
            case streamKey = "stream_key"
        }
    }
}

struct TwitchChannelInfo: Codable {
    let broadcasterId: String
    let broadcasterName: String
    let title: String?
    let gameName: String?
    let gameId: String?

    enum CodingKeys: String, CodingKey {
        case broadcasterId   = "broadcaster_id"
        case broadcasterName = "broadcaster_name"
        case title
        case gameName        = "game_name"
        case gameId          = "game_id"
    }
}

struct TwitchChannelResponse: Codable {
    let data: [TwitchChannelInfo]
}

struct TwitchCategory: Identifiable {
    let id: String
    let name: String

    static let allCategories: [TwitchCategory] = [
        .init(id: "509658", name: "Just Chatting"),
        .init(id: "509659", name: "Art"),
        .init(id: "26936",  name: "Music"),
        .init(id: "518203", name: "Sports"),
        .init(id: "32982",  name: "Gaming"),
        .init(id: "509672", name: "Science & Technology"),
        .init(id: "509660", name: "Talk Shows & Podcasts"),
        .init(id: "509667", name: "Food & Drink"),
        .init(id: "509673", name: "Travel & Outdoors"),
        .init(id: "509670", name: "Beauty & Body Art"),
    ]
}

struct TwitchIngestServer: Identifiable {
    let id: String
    let name: String
    let url: String

    static let allServers: [TwitchIngestServer] = [
        .init(id: "auto",    name: "Auto (Recommended)", url: "rtmp://live.twitch.tv/app"),
        .init(id: "us-west", name: "US West",            url: "rtmp://live-sjc.twitch.tv/app"),
        .init(id: "us-east", name: "US East",            url: "rtmp://live-jfk.twitch.tv/app"),
        .init(id: "eu-west", name: "EU West",            url: "rtmp://live-ams.twitch.tv/app"),
        .init(id: "eu-cent", name: "EU Central",         url: "rtmp://live-fra.twitch.tv/app"),
        .init(id: "asia",    name: "Asia Pacific",       url: "rtmp://live-hkg.twitch.tv/app"),
    ]
}
