# WatchTube

A small, **keyless, privacy-respecting YouTube client for Apple Watch** (built for
the Ultra, runs on any watchOS 10+ watch). It searches YouTube and plays video +
audio **directly on the watch** — no paired iPhone required, no Google account, no
API key, no analytics.

> **Honest disclaimer — read this first.**
> WatchTube plays YouTube by talking to YouTube's *internal* "InnerTube" API (the
> same endpoints the official apps use). That is **not** an officially sanctioned
> use and it **violates YouTube's Terms of Service**. This project is for
> **personal, sideloaded use only**. Do **not** ship it to the App Store — it will
> be rejected, and it would be a real ToS problem. You are responsible for how you
> use it. Treat it as a personal hack, like a homebrew client.

---

## How it works (the 30-second version)

| Step | What happens |
|------|--------------|
| **Search** | A POST to `youtubei/v1/search` (WEB client). We walk the JSON for `videoRenderer` nodes. |
| **Resolve** | A POST to `youtubei/v1/player` trying **TVHTML5 then iOS** clients; the first that returns an **HLS `.m3u8`** manifest wins. |
| **Play** | `AVPlayer` plays that HLS URL natively — adaptive bitrate, audio + video, perfect for a watch on cellular. |

The approach: the TV/iOS InnerTube clients can hand back a ready-to-play HLS
manifest, so we **never** run YouTube's signature-deciphering JavaScript (which
the watch can't do anyway). **Reality check (2026):** YouTube increasingly gates
stream resolution behind bot-detection. **Search is unaffected and reliable**,
but if a video resolves to `LOGIN_REQUIRED`, paste a **PoToken + visitorData**
into Settings → Advanced. All the fragile stuff lives in **one file**:
`Sources/Networking/InnerTubeClient.swift`.

---

## Prerequisites

1. **Xcode** (free, Mac App Store) — *not currently installed on this Mac*. The
   Command Line Tools alone can't build a watchOS app. Install full Xcode first.
2. **XcodeGen** — generates the `.xcodeproj` from `project.yml`:
   ```sh
   brew install xcodegen
   ```
3. An **Apple ID** for code signing (free works; a paid Apple Developer account
   lets the app live longer than 7 days — see below).

## Build & run

```sh
cd WatchTube
xcodegen generate          # creates WatchTube.xcodeproj
open WatchTube.xcodeproj
```

In Xcode:
1. Select the **WatchTube** target → **Signing & Capabilities** → pick your Team
   (your Apple ID). Xcode will auto-manage the provisioning profile.
2. Choose a run destination:
   - **Simulator:** an *Apple Watch Ultra* simulator — quickest way to see it work.
   - **Your watch:** pick your paired Apple Watch. (First time: trust the
     developer profile on the watch under *Settings → General → VPN & Device
     Management*.)
3. Press **⌘R**.

### Sideload lifetime
- **Free Apple ID:** the app runs for **7 days**, then needs a re-build/re-install.
- **Paid Apple Developer Program ($99/yr):** **1 year** per signing.

---

## App icon
The asset catalog ships with an **empty** `AppIcon` slot (you'll see a build
warning). Drop a single **1024×1024 PNG** into
`App/Assets.xcassets/AppIcon.appiconset/` and reference it in `Contents.json`, or
just drag one onto the AppIcon well in Xcode.

---

## When it breaks (because it will)

YouTube periodically rotates client versions and tightens access. If search or
playback suddenly stops working, **only one file** needs attention:
`Sources/Networking/InnerTubeClient.swift` → the `ClientProfile` constants.

- **Playback fails / "No watch-playable stream":** bump the **iOS** client
  `clientVersion` and matching `userAgent` to a current YouTube iOS app version.
- **A specific video says it can't be played:** it may need bot-attestation. Get a
  `PoToken` + `visitorData` (e.g. via the `yt-dlp` PO-Token guide) and paste them
  into **Settings → Advanced**. They're stored encrypted in the Keychain.
- **Search returns nothing:** bump the **WEB** client `clientVersion`.

There is no key to rotate and nothing tied to your identity — these are public
values shipped inside YouTube's own clients.

---

## Security & privacy posture

- **No accounts, no sign-in, no analytics, no history.** Nothing phones home.
- **App Transport Security stays fully ON.** Every endpoint is HTTPS
  (`youtubei.googleapis.com`, `*.googlevideo.com`); we add **zero** ATS exceptions.
- **Secrets in the Keychain**, not `UserDefaults` — encrypted at rest, passcode
  gated (`AfterFirstUnlock`).
- **No third-party dependencies.** 100% first-party Apple frameworks
  (SwiftUI, AVKit, Security). Smaller attack surface, nothing to audit but our own
  code.

---

## Known limitations

- **Playback resolution is gated by YouTube's anti-bot system (2026).** Search
  always works; stream resolution may return `LOGIN_REQUIRED` depending on your
  network — residential IPs (your watch on Wi-Fi/cellular) fare far better than
  datacenter IPs. When gated, add a PoToken in Settings → Advanced.
- **Brittle by nature** — see "When it breaks" above.
- **Age-restricted / login-required / some music videos** may not resolve without
  a PoToken.
- **Streaming only** — no offline downloads.
- **Heavy use from one IP** can get soft-rate-limited by YouTube.
- Live streams play via their HLS manifest; DVR/seek behavior varies.

---

## Project layout

```
WatchTube/
├── project.yml                     XcodeGen spec (the build definition)
├── App/
│   ├── WatchTubeApp.swift          @main entry point
│   ├── Info.plist                  WKApplication, ATS left ON, audio background mode
│   └── Assets.xcassets/            app icon (placeholder) + accent color
└── Sources/
    ├── Models/                     Video, StreamResolution
    ├── Networking/
    │   ├── InnerTubeClient.swift   ★ the extraction layer — edit this when it breaks
    │   ├── AppClient.swift         builds a client from saved settings
    │   └── APIError.swift
    ├── Security/
    │   └── KeychainStore.swift     encrypted storage for optional secrets
    ├── ViewModels/                 SearchViewModel, PlayerViewModel (@Observable)
    └── Views/                      RootView, SearchView, VideoRowView, PlayerView, SettingsView
```

---

*Personal project. Not affiliated with, endorsed by, or connected to YouTube or
Google. "YouTube" is a trademark of Google LLC.*
