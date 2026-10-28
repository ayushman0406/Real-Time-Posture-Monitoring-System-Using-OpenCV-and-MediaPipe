# PostureBar — Native macOS Menu Bar Posture Coach (`SwiftUI` + Apple `Vision`)

A native macOS menu bar application (`NSStatusBar` / `MenuBarExtra`) that lives next to your Wi-Fi and Battery icons, using Apple's on-device **Vision** framework (`VNDetectHumanBodyPoseRequest` + `VNDetectFaceLandmarksRequest`) and a scale-invariant biomechanical formula to detect slouching, forward head posture ("Tech Neck"), uneven shoulders, and screen crowding.

## Quick Start (Build & Launch the macOS App)

```bash
./build_app.sh
open PostureBar.app
```

Because `Info.plist` sets `LSUIElement = true`, **PostureBar** runs exclusively in your top menu bar without cluttering your Dock.

## First-Launch Setup & Onboarding Wizard

When you launch `PostureBar.app` for the first time (or click **Setup & Preferences…** in the menu bar popover), a 3-step setup wizard walks you through:

1. **Step 1 — Camera Tracking Mode Preference**
   - **Continuous Low-FPS (1–2 FPS)**: Instant real-time posture score updates in the menu bar; keeps the green camera indicator on continuously while active.
   - **Periodic Burst Check (1s every 30–60s)**: Opens the camera for ~1 second to sample a 5-frame burst, evaluates your posture, and powers the camera hardware completely off so the green indicator light stays off ~97% of the time.
2. **Step 2 — Slouching Feedback Style (Multi-Select + Live Preview)**
   - **macOS Notification Banner**: Native `UNUserNotificationCenter` alert naming the specific biomechanical issue and an ergonomic coaching tip.
   - **Subtle Audio Chime**: Soft macOS system chime (`NSSound`) with configurable cooldown.
   - **Gentle Screen Dim / Frosted Blur Overlay**: Click-through, non-activating `NSPanel` across all displays (`ignoresMouseEvents = true`) that gently dims or blurs the screen proportionally to your slouch severity and clears the instant you sit up.
3. **Step 3 — 3-Second Guided Upright Baseline Calibration**
   - Captures multi-frame biomechanical ratios over a 3-second countdown and saves your personal baseline to `~/Library/Application Support/PostureBar/posture_baseline.json`.

## Reworked Scale-Invariant Biomechanical Formula

All measurements in `Sources/PostureBar/Vision/PostureMathEngine.swift` are normalized by apparent **Inter-Shoulder Width ($W$)** so moving your chair slightly back or adjusting screen tilt does not trigger false positives:

1. **Cervical Extension Ratio ($R_{\text{neck}}$)**: $\frac{y_{\text{earMid}} - y_{\text{torsoTop}}}{W}$ — detects thoracic hunching and vertical neck compression.
2. **Differential Head-to-Shoulder Scale ($R_{\text{jut}}$)**: $\frac{D_{\text{eyes}}}{W}$ — compares inter-pupillary distance to shoulder width to separate **Forward Head Jut ("Tech Neck")** from whole-body chair movement.
3. **Craniovertebral Pitch ($R_{\text{pitch}}$)**: $\frac{y_{\text{nose}} - y_{\text{earMid}}}{W} + 0.35 \cdot \theta_{\text{facePitch}}$ — detects downward chin drop.
4. **Coronal Shoulder Roll ($\theta_{\text{roll}}$)**: $\left|\arctan2(\Delta y_{\text{shoulders}}, \Delta x_{\text{shoulders}})\right|$ — detects asymmetric leaning on one elbow.
5. **Lateral Head Offset ($R_{\text{lat}}$)**: $\frac{|x_{\text{head}} - x_{\text{shoulderMid}}|}{W}$ — detects off-center leaning.

## Project Structure

```text
├── Package.swift
├── Info.plist
├── build_app.sh
├── PostureBar.app/
├── Sources/PostureBar/
│   ├── App/
│   │   ├── PostureBarApp.swift          # @main MenuBarExtra + AppDelegate
│   │   └── AppSettings.swift            # @AppStorage preferences for sampling & alerts
│   ├── Vision/
│   │   ├── PostureMathEngine.swift      # Scale-invariant biomechanical formula & EMA hysteresis
│   │   ├── PoseVisionProcessor.swift    # Apple Vision body pose + face landmark extraction
│   │   └── CameraScheduler.swift        # Continuous (1–2 FPS) & Periodic Burst (1s/30–60s) manager
│   ├── Feedback/
│   │   ├── FeedbackCoordinator.swift    # Orchestrates Banner, Sound, and Screen Dim/Blur
│   │   └── ScreenOverlayWindow.swift    # Multi-monitor click-through dim/blur overlay
│   └── Views/
│       ├── OnboardingView.swift         # 3-step setup wizard with live previews
│       ├── MenuBarPopoverView.swift     # Top menu bar popover UI
│       └── CameraPreviewView.swift      # Mirrored camera preview + skeleton overlay
└── Tests/PostureBarTests/
    └── PostureMathEngineTests.swift     # Unit tests for scale invariance & slouch detection
```
