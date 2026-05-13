import Foundation

// MARK: - RLS1 Protocol Constants

enum RLSPacketType: UInt8 {
    case hello       = 1
    case videoConfig = 2
    case videoFrame  = 3
    case heartbeat   = 4
    case end         = 5
    case audioConfig = 6
    case audioFrame  = 7
}

struct RLSPacketFlags: OptionSet {
    let rawValue: UInt16
    static let keyFrame = RLSPacketFlags(rawValue: 1)
}

struct RLSHeader {
    static let magic: UInt32 = 0x524C5331  // "RLS1"
    static let version: UInt8 = 1
    static let size = 24

    let type: RLSPacketType
    let flags: RLSPacketFlags
    let sequence: UInt32
    let timestampUs: UInt64
    let payloadSize: UInt32

    /// Parse 24-byte header from Data at given offset. Returns nil if magic/version invalid.
    static func parse(from data: Data, offset: Int = 0) -> RLSHeader? {
        guard data.count >= offset + size else { return nil }
        let bytes = data[offset...]
        let magic = readUInt32BE(bytes, 0)
        guard magic == RLSHeader.magic else { return nil }
        let ver = bytes[bytes.startIndex + 4]
        guard ver == RLSHeader.version else { return nil }
        guard let type = RLSPacketType(rawValue: bytes[bytes.startIndex + 5]) else { return nil }
        let flags = RLSPacketFlags(rawValue: readUInt16BE(bytes, 6))
        let seq   = readUInt32BE(bytes, 8)
        let ts    = readUInt64BE(bytes, 12)
        let ps    = readUInt32BE(bytes, 20)
        return RLSHeader(type: type, flags: flags, sequence: seq, timestampUs: ts, payloadSize: ps)
    }

    private static func readUInt32BE(_ data: Data.SubSequence, _ relOffset: Int) -> UInt32 {
        let base = data.startIndex + relOffset
        return UInt32(data[base]) << 24
             | UInt32(data[base+1]) << 16
             | UInt32(data[base+2]) << 8
             | UInt32(data[base+3])
    }
    private static func readUInt16BE(_ data: Data.SubSequence, _ relOffset: Int) -> UInt16 {
        let base = data.startIndex + relOffset
        return UInt16(data[base]) << 8 | UInt16(data[base+1])
    }
    private static func readUInt64BE(_ data: Data.SubSequence, _ relOffset: Int) -> UInt64 {
        let base = data.startIndex + relOffset
        var v: UInt64 = 0
        for i in 0..<8 { v = (v << 8) | UInt64(data[base+i]) }
        return v
    }
}

// MARK: - Media packet model passed to publisher

struct MediaPacket {
    let type: RLSPacketType
    let isKeyFrame: Bool
    let timestampUs: UInt64
    let payload: Data
}
