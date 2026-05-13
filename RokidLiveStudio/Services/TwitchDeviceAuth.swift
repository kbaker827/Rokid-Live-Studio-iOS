import Foundation

/// Twitch OAuth 2.0 Device Authorization Flow
class TwitchDeviceAuth {

    enum AuthError: Error, LocalizedError {
        case declined
        case expired
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .declined: return "Authorization declined"
            case .expired:  return "Code expired — try again"
            case .serverError(let s): return s
            }
        }
    }

    private let clientId: String
    private let scopes = "channel:read:stream_key channel:manage:broadcast chat:read chat:edit"

    init(clientId: String) {
        self.clientId = clientId
    }

    /// Step 1: Request device code.
    func requestDeviceCode() async throws -> TwitchDeviceCodeResponse {
        let url = URL(string: "https://id.twitch.tv/oauth2/device")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let encodedScopes = scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scopes
        let body = "client_id=\(clientId)&scopes=\(encodedScopes)"
        req.httpBody = body.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(TwitchDeviceCodeResponse.self, from: data)
    }

    /// Step 2: Poll for access token.
    func pollForToken(deviceCode: String, interval: Int) async throws -> TwitchTokenResponse {
        let url = URL(string: "https://id.twitch.tv/oauth2/token")!
        let pollInterval = max(interval, 5)

        while true {
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let body = "client_id=\(clientId)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
            req.httpBody = body.data(using: .utf8)
            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(TwitchTokenResponse.self, from: data)
            if let token = resp.accessToken, !token.isEmpty { return resp }
            switch resp.error {
            case "authorization_pending": continue
            case "slow_down": try await Task.sleep(nanoseconds: 5_000_000_000)
            case "access_denied": throw AuthError.declined
            case "expired_token": throw AuthError.expired
            default:
                if let err = resp.error { throw AuthError.serverError(err) }
            }
        }
    }
}
