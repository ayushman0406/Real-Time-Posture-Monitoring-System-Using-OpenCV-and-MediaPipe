import SwiftUI
import AppKit

@main
public struct PostureBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var scheduler = CameraScheduler.shared

    public init() {}

    public var body: some Scene {
        // 1. Native macOS Top Menu Bar Extra (Clean icon only — no percentage clutter)
        MenuBarExtra {
            MenuBarPopoverView()
        } label: {
            Image(systemName: menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)

        // 2. Setup & Onboarding Wizard Window
        Window("PostureBar Setup & Preferences", id: "onboarding-setup") {
            OnboardingView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    private var menuBarSymbolName: String {
        if !scheduler.isMonitoring {
            return "pause.circle"
        }
        return scheduler.latestEvaluation.state.symbolName
    }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a pure menu bar accessory app (no clutter in the Dock)
        NSApp.setActivationPolicy(.accessory)

        let settings = AppSettings.shared
        let scheduler = CameraScheduler.shared

        if !settings.hasCompletedOnboarding || scheduler.mathEngine.baseline == nil {
            showOnboardingWindow()
        } else {
            FeedbackCoordinator.shared.requestNotificationPermissionIfNeeded()
            scheduler.startMonitoring()
        }
    }

    public func showOnboardingWindow() {
        if let existing = onboardingWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: OnboardingView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PostureBar Setup"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.onboardingWindow = window
    }
}
