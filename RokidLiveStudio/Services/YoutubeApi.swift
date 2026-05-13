import Foundation

/// YouTube Data API v3 calls, all using async/await.
class YouTubeApi {

    static let baseURL = "https://www.googleapis.com/youtube/v3"

    // MARK: - Channel

    static func fetchChannel(accessToken: String) async throws -> YouTubeChannel {
        let url = URL(string: "\(baseURL)/channels?part=snippet,id&mine=true")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(YouTubeChannelListResponse.self, from: data)
        guard let ch = resp.items?.first else {
            throw APIError.noItems("No YouTube channels found")
        }
        return ch
    }

    // MARK: - Live Broadcast

    static func createLiveBroadcast(
        accessToken: String,
        title: String,
        privacy: YouTubePrivacy,
        categoryId: String
    ) async throws -> YouTubeLiveBroadcast {
        let url = URL(string: "\(baseURL)/liveBroadcasts?part=snippet,contentDetails,status")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let now = ISO8601DateFormatter().string(from: Date().addingTimeInterval(30))
        let body: [String: Any] = [
            "snippet": [
                "title": title,
                "scheduledStartTime": now,
                "categoryId": categoryId
            ],
            "contentDetails": [
                "enableAutoStart": true,
                "enableAutoStop": true,
                "recordFromStart": true,
                "enableDvr": true
            ],
            "status": [
                "privacyStatus": privacy.rawValue,
                "selfDeclaredMadeForKids": false
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(YouTubeLiveBroadcast.self, from: data)
    }

    static func transitionBroadcast(
        accessToken: String,
        broadcastId: String,
        status: String    // "live" | "complete" | "testing"
    ) async throws {
        let urlStr = "\(baseURL)/liveBroadcasts/transition?broadcastStatus=\(status)&id=\(broadcastId)&part=status"
        var req = URLRequest(url: URL(string: urlStr)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("{}".utf8)
        _ = try await URLSession.shared.data(for: req)
    }

    // MARK: - Live Stream

    static func createLiveStream(
        accessToken: String,
        title: String,
        width: Int, height: Int,
        frameRate: String = "30fps",
        ingestionType: String = "rtmp"
    ) async throws -> YouTubeLiveStream {
        let url = URL(string: "\(baseURL)/liveStreams?part=cdn,snippet,status")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let resolution = "\(width)x\(height)"
        let body: [String: Any] = [
            "snippet": ["title": title],
            "cdn": [
                "frameRate": frameRate,
                "ingestionType": ingestionType,
                "resolution": resolution
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(YouTubeLiveStream.self, from: data)
    }

    static func bindBroadcastToStream(
        accessToken: String,
        broadcastId: String,
        streamId: String
    ) async throws -> YouTubeLiveBroadcast {
        let urlStr = "\(baseURL)/liveBroadcasts/bind?id=\(broadcastId)&streamId=\(streamId)&part=snippet,contentDetails"
        var req = URLRequest(url: URL(string: urlStr)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("{}".utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(YouTubeLiveBroadcast.self, from: data)
    }

    static func getLiveStreamStatus(
        accessToken: String,
        streamId: String
    ) async throws -> String {
        let urlStr = "\(baseURL)/liveStreams?part=status&id=\(streamId)"
        var req = URLRequest(url: URL(string: urlStr)!)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)

        struct Response: Codable {
            let items: [YouTubeLiveStream]?
        }
        let resp = try JSONDecoder().decode(Response.self, from: data)
        return resp.items?.first?.status?.streamStatus ?? "unknown"
    }

    // MARK: - Chat

    static func fetchChatMessages(
        accessToken: String,
        liveChatId: String,
        pageToken: String? = nil
    ) async throws -> YouTubeLiveChatResponse {
        var urlStr = "\(baseURL)/liveChat/messages?part=snippet,authorDetails&liveChatId=\(liveChatId)&maxResults=200"
        if let pt = pageToken { urlStr += "&pageToken=\(pt)" }
        var req = URLRequest(url: URL(string: urlStr)!)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(YouTubeLiveChatResponse.self, from: data)
    }

    // MARK: - Token Refresh

    static func refreshAccessToken(
        clientId: String,
        clientSecret: String,
        refreshToken: String
    ) async throws -> YouTubeTokenResponse {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=\(clientId)&client_secret=\(clientSecret)&refresh_token=\(refreshToken)&grant_type=refresh_token"
        req.httpBody = body.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(YouTubeTokenResponse.self, from: data)
    }

    enum APIError: Error, LocalizedError {
        case noItems(String)
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .noItems(let s): return s
            case .serverError(let s): return s
            }
        }
    }
}
