# Duo Camera Kit

**Turn your old iPhone Pro into a telephoto lens for iPhone Duo, or use the hinge as a tripod for time-lapse and long exposure.**

## Project Structure

```
duo-camera-kit-ios/
├── project.yml                    # XcodeGen project specification
├── App/                           # SwiftUI app layer (iOS only)
│   ├── Home/                      # Home screen with module cards
│   ├── Pairing/                   # Device pairing UI
│   ├── LensRole/                  # Lens device UI
│   ├── LensControl/               # Control device UI
│   ├── Tripod/                    # Tripod mode UI
│   ├── Gallery/                   # Capture gallery
│   ├── Paywall/                   # Pro purchase
│   ├── Settings/                  # App settings
│   ├── Diagnostics/               # Connection diagnostics
│   └── Resources/                 # Assets, localization, fixtures
├── Packages/                      # Swift packages (platform-independent)
│   ├── FoldKit/                   # Fold state management
│   ├── CameraKit/                 # Camera source abstraction
│   ├── LinkKit/                   # Device discovery & communication
│   ├── StreamKit/                 # Video encoding/decoding
│   ├── TripodKit/                 # Tripod mode features
│   ├── Library/                   # Capture storage
│   └── Store/                     # StoreKit 2 purchases
├── Tests/                         # Unit tests
├── UITests/                       # UI tests
└── docs/                          # Specification document
```

## Building on Linux (Package Testing)

All platform-independent logic is in Swift packages that can be built and tested on Linux:

```bash
# Install Swift 6.0+ (if not already installed)
# See https://swift.org/download/

# Test all packages
cd Packages/FoldKit && swift test
cd ../CameraKit && swift test
cd ../LinkKit && swift test
cd ../StreamKit && swift test
cd ../TripodKit && swift test
cd ../Library && swift test
cd ../Store && swift test
```

## Building on macOS (Xcode)

### Prerequisites

- macOS 14.0+
- Xcode 15.0+ (Xcode 27.1 for Duo simulator)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### Generate Xcode Project

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate project
xcodegen generate

# Open in Xcode
open DuoCameraKit.xcodeproj
```

### Testing with Fold State Mocks

The app supports launch arguments for mocking fold state in DEBUG builds and UI tests:

```
-FoldMock nohinge      # Non-Duo device
-FoldMock closed       # Closed (outer display)
-FoldMock open         # Fully open (flat)
-FoldMock half:110     # Partially open at 110°
-FoldMock sweep:180-0:2  # Sweep from 180° to 0° over 2 seconds
```

Enable the fold debug overlay:
```
-FoldDebugOverlay 1
```

## Test Results

All packages build and pass tests on Linux:

| Package | Tests | Status |
|---------|-------|--------|
| FoldKit | 34 | ✅ Pass |
| CameraKit | 30 | ✅ Pass |
| LinkKit | 61 | ✅ Pass |
| StreamKit | 17 | ✅ Pass |
| TripodKit | 27 | ✅ Pass |
| Library | 7 | ✅ Pass |
| Store | 10 | ✅ Pass |
| **Total** | **186** | ✅ |

## Implemented Milestones

### M0: Project Setup ✅
- Project structure with Swift packages
- Spec committed to `docs/`

### M1: Skeleton ✅
- **FoldKit**: `FoldState`, `FoldPosture`, `FoldStateProvider` protocol, `MockFoldStateProvider`, `RelativeAngleTracker`, launch argument parsing
- **CameraKit**: `CameraSource` protocol, `LensOption`, `LensCapabilities`, `CameraState`, `PhotoSettings`, `VideoSettings`, `MockCameraSource`
- **LinkKit**: `ControlMessage` enum, `Transport` protocol, `LoopbackTransport`, `PairingCode`, `ClockSync`, `PeerInfo`, `LensStatus`, `CaptureItem`
- **StreamKit**: `VideoEncoder`/`VideoDecoder` protocols, `EncoderConfig`, `VideoQuality`, `AdaptiveBitrateController`, `MockEncoder`/`MockDecoder`
- **TripodKit**: `TripodMode`, `StandAssistant`, `StandLock`, `TimelapseScheduler`, `StackingEngine` with mean/lighten/median modes
- **Library**: `CaptureLibrary` protocol, `MockCaptureLibrary`
- **Store**: `StoreManager` protocol, `MockStoreManager`, `ProFeatures`

### M2–M5: Pairing, preview, capture, transfer
- Network.framework Bonjour `_duocamkit._tcp` / `_duocamkit._udp`, TLS-PSK, reconnect
- VideoToolbox encoder/decoder (iOS), adaptive bitrate
- AVFoundation capture with telephoto detection and graceful degrade
- Chunked resumable transfer + clock sync
- StoreKit 2 Pro (Family Sharing via `Transaction.currentEntitlements`)
- Localization en + zh-Hans, Info.plist local network + Bonjour
- Deployment target **iOS 26.0**; Duo APIs gated `#available(iOS 27.1, *)`

## Duo Display Specifications

Based on PM research (public, not yet Apple-doc-confirmed):

| Display | Diagonal | Pixels | Aspect Ratio |
|---------|----------|--------|--------------|
| **Outer** (cover) | 5.4" | 1398×2034 px | ~1:1.455 (portrait) |
| **Inner** (unfolded) | 7.6" | 2670×1878 px | ~1.42:1 (landscape) |

**Note:** The inner display is landscape-oriented when unfolded, wider than tall (~1.42:1), NOT near-square or 4:3.

### Assumptions (Pending Device Confirmation)

Do **not** derive point sizes from panel pixels / 3. The inner screen renders at @3x (2853×2007 px → 951×669 pt landscape) then downsamples to the panel.

- **Runtime**: `UIScreen.main.bounds` + `scale` (logged on launch in DEBUG)
- **Third-party mock defaults**: inner 951×669 pt, outer 466×678 pt
- **Fold/crease**: `reservedRegions(kind: .division)` at runtime — 0 width when fully open; mock ~40 pt when half-folded
- **Safe areas**: read from `GeometryProxy.safeAreaInsets`, never hardcoded

## Open Questions / Unverified APIs

The following APIs are marked in the spec as unverified and are behind protocols with mocks. Verify on real hardware before release:

1. **Hinge APIs (iOS 27.1+)**
   - `View.onHingeChange(isEnabled:_:)` - availability version assumed
   - `DeviceHinge.angle` range and update rate are undocumented
   - Simulator posture control has no official CLI command

2. **Duo Camera APIs**
   - `.builtInOuterUltraWideCamera` / `.builtInInnerUltraWideCamera` device types
   - `AVCaptureDeviceDirectionCoordinator` exact signature (from forum posts)
   - Multi-cam supported combinations are runtime-only

3. **CoreMotion on Folded Device**
   - Which half's orientation does `CMDeviceMotion` report when folded?
   - Needs calibration step for stand assistant

4. **Network.framework Peer-to-Peer**
   - AWDL latency with `includePeerToPeer = true`
   - TCP vs QUIC for preview streaming (needs spike)

5. **Scene Accessories**
   - Whether outer display camera capture accessory receives touches
   - Non-camera scene accessories availability unclear

6. **Stand Lock Tolerance**
   - 1.5° threshold may need tuning based on hinge precision

7. **StoreKit Family Sharing**
   - Verify entitlement sharing across devices with same Apple Account

8. **Display Specifications**
   - Scale factor not confirmed (assumed 3x)
   - Exact crease width in points unknown
   - Safe insets around fold need device testing

## Architecture Decisions

### Why Swift Packages?
- Platform-independent logic testable on Linux CI
- Clear separation of concerns
- Thin app layer with minimal platform-specific code

### Why XcodeGen?
- Reduces merge conflicts in `xcodeproj`
- Declarative project configuration
- Easy to regenerate after changes

### Why Mocks for Everything?
- Tests run without device/simulator
- UI tests can control state via launch arguments
- Faster development iteration

## Privacy

This app collects no data off-device:
- No analytics
- No tracking
- No network calls except StoreKit (purchases) and local peer-to-peer
- Privacy label: "Data Not Collected"

## License

Proprietary - Jack Yu
