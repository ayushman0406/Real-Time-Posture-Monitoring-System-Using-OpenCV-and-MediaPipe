import AppKit
import SwiftUI

/// Creates a click-through, non-activating overlay window across all connected displays
/// that gently dims and/or blurs the screen proportionally to how much the user is slouching.
@MainActor
public final class ScreenOverlayWindowController {
    public static let shared = ScreenOverlayWindowController()

    private var overlayWindows: [NSWindow] = []
    private var blurViews: [NSVisualEffectView] = []
    private var dimViews: [NSView] = []
    private var currentIntensity: Double = 0.0

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildOverlayWindows()
            }
        }
    }

    public func updateOverlay(slouchSeverity: Double, style: ScreenOverlayStyle) {
        let clamped = max(0.0, min(1.0, slouchSeverity))
        guard clamped > 0.01 else {
            hideOverlays()
            return
        }

        if overlayWindows.isEmpty {
            rebuildOverlayWindows()
        }

        currentIntensity = clamped

        let targetDimAlpha: CGFloat = {
            switch style {
            case .dim: return CGFloat(0.45 * clamped)
            case .blur: return CGFloat(0.10 * clamped)
            case .dimAndBlur: return CGFloat(0.35 * clamped)
            }
        }()

        let targetBlurAlpha: CGFloat = {
            switch style {
            case .dim: return 0.0
            case .blur, .dimAndBlur: return CGFloat(0.85 * clamped)
            }
        }()

        for (index, window) in overlayWindows.enumerated() {
            if !window.isVisible {
                window.orderFrontRegardless()
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                if index < dimViews.count {
                    dimViews[index].animator().alphaValue = targetDimAlpha
                }
                if index < blurViews.count {
                    blurViews[index].animator().alphaValue = targetBlurAlpha
                }
            }
        }
    }

    public func hideOverlays() {
        guard currentIntensity > 0.0 || overlayWindows.contains(where: { $0.isVisible }) else { return }
        currentIntensity = 0.0

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            for dimView in dimViews {
                dimView.animator().alphaValue = 0.0
            }
            for blurView in blurViews {
                blurView.animator().alphaValue = 0.0
            }
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self = self, self.currentIntensity == 0.0 else { return }
                for window in self.overlayWindows {
                    window.orderOut(nil)
                }
            }
        })
    }

    private func rebuildOverlayWindows() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        blurViews.removeAll()
        dimViews.removeAll()

        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

            let container = NSView(frame: screen.frame)
            container.wantsLayer = true

            let blurView = NSVisualEffectView(frame: container.bounds)
            blurView.autoresizingMask = [.width, .height]
            blurView.blendingMode = .behindWindow
            blurView.material = .hudWindow
            blurView.state = .active
            blurView.alphaValue = 0.0

            let dimView = NSView(frame: container.bounds)
            dimView.autoresizingMask = [.width, .height]
            dimView.wantsLayer = true
            dimView.layer?.backgroundColor = NSColor.black.cgColor
            dimView.alphaValue = 0.0

            container.addSubview(blurView)
            container.addSubview(dimView)
            panel.contentView = container

            overlayWindows.append(panel)
            blurViews.append(blurView)
            dimViews.append(dimView)
        }
    }
}
