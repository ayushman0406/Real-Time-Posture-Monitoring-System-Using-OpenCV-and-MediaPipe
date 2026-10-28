import Foundation
import SwiftUI
import Combine

public enum CameraSamplingMode: String, CaseIterable, Codable, Identifiable {
    case continuousLowFPS = "continuous"
    case periodicBurst = "burst"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .continuousLowFPS:
            return "Continuous Low-FPS (1–2 FPS)"
        case .periodicBurst:
            return "Periodic Burst Check (1s every 30–60s)"
        }
    }

    public var subtitle: String {
        switch self {
        case .continuousLowFPS:
            return "Instant real-time posture status updates. Keeps the green camera indicator on continuously while monitoring."
        case .periodicBurst:
            return "Opens the camera for 1 second at set intervals, then powers it off completely so the camera light stays off ~97% of the time."
        }
    }

    public var badgeText: String {
        switch self {
        case .continuousLowFPS:
            return "Instant Feedback"
        case .periodicBurst:
            return "Maximum Privacy & Battery"
        }
    }
}

public enum PostureSensitivity: String, CaseIterable, Codable, Identifiable {
    case relaxed = "relaxed"
    case balanced = "balanced"
    case strict = "strict"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .relaxed: return "Relaxed"
        case .balanced: return "Balanced"
        case .strict: return "Strict"
        }
    }

    /// Multiplier applied to deviation tolerances (smaller = more sensitive to small posture changes)
    public var toleranceMultiplier: Double {
        switch self {
        case .relaxed: return 1.25
        case .balanced: return 0.90
        case .strict: return 0.65
        }
    }
}

public enum ScreenOverlayStyle: String, CaseIterable, Codable, Identifiable {
    case dim = "dim"
    case blur = "blur"
    case dimAndBlur = "dimAndBlur"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dim: return "Gentle Screen Dim"
        case .blur: return "Subtle Frosted Blur"
        case .dimAndBlur: return "Dim + Subtle Blur"
        }
    }
}

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    @AppStorage("hasCompletedOnboarding") public var hasCompletedOnboarding: Bool = false

    // Camera Sampling Preferences (Asked during Setup)
    @AppStorage("cameraSamplingMode") public var samplingModeRaw: String = CameraSamplingMode.continuousLowFPS.rawValue
    @AppStorage("continuousFPS") public var continuousFPS: Double = 2.0
    @AppStorage("burstIntervalSeconds") public var burstIntervalSeconds: Double = 30.0
    @AppStorage("selectedCameraID") public var selectedCameraID: String = ""

    // Feedback Preferences (Asked during Setup)
    @AppStorage("enableNotificationBanner") public var enableNotificationBanner: Bool = true
    @AppStorage("enableSubtleSound") public var enableSubtleSound: Bool = true
    @AppStorage("enableScreenDimBlur") public var enableScreenDimBlur: Bool = true
    @AppStorage("screenOverlayStyle") public var screenOverlayStyleRaw: String = ScreenOverlayStyle.dimAndBlur.rawValue
    @AppStorage("soundVolume") public var soundVolume: Double = 0.45
    @AppStorage("soundName") public var soundName: String = "Glass"

    // Posture Detection Tuning (Default faster 2.5s response so slouching triggers promptly)
    @AppStorage("postureSensitivity") public var sensitivityRaw: String = PostureSensitivity.balanced.rawValue
    @AppStorage("slouchGracePeriodSeconds") public var slouchGracePeriodSeconds: Double = 2.5
    @AppStorage("notificationCooldownSeconds") public var notificationCooldownSeconds: Double = 30.0

    // UI State
    @Published public var onboardingStep: Int = 0
    @Published public var calibrationSuccess: Bool = false
    @Published public var showCameraFeedInPopover: Bool = false

    public var samplingMode: CameraSamplingMode {
        get { CameraSamplingMode(rawValue: samplingModeRaw) ?? .continuousLowFPS }
        set {
            samplingModeRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    public var sensitivity: PostureSensitivity {
        get { PostureSensitivity(rawValue: sensitivityRaw) ?? .balanced }
        set {
            sensitivityRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    public var screenOverlayStyle: ScreenOverlayStyle {
        get { ScreenOverlayStyle(rawValue: screenOverlayStyleRaw) ?? .dimAndBlur }
        set {
            screenOverlayStyleRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    private init() {}
}
