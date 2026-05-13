import Foundation

/// Polls YouTube Live Chat API for messages.
@MainActor
class YoutubeChatClient: ObservableObject {

    var onMessage: ((ChatMessage) -> Void)?
    var onError: ((String) -> Void)?

    private var pollTask: Task<Void, Never>?
    private var nextPageToken: String? = nil

    func start(accessToken: String, liveChatId: String) {
        stop()
        nextPageToken = nil
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    let resp = try await YouTubeApi.fetchChatMessages(
                        accessToken: accessToken,
                        liveChatId: liveChatId,
                        pageToken: self.nextPageToken
                    )
                    self.nextPageToken = resp.nextPageToken
                    let items = resp.items ?? []
                    for item in items {
                        let author = item.authorDetails?.displayName ?? "Unknown"
                        let text   = item.snippet?.displayMessage ?? ""
                        let msg    = ChatMessage(author: author, text: text, timestamp: Date())
                        self.onMessage?(msg)
                    }
                    let waitMs = resp.pollingIntervalMillis ?? 5000
                    try? await Task.sleep(nanoseconds: UInt64(waitMs) * 1_000_000)
                } catch {
                    self.onError?("YouTube chat error: \(error.localizedDescription)")
                    try? await Task.sleep(nanoseconds: 10_000_000_000)
                }
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }
}
