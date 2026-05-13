import Foundation

/// Twitch Helix API calls using async/await.
class TwitchApi {

    static let helixBase = "https://api.twitch.tv/helix"

    // MARK: - Users

    static func getUser(accessToken: String, clientId: String, login: String? = nil) async throws -> TwitchUser {
        var urlStr = "\(helixBase)/users"
        if let login = login { urlStr += "?login=\(login)" }
        var req = URLRequest(url: URL(string: urlStr)!)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(clientId, forHTTPHeaderField: "Client-Id")
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(TwitchUsersResponse.self, from: data)
        guard let user = resp.data.first else { throw TwitchError.noUser }
        return user
    }

    // MARK: - Channel

    static func getChannel(accessToken: String, clientId: String, broadcasterId: String) async throws -> TwitchChannelInfo {
        let urlStr = "\(helixBase)/channels?broadcaster_id=\(broadcasterId)"
        var req = URLRequest(url: URL(string: urlStr)!)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(clientId, forHTTPHeaderField: "Client-Id")
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(TwitchChannelResponse.self, from: data)
        guard let ch = resp.data.first else { throw TwitchError.noChannel }
        return ch
    }

    static func updateChannel(
        accessToken: String,
        clientId: String,
        broadcasterId: String,
        title: String,
        gameId: String
    ) async throws {
        let urlStr = "\(helixBase)/channels?broadcaster_id=\(broadcasterId)"
        var req = URLRequest(url: URL(string: urlStr)!)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(clientId, forHTTPHeaderField: "Client-Id")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["title": title, "game_id": gameId]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: req)
    }

    // MARK: - Stream Key

    static func getStreamKey(accessToken: String, clientId: String, broadcasterId: String) async throws -> String {
        let urlStr = "\(helixBase)/streams/key?broadcaster_id=\(broadcasterId)"
        var req = URLRequest(url: URL(string: urlStr)!)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(clientId, forHTTPHeaderField: "Client-Id")
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(TwitchStreamKeyResponse.self, from: data)
        guard let key = resp.data.first?.streamKey else { throw TwitchError.noStreamKey }
        return key
    }

    enum TwitchError: Error, LocalizedError {
        case noUser
        case noChannel
        case noStreamKey

        var errorDescription: String? {
            switch self {
            case .noUser:      return "No Twitch user found"
            case .noChannel:   return "No Twitch channel found"
            case .noStreamKey: return "Could not fetch stream key"
            }
        }
    }
}
