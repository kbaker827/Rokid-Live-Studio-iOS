import SwiftUI

// SF Symbol names used throughout the app
enum AppIcon {
    static let home       = "house.fill"
    static let youtube    = "play.rectangle.fill"
    static let twitch     = "tv.fill"
    static let settings   = "gearshape.fill"
    static let glasses    = "eyeglasses"
    static let wifi       = "wifi"
    static let play       = "play.fill"
    static let stop       = "stop.fill"
    static let eye        = "eye"
    static let eyeSlash   = "eye.slash"
    static let copy       = "doc.on.doc"
    static let chevron    = "chevron.right"
    static let info       = "info.circle"
    static let link       = "link"
    static let check      = "checkmark.circle.fill"
    static let xmark      = "xmark.circle.fill"
    static let refresh    = "arrow.clockwise"
    static let broadcast  = "antenna.radiowaves.left.and.right"
    static let chat       = "bubble.left.and.bubble.right"
    static let lock       = "lock.fill"
    static let unlock     = "lock.open.fill"
    static let video      = "video.fill"
    static let mic        = "mic.fill"
    static let package_   = "shippingbox.fill"
}

// MARK: - Color constants matching design spec
extension Color {
    static let rBackground    = Color(hex: "#0B0E0D")
    static let rBackground2   = Color(hex: "#040605")
    static let rCard          = Color(hex: "#111413")
    static let rCard2         = Color(hex: "#151918")
    static let rBorder        = Color(hex: "#242A28")
    static let rGreen         = Color(hex: "#5CF018")
    static let rText          = Color(hex: "#F3F4F6")
    static let rMuted         = Color(hex: "#9CA3AF")
    static let rRed           = Color(hex: "#FF1F1F")
    static let rPurple        = Color(hex: "#7C35FF")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
