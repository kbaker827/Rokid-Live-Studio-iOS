import Foundation

/// Connects to Twitch IRC over WebSocket and receives chat messages.
@MainActor
class TwitchChatClient: NSObject, ObservableObject {

    var onMessage: ((ChatMessage) -> Void)?
    var onError: ((String) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var channel: String = ""
    private var token: String = ""
    private var nick: String = ""

    func connect(channel: String, token: String, nick: String) {
        self.channel = channel.lowercased()
        self.token = token
        self.nick = nick.lowercased()

        let url = URL(string: "wss://irc-ws.chat.twitch.tv/")!
        session = URLSession(configuration: .default)
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()

        sendMessage("PASS oauth:\(token)")
        sendMessage("NICK \(nick)")
        sendMessage("CAP REQ :twitch.tv/tags twitch.tv/commands")
        sendMessage("JOIN #\(self.channel)")
        receiveNextMessage()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        session = nil
    }

    private func sendMessage(_ text: String) {
        webSocketTask?.send(.string(text)) { _ in }
    }

    private func receiveNextMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let msg):
                    switch msg {
                    case .string(let text):
                        self.parseIRC(text)
                    default: break
                    }
                    self.receiveNextMessage()
                case .failure(let err):
                    self.onError?("Twitch chat error: \(err.localizedDescription)")
                }
            }
        }
    }

    private func parseIRC(_ raw: String) {
        let lines = raw.components(separatedBy: "\r\n")
        for line in lines where !line.isEmpty {
            if line.hasPrefix("PING") {
                sendMessage("PONG :tmi.twitch.tv")
                continue
            }

            // Parse: @tags :user!user@user.tmi.twitch.tv PRIVMSG #channel :message
            var remainder = line
            var tags: [String: String] = [:]

            if remainder.hasPrefix("@") {
                let parts = remainder.dropFirst().components(separatedBy: " ")
                if parts.count > 1 {
                    let tagStr = parts[0]
                    for tag in tagStr.components(separatedBy: ";") {
                        let kv = tag.components(separatedBy: "=")
                        if kv.count == 2 { tags[kv[0]] = kv[1] }
                    }
                    remainder = parts[1...].joined(separator: " ")
                }
            }

            guard remainder.contains("PRIVMSG") else { continue }
            let msgParts = remainder.components(separatedBy: " PRIVMSG #\(channel) :")
            guard msgParts.count >= 2 else { continue }

            let prefix = msgParts[0] // :user!user@host
            let text = msgParts[1...].joined(separator: " PRIVMSG #\(channel) :")

            let displayName = tags["display-name"] ?? extractNick(from: prefix)
            let chatMsg = ChatMessage(author: displayName, text: text, timestamp: Date())
            onMessage?(chatMsg)
        }
    }

    private func extractNick(from prefix: String) -> String {
        // :nick!nick@host
        let stripped = prefix.hasPrefix(":") ? String(prefix.dropFirst()) : prefix
        return stripped.components(separatedBy: "!").first ?? stripped
    }
}
