import SwiftUI

// MARK: - Brand Header

struct BrandHeader: View {
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text("Rokid")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.rGreen)
            Text("Live Studio")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(.rText)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Action Card Row

struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var accentColor: Color = .rGreen
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundColor(accentColor)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.rText)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.rMuted)
                        .lineLimit(2)
                }
                Spacer()
                if action != nil {
                    Image(systemName: AppIcon.chevron)
                        .foregroundColor(.rMuted)
                        .font(.system(size: 12))
                }
            }
            .padding(14)
            .background(Color.rCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    var color: Color = .rGreen
    var isLoading = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color == .rGreen ? .black : .white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color)
            .cornerRadius(12)
        }
    }
}

// MARK: - Section Card

struct SectionCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.rMuted)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
            }
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .background(Color.rCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rBorder, lineWidth: 1))
        }
    }
}

// MARK: - Labeled Text Field

struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    @State private var showSecret = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.rMuted)
            HStack {
                if isSecure && !showSecret {
                    SecureField(placeholder, text: $text)
                        .foregroundColor(.rText)
                        .keyboardType(keyboard)
                } else {
                    TextField(placeholder, text: $text)
                        .foregroundColor(.rText)
                        .keyboardType(keyboard)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                if isSecure {
                    Button {
                        showSecret.toggle()
                    } label: {
                        Image(systemName: showSecret ? AppIcon.eyeSlash : AppIcon.eye)
                            .foregroundColor(.rMuted)
                    }
                }
            }
            .padding(10)
            .background(Color.rCard2)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.rBorder, lineWidth: 1))
        }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: AppIcon.xmark)
                .foregroundColor(.rRed)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.rText)
                .lineLimit(3)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.rMuted)
                    .font(.system(size: 12))
            }
        }
        .padding(12)
        .background(Color.rRed.opacity(0.15))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rRed.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Segmented Control

struct SegmentedPicker<T: Hashable & CustomStringConvertible>: View {
    let options: [T]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button(action: { selection = option }) {
                    Text(option.description)
                        .font(.system(size: 14, weight: selection == option ? .semibold : .regular))
                        .foregroundColor(selection == option ? .black : .rMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection == option ? Color.rGreen : Color.clear)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.rCard2)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rBorder, lineWidth: 1))
    }
}

extension YouTubeMode: CustomStringConvertible {
    public var description: String { rawValue }
}

// MARK: - Status Row

struct StatusRow: View {
    let label: String
    let value: String
    var valueColor: Color = .rText

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.rMuted)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(Color.rGreen.opacity(0.3))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(message.author.prefix(1)).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.rGreen)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(message.author)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.rGreen)
                Text(message.text)
                    .font(.system(size: 13))
                    .foregroundColor(.rText)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - RTMP Diagnostics Card

struct RTMPDiagnosticsCard: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        SectionCard(title: "RTMP Diagnostics") {
            StatusRow(label: "Upload", value: formatBytes(appState.rtmpBytesPerSec) + "/s")
            Divider().background(Color.rBorder)
            StatusRow(label: "Buffer", value: "\(appState.rtmpBufferSize) KB")
        }
    }

    private func formatBytes(_ n: Int) -> String {
        if n > 1_000_000 { return String(format: "%.1f MB", Double(n) / 1_000_000) }
        if n > 1_000 { return String(format: "%.1f KB", Double(n) / 1_000) }
        return "\(n) B"
    }
}
