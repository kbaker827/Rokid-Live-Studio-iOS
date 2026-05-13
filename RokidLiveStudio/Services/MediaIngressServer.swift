import Foundation
import Network

/// Listens on TCP port 39440 for incoming RLS1 media stream from glasses helper.
/// Parsed MediaPackets are forwarded to VideoDecoder and RtmpPublisher.
@MainActor
class MediaIngressServer: ObservableObject {

    static let port: UInt16 = 39440

    // Callbacks set by owner
    var onVideoConfig:  ((_ sps: Data, _ pps: Data) -> Void)?
    var onVideoFrame:   ((_ packet: MediaPacket) -> Void)?
    var onAudioConfig:  ((_ config: Data) -> Void)?
    var onAudioFrame:   ((_ packet: MediaPacket) -> Void)?
    var onError:        ((_ message: String) -> Void)?
    var onConnected:    (() -> Void)?
    var onDisconnected: (() -> Void)?

    private var listener: NWListener?
    private var connection: NWConnection?
    private var readBuffer = Data()
    private let queue = DispatchQueue(label: "rokid.ingress", qos: .userInteractive)

    // Stats
    private(set) var videoFrameCount = 0
    private(set) var audioFrameCount = 0
    private var bytesThisSecond = 0
    private(set) var bytesPerSec = 0
    private var statsTimer: Timer?

    func start() {
        stop()
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            let port = NWEndpoint.Port(rawValue: MediaIngressServer.port)!
            listener = try NWListener(using: parameters, on: port)
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .failed(let error):
                        self?.onError?("Server failed: \(error)")
                    default: break
                    }
                }
            }
            listener?.newConnectionHandler = { [weak self] conn in
                Task { @MainActor in
                    self?.accept(connection: conn)
                }
            }
            listener?.start(queue: queue)
            statsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.bytesPerSec = self?.bytesThisSecond ?? 0
                    self?.bytesThisSecond = 0
                }
            }
        } catch {
            onError?("Could not start listener: \(error)")
        }
    }

    func stop() {
        statsTimer?.invalidate()
        statsTimer = nil
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        readBuffer = Data()
        videoFrameCount = 0
        audioFrameCount = 0
    }

    private func accept(connection conn: NWConnection) {
        // Only one connection at a time
        connection?.cancel()
        connection = conn
        readBuffer = Data()
        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.onConnected?()
                    self?.receiveNextChunk(from: conn)
                case .failed, .cancelled:
                    self?.onDisconnected?()
                default: break
                }
            }
        }
        conn.start(queue: queue)
    }

    private func receiveNextChunk(from conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let data = data, !data.isEmpty {
                    self.bytesThisSecond += data.count
                    self.readBuffer.append(data)
                    self.processBuffer()
                }
                if let error = error {
                    self.onError?("Receive error: \(error)")
                    return
                }
                if isComplete {
                    self.onDisconnected?()
                    return
                }
                self.receiveNextChunk(from: conn)
            }
        }
    }

    private func processBuffer() {
        while readBuffer.count >= RLSHeader.size {
            guard let header = RLSHeader.parse(from: readBuffer) else {
                // Bad magic — scan forward for next magic
                if let idx = findNextMagic(in: readBuffer, after: 1) {
                    readBuffer = readBuffer[idx...]
                } else {
                    readBuffer.removeAll()
                }
                return
            }
            let totalNeeded = RLSHeader.size + Int(header.payloadSize)
            guard readBuffer.count >= totalNeeded else { return }

            let payload = readBuffer[RLSHeader.size ..< totalNeeded]
            readBuffer = readBuffer[totalNeeded...]

            dispatchPacket(header: header, payload: Data(payload))
        }
    }

    private func findNextMagic(in data: Data, after start: Int) -> Int? {
        let magic: [UInt8] = [0x52, 0x4C, 0x53, 0x31]
        guard data.count >= start + 4 else { return nil }
        for i in start ..< (data.count - 3) {
            if data[i] == magic[0] && data[i+1] == magic[1] &&
               data[i+2] == magic[2] && data[i+3] == magic[3] {
                return i
            }
        }
        return nil
    }

    private func dispatchPacket(header: RLSHeader, payload: Data) {
        let isKey = header.flags.contains(.keyFrame)
        let pkt = MediaPacket(type: header.type, isKeyFrame: isKey,
                              timestampUs: header.timestampUs, payload: payload)

        switch header.type {
        case .videoConfig:
            let (sps, pps) = parseAnnexBSPSPPS(payload)
            if let s = sps, let p = pps {
                onVideoConfig?(s, p)
            }
        case .videoFrame:
            videoFrameCount += 1
            onVideoFrame?(pkt)
        case .audioConfig:
            onAudioConfig?(payload)
        case .audioFrame:
            audioFrameCount += 1
            onAudioFrame?(pkt)
        case .heartbeat:
            break // keep-alive, no action needed
        case .end:
            onDisconnected?()
        default:
            break
        }
    }

    /// Parse Annex-B bytestream and extract SPS and PPS NAL units.
    private func parseAnnexBSPSPPS(_ data: Data) -> (sps: Data?, pps: Data?) {
        var sps: Data?
        var pps: Data?
        let nalUnits = splitAnnexB(data)
        for nal in nalUnits {
            guard !nal.isEmpty else { continue }
            let nalType = nal[0] & 0x1F
            if nalType == 7 { sps = nal }
            else if nalType == 8 { pps = nal }
        }
        return (sps, pps)
    }

    /// Split Annex-B stream on 00 00 00 01 start codes.
    static func splitAnnexB(_ data: Data) -> [Data] {
        var result: [Data] = []
        var i = 0
        var start = -1
        let bytes = [UInt8](data)
        let count = bytes.count
        while i < count {
            if i + 3 < count && bytes[i] == 0 && bytes[i+1] == 0 &&
               bytes[i+2] == 0 && bytes[i+3] == 1 {
                if start >= 0 {
                    result.append(Data(bytes[start ..< i]))
                }
                start = i + 4
                i += 4
            } else if i + 2 < count && bytes[i] == 0 && bytes[i+1] == 0 && bytes[i+2] == 1 {
                if start >= 0 {
                    result.append(Data(bytes[start ..< i]))
                }
                start = i + 3
                i += 3
            } else {
                i += 1
            }
        }
        if start >= 0 && start < count {
            result.append(Data(bytes[start...]))
        }
        return result
    }
}
