import SwiftUI
import AVFoundation

/// UIViewRepresentable wrapper around AVSampleBufferDisplayLayer for live H264 preview.
struct PreviewView: UIViewRepresentable {
    let decoder: VideoDecoder

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        decoder.displayLayer = view.displayLayer
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        decoder.displayLayer = uiView.displayLayer
    }
}

class PreviewUIView: UIView {
    let displayLayer = AVSampleBufferDisplayLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.black.cgColor
        layer.addSublayer(displayLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        displayLayer.frame = bounds
    }
}

// MARK: - Preview Card (SwiftUI wrapper)

struct PreviewCard: View {
    @EnvironmentObject var appState: AppState
    let decoder: VideoDecoder

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: AppIcon.video)
                    .foregroundColor(.rGreen)
                Text("Live Preview")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.rText)
                Spacer()
                Button(action: { appState.showPreview.toggle() }) {
                    Image(systemName: appState.showPreview ? AppIcon.eyeSlash : AppIcon.eye)
                        .foregroundColor(.rMuted)
                }
            }
            .padding(12)

            if appState.showPreview {
                PreviewView(decoder: decoder)
                    .frame(height: 220)
                    .background(Color.black)
                    .cornerRadius(8)
                    .padding([.horizontal, .bottom], 10)

                HStack(spacing: 16) {
                    Label("\(appState.ingressVideoFrameCount) frames", systemImage: AppIcon.video)
                    Label("\(appState.ingressAudioFrameCount) audio pkts", systemImage: AppIcon.mic)
                    Label(formatBps(appState.ingressBytesPerSec), systemImage: AppIcon.broadcast)
                }
                .font(.system(size: 11))
                .foregroundColor(.rMuted)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.rCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rBorder, lineWidth: 1))
    }

    private func formatBps(_ n: Int) -> String {
        if n > 1_000_000 { return String(format: "%.1f MB/s", Double(n) / 1_000_000) }
        if n > 1_000 { return String(format: "%.0f KB/s", Double(n) / 1_000) }
        return "\(n) B/s"
    }
}
