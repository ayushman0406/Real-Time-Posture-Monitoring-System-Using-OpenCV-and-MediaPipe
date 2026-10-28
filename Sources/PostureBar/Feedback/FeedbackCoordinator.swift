import Foundation
import AppKit
import UserNotifications

/// Coordinates the user's chosen slouching feedback methods:
/// 1. macOS Notification Banner (`UNUserNotificationCenter`)
/// 2. Subtle Audio Sound (`NSSound`)
/// 3. Gentle Screen Dim / Blur Overlay (`ScreenOverlayWindowController`)
@MainActor
public final class FeedbackCoordinator {
    public static let shared = FeedbackCoordinator()

    private var lastNotificationTime: TimeInterval = 0
    private var lastSoundTime: TimeInterval = 0
    private var notificationsAuthorized: Bool = false

    private init() {}

    public func requestNotificationPermissionIfNeeded() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.notificationsAuthorized = granted
            }
        }
    }

    public func handlePostureEvaluation(_ evaluation: PostureEvaluation) {
        let settings = AppSettings.shared
        let now = Date().timeIntervalSince1970

        if evaluation.state == .slouching {
            // 1. Gentle Screen Dim / Blur
            if settings.enableScreenDimBlur {
                ScreenOverlayWindowController.shared.updateOverlay(
                    slouchSeverity: evaluation.slouchSeverity,
                    style: settings.screenOverlayStyle
                )
            } else {
                ScreenOverlayWindowController.shared.hideOverlays()
            }

            // 2. macOS Notification Banner (respecting cooldown)
            if settings.enableNotificationBanner,
               now - lastNotificationTime >= settings.notificationCooldownSeconds {
                lastNotificationTime = now
                sendPostureNotification(issue: evaluation.primaryIssue)
            }

            // 3. Subtle Sound Chime (respecting cooldown)
            if settings.enableSubtleSound,
               now - lastSoundTime >= max(15.0, settings.notificationCooldownSeconds * 0.5) {
                lastSoundTime = now
                playSubtleChime(soundName: settings.soundName, volume: Float(settings.soundVolume))
            }
        } else {
            // Immediately lift screen dim/blur the moment the user sits up
            ScreenOverlayWindowController.shared.hideOverlays()
        }
    }

    public func clearAllActiveAlerts() {
        ScreenOverlayWindowController.shared.hideOverlays()
    }

    // MARK: - Interactive Test Previews (Used in Setup Wizard & Settings)

    public func triggerTestNotification() {
        requestNotificationPermissionIfNeeded()
        sendPostureNotification(issue: .forwardHeadJut, isPreview: true)
    }

    public func triggerTestSound() {
        let settings = AppSettings.shared
        playSubtleChime(soundName: settings.soundName, volume: Float(settings.soundVolume))
    }

    public func triggerTestScreenDimBlur() {
        let style = AppSettings.shared.screenOverlayStyle
        ScreenOverlayWindowController.shared.updateOverlay(slouchSeverity: 0.75, style: style)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            ScreenOverlayWindowController.shared.hideOverlays()
        }
    }

    // MARK: - Internal Helpers

    private func sendPostureNotification(issue: PostureIssue?, isPreview: Bool = false) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        if isPreview {
            content.title = "PostureBar — Alert Preview"
            content.subtitle = PostureIssue.forwardHeadJut.rawValue
            content.body = PostureIssue.forwardHeadJut.coachingTip
        } else if let issue = issue {
            content.title = "Posture Check: \(issue.rawValue)"
            content.body = issue.coachingTip
        } else {
            content.title = "Posture Check: Bad Posture Detected"
            content.body = "Sit tall and return your head to your calibrated upright height."
        }

        let request = UNNotificationRequest(
            identifier: "com.posturebar.alert.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func playSubtleChime(soundName: String, volume: Float) {
        if let sound = NSSound(named: NSSound.Name(soundName)) ?? NSSound(named: NSSound.Name("Glass")) {
            sound.volume = max(0.05, min(1.0, volume))
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
