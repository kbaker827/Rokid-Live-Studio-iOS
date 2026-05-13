import Foundation

// MARK: - YouTube OAuth & API Models

struct YouTubeDeviceCodeResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUrl: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode       = "device_code"
        case userCode         = "user_code"
        case verificationUrl  = "verification_url"
        case expiresIn        = "expires_in"
        case interval
    }
}

struct YouTubeTokenResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken     = "access_token"
        case refreshToken    = "refresh_token"
        case expiresIn       = "expires_in"
        case tokenType       = "token_type"
        case error
        case errorDescription = "error_description"
    }
}

struct YouTubeChannel: Codable, Identifiable {
    let id: String
    let snippet: Snippet

    struct Snippet: Codable {
        let title: String
        let description: String?
    }
}

struct YouTubeChannelListResponse: Codable {
    let items: [YouTubeChannel]?
}

struct YouTubeLiveBroadcast: Codable, Identifiable {
    let id: String
    let snippet: Snippet?
    let contentDetails: ContentDetails?
    let status: Status?

    struct Snippet: Codable {
        let title: String?
        let liveChatId: String?
    }
    struct ContentDetails: Codable {
        let boundStreamId: String?
    }
    struct Status: Codable {
        let lifeCycleStatus: String?
        let privacyStatus: String?
    }
}

struct YouTubeLiveStream: Codable, Identifiable {
    let id: String
    let cdn: CDN?
    let status: StreamStatus?

    struct CDN: Codable {
        let ingestionInfo: IngestionInfo?
        struct IngestionInfo: Codable {
            let streamName: String?
            let ingestionAddress: String?
        }
    }
    struct StreamStatus: Codable {
        let streamStatus: String?
    }
}

struct YouTubeLiveChatMessage: Codable, Identifiable {
    let id: String
    let snippet: Snippet?
    let authorDetails: AuthorDetails?

    struct Snippet: Codable {
        let displayMessage: String?
        let publishedAt: String?
    }
    struct AuthorDetails: Codable {
        let displayName: String?
        let profileImageUrl: String?
    }
}

struct YouTubeLiveChatResponse: Codable {
    let items: [YouTubeLiveChatMessage]?
    let nextPageToken: String?
    let pollingIntervalMillis: Int?
}

enum YouTubePrivacy: String, CaseIterable, Identifiable {
    case `private` = "private"
    case unlisted  = "unlisted"
    case `public`  = "public"
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

struct YouTubeCategory: Identifiable {
    let id: String
    let name: String

    static let allCategories: [YouTubeCategory] = [
        .init(id: "1",  name: "Film & Animation"),
        .init(id: "2",  name: "Autos & Vehicles"),
        .init(id: "10", name: "Music"),
        .init(id: "15", name: "Pets & Animals"),
        .init(id: "17", name: "Sports"),
        .init(id: "19", name: "Travel & Events"),
        .init(id: "20", name: "Gaming"),
        .init(id: "22", name: "People & Blogs"),
        .init(id: "23", name: "Comedy"),
        .init(id: "24", name: "Entertainment"),
        .init(id: "25", name: "News & Politics"),
        .init(id: "26", name: "Howto & Style"),
        .init(id: "27", name: "Education"),
        .init(id: "28", name: "Science & Technology"),
        .init(id: "29", name: "Nonprofits & Activism"),
    ]
}

// Chat message for display
struct ChatMessage: Identifiable {
    let id = UUID()
    let author: String
    let text: String
    let timestamp: Date
    var isOwn: Bool = false
}
