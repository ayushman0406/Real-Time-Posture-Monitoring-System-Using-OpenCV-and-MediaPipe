import SwiftUI

/// First-launch interactive setup wizard that asks the user's preferences for:
/// 1. Camera Sampling Mode (Continuous Low-FPS 1–2 FPS vs. Periodic Burst Check 1s every 30–60s)
/// 2. Slouching Feedback Style (macOS Notification Banner, Subtle Sound, Gentle Screen Dim/Blur)
/// 3. 3-Second Guided Upright Posture Calibration
public struct OnboardingView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var scheduler = CameraScheduler.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top Header & Step Indicator
            headerBar

            Divider()

            // Main Step Content
            Group {
                switch settings.onboardingStep {
                case 0:
                    cameraSamplingStep
                case 1:
                    feedbackPreferencesStep
                default:
                    calibrationStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(28)

            Divider()

            // Bottom Navigation Bar
            footerBar
        }
        .frame(width: 640, height: 560)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to PostureBar")
                    .font(.system(size: 20, weight: .bold))
                Text("Native macOS Menu Bar Posture Coach • Powered by Apple Vision")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { step in
                    Capsule()
                        .fill(step <= settings.onboardingStep ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: step == settings.onboardingStep ? 28 : 12, height: 8)
                        .animation(.spring(response: 0.3), value: settings.onboardingStep)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    // MARK: - Step 1: Camera Sampling Mode Question

    private var cameraSamplingStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Step 1 of 3 • Camera Tracking Mode")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accentColor)
                Text("How would you like PostureBar to check your posture?")
                    .font(.title2.weight(.bold))
                Text("Choose between instant continuous tracking or periodic privacy/battery-saving burst checks:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 14) {
                ForEach(CameraSamplingMode.allCases) { mode in
                    samplingModeCard(mode)
                }
            }

            // Dynamic slider based on selected mode
            GroupBox {
                if settings.samplingMode == .continuousLowFPS {
                    HStack {
                        Label("Sampling Rate:", systemImage: "speedometer")
                            .font(.subheadline.weight(.medium))
                        Slider(value: $settings.continuousFPS, in: 1.0...2.0, step: 0.5)
                        Text(String(format: "%.1f FPS", settings.continuousFPS))
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                            .frame(width: 65, alignment: .trailing)
                    }
                    .padding(6)
                } else {
                    HStack {
                        Label("Check Every:", systemImage: "timer")
                            .font(.subheadline.weight(.medium))
                        Slider(value: $settings.burstIntervalSeconds, in: 30.0...60.0, step: 15.0)
                        Text("\(Int(settings.burstIntervalSeconds)) sec")
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                            .frame(width: 65, alignment: .trailing)
                    }
                    .padding(6)
                }
            }
        }
    }

    private func samplingModeCard(_ mode: CameraSamplingMode) -> some View {
        let isSelected = settings.samplingMode == mode
        return Button {
            settings.samplingMode = mode
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(mode.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(mode.badgeText)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                            .clipShape(Capsule())
                    }
                    Text(mode.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Slouching Feedback Preferences Question

    private var feedbackPreferencesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Step 2 of 3 • Slouching Feedback Preferences")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accentColor)
                Text("How should PostureBar nudge you when you slouch?")
                    .font(.title2.weight(.bold))
                Text("Select one or more feedback styles below. You can test each one right now:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                feedbackOptionRow(
                    isEnabled: $settings.enableNotificationBanner,
                    icon: "bell.badge.fill",
                    title: "Send a macOS Notification Banner",
                    subtitle: "Displays a native banner with the specific posture issue (e.g., Slouching Down or Leaning Too Close).",
                    previewAction: { FeedbackCoordinator.shared.triggerTestNotification() }
                )

                feedbackOptionRow(
                    isEnabled: $settings.enableSubtleSound,
                    icon: "speaker.wave.2.fill",
                    title: "Play a Subtle Audio Chime",
                    subtitle: "Plays a soft macOS system sound when sustained slouching is detected.",
                    previewAction: { FeedbackCoordinator.shared.triggerTestSound() }
                )

                feedbackOptionRow(
                    isEnabled: $settings.enableScreenDimBlur,
                    icon: "sparkles.rectangle.stack.fill",
                    title: "Gently Dim / Blur the Screen",
                    subtitle: "Gradually applies a click-through dim/frosted blur overlay that clears the instant you sit up straight.",
                    previewAction: { FeedbackCoordinator.shared.triggerTestScreenDimBlur() }
                )
            }

            if settings.enableScreenDimBlur {
                HStack {
                    Text("Overlay Effect Style:")
                        .font(.subheadline.weight(.medium))
                    Picker("", selection: Binding(
                        get: { settings.screenOverlayStyle },
                        set: { settings.screenOverlayStyle = $0 }
                    )) {
                        ForEach(ScreenOverlayStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.top, 4)
            }
        }
    }

    private func feedbackOptionRow(
        isEnabled: Binding<Bool>,
        icon: String,
        title: String,
        subtitle: String,
        previewAction: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Toggle("", isOn: isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)

            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isEnabled.wrappedValue ? .accentColor : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button("Preview") {
                previewAction()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isEnabled.wrappedValue ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Step 3: Live 3-Second Upright Posture Calibration

    private var calibrationStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Step 3 of 3 • Upright Baseline Calibration")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accentColor)
                Text("Lock in your personal ergonomic baseline")
                    .font(.title2.weight(.bold))
                Text("Sit comfortably tall and look straight at the screen. Works even close-up or with headphones.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black)

                CameraPreviewView(session: scheduler.captureSession)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                PoseSkeletonOverlayView(
                    landmarks: scheduler.latestLandmarks,
                    state: scheduler.latestEvaluation.state,
                    baselineY: scheduler.mathEngine.baseline?.mean.headVerticalPositionY
                )

                if scheduler.isCalibrating {
                    VStack(spacing: 12) {
                        if scheduler.calibrationCountdown > 0 {
                            Text("\(scheduler.calibrationCountdown)")
                                .font(.system(size: 64, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(radius: 8)
                            Text("Hold upright posture...")
                                .font(.headline)
                                .foregroundColor(.white)
                        } else {
                            ProgressView()
                                .controlSize(.regular)
                                .tint(.green)
                            Text("Locking in your upright baseline...")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                } else if settings.calibrationSuccess || scheduler.mathEngine.baseline != nil {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.green)
                        Text("Baseline Calibrated!")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(12)
                }
            }
            .frame(height: 230)

            HStack {
                Button {
                    scheduler.startGuidedCalibration { success in
                        Task { @MainActor in
                            AppSettings.shared.calibrationSuccess = success
                        }
                    }
                } label: {
                    Label(
                        scheduler.mathEngine.baseline == nil ? "Start 3-Second Calibration" : "Recalibrate Upright Baseline",
                        systemImage: "camera.metering.center.weighted"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(scheduler.isCalibrating)

                Spacer()

                if scheduler.mathEngine.baseline != nil {
                    Label("Baseline saved", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green)
                }
            }
        }
        .onAppear {
            Task {
                _ = await scheduler.requestCameraPermissionAndConfigure()
                scheduler.startMonitoring()
            }
        }
    }

    // MARK: - Footer Navigation

    private var footerBar: some View {
        HStack {
            if settings.onboardingStep > 0 {
                Button("Back") {
                    withAnimation {
                        settings.onboardingStep -= 1
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if settings.onboardingStep < 2 {
                Button("Continue") {
                    withAnimation {
                        settings.onboardingStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Finish & Pin to Top Menu Bar") {
                    settings.hasCompletedOnboarding = true
                    FeedbackCoordinator.shared.requestNotificationPermissionIfNeeded()
                    scheduler.startMonitoring()
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
                .disabled(scheduler.isCalibrating)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }
}
