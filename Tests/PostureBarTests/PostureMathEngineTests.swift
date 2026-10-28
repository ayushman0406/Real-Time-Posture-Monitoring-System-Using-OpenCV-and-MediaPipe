import XCTest
import CoreGraphics
@testable import PostureBar

final class PostureMathEngineTests: XCTestCase {

    private func makeCloseUpWebcamFrame(
        timestamp: TimeInterval = 1000.0,
        headY: Double = 0.62,
        headX: Double = 0.50,
        scale: Double = 1.0,
        tiltDegrees: Double = 0.0,
        pitchRad: Double = 0.0
    ) -> PoseFrameLandmarks {
        let iod = 0.095 * scale
        let tiltRad = tiltDegrees * (.pi / 180.0)
        let dx = (iod * 0.5) * cos(tiltRad)
        let dy = (iod * 0.5) * sin(tiltRad)

        let lEye = CGPoint(x: headX - dx, y: headY - dy)
        let rEye = CGPoint(x: headX + dx, y: headY + dy)
        let nose = CGPoint(x: headX, y: headY - 0.065 * scale)
        let bbox = CGRect(
            x: headX - 0.16 * scale,
            y: headY - 0.22 * scale,
            width: 0.32 * scale,
            height: 0.40 * scale
        )

        return PoseFrameLandmarks(
            timestamp: timestamp,
            faceBoundingBox: bbox,
            faceCenter: CGPoint(x: headX, y: headY - 0.02 * scale),
            leftEye: lEye,
            rightEye: rEye,
            nose: nose,
            neck: nil,
            leftShoulder: nil, // Simulate close-up MacBook framing where shoulders are clipped!
            rightShoulder: nil,
            interOcularDistance: iod,
            faceScaleProxy: iod,
            facePitchRadians: pitchRad,
            faceRollRadians: tiltRad,
            faceYawRadians: 0.0,
            averageConfidence: 0.95
        )
    }

    func testCloseUpWithoutShouldersDetectsPersonReliably() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let engine = PostureMathEngine(storageDirectory: tempDir)

        let closeFrame = makeCloseUpWebcamFrame(scale: 1.35) // Very close to webcam, no shoulders
        guard let metrics = PostureMathEngine.extractMetrics(from: closeFrame) else {
            XCTFail("Expected valid metrics even when very close to webcam without shoulders visible")
            return
        }
        engine.calibrate(with: [metrics])

        let eval = engine.evaluate(frame: closeFrame, sensitivity: .balanced, slouchGracePeriod: 0)
        XCTAssertEqual(eval.state, .good)
    }

    func testModerateVerticalSlouchTriggersBadPostureEasily() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let engine = PostureMathEngine(storageDirectory: tempDir)

        let baseFrame = makeCloseUpWebcamFrame(headY: 0.62)
        let baseMetrics = PostureMathEngine.extractMetrics(from: baseFrame)!
        engine.calibrate(with: [baseMetrics])

        // Drop head height by 5.8% of frame height (realistic moderate slouch on a MacBook webcam)
        let slouched1 = makeCloseUpWebcamFrame(timestamp: 1001.0, headY: 0.562)
        _ = engine.evaluate(frame: slouched1, sensitivity: .balanced, slouchGracePeriod: 2.0)

        let slouched2 = makeCloseUpWebcamFrame(timestamp: 1004.0, headY: 0.562)
        let eval = engine.evaluate(frame: slouched2, sensitivity: .balanced, slouchGracePeriod: 2.0)

        XCTAssertEqual(eval.state, .slouching)
        XCTAssertEqual(eval.primaryIssue, .verticalSlouch)
    }
}
