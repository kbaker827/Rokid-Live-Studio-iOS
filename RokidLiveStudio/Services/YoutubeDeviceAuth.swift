import Foundation

/// YouTube OAuth 2.0 Device Authorization Flow
class YouTubeDeviceAuth {

    enum AuthError: Error, LocalizedError {
        case declined
        case expired
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .declined: return "Authorization declined by user"
            case .expired:  return "Device code expired — please try again"
            case .serverError(let s): return s
            }
        }
    }

    private let clientId: String
    private let clientSecret: String
    private let scope = "https://www.googleapis.com/auth/youtube"

    init(clientId: String, clientSecret: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    /// Step 1: Request device code. Returns (userCode, deviceCode, verificationUrl, interval).
    func requestDeviceCode() async throws -> YouTubeDeviceCodeResponse {
        let url = URL(string: "https://oauth2.googleapis.com/device/code")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=\(clientId)&scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scope)"
        req.httpBody = body.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(YouTubeDeviceCodeResponse.self, from: data)
    }

    /// Step 2: Poll for tokens. Calls completion when authorized or throws on error/expiry.
    func pollForToken(deviceCode: String, interval: Int) async throws -> YouTubeTokenResponse {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        let pollInterval = max(interval, 5)

        while true {
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let body = "client_id=\(clientId)&client_secret=\(clientSecret)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
            req.httpBody = body.data(using: .utf8)

            let (data, _) = try await URLSession.shared.data(for: req)
            let resp = try JSONDecoder().decode(YouTubeTokenResponse.self, from: data)

            if let accessToken = resp.accessToken, !accessToken.isEmpty {
                return resp
            }
            switch resp.error {
            case "authorization_pending": continue
            case "slow_down":            try await Task.sleep(nanoseconds: 5_000_000_000)
            case "access_denied":        throw AuthError.declined
            case "expired_token":        throw AuthError.expired
            default:
                if let err = resp.error {
                    throw AuthError.serverError(err)
                }
            }
        }
    }
}
