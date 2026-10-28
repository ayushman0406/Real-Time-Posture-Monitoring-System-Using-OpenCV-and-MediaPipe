import Foundation
import CoreGraphics

/// Raw landmarks extracted from Apple Vision (`VNDetectFaceLandmarksRequest` + `VNDetectHumanBodyPoseRequest`).
/// Designed specifically for laptop webcams where only the head/face and upper collarbones are in frame,
/// and where headphones may cover the ears or sitting close may clip the shoulders.
public struct PoseFrameLandmarks: Sendable, Equatable {
    public let timestamp: TimeInterval
    public let faceBoundingBox: CGRect?
    public let faceCenter: CGPoint?
    public let leftEye: CGPoint?
    public let rightEye: CGPoint?
    public let nose: CGPoint?
    public let neck: CGPoint?
    public let leftShoulder: CGPoint?
    public let rightShoulder: CGPoint?
    public let interOcularDistance: Double?
    public let faceScaleProxy: Double?
    public let facePitchRadians: Double?
    public let faceRollRadians: Double?
    public let faceYawRadians: Double?
    public let averageConfidence: Double

    public init(
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        faceBoundingBox: CGRect? = nil,
        faceCenter: CGPoint? = nil,
        leftEye: CGPoint? = nil,
        rightEye: CGPoint? = nil,
        nose: CGPoint? = nil,
        neck: CGPoint? = nil,
        leftShoulder: CGPoint? = nil,
        rightShoulder: CGPoint? = nil,
        interOcularDistance: Double? = nil,
        faceScaleProxy: Double? = nil,
        facePitchRadians: Double? = nil,
        faceRollRadians: Double? = nil,
        faceYawRadians: Double? = nil,
        averageConfidence: Double = 1.0
    ) {
        self.timestamp = timestamp
        self.faceBoundingBox = faceBoundingBox
        self.faceCenter = faceCenter
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.nose = nose
        self.neck = neck
        self.leftShoulder = leftShoulder
        self.rightShoulder = rightShoulder
        self.interOcularDistance = interOcularDistance
        self.faceScaleProxy = faceScaleProxy
        self.facePitchRadians = facePitchRadians
        self.faceRollRadians = faceRollRadians
        self.faceYawRadians = faceYawRadians
        self.averageConfidence = averageConfidence
    }
}

/// Biomechanical metrics tailored for a MacBook webcam field-of-view.
public struct BiomechanicalMetrics: Codable, Sendable, Equatable {
    /// Vertical height of the head/eyes in the camera frame (0.0 bottom to 1.0 top).
    /// Drops immediately when you slouch down in your chair or slump your spine.
    public let headVerticalPositionY: Double
    /// Horizontal centering of the head in the camera frame (0.0 left to 1.0 right).
    /// Shifts when you lean sideways on an armrest.
    public let headHorizontalPositionX: Double
    /// Apparent size of the face/eyes in the frame.
    /// Increases when you jut your head forward toward the screen ("Tech Neck") or lean into the camera.
    public let headDepthScale: Double
    /// Downward head pitch proxy (combining nose-to-eye vertical geometry and Vision 3D face pitch).
    /// Decreases when your chin drops or you tilt your head downward.
    public let headPitchMetric: Double
    /// Absolute head/shoulder roll tilt in degrees (0° = level eyes and shoulders).
    public let lateralTiltDegrees: Double
    /// Optional neck-to-shoulder vertical extension ratio when shoulders are visible.
    public let shoulderNeckExtension: Double?

    public init(
        headVerticalPositionY: Double,
        headHorizontalPositionX: Double,
        headDepthScale: Double,
        headPitchMetric: Double,
        lateralTiltDegrees: Double,
        shoulderNeckExtension: Double? = nil
    ) {
        self.headVerticalPositionY = headVerticalPositionY
        self.headHorizontalPositionX = headHorizontalPositionX
        self.headDepthScale = headDepthScale
        self.headPitchMetric = headPitchMetric
        self.lateralTiltDegrees = lateralTiltDegrees
        self.shoulderNeckExtension = shoulderNeckExtension
    }
}

/// Stored multi-frame calibration baseline for a user's upright ergonomic posture.
public struct PostureBaseline: Codable, Sendable, Equatable {
    public let capturedAt: Date
    public let sampleCount: Int
    public let mean: BiomechanicalMetrics
    public let stdDev: BiomechanicalMetrics

    public init(capturedAt: Date = Date(), sampleCount: Int, mean: BiomechanicalMetrics, stdDev: BiomechanicalMetrics) {
        self.capturedAt = capturedAt
        self.sampleCount = sampleCount
        self.mean = mean
        self.stdDev = stdDev
    }
}

public enum PostureIssue: String, CaseIterable, Codable, Sendable {
    case verticalSlouch = "Slouching Down"
    case forwardHeadJut = "Leaning Too Close / Tech-Neck"
    case downwardChinDrop = "Head Tilted Down"
    case lateralTilt = "Head / Shoulders Tilted"
    case offCenterLean = "Leaning Sideways"

    public var coachingTip: String {
        switch self {
        case .verticalSlouch:
            return "Sit tall and lengthen your spine upward toward your calibrated height."
        case .forwardHeadJut:
            return "Lean back against your chair and tuck your chin gently away from the screen."
        case .downwardChinDrop:
            return "Lift your chin and look forward so your neck stays neutral."
        case .lateralTilt:
            return "Level your head and shoulders instead of resting on one side."
        case .offCenterLean:
            return "Center your torso and head in front of your screen."
        }
    }
}

public enum PostureState: String, Codable, Sendable {
    case uncalibrated = "Uncalibrated"
    case good = "Good Posture"
    case drifting = "Slight Drift"
    case slouching = "Bad Posture"
    case away = "Away from Desk"
    case paused = "Paused"

    public var symbolName: String {
        switch self {
        case .uncalibrated: return "scope"
        case .good: return "checkmark.circle.fill"
        case .drifting: return "exclamationmark.triangle.fill"
        case .slouching: return "exclamationmark.octagon.fill"
        case .away: return "person.slash"
        case .paused: return "pause.circle"
        }
    }
}

public struct PostureEvaluation: Sendable, Equatable {
    public let timestamp: TimeInterval
    public let rawScore: Double
    public let smoothedScore: Double
    public let state: PostureState
    public let primaryIssue: PostureIssue?
    public let activeIssues: [PostureIssue]
    public let metrics: BiomechanicalMetrics?
    public let componentPenalties: [PostureIssue: Double]
    /// 0.0 (upright) to 1.0 (severe sustained slouch) used to drive screen dimming/blur.
    public let slouchSeverity: Double

    public var summaryText: String {
        switch state {
        case .uncalibrated:
            return "Calibrate your upright sitting position to start."
        case .good:
            return "Sitting upright in your target zone."
        case .drifting:
            if let issue = primaryIssue {
                return "Starting to drift: \(issue.rawValue)."
            }
            return "Posture starting to drift."
        case .slouching:
            if let issue = primaryIssue {
                return "\(issue.rawValue) — \(issue.coachingTip)"
            }
            return "Bad posture detected — sit upright."
        case .away:
            return "Step into view of the camera."
        case .paused:
            return "Posture monitoring is paused."
        }
    }
}

/// Biomechanical posture engine optimized for MacBook webcam framing.
public final class PostureMathEngine {
    public private(set) var baseline: PostureBaseline?
    private var emaScore: Double = 100.0
    private var hasInitializedEMA: Bool = false
    private var lowScoreStartTime: TimeInterval?

    /// Responsive EMA smoothing factor so posture changes register quickly.
    public var emaAlpha: Double = 0.42

    private let baselineFileURL: URL

    public init(storageDirectory: URL? = nil) {
        if let customDir = storageDirectory {
            self.baselineFileURL = customDir.appendingPathComponent("posture_baseline_v2.json")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let folder = appSupport.appendingPathComponent("PostureBar", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.baselineFileURL = folder.appendingPathComponent("posture_baseline_v2.json")
        }
        loadBaselineFromDisk()
    }

    // MARK: - Step 1: Extract Webcam-Resilient Biomechanical Metrics

    public static func extractMetrics(from frame: PoseFrameLandmarks) -> BiomechanicalMetrics? {
        guard frame.averageConfidence >= 0.30 else { return nil }

        // 1. Primary Head Anchor (Eye midpoint -> Face center -> Nose)
        let eyeMidpoint: CGPoint? = {
            if let lEye = frame.leftEye, let rEye = frame.rightEye {
                return CGPoint(x: (lEye.x + rEye.x) * 0.5, y: (lEye.y + rEye.y) * 0.5)
            }
            return nil
        }()

        guard let primaryHeadPt = eyeMidpoint ?? frame.faceCenter ?? frame.nose else {
            return nil
        }

        let headY = Double(primaryHeadPt.y)
        let headX = Double(primaryHeadPt.x)

        // 2. Depth Scale Proxy (Detects leaning in / getting too close to the screen)
        let depthScale: Double = {
            if let scale = frame.faceScaleProxy, scale > 0.01 {
                return scale
            }
            if let iod = frame.interOcularDistance, iod > 0.01 {
                return iod
            }
            if let bbox = frame.faceBoundingBox {
                return Double(hypot(bbox.width, bbox.height)) * 0.20
            }
            if let lSh = frame.leftShoulder, let rSh = frame.rightShoulder {
                return hypot(Double(lSh.x - rSh.x), Double(lSh.y - rSh.y)) * 0.25
            }
            return 0.08
        }()

        // 3. Head Pitch Metric (Detects chin drop / looking down)
        // Combines vertical nose-to-eye ratio within the face and Vision's 3D face pitch angle
        let noseEyeRatio: Double = {
            if let eyeMid = eyeMidpoint, let nose = frame.nose, depthScale > 0.01 {
                // When looking straight ahead, nose is below eyes (nose.y < eyeMid.y).
                // When tilting head down, the vertical distance or pitch shifts downward.
                return Double(nose.y - eyeMid.y) / depthScale
            }
            return -0.65
        }()
        let pitchRad = frame.facePitchRadians ?? 0.0
        let headPitchMetric = noseEyeRatio + (pitchRad * 0.85)

        // 4. Lateral Head / Eye / Shoulder Roll Tilt (Degrees)
        let rollDegrees: Double = {
            if let lEye = frame.leftEye, let rEye = frame.rightEye {
                let dy = abs(Double(rEye.y - lEye.y))
                let dx = max(0.001, abs(Double(rEye.x - lEye.x)))
                return atan2(dy, dx) * (180.0 / .pi)
            }
            if let rollRad = frame.faceRollRadians {
                return abs(rollRad) * (180.0 / .pi)
            }
            if let lSh = frame.leftShoulder, let rSh = frame.rightShoulder {
                let dy = abs(Double(lSh.y - rSh.y))
                let dx = max(0.001, abs(Double(lSh.x - rSh.x)))
                return atan2(dy, dx) * (180.0 / .pi)
            }
            return 0.0
        }()

        // 5. Optional Shoulder-to-Head Extension (when shoulders are cleanly visible in frame)
        let shoulderExtension: Double? = {
            if let lSh = frame.leftShoulder, let rSh = frame.rightShoulder {
                let shWidth = hypot(Double(lSh.x - rSh.x), Double(lSh.y - rSh.y))
                let shMidY = Double(lSh.y + rSh.y) * 0.5
                if shWidth > 0.12 && headY > shMidY + 0.05 {
                    return (headY - shMidY) / shWidth
                }
            }
            return nil
        }()

        return BiomechanicalMetrics(
            headVerticalPositionY: headY,
            headHorizontalPositionX: headX,
            headDepthScale: depthScale,
            headPitchMetric: headPitchMetric,
            lateralTiltDegrees: rollDegrees,
            shoulderNeckExtension: shoulderExtension
        )
    }

    // MARK: - Step 2: Calibrate Upright Baseline

    @discardableResult
    public func calibrate(with samples: [BiomechanicalMetrics]) -> PostureBaseline? {
        guard !samples.isEmpty else { return nil }
        let n = Double(samples.count)

        let extSamples = samples.compactMap(\.shoulderNeckExtension)
        let meanExt: Double? = extSamples.isEmpty ? nil : (extSamples.reduce(0, +) / Double(extSamples.count))

        let mean = BiomechanicalMetrics(
            headVerticalPositionY: samples.map(\.headVerticalPositionY).reduce(0, +) / n,
            headHorizontalPositionX: samples.map(\.headHorizontalPositionX).reduce(0, +) / n,
            headDepthScale: samples.map(\.headDepthScale).reduce(0, +) / n,
            headPitchMetric: samples.map(\.headPitchMetric).reduce(0, +) / n,
            lateralTiltDegrees: samples.map(\.lateralTiltDegrees).reduce(0, +) / n,
            shoulderNeckExtension: meanExt
        )

        let stdDev = BiomechanicalMetrics(
            headVerticalPositionY: 0.02,
            headHorizontalPositionX: 0.025,
            headDepthScale: 0.01,
            headPitchMetric: 0.03,
            lateralTiltDegrees: 1.5,
            shoulderNeckExtension: 0.03
        )

        let newBaseline = PostureBaseline(
            capturedAt: Date(),
            sampleCount: samples.count,
            mean: mean,
            stdDev: stdDev
        )
        self.baseline = newBaseline
        self.emaScore = 100.0
        self.hasInitializedEMA = true
        self.lowScoreStartTime = nil
        saveBaselineToDisk(newBaseline)
        return newBaseline
    }

    // MARK: - Step 3: Evaluate Posture with Tight, Responsive Sensitivity

    public func evaluate(
        frame: PoseFrameLandmarks?,
        sensitivity: PostureSensitivity = .balanced,
        slouchGracePeriod: TimeInterval = 3.0
    ) -> PostureEvaluation {
        let now = frame?.timestamp ?? Date().timeIntervalSince1970

        guard let baseline = self.baseline else {
            return PostureEvaluation(
                timestamp: now,
                rawScore: 0,
                smoothedScore: 0,
                state: .uncalibrated,
                primaryIssue: nil,
                activeIssues: [],
                metrics: nil,
                componentPenalties: [:],
                slouchSeverity: 0
            )
        }

        guard let frame = frame, let metrics = Self.extractMetrics(from: frame) else {
            return PostureEvaluation(
                timestamp: now,
                rawScore: emaScore,
                smoothedScore: emaScore,
                state: .away,
                primaryIssue: nil,
                activeIssues: [],
                metrics: nil,
                componentPenalties: [:],
                slouchSeverity: 0
            )
        }

        let tol = sensitivity.toleranceMultiplier
        let ref = baseline.mean

        // 1. Vertical Slouch Penalty:
        // When you slouch in your chair, your head/eye level drops in the camera frame (headVerticalPositionY decreases).
        // Even a 3.5% frame height drop starts penalizing; a 9% drop triggers a full slouch alert.
        let verticalDrop = max(0.0, ref.headVerticalPositionY - metrics.headVerticalPositionY)
        var verticalPenalty = Self.smoothStepPenalty(
            value: verticalDrop,
            deadzone: 0.022 * tol,
            fullScale: 0.085 * tol
        )

        // If shoulders are also visible and neck extension shrinks, fuse it into vertical slouch
        if let refExt = ref.shoulderNeckExtension, let curExt = metrics.shoulderNeckExtension {
            let extDrop = max(0.0, (refExt - curExt) / max(refExt, 0.20))
            let extPenalty = Self.smoothStepPenalty(value: extDrop, deadzone: 0.04 * tol, fullScale: 0.16 * tol)
            verticalPenalty = max(verticalPenalty, extPenalty)
        }

        // 2. Forward Head Jut / Leaning Too Close Penalty:
        // When you lean forward toward the screen, your apparent face/inter-ocular scale increases relative to baseline.
        // Starts penalizing at +6% larger face scale, full slouch at +18% larger scale.
        let scaleRatio = (metrics.headDepthScale / max(ref.headDepthScale, 0.015)) - 1.0
        let forwardJutPenalty = Self.smoothStepPenalty(
            value: max(0.0, scaleRatio),
            deadzone: 0.055 * tol,
            fullScale: 0.18 * tol
        )

        // 3. Downward Chin / Head Pitch Drop Penalty:
        let pitchDrop = max(0.0, ref.headPitchMetric - metrics.headPitchMetric)
        let pitchPenalty = Self.smoothStepPenalty(
            value: pitchDrop,
            deadzone: 0.06 * tol,
            fullScale: 0.22 * tol
        )

        // 4. Lateral Head / Eye Roll Tilt Penalty (Degrees):
        // Tilting your head onto your hand or leaning sideways starts penalizing at 4.5°, full penalty at 13°.
        let tiltDelta = max(0.0, abs(metrics.lateralTiltDegrees - ref.lateralTiltDegrees))
        let tiltPenalty = Self.smoothStepPenalty(
            value: tiltDelta,
            deadzone: 4.0 * tol,
            fullScale: 12.5 * tol
        )

        // 5. Off-Center Sideways Lean Penalty:
        // Moving your head > 6% horizontally off your calibrated center starts penalizing, full penalty at 16%.
        let horizontalShift = abs(metrics.headHorizontalPositionX - ref.headHorizontalPositionX)
        let offCenterPenalty = Self.smoothStepPenalty(
            value: horizontalShift,
            deadzone: 0.055 * tol,
            fullScale: 0.16 * tol
        )

        let penalties: [PostureIssue: Double] = [
            .verticalSlouch: verticalPenalty,
            .forwardHeadJut: forwardJutPenalty,
            .downwardChinDrop: pitchPenalty,
            .lateralTilt: tiltPenalty,
            .offCenterLean: offCenterPenalty
        ]

        // Make the worst biomechanical violation dominate so ANY single bad posture habit triggers immediately
        let maxSinglePenalty = penalties.values.max() ?? 0.0
        let secondaryPenaltiesSum = penalties.values.sorted(by: >).dropFirst().reduce(0, +)
        let combinedPenalty = min(1.0, maxSinglePenalty + 0.25 * secondaryPenaltiesSum)

        let rawScore = max(0.0, min(100.0, 100.0 * (1.0 - combinedPenalty)))

        if !hasInitializedEMA {
            emaScore = rawScore
            hasInitializedEMA = true
        } else {
            emaScore = emaAlpha * rawScore + (1.0 - emaAlpha) * emaScore
        }

        // Active issues (any component with >= 25% penalty)
        let sortedIssues = penalties
            .filter { $0.value >= 0.25 }
            .sorted { $0.value > $1.value }
            .map(\.key)

        let primaryIssue = sortedIssues.first

        // Tighter Thresholds:
        // Good Posture: >= 85
        // Slight Drift: 75 ..< 85
        // Bad Posture (Slouching): < 75 (previously 62, which was far too forgiving!)
        let slouchThreshold = 75.0
        let driftThreshold = 85.0

        let state: PostureState
        let slouchSeverity: Double

        if rawScore < slouchThreshold || emaScore < slouchThreshold {
            if lowScoreStartTime == nil {
                lowScoreStartTime = now
            }
            let elapsed = now - (lowScoreStartTime ?? now)
            if elapsed >= slouchGracePeriod {
                state = .slouching
                let effectiveScore = min(emaScore, rawScore)
                let deficit = max(0.15, (slouchThreshold - effectiveScore) / slouchThreshold)
                slouchSeverity = min(1.0, max(0.25, deficit * 1.5))
            } else {
                state = .drifting
                slouchSeverity = 0.0
            }
        } else if rawScore < driftThreshold || emaScore < driftThreshold {
            lowScoreStartTime = nil
            state = .drifting
            slouchSeverity = 0.0
        } else {
            lowScoreStartTime = nil
            state = .good
            slouchSeverity = 0.0
        }

        return PostureEvaluation(
            timestamp: now,
            rawScore: rawScore,
            smoothedScore: emaScore,
            state: state,
            primaryIssue: primaryIssue,
            activeIssues: sortedIssues,
            metrics: metrics,
            componentPenalties: penalties,
            slouchSeverity: slouchSeverity
        )
    }

    /// Instantaneous evaluation used in burst mode
    public func evaluateBurst(
        frames: [PoseFrameLandmarks],
        sensitivity: PostureSensitivity = .balanced
    ) -> PostureEvaluation {
        let validMetrics = frames.compactMap { Self.extractMetrics(from: $0) }
        guard !validMetrics.isEmpty, let lastFrame = frames.last else {
            return evaluate(frame: nil, sensitivity: sensitivity, slouchGracePeriod: 0)
        }
        let savedAlpha = emaAlpha
        emaAlpha = 0.75
        defer { emaAlpha = savedAlpha }

        var latestEval = evaluate(frame: lastFrame, sensitivity: sensitivity, slouchGracePeriod: 0)
        for frame in frames {
            latestEval = evaluate(frame: frame, sensitivity: sensitivity, slouchGracePeriod: 0)
        }
        return latestEval
    }

    private static func smoothStepPenalty(value: Double, deadzone: Double, fullScale: Double) -> Double {
        guard value > deadzone else { return 0.0 }
        guard fullScale > deadzone else { return 1.0 }
        let normalized = min(1.0, max(0.0, (value - deadzone) / (fullScale - deadzone)))
        return normalized * normalized * (3.0 - 2.0 * normalized)
    }

    // MARK: - Persistence

    private func saveBaselineToDisk(_ baseline: PostureBaseline) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(baseline) {
            try? data.write(to: baselineFileURL, options: .atomic)
        }
    }

    public func loadBaselineFromDisk() {
        guard FileManager.default.fileExists(atPath: baselineFileURL.path),
              let data = try? Data(contentsOf: baselineFileURL),
              let decoded = try? JSONDecoder().decode(PostureBaseline.self, from: data) else {
            return
        }
        self.baseline = decoded
    }
}
