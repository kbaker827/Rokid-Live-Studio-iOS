import Foundation
import Network

// MARK: - RTMP Publisher
// Full RTMP client implementation using Network.framework.
// Supports: handshake, connect, createStream, publish,
// @setDataFrame, H264/AAC FLV tags, chunk splitting at 128 bytes.

class RtmpPublisher {

    enum State {
        case idle, connecting, handshaking, connected, publishing, error(String)
    }

    var onStateChange: ((State) -> Void)?
    var onBytesPerSec: ((Int) -> Void)?

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "rokid.rtmp", qos: .userInteractive)
    private var state: State = .idle {
        didSet { onStateChange?(state) }
    }

    // Handshake buffers
    private var receiveBuffer = Data()
    private var handshakePhase = 0
    private var c1Data = Data(count: 1536)

    // RTMP state
    private var chunkStreamId: UInt32 = 4
    private var streamId: UInt32 = 0
    private var nextTransactionId: Double = 1
    private var chunkSize: Int = 128
    private var serverBandwidth: UInt32 = 2_500_000

    // Video/Audio config
    private var videoSPS: Data?
    private var videoPPS: Data?
    private var aacConfig: Data?
    private var videoConfigSent = false
    private var audioConfigSent = false

    private var startTimestamp: UInt64 = 0
    private var bytesThisSecond = 0
    private var statsTimer: DispatchSourceTimer?

    // MARK: - Public API

    func connect(url: String) {
        guard let (host, port, app, key) = parseRTMPUrl(url) else {
            state = .error("Invalid RTMP URL: \(url)"); return
        }
        rtmpApp  = app
        streamKey = key
        let endpoint = NWEndpoint.hostPort(host: .init(host), port: .init(rawValue: UInt16(port))!)
        connection = NWConnection(to: endpoint, using: .tcp)
        connection?.stateUpdateHandler = { [weak self] s in
            self?.handleConnectionState(s)
        }
        connection?.start(queue: queue)
        state = .connecting

        let src = DispatchSource.makeTimerSource(queue: queue)
        src.schedule(deadline: .now() + 1, repeating: 1)
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let bps = self.bytesThisSecond
            self.bytesThisSecond = 0
            DispatchQueue.main.async { self.onBytesPerSec?(bps) }
        }
        src.resume()
        statsTimer = src
    }

    func sendVideoConfig(sps: Data, pps: Data) {
        videoSPS = sps
        videoPPS = pps
        videoConfigSent = false
        if case .publishing = state { flushVideoConfig() }
    }

    func sendAudioConfig(_ config: Data) {
        aacConfig = config
        audioConfigSent = false
        if case .publishing = state { flushAudioConfig() }
    }

    func sendVideoFrame(_ packet: MediaPacket) {
        guard case .publishing = state else { return }
        if !videoConfigSent { flushVideoConfig() }
        let ts = relativeTimestampMs(packet.timestampUs)
        // Annex-B → AVCC NALUs
        let nalUnits = MediaIngressServer.splitAnnexB(packet.payload)
        var avcc = Data()
        for nal in nalUnits where !nal.isEmpty {
            var len = UInt32(nal.count).bigEndian
            avcc.append(contentsOf: withUnsafeBytes(of: &len) { Array($0) })
            avcc.append(nal)
        }
        let flvPayload = buildAVCNALUs(avcc: avcc, isKeyFrame: packet.isKeyFrame)
        sendFLVVideoTag(payload: flvPayload, timestamp: ts)
    }

    func sendAudioFrame(_ packet: MediaPacket) {
        guard case .publishing = state else { return }
        if !audioConfigSent { flushAudioConfig() }
        let ts = relativeTimestampMs(packet.timestampUs)
        let flvPayload = buildAACRaw(packet.payload)
        sendFLVAudioTag(payload: flvPayload, timestamp: ts)
    }

    func disconnect() {
        statsTimer?.cancel(); statsTimer = nil
        connection?.cancel(); connection = nil
        state = .idle
        receiveBuffer = Data()
        handshakePhase = 0
        videoConfigSent = false; audioConfigSent = false
        startTimestamp = 0
    }

    // MARK: - Private state

    private var rtmpApp  = "live2"
    private var streamKey = ""
    private var tcUrl    = ""

    // MARK: - Connection handling

    private func handleConnectionState(_ s: NWConnection.State) {
        switch s {
        case .ready:
            state = .handshaking
            startHandshake()
        case .failed(let err):
            state = .error("Connection failed: \(err)")
        case .cancelled:
            state = .idle
        default: break
        }
    }

    // MARK: - RTMP Handshake

    private func startHandshake() {
        // C0: version byte
        var c0 = Data([0x03])
        // C1: time (4 bytes) + zeros (4 bytes) + random (1528 bytes)
        var c1 = Data(count: 1536)
        c1.withUnsafeMutableBytes { ptr in
            let p = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)
            // timestamp = 0
            p[0] = 0; p[1] = 0; p[2] = 0; p[3] = 0
            // zeros
            p[4] = 0; p[5] = 0; p[6] = 0; p[7] = 0
            for i in 8..<1536 { p[i] = UInt8.random(in: 0...255) }
        }
        c1Data = c1
        c0.append(c1)
        sendRaw(c0)
        handshakePhase = 1
        receiveHandshake()
    }

    private func receiveHandshake() {
        receive(exactly: 1 + 1536) { [weak self] data in  // S0 + S1
            guard let self, let data else { return }
            self.receiveBuffer.append(data)
            // S0 = data[0], S1 = data[1..<1537]
            let s1 = data[1..<1537]
            // Send C2 = copy of S1
            self.sendRaw(Data(s1))
            // Receive S2
            self.receive(exactly: 1536) { [weak self] s2Data in
                guard let self, let _ = s2Data else { return }
                // Handshake complete
                self.handshakePhase = 2
                self.sendConnectCommand()
                self.receiveRTMPMessages()
            }
        }
    }

    // MARK: - RTMP Commands

    private func sendConnectCommand() {
        let transId = nextTransactionId
        nextTransactionId += 1

        let appValue = rtmpApp
        tcUrl = "rtmp://\(connectionHost())/\(appValue)"

        var amf = Data()
        amf.append(amfString("connect"))
        amf.append(amfNumber(transId))
        // Command object
        amf.append(0x03)  // AMF Object marker
        amf.append(amfKeyValue("app",     stringValue: appValue))
        amf.append(amfKeyValue("flashVer", stringValue: "LNX 9,0,124,2"))
        amf.append(amfKeyValue("tcUrl",   stringValue: tcUrl))
        amf.append(amfKeyValue("fpad",    boolValue: false))
        amf.append(amfKeyValue("capabilities", numberValue: 15))
        amf.append(amfKeyValue("audioCodecs",  numberValue: 4071))
        amf.append(amfKeyValue("videoCodecs",  numberValue: 252))
        amf.append(amfKeyValue("videoFunction", numberValue: 1))
        amf.append(objectEnd())

        sendChunk(csid: 3, type: 0x14, streamId: 0, timestamp: 0, payload: amf)
    }

    private func sendSetChunkSize(_ size: Int) {
        var payload = Data(count: 4)
        payload.withUnsafeMutableBytes { ptr in
            let p = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let v = UInt32(size)
            p[0] = UInt8((v >> 24) & 0xFF)
            p[1] = UInt8((v >> 16) & 0xFF)
            p[2] = UInt8((v >> 8)  & 0xFF)
            p[3] = UInt8( v        & 0xFF)
        }
        sendChunk(csid: 2, type: 0x01, streamId: 0, timestamp: 0, payload: payload)
    }

    private func sendWindowAcknowledgementSize(_ size: UInt32) {
        var payload = Data(count: 4)
        payload.withUnsafeMutableBytes { ptr in
            let p = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)
            p[0] = UInt8((size >> 24) & 0xFF)
            p[1] = UInt8((size >> 16) & 0xFF)
            p[2] = UInt8((size >> 8)  & 0xFF)
            p[3] = UInt8( size        & 0xFF)
        }
        sendChunk(csid: 2, type: 0x05, streamId: 0, timestamp: 0, payload: payload)
    }

    private func sendCreateStream() {
        let transId = nextTransactionId
        nextTransactionId += 1
        var amf = Data()
        amf.append(amfString("createStream"))
        amf.append(amfNumber(transId))
        amf.append(0x05) // null
        sendChunk(csid: 3, type: 0x14, streamId: 0, timestamp: 0, payload: amf)
    }

    private func sendPublish() {
        var amf = Data()
        amf.append(amfString("publish"))
        amf.append(amfNumber(0))
        amf.append(0x05) // null
        amf.append(amfString(streamKey))
        amf.append(amfString("live"))
        sendChunk(csid: 8, type: 0x14, streamId: streamId, timestamp: 0, payload: amf)
    }

    private func sendSetDataFrame() {
        var amf = Data()
        amf.append(amfString("@setDataFrame"))
        amf.append(amfString("onMetaData"))
        amf.append(0x08) // ECMA array
        // array length = 0 (we'll fill dynamically)
        amf.append(contentsOf: [0, 0, 0, 5])
        amf.append(amfKeyValue("duration",    numberValue: 0))
        amf.append(amfKeyValue("width",       numberValue: 1280))
        amf.append(amfKeyValue("height",      numberValue: 720))
        amf.append(amfKeyValue("videodatarate", numberValue: 2500))
        amf.append(amfKeyValue("framerate",   numberValue: 30))
        amf.append(amfKeyValue("videocodecid", numberValue: 7))
        amf.append(objectEnd())
        sendChunk(csid: 4, type: 0x12, streamId: streamId, timestamp: 0, payload: amf)
    }

    // MARK: - FLV Video/Audio tags

    private func flushVideoConfig() {
        guard let sps = videoSPS, let pps = videoPPS else { return }
        let avcSeq = buildAVCSequenceHeader(sps: sps, pps: pps)
        sendFLVVideoTag(payload: avcSeq, timestamp: 0)
        videoConfigSent = true
    }

    private func flushAudioConfig() {
        guard let cfg = aacConfig else { return }
        let aacSeq = buildAACSequenceHeader(cfg)
        sendFLVAudioTag(payload: aacSeq, timestamp: 0)
        audioConfigSent = true
    }

    private func buildAVCSequenceHeader(sps: Data, pps: Data) -> Data {
        var d = Data()
        d.append(0x17) // key frame | AVC
        d.append(0x00) // AVC sequence header
        d.append(contentsOf: [0,0,0]) // composition time
        // AVCDecoderConfigurationRecord
        d.append(0x01) // configurationVersion
        d.append(sps[1]); d.append(sps[2]); d.append(sps[3]) // profile/compat/level
        d.append(0xFF) // lengthSizeMinusOne = 3
        d.append(0xE1) // numSPS = 1
        let spsLen = UInt16(sps.count).bigEndian
        d.append(contentsOf: withUnsafeBytes(of: spsLen) { Array($0) })
        d.append(sps)
        d.append(0x01) // numPPS = 1
        let ppsLen = UInt16(pps.count).bigEndian
        d.append(contentsOf: withUnsafeBytes(of: ppsLen) { Array($0) })
        d.append(pps)
        return d
    }

    private func buildAVCNALUs(avcc: Data, isKeyFrame: Bool) -> Data {
        var d = Data()
        d.append(isKeyFrame ? 0x17 : 0x27) // frame type | AVC
        d.append(0x01) // AVC NALU
        d.append(contentsOf: [0,0,0]) // composition time offset
        d.append(avcc)
        return d
    }

    private func buildAACSequenceHeader(_ config: Data) -> Data {
        var d = Data()
        d.append(0xAF) // SoundFormat=AAC, SoundRate=44kHz, SoundSize=16bit, Stereo
        d.append(0x00) // AAC sequence header
        d.append(config)
        return d
    }

    private func buildAACRaw(_ frame: Data) -> Data {
        var d = Data()
        d.append(0xAF)
        d.append(0x01) // AAC raw
        d.append(frame)
        return d
    }

    private func sendFLVVideoTag(payload: Data, timestamp: UInt32) {
        sendChunk(csid: 6, type: 0x09, streamId: streamId, timestamp: timestamp, payload: payload)
    }

    private func sendFLVAudioTag(payload: Data, timestamp: UInt32) {
        sendChunk(csid: 4, type: 0x08, streamId: streamId, timestamp: timestamp, payload: payload)
    }

    // MARK: - Receiving server messages

    private func receiveRTMPMessages() {
        receiveMsgHeader()
    }

    private func receiveMsgHeader() {
        receive(exactly: 1) { [weak self] data in
            guard let self, let data else { return }
            let firstByte = data[0]
            let fmt = (firstByte >> 6) & 0x03
            let csid = Int(firstByte & 0x3F)
            self.receiveFullChunkHeader(fmt: fmt, csid: csid)
        }
    }

    private func receiveFullChunkHeader(fmt: UInt8, csid: Int) {
        var headerSize = 0
        switch fmt {
        case 0: headerSize = 11
        case 1: headerSize = 7
        case 2: headerSize = 3
        case 3: headerSize = 0
        default: break
        }

        let readSize = headerSize + (csid == 0 ? 1 : csid == 1 ? 2 : 0)
        if readSize == 0 {
            // Type 3 — reuse last header. Skip message processing for now.
            receiveMsgHeader()
            return
        }

        receive(exactly: readSize) { [weak self] data in
            guard let self, let data else { return }
            var msgTypeId: UInt8 = 0
            var msgLength: Int = 0
            var timestamp: UInt32 = 0
            var msgStreamId: UInt32 = 0
            let bytes = [UInt8](data)

            if fmt == 0 {
                timestamp  = (UInt32(bytes[0]) << 16) | (UInt32(bytes[1]) << 8) | UInt32(bytes[2])
                msgLength  = (Int(bytes[3]) << 16) | (Int(bytes[4]) << 8) | Int(bytes[5])
                msgTypeId  = bytes[6]
                msgStreamId = UInt32(bytes[7]) | (UInt32(bytes[8]) << 8) |
                              (UInt32(bytes[9]) << 16) | (UInt32(bytes[10]) << 24)
            } else if fmt == 1 {
                timestamp  = (UInt32(bytes[0]) << 16) | (UInt32(bytes[1]) << 8) | UInt32(bytes[2])
                msgLength  = (Int(bytes[3]) << 16) | (Int(bytes[4]) << 8) | Int(bytes[5])
                msgTypeId  = bytes[6]
            }

            if msgLength > 0 {
                self.receive(exactly: min(msgLength, self.chunkSize)) { [weak self] payload in
                    guard let self, let payload else { return }
                    self.handleServerMessage(typeId: msgTypeId, payload: payload,
                                             streamId: msgStreamId, timestamp: timestamp)
                    self.receiveMsgHeader()
                }
            } else {
                self.receiveMsgHeader()
            }
        }
    }

    private func handleServerMessage(typeId: UInt8, payload: Data, streamId: UInt32, timestamp: UInt32) {
        switch typeId {
        case 0x01: // Set Chunk Size
            if payload.count >= 4 {
                let bytes = [UInt8](payload)
                chunkSize = (Int(bytes[0]) << 24) | (Int(bytes[1]) << 16) | (Int(bytes[2]) << 8) | Int(bytes[3])
                chunkSize = min(max(chunkSize, 128), 65536)
            }
        case 0x05: // Window Acknowledgement
            break
        case 0x06: // Set Peer Bandwidth
            if payload.count >= 4 {
                let bytes = [UInt8](payload)
                serverBandwidth = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) |
                                  (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
            }
        case 0x14: // AMF0 command
            handleAMFCommand(payload)
        case 0x04: // User Control
            break
        default:
            break
        }
    }

    private func handleAMFCommand(_ data: Data) {
        guard let (name, pos) = amfReadString(data, offset: 0) else { return }
        guard let (transId, _) = amfReadNumber(data, offset: pos) else { return }
        _ = transId

        switch name {
        case "_result":
            if handshakePhase == 2 {
                handshakePhase = 3
                sendSetChunkSize(4096)
                chunkSize = 4096
                sendWindowAcknowledgementSize(2_500_000)
                sendCreateStream()
            } else if handshakePhase == 3 {
                handshakePhase = 4
                // parse stream ID from result
                // skip null (0x05) then read number
                var off = pos + 8 // skip transId number
                if off < data.count && data[off] == 0x05 { off += 1 }
                if let (sid, _) = amfReadNumber(data, offset: off) {
                    streamId = UInt32(sid)
                }
                sendPublish()
            }
        case "onStatus":
            let bytes = [UInt8](data)
            // Look for "code" key with "NetStream.Publish.Start"
            if let range = data.range(of: "NetStream.Publish.Start".data(using: .utf8)!) {
                _ = range
                startTimestamp = 0
                sendSetDataFrame()
                flushVideoConfig()
                flushAudioConfig()
                state = .publishing
            } else if let range = data.range(of: "error".data(using: .utf8)!) {
                _ = range
                state = .error("Server rejected publish: check stream key")
            }
            _ = bytes
        default:
            break
        }
    }

    // MARK: - Chunk sending

    private func sendChunk(csid: UInt8, type: UInt8, streamId: UInt32, timestamp: UInt32, payload: Data) {
        var data = Data()
        // Basic header: fmt=0, csid
        data.append(csid & 0x3F)
        // Timestamp (3 bytes)
        data.append(UInt8((timestamp >> 16) & 0xFF))
        data.append(UInt8((timestamp >> 8)  & 0xFF))
        data.append(UInt8( timestamp        & 0xFF))
        // Message length (3 bytes)
        let len = payload.count
        data.append(UInt8((len >> 16) & 0xFF))
        data.append(UInt8((len >> 8)  & 0xFF))
        data.append(UInt8( len        & 0xFF))
        // Message type
        data.append(type)
        // Stream ID (little-endian)
        data.append(UInt8( streamId        & 0xFF))
        data.append(UInt8((streamId >> 8)  & 0xFF))
        data.append(UInt8((streamId >> 16) & 0xFF))
        data.append(UInt8((streamId >> 24) & 0xFF))

        // Payload in chunks of chunkSize
        var offset = 0
        var first = true
        while offset < payload.count {
            if !first {
                data.append((3 << 6) | (csid & 0x3F)) // type 3 continuation
            }
            let end = min(offset + chunkSize, payload.count)
            data.append(payload[offset ..< end])
            offset = end
            first = false
        }
        sendRaw(data)
    }

    private func sendRaw(_ data: Data) {
        bytesThisSecond += data.count
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }

    // MARK: - Receive helper

    private func receive(exactly count: Int, completion: @escaping (Data?) -> Void) {
        connection?.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
            if let error = error {
                DispatchQueue.main.async { [weak self] in
                    self?.state = .error("Receive error: \(error)")
                }
                completion(nil)
                return
            }
            completion(data)
        }
    }

    // MARK: - Helpers

    private func connectionHost() -> String {
        // Extract from tcUrl
        if let url = URL(string: "rtmp://placeholder/"), let h = url.host { return h }
        return "a.rtmp.youtube.com"
    }

    private func relativeTimestampMs(_ tsUs: UInt64) -> UInt32 {
        if startTimestamp == 0 { startTimestamp = tsUs }
        let delta = tsUs >= startTimestamp ? tsUs - startTimestamp : 0
        return UInt32(delta / 1000)
    }

    private func parseRTMPUrl(_ url: String) -> (host: String, port: Int, app: String, key: String)? {
        // rtmp://host[:port]/app/key
        var s = url
        guard s.hasPrefix("rtmp://") else { return nil }
        s = String(s.dropFirst(7))
        let parts = s.components(separatedBy: "/")
        guard parts.count >= 3 else { return nil }
        let hostPort = parts[0].components(separatedBy: ":")
        let host = hostPort[0]
        let port = hostPort.count > 1 ? (Int(hostPort[1]) ?? 1935) : 1935
        let app  = parts[1]
        let key  = parts[2...].joined(separator: "/")
        return (host, port, app, key)
    }

    // MARK: - AMF0 Encoding helpers

    private func amfString(_ s: String) -> Data {
        var d = Data([0x02])
        let bytes = s.utf8
        let len = UInt16(bytes.count).bigEndian
        d.append(contentsOf: withUnsafeBytes(of: len) { Array($0) })
        d.append(contentsOf: bytes)
        return d
    }

    private func amfNumber(_ n: Double) -> Data {
        var d = Data([0x00])
        var be = n.bitPattern.bigEndian
        d.append(contentsOf: withUnsafeBytes(of: &be) { Array($0) })
        return d
    }

    private func amfBool(_ b: Bool) -> Data {
        Data([0x01, b ? 0x01 : 0x00])
    }

    private func objectEnd() -> Data { Data([0x00, 0x00, 0x09]) }

    private func amfKeyValue(_ key: String, stringValue v: String) -> Data {
        var d = amfPropertyKey(key)
        d.append(amfString(v))
        return d
    }

    private func amfKeyValue(_ key: String, numberValue v: Double) -> Data {
        var d = amfPropertyKey(key)
        d.append(amfNumber(v))
        return d
    }

    private func amfKeyValue(_ key: String, boolValue v: Bool) -> Data {
        var d = amfPropertyKey(key)
        d.append(amfBool(v))
        return d
    }

    private func amfPropertyKey(_ key: String) -> Data {
        let bytes = key.utf8
        let len = UInt16(bytes.count).bigEndian
        var d = Data()
        d.append(contentsOf: withUnsafeBytes(of: len) { Array($0) })
        d.append(contentsOf: bytes)
        return d
    }

    // MARK: - AMF0 Decoding helpers

    private func amfReadString(_ data: Data, offset: Int) -> (String, Int)? {
        guard offset < data.count else { return nil }
        let bytes = [UInt8](data)
        if bytes[offset] != 0x02 { return nil }
        guard offset + 3 <= data.count else { return nil }
        let len = Int(bytes[offset+1]) << 8 | Int(bytes[offset+2])
        guard offset + 3 + len <= data.count else { return nil }
        let str = String(bytes: bytes[(offset+3)..<(offset+3+len)], encoding: .utf8) ?? ""
        return (str, offset + 3 + len)
    }

    private func amfReadNumber(_ data: Data, offset: Int) -> (Double, Int)? {
        let bytes = [UInt8](data)
        guard offset < data.count, bytes[offset] == 0x00,
              offset + 9 <= data.count else { return nil }
        var bits: UInt64 = 0
        for i in 0..<8 { bits = (bits << 8) | UInt64(bytes[offset+1+i]) }
        return (Double(bitPattern: bits), offset + 9)
    }
}
