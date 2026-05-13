# Rokid Live Studio — iOS

> Stream your Rokid AR glasses camera and microphone to YouTube and Twitch directly from your iPhone.

An iOS port of [Rokid Live Studio](https://github.com/Anezium/Rokid-Live-Studio) (Android) by [@Anezium](https://github.com/Anezium). Built with SwiftUI, VideoToolbox, and a hand-rolled RTMP client — no third-party dependencies required.

---

## Features

- **YouTube & Twitch streaming** via RTMP — stream key or full OAuth account mode
- **Live preview** of the Rokid glasses camera feed on your iPhone screen
- **OAuth device flow** for both platforms — link your account without a browser on the phone
- **YouTube Live broadcast management** — create, start, and end broadcasts with title, category, privacy, and description set from the app
- **Twitch channel management** — update title and category before going live
- **Chat overlay** — pull live chat from YouTube or Twitch and display it on the glasses helper
- **Bitrate & resolution control** — pick from Rokid-optimized presets, override the stream bitrate independently
- **Keychain storage** — stream keys and OAuth tokens stored securely on-device
- **Dark UI** matching the original Android design — green-on-black studio aesthetic

---

## Requirements

| Requirement | Version |
|---|---|
| Xcode | 15.0+ |
| iOS deployment target | 16.0+ |
| Device | Physical iPhone or iPad (Simulator not supported — VideoToolbox + TCP server) |
| Rokid glasses | Any model running the companion [glasses helper APK](https://github.com/Anezium/Rokid-Live-Studio) |

---

## Quick Start

### 1. Open in Xcode

```bash
open RokidLiveStudio.xcodeproj
```

### 2. Sign the app

In Xcode → **Signing & Capabilities** → set your **Team**.  
Bundle ID: `com.anezium.rokidlive.phone.ios` (change if needed).

### 3. Build and run on device

Connect your iPhone, select it as the run destination, and hit **Run**.

---

## Connecting Rokid Glasses

> **Note:** The Android version uses the Rokid CXR SDK (`com.rokid.cxr:client-l`) to automatically discover and control the glasses. This SDK is Android-only — there is no iOS equivalent. On iOS, connection is configured manually.

1. Launch the app and open the **Home** tab.
2. Note the **Phone IP** displayed (e.g. `192.168.1.42`).
3. Tap **Start Receiving** — this opens TCP port **39440** on your iPhone.
4. In the Rokid **glasses helper** app, point its stream destination to `<phone-ip>:39440`.
5. The connection status turns green once the glasses connect and begin sending video.

The phone and glasses must be on the same Wi-Fi network (or a hotspot created by either device).

---

## Streaming

### YouTube

| Mode | How it works |
|---|---|
| **Stream Key** | Paste your key from YouTube Studio → Go Live → Stream Setup. No OAuth needed. |
| **OAuth account** | Creates a full YouTube Live broadcast (title, category, privacy, description) automatically. Requires a Google Cloud OAuth 2.0 client with the YouTube scope. |

**OAuth setup (one-time):**
1. Create a "TV & Limited Input Devices" OAuth 2.0 client in [Google Cloud Console](https://console.cloud.google.com/).
2. Enter the **Client ID** and **Client Secret** in the app under YouTube → Advanced OAuth Setup.
3. Tap **Link with Device Code**, visit the URL shown, and enter the code.

### Twitch

| Mode | How it works |
|---|---|
| **OAuth account** | Links your Twitch account, fetches the stream key automatically, and updates title/category before going live. |
| **Stream Key** | Paste your key from Twitch Dashboard → Settings → Stream. |

**OAuth setup (one-time):**
1. Create a Twitch application at [dev.twitch.tv/console/apps](https://dev.twitch.tv/console/apps).
2. Enter the **Client ID** in the app under Twitch → Advanced OAuth Setup.
3. Tap **Link Twitch Account** and follow the verification URL.

---

## Architecture

```
RokidLiveStudio/
├── App/
│   └── RokidLiveStudioApp.swift       Entry point, dark color scheme
├── Models/
│   ├── AppState.swift                 Central ObservableObject (all UI state)
│   ├── VideoPreset.swift              Rokid resolution/bitrate presets
│   ├── ProtocolModels.swift           RLS1 binary packet types
│   ├── YoutubeModels.swift            YouTube API response models
│   └── TwitchModels.swift             Twitch API response models
├── Services/
│   ├── MediaIngressServer.swift       NWListener TCP:39440 — receives H264+AAC
│   ├── VideoDecoder.swift             VTDecompressionSession + AVSampleBufferDisplayLayer
│   ├── RtmpPublisher.swift            Full RTMP client (handshake, FLV tags, chunk splitting)
│   ├── YoutubeApi.swift               YouTube Data API v3
│   ├── YoutubeDeviceAuth.swift        Google OAuth device flow
│   ├── TwitchApi.swift                Twitch Helix API
│   ├── TwitchDeviceAuth.swift         Twitch OAuth device flow
│   ├── TwitchChatClient.swift         Twitch IRC over WebSocket
│   ├── YoutubeChatClient.swift        YouTube Live Chat polling
│   └── SecretStore.swift              Keychain wrapper
└── Views/
    ├── PhoneScreen.swift              Root tab view
    ├── HomeScreen.swift               Connection + preview tab
    ├── YoutubeScreen.swift            YouTube streaming tab
    ├── TwitchScreen.swift             Twitch streaming tab
    ├── SettingsScreen.swift           Info + version tab
    ├── StudioComponents.swift         Shared UI components
    ├── PreviewView.swift              UIViewRepresentable AVSampleBufferDisplayLayer
    └── Icons.swift                    SF Symbol constants + design colors
```

### RLS1 Binary Protocol

The glasses helper communicates over TCP using the **RLS1** binary format (identical to the Android version):

```
Offset  Size  Field
──────  ────  ─────────────────────────────────────
0       4     Magic = 0x524C5331 ("RLS1"), big-endian
4       1     Version = 1
5       1     Packet type (see below)
6       2     Flags  (bit 0 = key frame)
8       4     Sequence number
12      8     Timestamp (microseconds)
20      4     Payload size
24      …     Payload
```

| Type | ID | Payload |
|---|---|---|
| HELLO | 1 | — |
| VIDEO_CONFIG | 2 | H264 SPS + PPS (Annex-B) |
| VIDEO_FRAME | 3 | H264 Annex-B frame |
| HEARTBEAT | 4 | — |
| END | 5 | — |
| AUDIO_CONFIG | 6 | AAC codec config |
| AUDIO_FRAME | 7 | AAC raw frame |

### RTMP Publisher

`RtmpPublisher.swift` implements a full RTMP client with no external dependencies:

- C0/C1/C2 handshake
- AMF0-encoded `connect`, `createStream`, `publish` commands
- `@setDataFrame` metadata
- H264: AVCDecoderConfigurationRecord sequence header → AVC NALU frames
- AAC: AudioSpecificConfig sequence header → raw AAC frames
- 128-byte chunk splitting with proper chunk stream IDs and timestamps

---

## Credits

- Original Android app: [Anezium/Rokid-Live-Studio](https://github.com/Anezium/Rokid-Live-Studio)
- iOS port maintains full protocol and UI parity with the Android version

---

## License

MIT License — see [LICENSE](LICENSE).
