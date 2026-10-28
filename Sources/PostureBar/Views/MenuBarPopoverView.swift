import SwiftUI

/// Rich macOS Menu Bar popover displayed when clicking the PostureBar icon next to the battery/Wi-Fi icons.
/// Uses clean status badges and posture issue indicators instead of percentage bars.
public struct MenuBarPopoverView: View {
    @ObservedObject private var scheduler = CameraScheduler.shared
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.openWindow) private var openWindow

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Status Badge Header (No percentage ring)
            statusHeaderSection

            Divider()

            // Optional Collapsible Live Camera & Alignment Guide View
            if settings.showCameraFeedInPopover {
                ZStack {
                    CameraPreviewView(session: scheduler.captureSession)
                        .frame(height: 165)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    PoseSkeletonOverlayView(
                        landmarks: scheduler.latestLandmarks,
                        state: scheduler.latestEvaluation.state,
                        baselineY: scheduler.mathEngine.baseline?.mean.headVerticalPositionY
                    )
                    .frame(height: 165)
                }
            }

            // Real-Time Posture Checks & Sensitivity Selector
            postureCheckSection

            Divider()

            // Quick Mode & Feedback Toggles
            quickPreferencesSection

            Divider()

            // Action Buttons (Recalibrate, Setup Wizard, Pause, Quit)
            bottomActionsSection
        }
        .padding(16)
        .frame(width: 350)
    }

    // MARK: - Top Status Header (Clean Icon Badge — No Percentage Bar)

    private var statusHeaderSection: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(statusColor.opacity(0.16))
                    .frame(width: 48, height: 48)
                Image(systemName: scheduler.latestEvaluation.state.symbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(scheduler.latestEvaluation.state.rawValue)
                        .font(.headline)
                        .foregroundColor(statusColor == .secondary ? .primary : statusColor)
                    Spacer()
                    // Camera Hardware Indicator Pill
                    HStack(spacing: 4) {
                        Circle()
                            .fill(scheduler.isCameraHardwareActive ? Color.green : Color.secondary.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text(scheduler.isCameraHardwareActive ? "CAM ON" : "CAM IDLE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                }

                Text(scheduler.latestEvaluation.summaryText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusColor: Color {
        switch scheduler.latestEvaluation.state {
        case .good: return .green
        case .drifting: return .orange
        case .slouching: return .red
        case .away, .paused, .uncalibrated: return .secondary
        }
    }

    // MARK: - Live Posture Alignment Checks & Sensitivity

    private var postureCheckSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Live Alignment Checks")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("Sensitivity", selection: Binding(
                    get: { settings.sensitivity },
                    set: { settings.sensitivity = $0 }
                )) {
                    ForEach(PostureSensitivity.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.mini)
                .frame(width: 165)
            }

            if scheduler.mathEngine.baseline != nil && scheduler.latestEvaluation.metrics != nil {
                let penalties = scheduler.latestEvaluation.componentPenalties
                HStack(spacing: 8) {
                    checkStatusPill(
                        label: "Height / Spine",
                        isSlouching: (penalties[.verticalSlouch] ?? 0) >= 0.25
                    )
                    checkStatusPill(
                        label: "Screen Distance",
                        isSlouching: (penalties[.forwardHeadJut] ?? 0) >= 0.25
                    )
                    checkStatusPill(
                        label: "Head Level",
                        isSlouching: ((penalties[.downwardChinDrop] ?? 0) >= 0.25) || ((penalties[.lateralTilt] ?? 0) >= 0.25) || ((penalties[.offCenterLean] ?? 0) >= 0.25)
                    )
                }
            } else {
                Text(scheduler.mathEngine.baseline == nil
                     ? "Click 'Recalibrate (3s)' below while sitting upright to lock in your posture baseline."
                     : "Make sure your face is visible to the camera.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func checkStatusPill(label: String, isSlouching: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: isSlouching ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(isSlouching ? .red : .green)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSlouching ? Color.red.opacity(0.12) : Color.green.opacity(0.10))
        )
    }

    // MARK: - Quick Mode & Feedback Toggles

    private var quickPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sampling Mode")
                    .font(.caption.weight(.medium))
                Spacer()
                Picker("", selection: Binding(
                    get: { settings.samplingMode },
                    set: { newValue in
                        settings.samplingMode = newValue
                        scheduler.applyUpdatedSamplingSettings()
                    }
                )) {
                    Text("1–2 FPS Live").tag(CameraSamplingMode.continuousLowFPS)
                    Text("Burst (\(Int(settings.burstIntervalSeconds))s)").tag(CameraSamplingMode.periodicBurst)
                }
                .pickerStyle(.segmented)
                .frame(width: 195)
            }

            HStack(spacing: 8) {
                feedbackTogglePill(
                    title: "Banner",
                    icon: "bell.fill",
                    isOn: $settings.enableNotificationBanner
                )
                feedbackTogglePill(
                    title: "Sound",
                    icon: "speaker.wave.2.fill",
                    isOn: $settings.enableSubtleSound
                )
                feedbackTogglePill(
                    title: "Dim/Blur",
                    icon: "sparkles.rectangle.stack.fill",
                    isOn: Binding(
                        get: { settings.enableScreenDimBlur },
                        set: { val in
                            settings.enableScreenDimBlur = val
                            if !val { ScreenOverlayWindowController.shared.hideOverlays() }
                        }
                    )
                )
            }
        }
    }

    private func feedbackTogglePill(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isOn.wrappedValue ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))
            )
            .foregroundColor(isOn.wrappedValue ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Actions

    private var bottomActionsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    scheduler.startGuidedCalibration()
                } label: {
                    Label(
                        scheduler.isCalibrating ? "Calibrating (\(scheduler.calibrationCountdown)s)..." : "Recalibrate (3s)",
                        systemImage: "scope"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(scheduler.isCalibrating)

                Button {
                    if scheduler.isMonitoring {
                        scheduler.stopMonitoring()
                    } else {
                        scheduler.startMonitoring()
                    }
                } label: {
                    Label(
                        scheduler.isMonitoring ? "Pause" : "Resume",
                        systemImage: scheduler.isMonitoring ? "pause.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack {
                Button {
                    settings.showCameraFeedInPopover.toggle()
                } label: {
                    Label(settings.showCameraFeedInPopover ? "Hide Camera" : "Camera View", systemImage: "video")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "onboarding-setup")
                } label: {
                    Label("Setup & Preferences…", systemImage: "slider.horizontal.3")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.top, 2)
        }
    }
}
