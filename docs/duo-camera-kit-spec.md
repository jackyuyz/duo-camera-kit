# Duo Camera Kit (ProLens Link + HingeCam): Implementation Spec (iOS)

> **Instructions for the coding agent**
> 1. Read this whole spec before writing any code, including §3 (fold-state matrix), §7 (edge cases), §8 (tests and acceptance criteria) and §11 (assumptions).
> 2. Implement strictly in the milestone order in §10. Finish each milestone's tests before starting the next one, and keep `main` buildable at every step.
> 3. Keep everything local and on-device: no backend, no server, no database beyond local files / SwiftData / UserDefaults, no login, no analytics or ad SDKs, no third-party networking.
> 4. Write unit tests alongside each module (not at the end). UI tests drive the app through the mockable `FoldStateProvider` and launch arguments described in §8.
> 5. Any API marked **UNCONFIRMED** in this spec must be wrapped in a runtime capability check with the fallback described next to it. Never call it unguarded, and never "fix" a compile error by inventing a different API name: stop and leave a `// TODO(verify-api):` note instead.
> 6. Use the hinge only for interactions and effects. Use size classes, `ArrangementView`, and reserved regions for layout (Apple's guidance).
> 7. Do not add a backend, login, cloud sync service, or remote config. If something seems to need one, stop and add it to §11 as an open question.

## 0. Header

| Field | Value |
|---|---|
| Project codename | **Duo Camera Kit** (Notion: merged page "Duo Camera Kit" = Reddit doc #4 **ProLens Link** + #5 **HingeCam**; Reddit doc §4 ranked #4 and suggested the merge) |
| Official App Store name | **Duo Camera Kit: Tele & Tripod** (29 chars) |
| Subtitle | **Old iPhone as zoom + hinge cam** (30 chars) |
| Name check (US App Store, 2026-10-13) | No app named "Duo Camera Kit". Many generic "remote camera"/"dual camera" apps exist (e.g. "DuoShot" camera apps, "Duo Camera"-style names), so expect a crowded keyword space. Fallback: "FoldLens: Tele & Tripod". |
| Recommended repo | `duo-camera-kit-ios` |
| Bundle ID | `com.jackyu.duocamerakit` |
| Platform / min OS | iOS, iPhone only, **min iOS 26.0**. That's lower than the other Duo apps because the **Lens role runs on older iPhone Pros** (13 Pro and later run iOS 26; verify the device list). Duo-specific features are guarded by `#available(iOS 27.1, *)` and `hinge != nil`. |
| Priority | **Medium** |
| Target | ≈4 weeks (two modules) |

**Platform API status (checked 2026-10-13, ET).** Sources: Apple tech talks 111463 / 111464 / 111465 on developer.apple.com/videos (transcript summaries at wwdc.ai), Apple's "Prepare your app for iPhone Duo" page (developer.apple.com/iphone-duo/prepare/), Apple doc content for `UIHingeInteraction` and `onHingeChange` (developer.apple.com pages render with JavaScript, so their text was read through a doc mirror and the tech talks), and the Apple-engineer answers in the Sept 23–24 iPhone Duo Photos & Camera forum Q&A.

| API / fact | Status | Notes |
|---|---|---|
| `View.onHingeChange(isEnabled:_:)` → `(DeviceHingeContext, DeviceHingeContext)`; `context.hinge: DeviceHinge?`; `DeviceHinge.angle: Angle`; `DeviceHinge.status` ∈ `.closed / .partiallyOpen / .fullyOpen` | **Confirmed** | `hinge == nil` means no hinge (any non-Duo device). Exact `@available` version is assumed to be iOS 27.1: guard with `if #available(iOS 27.1, *)`. |
| `UIHingeInteraction(updateHandler:)`, `update.hinge` (`UIHinge`, angle in radians `CGFloat`, status includes extra `.unknown`) | **Confirmed** | `hinge` becomes nil when the interaction leaves a hierarchy that provides hinge updates. |
| Hinge angle range, update rate, precision | **Not documented** ("system policy") | Never map absolute angles to outcomes. Use relative angle from an anchor, plus a calibration step. Smooth between samples. |
| `ArrangementView { } secondary: { }`, `.arrangementViewStyle(.split)`, `.split.axes(.horizontal)`, `.overlay`, `@Environment(\.overlayArrangementZIndex)`; UIKit `UIArrangementViewController` | **Confirmed** (iOS 27.1) | Put it inside a `NavigationStack`, never inside `List` / `ScrollView`. |
| `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`, kinds `.division` (fold) and `.occlusion` (cameras), option `.includeInactive`; `UIView.reservedRegions(kind:options:)` | **Confirmed** | The fold region is active only while the device is partially folded and has zero width when flat. Reported to be empty on the first layout pass, so re-query with `onGeometryChange`. |
| `.sceneAccessory { CameraCaptureAccessory(isEnabled:) { … } .onAvailabilityChange { } }`; UIKit `UISceneAccessory.cameraCapture(sceneConfiguration:userInfo:)` + `registerSceneAccessory(_:)` | **SwiftUI confirmed**; UIKit names are from a third-party write-up (**verify**) | Available only while the app is full screen on the inner display, in the foreground, with an active capture session (an `ARSession` also qualifies). Goes away when the device closes. Whether accessory views receive touches is **UNCONFIRMED**: treat them as display-only. |
| Non-camera scene accessories for third parties (outer display UI without a camera session) | **UNCONFIRMED / not available as far as public docs show** | Don't design around it. |
| `.builtInOuterUltraWideCamera`, `.builtInInnerUltraWideCamera`, Virtual Front Camera (position `.front`), `AVCaptureDeviceDirectionCoordinator(view:deviceTypes:changeHandler:)`, `AVCaptureDeviceDescriptor`, `AVCaptureDevice.dynamicAspectRatio`, `AVCaptureDeviceRotationCoordinator`, `AVCapturePhotoOutput.isCameraSensorOrientationCompensationEnabled` | **Confirmed** (tech talk 111465) | Inner camera: 1080p up to 60 fps. Outer front: up to 4K/120. The inner camera is unavailable while closed. Ask the direction coordinator; don't infer from the hinge. |
| `AVCaptureMultiCamSession` on Duo | **Confirmed in principle** (Apple engineer: up to 3 physical cameras) | Specific combinations: **runtime only** via `AVCaptureMultiCamSession.isMultiCamSupported` and `AVCaptureDevice.DiscoverySession.supportedMultiCamDeviceSets`. |
| New windows on the outer display | **Not allowed** | Use `UIWindowSceneActivation` for new-window UI; it hides itself when unavailable. Handle scene-request errors. |
| A public "which display am I on" API | **Not found** | For layout use size/traits. For cameras use the direction coordinator. For behavior, treat `hinge.status == .closed` as "on outer display" (heuristic, **verify on device**). |
| Background hinge events / lifetime fold count | **Not found** | Count only while the app is in the foreground. |
| Simulator posture control from CLI | **No official command** (`simctl` has no posture/hinge subcommand) | Device Hub UI has Closed / Open / Rotate buttons and an Option-key hinge slider. The third-party `hinge` CLI (github.com/artemnovichkov/hinge) uses a private protocol. Use it for local experiments only, never in CI gates. |

**Camera Kit-specific API notes (from the Sept 23–24 Duo Photos & Camera forum Q&A and the "Prepare your app" page):**
- New device types `.builtInOuterUltraWideCamera` (front camera above the outer display, up to 4K/120) and `.builtInInnerUltraWideCamera` (under the inner display, 1080p/60, **unavailable when closed**) are **confirmed** by Apple engineers. Use `AVCaptureDevice.DiscoverySession` with these types plus the standard rear types; never hard-code a device.
- `AVCaptureDeviceDirectionCoordinator(view:deviceTypes:changeHandler:)` reports which camera faces the user for a given view. It's **confirmed in the Q&A**, but signature details come from forum text; verify in Xcode.
- MultiCam: up to 3 physical cameras; supported combinations are **runtime-only** via `AVCaptureMultiCamSession.isMultiCamSupported` and `supportedMultiCamDeviceSets`.
- There's **no telephoto** on Duo. Rear: wide 48 MP + ultra-wide (per Reddit compromise thread; check `DiscoverySession` at runtime).
- Long-exposure limits: `activeFormat.maxExposureDuration` (typically ≤ 1 s on iPhones). Longer effects come from **frame stacking**, not a single exposure.
- **Apple built-ins to differentiate from:** Duo Preview (shows the viewfinder to the subject on the outer screen), Smart Take (AI auto-capture), Kid Cue (cartoon on the outer screen for kids). Don't re-implement these; link to them in onboarding where useful.

## 1. PRD background

**Positioning:** Two fixes for the Duo's camera compromises in one app. **Lens**: turn your old iPhone Pro into a wireless telephoto camera you monitor and control from the Duo's big screen. **Tripod**: use the hinge as a built-in stand for time-lapse, long exposure, star trails, hands-free group shots, and top-down shots.

**Target users:** Duo early adopters upgrading from an iPhone Pro (they keep the old phone); parents filming school events and sports; hobby photographers (night/long exposure); creators who need a second angle.

**Pain points + evidence:**
- No telephoto on Duo: compromise list https://www.reddit.com/r/iPhoneFold/comments/1w186rb/ (64/152); "I can't live without the zoom lens" https://www.reddit.com/r/iPhoneFold/comments/1wywcc6/ ; a user plans to keep a 16 Pro as an "ipod/point and shoot camera" for concerts and sports https://www.reddit.com/r/iPhoneFold/comments/1w7y5h6/ ; "considering keeping both and using the handoff feature" (comment p7yjpld in that thread); the old Pro has ProRAW where Duo doesn't (https://www.reddit.com/r/iPhoneFold/comments/1wewlgp/).
- Hinge-as-tripod is a long-standing foldable habit: "Use it as a camera holder. Open it halfway on a shelf", lap filming at kids' performances, and long exposure, all in https://www.reddit.com/r/GalaxyFold/comments/1vdgr8k/ ; "Recording video while putting the phone down, or just taking timed pictures makes group photos way easier" https://www.reddit.com/r/GalaxyFold/comments/1v66t3o/comment/ozq6izd/ ; Duo owners planning tabletop family videos https://www.reddit.com/r/iPhoneFold/comments/1x0mmtn/comment/penbahi/ (post 294/369).

**Selling points:** (1) 3×–5× optical zoom from your old Pro, live on the Duo's 7.6" screen with < 200 ms preview latency (target); (2) full-resolution originals (incl. ProRAW/ProRes where the old phone supports them) recorded on the Lens phone and transferred to the Duo afterwards, peer-to-peer; (3) two-angle sync record (Duo wide + Pro tele); (4) **Tripod modes** that use the hinge: level and stability lock, time-lapse, stacked long exposure, star trails, palm-trigger group shot, top-down; (5) no account, no cloud, no internet needed (works in a stadium with no signal over peer-to-peer Wi-Fi).

**Pricing (StoreKit 2):** Free: Lens mode with live preview and remote shutter (photos up to 12 MP, video up to 1080p30); Tripod level + time-lapse (up to 10 min). **Camera Kit Pro, one-time $9.99** (launch $7.99): Lens full-res/ProRAW/4K, sync two-angle recording, auto-transfer, all Tripod modes (long exposure, star trails, palm trigger, unlimited time-lapse). **One purchase unlocks both devices** if they share an Apple Account (StoreKit entitlement on each device; restore on the Lens phone). If the Lens phone uses a different Apple Account, the **Lens role is always free**: Pro is checked only on the controlling Duo. This avoids double-charging and needs no server.

**Success metrics:** 4,000 downloads in 60 days; ≥5% Pro conversion; ≥4.4★; median preview latency ≤ 200 ms on real devices (measured in-app and shown in Diagnostics, never uploaded).

## 2. MVP scope

**Module A: Lens (ProLens Link)**

| ID | Feature | Detail |
|---|---|---|
| A1 | Roles & pairing | On launch, choose **Control (this Duo)** or **Lens (this iPhone)**. A non-Duo device defaults to Lens; a Duo defaults to Control. Pairing: Lens shows a 6-digit code + QR (CIQRCodeGenerator); Control discovers it via Bonjour `_duocamkit._tcp` (Network.framework `NWBrowser`, `includePeerToPeer = true` for AWDL). The user enters/scans the code, which is used as a TLS pre-shared key (`sec_protocol_options_add_pre_shared_key`). Paired peers remembered (Keychain: peer ID + derived key) for one-tap reconnect. |
| A2 | Live preview | Lens encodes preview frames with VideoToolbox (H.264/HEVC low-latency, 720p30 default, 1080p30 option), sent as length-prefixed packets over a TCP (or QUIC; spike decides) `NWConnection`. Control decodes with `VTDecompressionSession` → `AVSampleBufferDisplayLayer`. Adaptive bitrate on RTT/throughput. Latency HUD in Diagnostics. |
| A3 | Remote control | Lens selection (tele/wide/ultra-wide by `DiscoverySession` on the Lens phone), zoom factor, tap-to-focus/expose (normalized point), exposure bias, WB presets/lock, AE/AF lock, photo format (HEIF/JPEG/ProRAW when `isAppleProRAWSupported`), video format (HEVC/H.264/ProRes when available), shutter, record start/stop. Control messages are a Codable enum over a separate reliable channel. |
| A4 | Capture on Lens | Full-quality capture happens on the Lens device (`AVCapturePhotoOutput` / `AVCaptureMovieFileOutput`), stored locally in the app container. A thumbnail is sent to Control immediately. |
| A5 | Transfer | After capture (auto, Pro) or on demand: files sent over the same connection in chunks with resume; Control saves to its app library + optional Save to Photos (add-only). Large ProRes files show an estimate and prefer "transfer later". |
| A6 | Two-angle sync record (Pro) | Control records its own wide camera while the Lens records tele. A start command is scheduled for `T = now + 500 ms` using a clock-offset estimate (NTP-style ping exchange, 8 samples, median). Both files carry the start timestamp in metadata, and the app also adds a sync clap (screen flash + beep on both). Output: two files plus a JSON sidecar; no in-app editing. |
| A7 | Inner-screen layout | Open Duo: `ArrangementView(.split)`: tele preview primary (left), controls + Duo's own wide preview thumbnail secondary (right). Half-open (tabletop "director desk"): same layout, user-flippable. Closed: full-screen preview with controls overlaid. |

**Module B: Tripod (HingeCam)**

| ID | Feature | Detail |
|---|---|---|
| B1 | Stand assistant | When `partiallyOpen`, show the relative hinge angle and a **stability lock**: after the user taps Lock, any change > 1.5° relative to the locked angle, or device motion above a threshold (CoreMotion `userAcceleration`), shows a "moved" warning and pauses interval capture. Horizon level from `CMDeviceMotion.gravity`. **Which half of the device CoreMotion reports for when folded is UNCONFIRMED**: calibrate with a "place flat" step and allow manual level offset. |
| B2 | Time-lapse | Interval 0.5–60 s, duration or unlimited, locked AE/AF/WB option, output = HEVC video assembled with `AVAssetWriter` + original frames optional (Pro). Screen dimming during capture (app brightness overlay). Battery/thermal estimate. |
| B3 | Long exposure (Pro) | Burst capture at the format's max fps with fixed exposure, **frame stacking** on Metal/Core Image: mean (silky water), lighten (light trails), median (crowd removal). 2–30 s virtual exposure. Alignment off by default (tripod); on = Vision `VNTranslationalImageRegistrationRequest`. |
| B4 | Star trails (Pro) | Interval capture (max exposure duration per frame), lighten-blend accumulation, live preview of the accumulating image, output photo + optional time-lapse video. |
| B5 | Hands-free trigger | Countdown (3/5/10 s), **open-palm trigger** via Vision `VNDetectHumanHandPoseRequest` (palm facing camera for 0.7 s), burst of 5 with best-sharpness pick (Laplacian variance). Clearly different from Apple's Smart Take: it's user-triggered. |
| B6 | Lap / low-angle cam | Half-open, viewfinder on the "upper" half oriented to the user's eyes, record button on the "lower" half; rear camera records the stage. Suited to filming kids' performances without raising the phone. |
| B7 | Top-down (desk) | Hinge ≈ 90° with one half flat on the table: rear camera on the upright half faces forward, so "top-down" here means **a tilted overhead framing guide**. True overhead needs the phone over the desk, so provide a guide plus a keystone-correction toggle (Core Image `CIPerspectiveCorrection` with Vision rectangle detection). |

**Non-goals (MVP):** live streaming; more than one Lens device; Android Lens; internet relay/cloud (peer-to-peer only); in-app video editing/merging; RAW processing beyond saving; Apple Watch remote; anything that replicates Duo Preview/Smart Take/Kid Cue.

**Backlog:** multi-Lens (3 angles); picture-in-picture composite export; Shortcuts intents; Mac as Control (Catalyst); RAW stacking; meteor-detection mode; Lens role on iPad.

## 3. Fold-state behavior matrix

| State (Control = Duo) | Lens module | Tripod module |
|---|---|---|
| `closed` (outer) | Full-screen tele preview with overlay controls; compact control drawer; Duo's own camera options = rear + outer front | Tripod modes still available (phone propped in a stand) but the stand assistant shows "Half-open your Duo to use it as a stand" |
| `partiallyOpen` | Director desk: preview + controls split; layout flip button | **Primary state.** Angle readout, lock, level; capture modes enabled. Hinge angle used *only* for stability detection (relative), never for absolute geometry |
| `fullyOpen` | Split view: preview primary, controls secondary | Modes available; stand assistant hidden (no stand) |
| Transitions | Connection and preview unaffected; layout re-arranges; no command dropped | Lock broken by a fold change → interval capture pauses with "Stand moved" and resumes on re-lock |
| Rotation | Preview rotation via Lens-side `RotationCoordinator` metadata sent with frames | Locked orientation during capture |
| Split View | Compact layout; preview continues | Capture continues if the camera session remains (iOS may pause camera access in multitasking; handle the interruption) |
| Non-Duo iPhone as Control | Allowed (any iPhone can be Control; useful for testing and for non-Duo users) | Tripod modes available without the hinge features (level + stability by CoreMotion only) |
| Lens device (any iPhone, any state) | Lens UI: minimal status screen (paired, recording, battery, thermal), dims the screen, keeps the camera running; `isIdleTimerDisabled = true` | n/a |
| iPad | Lens or Control in compatibility mode | Tripod without hinge |

## 4. Flows and screens

Navigation: Home (two big cards: **Lens** and **Tripod**) → module screens. Settings sheet. Gallery (local captures) tab-free, from the Home toolbar.

| Screen | States |
|---|---|
| S1 Home / role picker | first run explanation; Lens card shows "Pair your old iPhone" |
| S2 Pairing (Control) | searching (spinner); **local network permission denied** (explain + Open Settings); none found after 20 s ("Open Duo Camera Kit on your other iPhone and tap Lens") ; code entry / QR scan; pairing failed (wrong code); connected |
| S3 Lens role screen (on old iPhone) | waiting for Control (shows code + QR); connected; capturing; **camera permission denied**; thermal serious/critical; low battery; transfer in progress |
| S4 Lens control (Duo) | preview loading; live; **degraded** (high latency, low bitrate badge); **disconnected** (auto-reconnect 3 attempts with backoff, then "Reconnect"); recording; transfer queue |
| S5 Tripod mode picker | per-mode cards with Pro badges |
| S6 Tripod capture | setup (interval, duration); stand assistant; capturing (progress, frames, ETA, battery estimate); paused (stand moved / interrupted); processing (stacking progress); done (result preview) |
| S7 Gallery | empty; grid; detail with share/save; save denied → Files fallback |
| S8 Paywall, S9 Settings, S10 Diagnostics (latency, bitrate, clock offset, peer info) | offline / loading StoreKit states |

Offline: everything works offline (peer-to-peer). Only purchases need the App Store.

## 5. UI / design brief

- **Direction:** a pro camera feel: black UI, monochrome controls, a single accent (suggest signal-yellow) for record/shutter and warnings; big touch targets usable at a stadium. Two "personalities": Lens (telephoto glass motif) and Tripod (hinge/stand motif) with the same component library.
- **Layouts:** see §3. Controls never in `reservedRegions(.division)`; shutter on the side away from the inner camera's occlusion region. Tabletop: preview on the upper half, controls lower, with a flip button.
- **Components:** RemotePreviewView, LatencyBadge, LensPicker (0.5×/1×/3×/5× chips showing what the Lens phone offers), ExposureDial, ShutterButton, RecordTimer, StabilityGauge (angle + lock), LevelIndicator, IntervalPicker, StackingProgress, TransferQueueRow, PairingCodeView (large digits + QR).
- **Type:** SF Pro, monospaced digits for timers/angles; Dynamic Type for chrome.
- **Color & dark mode:** UI is dark in capture screens regardless of system setting; Home/Settings/Gallery follow the system.
- **Motion:** minimal; no animation during capture; Reduce Motion respected.
- **Accessibility:** VoiceOver labels for all controls (e.g., "Lens zoom 5 times"), haptic + spoken countdown option, high-contrast warnings, controls work with Voice Control ("Tap shutter").
- **Localization:** en + zh-Hans.
- **Screenshots:** Duo inner showing a 5× tele preview from an "old iPhone" with controls; tabletop director desk; star-trail result; time-lapse stand assistant; outer screen Lens control. Show both phones in the marketing frame (allowed as generic devices; don't use Apple marketing imagery). **Icon:** a lens ring with a hinge line through it.

## 6. Technical architecture

**Stack:** Swift 6, SwiftUI, AVFoundation, VideoToolbox, Network.framework, CoreMotion, Vision, Core Image + Metal (stacking), Photos (add-only), SwiftData (gallery metadata), StoreKit 2, FoldKit.

All fold logic goes through one small local Swift package, **`FoldKit`**. It's the same package in every iOS project in this portfolio: copy it in as `Packages/FoldKit`. Nothing else in the app may call `onHingeChange` / `UIHingeInteraction` directly.

```swift
// Packages/FoldKit/Sources/FoldKit/FoldState.swift
import SwiftUI
import Observation

public enum FoldPosture: String, Codable, Sendable, CaseIterable {
    case noHinge        // non-Duo iPhone, iPad, Mac ("Designed for iPad"), or hinge context unavailable
    case closed         // folded; app is (assumed) on the outer display
    case partiallyOpen  // flexed / half-folded (laptop, book, tent… system does not tell which)
    case fullyOpen      // flat; app on inner display
    case unknown        // UIKit `.unknown`, or transient states
}

public struct FoldState: Equatable, Sendable {
    public var posture: FoldPosture
    /// Degrees exactly as reported by the system. `nil` when there is no hinge.
    /// The range is NOT documented. Never compare to absolute thresholds without calibration.
    public var angleDegrees: Double?
    public var timestamp: Date
    public init(posture: FoldPosture, angleDegrees: Double?, timestamp: Date = .now) {
        self.posture = posture; self.angleDegrees = angleDegrees; self.timestamp = timestamp
    }
    public static let noHinge = FoldState(posture: .noHinge, angleDegrees: nil, timestamp: .distantPast)
    public var hasHinge: Bool { posture != .noHinge }
}

@MainActor
public protocol FoldStateProvider: AnyObject, Observable {
    var state: FoldState { get }
    /// Yields the current value immediately, then every change.
    func states() -> AsyncStream<FoldState>
}

/// Production provider. Fed by `HingeBridge`, attached once at the root of every scene.
@MainActor @Observable
public final class SystemFoldStateProvider: FoldStateProvider { /* stores state, fans out to continuations */ }

/// Test / preview / UI-test provider. Driven by code or by launch arguments (see §8).
@MainActor @Observable
public final class MockFoldStateProvider: FoldStateProvider {
    public func set(_ posture: FoldPosture, angle: Double? = nil)
    public func play(_ script: [FoldScriptStep]) async   // e.g. sweep 180→0 over 2 s at 30 Hz
}

public struct HingeBridge: ViewModifier {
    let provider: SystemFoldStateProvider
    public func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {                     // availability version assumed. Verify in Xcode 27.1
            content.onHingeChange { _, ctx in provider.ingest(ctx.hinge) }   // maps DeviceHinge → FoldState
        } else {
            content.onAppear { provider.ingestNoHinge() }
        }
    }
}

/// Converts noisy absolute angles into a stable 0…1 control value.
public struct RelativeAngleTracker: Sendable {
    public var anchorDegrees: Double?             // set when the interaction starts
    public var observedMin: Double, observedMax: Double   // learned during calibration
    public var smoothing: Double = 0.25           // EMA factor; animate between samples
    public mutating func begin(at degrees: Double)
    public mutating func update(_ degrees: Double) -> Double     // returns normalized progress 0…1
    public mutating func delta(_ degrees: Double) -> Double       // signed degrees since anchor
    public mutating func reset()
}
```

Rules:
- `DeviceHinge.status` mapping: `.closed → .closed`, `.partiallyOpen → .partiallyOpen`, `.fullyOpen → .fullyOpen`, `@unknown default → .unknown`. A `nil` hinge maps to `.noHinge`.
- Inject the provider through the SwiftUI environment: `@Environment(\.foldState)`. Feature code depends on the `FoldStateProvider` protocol, never on the concrete class.
- Launch argument `-FoldMock <value>` swaps in `MockFoldStateProvider`. Values: `nohinge`, `closed`, `open`, `half:<deg>`, `sweep:<from>-<to>:<seconds>`, `script:<bundled-json-name>`. It is only honored in DEBUG builds or when `-UITestMode 1` is present.
- Every hinge-driven interaction must also have a non-hinge control (slider, buttons, drag, or tilt) with identical results. This covers non-Duo devices, VoiceOver users, and App Review on devices without a hinge.

**Modules:** `FoldKit`; `CameraKit` (shared `CameraSource` protocol with `AVCameraSource` and `MockCameraSource` that plays fixture video; see the FoldCue spec for the protocol, reused verbatim); `LinkKit` (discovery, pairing, TLS-PSK, framing, control channel, clock sync, file transfer); `StreamKit` (VT encoder/decoder, adaptive bitrate); `TripodKit` (stand assistant, interval scheduler, stacking engines, hand-pose trigger, keystone); `Library` (SwiftData gallery); `Store`; `App`.

**Key types:**
```swift
enum DeviceRole: String, Codable { case control, lens }
struct PeerInfo: Codable, Hashable { let id: UUID; var name: String; var model: String; var appVersion: String; var capabilities: LensCapabilities }
struct LensCapabilities: Codable, Hashable { var lenses: [LensOption]; var proRAW: Bool; var proRes: Bool; var maxVideo: VideoFormatOption }
struct LensOption: Codable, Hashable { var id: String /* AVCaptureDevice.uniqueID */; var kind: LensKind /* ultraWide, wide, tele */; var zoomFactors: [Double]; var displayName: String }
enum ControlMessage: Codable { case hello(PeerInfo), selectLens(String), zoom(Double), focus(CGPoint), exposureBias(Float), whiteBalance(WBPreset), lockAEAF(Bool), capturePhoto(PhotoSettings), startRecording(at: UInt64 /* peer clock ns */), stopRecording, requestTransfer(UUID), ping(UInt64), pong(UInt64, UInt64), status(LensStatus) }
struct LensStatus: Codable { var battery: Float; var thermal: Int; var isRecording: Bool; var freeBytes: Int64 }
struct CaptureItem: Codable, Identifiable { var id: UUID; var kind: CaptureKind; var source: DeviceRole; var fileName: String; var createdAt: Date; var transferred: Bool }
enum TripodMode: String, Codable, CaseIterable { case timelapse, longExposure, starTrails, palmTrigger, lapCam, topDown }
struct StandLock { var anchorAngle: Double; var anchorGravity: SIMD3<Double>; var toleranceDegrees: Double = 1.5 }
protocol Transport { func send(_ m: ControlMessage) async throws; var messages: AsyncStream<ControlMessage> { get }; func sendVideo(_ packet: Data) ; var video: AsyncStream<Data> { get } }
// NWTransport (real) and LoopbackTransport (tests: two in-process endpoints, optional injected latency/loss)
```

**Persistence:** SwiftData gallery; files in Application Support/Captures; paired peers in Keychain (`kSecClassGenericPassword`, this-device-only); settings in UserDefaults.

**Permissions (Info.plist):**
- `NSCameraUsageDescription`: "Duo Camera Kit uses the camera to take photos and videos, including when this iPhone is used as a remote lens." / "Duo Camera Kit 使用相机拍摄照片和视频，包括把这台 iPhone 当作远程镜头时。"
- `NSMicrophoneUsageDescription`: "Record sound with your videos." / "录像时录制声音。"
- `NSLocalNetworkUsageDescription`: "Duo Camera Kit connects directly to your other iPhone nearby to share the camera preview and transfer photos. Nothing goes to the internet." / "Duo Camera Kit 会直接连接你附近的另一台 iPhone，用来传输取景画面和照片，不经过互联网。"
- `NSBonjourServices`: `_duocamkit._tcp` (and `_duocamkit._udp` if QUIC is chosen).
- `NSPhotoLibraryAddUsageDescription`: "Save captures to Photos." / "将拍摄内容保存到照片。"
- `NSMotionUsageDescription` is **not** required for `CMMotionManager` device motion (only for pedometer/activity). Confirm with Xcode warnings.
- `UIBackgroundModes`: none (Lens must stay in the foreground; document this).

Privacy stance: **no tracking, no data collection off-device.** App Store privacy label: **Data Not Collected.** No third-party SDKs. No `NSUserTrackingUsageDescription`, no ATT prompt.

Base `PrivacyInfo.xcprivacy` (add a required-reason entry only for APIs the app actually touches. The reason codes below are Apple's published codes; re-check against the current list when submitting):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>NSPrivacyTracking</key><false/>
  <key>NSPrivacyTrackingDomains</key><array/>
  <key>NSPrivacyCollectedDataTypes</key><array/>
  <key>NSPrivacyAccessedAPITypes</key><array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>CA92.1</string></array>
    </dict>
    <!-- add FileTimestamp (C617.1) if you read file modification dates in the app container -->
    <!-- add DiskSpace (E174.1) if you check free space before writing large files -->
  </array>
</dict></plist>
```
Widget / app extensions get their own copy of the manifest.
Camera Kit entries: UserDefaults CA92.1, FileTimestamp C617.1, DiskSpace E174.1 (Lens free-space status), SystemBootTime (35F9.1) **only if** `mach_absolute_time`/`systemUptime` is used for clock sync. It is (monotonic clock for sync), so include it with reason 35F9.1 (measuring elapsed time between events in the app).

**StoreKit:** `com.jackyu.duocamerakit.pro` non-consumable $9.99, Family Sharing on. The Lens role never checks entitlements.
StoreKit 2 implementation (shared pattern, `Store` module):
- `@MainActor @Observable final class Store`: loads products with `Product.products(for:)`, starts a `Transaction.updates` listener at launch, and recomputes entitlements from `Transaction.currentEntitlements`. Every `VerificationResult` is checked; `.unverified` grants nothing.
- Purchase: `product.purchase()`. Handle `.success(.verified)` (then `transaction.finish()`), `.pending` (Ask to Buy / SCA: show a "Waiting for approval" state), and `.userCancelled` (silently return).
- Restore: a "Restore Purchases" button calls `AppStore.sync()`. Also show it in Settings.
- Refunds / revocation: a transaction with `revocationDate != nil` removes the entitlement immediately (next launch at the latest).
- Family Sharing: enable it in App Store Connect for the non-consumable unlock(s). The code doesn't change.
- Offline: cache the last computed entitlement set in `UserDefaults` only to avoid a paywall flash, and always re-verify when `currentEntitlements` arrives.
- The paywall uses SwiftUI `ProductView` / `StoreView` where it fits (it localizes prices automatically). Never hardcode prices in UI strings.
- Local testing: a `Configuration.storekit` file in the repo, selected in the Run scheme. Unit tests use `StoreKitTest.SKTestSession` (purchase, Ask-to-Buy, refund, expire, failure).

**Project tree:**
```
duo-camera-kit-ios/
├─ DuoCameraKit.xcodeproj
├─ App/ (Home/, Pairing/, LensRole/, LensControl/, Tripod/, Gallery/, Paywall/, Settings/, Diagnostics/)
│  ├─ Resources/ Localizable.xcstrings, Assets.xcassets, Fixtures/ (DEBUG mock videos, star-field frames)
│  ├─ Info.plist, PrivacyInfo.xcprivacy
├─ Packages/ FoldKit/ CameraKit/ LinkKit/ StreamKit/ TripodKit/ Library/ Store/
├─ Tests/ UITests/
└─ Configuration.storekit
```

## 7. Edge cases

- Both devices pick the same role → second one prompts "This iPhone is already set as Control. Switch?"
- Local Network permission denied on either device → discovery fails silently on iOS. Detect with a browse timeout plus the `NWBrowser` state `.waiting(.dns(kDNSServiceErr_PolicyDenied))` and show instructions.
- Wi-Fi off / Bluetooth off → AWDL needs Wi-Fi radio on (not joined). Show "Turn on Wi-Fi (you don't need to join a network)". Personal Hotspot/Captive Wi-Fi → still peer-to-peer.
- Connection drops mid-recording → Lens **keeps recording locally** and Control shows "Lens still recording (last status 5 s ago)"; on reconnect, status is re-synced; a stop command is queued.
- Lens app backgrounded/locked → camera stops (iOS); Lens sends `status` before backgrounding when possible; Control shows "Lens paused: bring the app to the front". Keep the screen on with `isIdleTimerDisabled` and a dimming overlay.
- Thermal throttling on the Lens (old phones heat fast) → reduce preview to 540p15, warn; critical → stop recording safely.
- Clock offset unstable (high jitter) → sync record warns "sync ±X ms" and still includes the clap.
- Lens lacks a telephoto (non-Pro) → still usable as a second angle; Lens picker shows only available lenses.
- ProRAW/ProRes unsupported on the Lens model → options hidden.
- Transfer of a 6 GB ProRes file → resumable chunks, free-space check on Control, cancel/resume; if interrupted, keep partial and resume on reconnect.
- Pairing code brute force → 5 attempts then a new code; codes expire in 10 minutes.
- Two Duos and one Lens → Lens accepts one Control at a time.
- Different app versions on the two devices → `hello` carries a protocol version; incompatible → "Update the app on both iPhones".
- Tripod: phone fully closed during a time-lapse → pause; reopened → "Re-lock stand to resume".
- Tripod: inner camera selected and device closed → camera unavailable → switch prompt.
- Long-exposure stacking memory → stream accumulation (running sum in a float texture), never keep all frames; cap at 900 frames.
- Star trails with screen on draining battery → auto-dim overlay with "tap to wake".
- Low Power Mode → warn for time-lapse > 30 min.
- Storage full → stop capture, keep everything captured so far.
- StoreKit: Control without Pro + Lens with Pro (different accounts) → Pro features follow the Control device.

## 8. Testing plan

How to simulate fold states and hinge angles:
1. **Unit tests (fast, CI):** inject `MockFoldStateProvider`. Drive `set(.closed)`, `set(.partiallyOpen, angle: 95)`, `set(.fullyOpen)`, `set(.noHinge)` and scripted sweeps, and assert on view-model state. No simulator posture needed.
2. **UI tests (XCUITest, CI):** launch with `-UITestMode 1 -FoldMock <value>`. A hidden DEBUG-only "Fold debug" overlay (toggled with `-FoldDebugOverlay 1`) exposes buttons with accessibility identifiers `fold.closed`, `fold.half`, `fold.open`, `fold.nohinge`, `fold.sweep`, so a UI test can change the mocked posture mid-flow. Mocking changes hinge signals only. It does **not** resize the window.
3. **Real layout changes (manual or semi-automated):** run on the **iPhone Duo simulator** (Xcode 27.1, Device Hub). Use the Closed / Open / Rotate buttons, and hold Option for the hinge-angle slider. This is the only official way to test true outer↔inner resizing, reserved regions, and split view. `simctl` has no posture command.
4. **Optional local helper:** the third-party `hinge` CLI (`hinge 120`, `hinge sweep 180 0 2`) sets the simulator hinge through a private, undocumented protocol. Use it for local exploration only, and never make a CI gate depend on it.
5. **Non-Duo fallback:** run the same UI tests on an iPhone 17/18 simulator with `-FoldMock nohinge`, and without any mock, to verify `hinge == nil` handling.

**Camera-specific:** The Simulator has no camera. Use `MockCameraSource` (fixture videos of a scene, a star field, and a hand-palm clip) for both roles. Run two simulators (one as Lens, one as Control) on the same Mac for LinkKit integration. Bonjour works between simulators on one host; peer-to-peer AWDL doesn't apply.

**Unit:** LinkKit framing (fragmentation, partial reads), ControlMessage codable round-trips, pairing PSK derivation, retry/backoff, clock sync estimator with injected offsets/jitter (LoopbackTransport), transfer resume logic; StreamKit encoder/decoder round-trip on fixture frames; adaptive bitrate controller; TripodKit interval scheduler (virtual clock), stand lock thresholds with `MockFoldStateProvider` sweeps (`half:100` → lock → `half:103` → paused), stacking math (mean/lighten/median on synthetic frames, deterministic outputs), palm-trigger debounce with fixture pose observations; Store gating.

**UI tests:** `-UITestMode 1 -MockCamera 1 -LoopbackLink 1` → pair flow with a fixed code → preview visible (`lens.preview.live`) → capture photo → item in gallery; Tripod time-lapse with `-FoldMock half:110` and a virtual clock (`-TimeScale 60`) produces a video file; `-FoldMock nohinge` hides the stand angle UI and keeps the level.

**Real devices needed:** latency/bitrate on AWDL; thermal on old Pro (13/14/15/16 Pro); ProRAW capture over remote; Duo camera device types and multi-cam sets; CoreMotion semantics when folded; outdoor low-light star trails.

**Acceptance criteria:**
- AC1: Two physical iPhones pair in ≤ 15 s from opening the app on both, with no Wi-Fi network joined (Wi-Fi radio on).
- AC2: Median glass-to-glass preview latency ≤ 200 ms and p95 ≤ 350 ms at 720p30 over 2 minutes (Diagnostics measurement with an on-screen timecode test).
- AC3: A remote photo at full resolution (including ProRAW on a supported Lens) arrives on the Duo with original metadata intact (byte-identical file hash on both).
- AC4: Pulling the Wi-Fi radio (airplane mode on Control) mid-recording: the Lens recording is intact; after reconnect, Control shows the take and can transfer it.
- AC5: Two-angle sync start: measured offset between files ≤ 50 ms on the same Wi-Fi conditions (clap test).
- AC6: Stand lock: a simulated hinge change of +2° (`MockFoldStateProvider`) pauses interval capture within 1 sample; re-lock resumes.
- AC7: Stacked 10 s "virtual exposure" of the fixture waterfall matches the golden image within SSIM ≥ 0.98.
- AC8: The open-palm trigger fires on the positive fixture and never on the 5 negative fixtures.
- AC9: With `-FoldMock nohinge` and on an iPhone without iOS 27.1, the app runs; the Lens role works on iOS 26.
- AC10: The Lens role never shows a paywall; Pro on Control unlocks ProRAW/4K/sync immediately (StoreKit test).
- AC11: Local network, camera, mic, and photos denial each lead to the specified recoverable state.
- AC12: All strings are localized en + zh-Hans; VoiceOver can complete pairing and a remote capture.

## 9. App Store review risks

| Risk | Mitigation |
|---|---|
| Camera privacy (5.1.1): the remote camera could be seen as covert | Lens screen always shows a visible "Camera active / controlled by <name>" state; a REC indicator on the Lens; pairing requires a code shown on the Lens; no background camera. |
| Local network permission rationale | Precise purpose string; requested only when entering Lens mode. |
| 4.2 overlap with built-in Duo Preview / Smart Take / Continuity Camera | Differentiation stated in the description: telephoto from another iPhone, stacking modes. Review Notes explain how to test with two devices, and in single-device mode (Tripod). |
| Reviewer has only one device | Tripod module fully testable on one iPhone; Review Notes include a demo video of Lens mode. |
| Trademark "Duo" / "ProLens" | Avoid "Pro" in names referencing Apple's iPhone Pro; marketing says "your previous iPhone". |

## 10. Milestones

| # | Milestone | Tasks | Est. |
|---|---|---|---|
| M0 | Spike | Two-device AWDL link with Network.framework: latency of VT-encoded 720p30 over TCP vs QUIC; TLS-PSK pairing; Duo camera discovery and multi-cam sets (Duo simulator lists device types? verify); write `docs/M0-findings.md` | 2 d |
| M1 | Skeleton | Project, FoldKit, CameraKit + Mock, LinkKit protocols + Loopback, String Catalog, privacy manifest, CI | 1 d |
| M2 | Pairing & link | Discovery, code/QR, PSK, reconnect, hello/version, Diagnostics (AC1) | 2.5 d |
| M3 | Live preview | Encoder/decoder, display layer, adaptive bitrate, latency HUD (AC2) | 3 d |
| M4 | Remote control & capture | Lens picker, focus/exposure/WB, photo/video capture on Lens, thumbnails, status (AC3) | 2.5 d |
| M5 | Transfer & sync record | Chunked resumable transfer, clock sync, scheduled start, clap, sidecar (AC4, AC5) | 2.5 d |
| M6 | Tripod core | Stand assistant (hinge lock + level), time-lapse with AVAssetWriter (AC6) | 2 d |
| M7 | Tripod Pro modes | Stacking engine (mean/lighten/median), star trails, palm trigger, lap cam, top-down keystone (AC7, AC8) | 3 d |
| M8 | Layouts, Store, polish | ArrangementView layouts per fold state, paywall, gallery, a11y, zh-Hans, screenshots, Review Notes (AC9–AC12) | 2.5 d |
| M9 | Device QA | Real Duo + old Pro: latency, thermal, AWDL, CoreMotion folded | 1.5 d |
| | **Total** | | **≈22.5 dev-days** |

## 11. Open questions & assumptions

1. Which camera device types does the Duo expose to third parties (rear wide/ultra-wide names, the new inner/outer ultra-wide), and which multi-cam sets are supported?
2. AWDL peer-to-peer latency and stability with Network.framework `includePeerToPeer`. Is TCP enough, or is QUIC/UDP needed?
3. CoreMotion when folded: which half's orientation does `CMDeviceMotion` report? (Assumed the half containing the main logic board; calibrate.)
4. `AVCaptureDeviceDirectionCoordinator` exact API and availability (forum-sourced).
5. The minimum iOS for the Lens role: iOS 26.0 assumed. Confirm which older Pros run iOS 26 and that StoreKit/Network APIs used are available there.
6. Hinge angle precision and update rate for the 1.5° stand-lock tolerance (undocumented; tune on device, maybe 3°).
7. Pricing $9.99 one-time with Lens role always free. Confirm StoreKit Family Sharing behavior across two devices on the same account.
8. Does App Review accept a two-device feature with only a video demo? (Plan for the Tripod module to carry review.)


---
*Spec version 1.0 · 2026-10-13 · Prepared for Jack Yu. API facts were checked against Apple developer sources on that date (see the API status table). Items marked UNCONFIRMED or "verify" must be validated in M0 or on a real device.*
