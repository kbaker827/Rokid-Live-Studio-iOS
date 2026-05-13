import Foundation

enum VideoPreset: String, CaseIterable, Identifiable {
    case rokid768x1024    = "ROKID_768_1024"
    case live720p916      = "LIVE_720P_9_16"
    case rokid2K916       = "ROKID_2K_9_16"
    case rokid25K34       = "ROKID_2_5K_3_4"
    case rokid3K916       = "ROKID_3K_9_16"
    case rokid25K43       = "ROKID_2_5K_4_3"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rokid768x1024: return "Rokid 768×1024 (30fps)"
        case .live720p916:   return "720p 9:16 (30fps)"
        case .rokid2K916:    return "2K 9:16 (30fps)"
        case .rokid25K34:    return "2.5K 3:4 (30fps)"
        case .rokid3K916:    return "3K 9:16 (30fps)"
        case .rokid25K43:    return "2.5K 4:3 (30fps)"
        }
    }

    var width: Int {
        switch self {
        case .rokid768x1024: return 1024
        case .live720p916:   return 720
        case .rokid2K916:    return 1080
        case .rokid25K34:    return 2268
        case .rokid3K916:    return 3072
        case .rokid25K43:    return 2582
        }
    }

    var height: Int {
        switch self {
        case .rokid768x1024: return 768
        case .live720p916:   return 1280
        case .rokid2K916:    return 1920
        case .rokid25K34:    return 3024
        case .rokid3K916:    return 1728
        case .rokid25K43:    return 1936
        }
    }

    var fps: Int { 30 }

    var bitrateKbps: Int {
        switch self {
        case .rokid768x1024: return 1600
        case .live720p916:   return 2500
        case .rokid2K916:    return 5000
        case .rokid25K34:    return 9000
        case .rokid3K916:    return 12000
        case .rokid25K43:    return 8000
        }
    }

    /// Rotation applied when displaying (degrees clockwise)
    var displayRotation: Int {
        switch self {
        case .rokid768x1024: return 270
        case .rokid3K916:    return 270
        default:             return 0
        }
    }

    /// YouTube output resolution override (nil = use source)
    var youtubeOutputSize: (Int, Int)? {
        switch self {
        case .rokid25K34: return (1080, 1440)
        case .rokid3K916: return (1080, 1920)
        default:          return nil
        }
    }
}

enum BitrateOverride: String, CaseIterable, Identifiable {
    case auto   = "Auto"
    case k800   = "800 Kbps"
    case k1200  = "1.2 Mbps"
    case k2000  = "2 Mbps"
    case k3000  = "3 Mbps"
    case k4500  = "4.5 Mbps"
    case k6000  = "6 Mbps"
    case k8000  = "8 Mbps"

    var id: String { rawValue }

    var kbps: Int? {
        switch self {
        case .auto:  return nil
        case .k800:  return 800
        case .k1200: return 1200
        case .k2000: return 2000
        case .k3000: return 3000
        case .k4500: return 4500
        case .k6000: return 6000
        case .k8000: return 8000
        }
    }
}
