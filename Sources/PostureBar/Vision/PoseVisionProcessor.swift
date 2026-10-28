import Foundation
import Vision
import CoreMedia
import CoreImage

/// Extracts both Face Landmarks (primary for close-up laptop webcams, unaffected by headphones or clipped shoulders)
/// and Upper-Body Pose Landmarks (secondary when shoulders are visible in frame).
public final class PoseVisionProcessor: Sendable {
    private let minimumBodyJointConfidence: Float = 0.25

    public init() {}

    public func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> PoseFrameLandmarks? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        return processPixelBuffer(pixelBuffer)
    }

    public func processPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> PoseFrameLandmarks? {
        let faceLandmarksRequest = VNDetectFaceLandmarksRequest()
        let faceRectanglesRequest = VNDetectFaceRectanglesRequest()
        let bodyPoseRequest = VNDetectHumanBodyPoseRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .upMirrored, options: [:])
        do {
            try handler.perform([faceLandmarksRequest, faceRectanglesRequest, bodyPoseRequest])
        } catch {
            return nil
        }

        // 1. Primary Signal: Face Detection (Works even when very close to the camera or when shoulders/ears are cropped/covered)
        let faceObs = faceLandmarksRequest.results?.first ?? faceRectanglesRequest.results?.first

        var faceCenter: CGPoint? = nil
        var faceBox: CGRect? = nil
        var leftEyePoint: CGPoint? = nil
        var rightEyePoint: CGPoint? = nil
        var nosePoint: CGPoint? = nil
        var interOcularDistance: Double? = nil
        var faceScaleProxy: Double? = nil
        var facePitchRadians: Double? = nil
        var faceRollRadians: Double? = nil
        var faceYawRadians: Double? = nil
        var faceConfidence: Float = 0.0

        if let face = faceObs {
            let bbox = face.boundingBox
            faceBox = bbox
            faceConfidence = face.confidence
            faceCenter = CGPoint(x: bbox.midX, y: bbox.midY)
            facePitchRadians = face.pitch?.doubleValue
            faceRollRadians = face.roll?.doubleValue
            faceYawRadians = face.yaw?.doubleValue

            // Helper to convert landmark point normalized within face boundingBox to full-frame normalized coordinates
            func toFramePoint(_ pt: CGPoint) -> CGPoint {
                CGPoint(
                    x: bbox.origin.x + pt.x * bbox.size.width,
                    y: bbox.origin.y + pt.y * bbox.size.height
                )
            }

            func centroid(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
                guard let pts = region?.normalizedPoints, !pts.isEmpty else { return nil }
                let sumX = pts.reduce(0.0) { $0 + Double($1.x) }
                let sumY = pts.reduce(0.0) { $0 + Double($1.y) }
                let avg = CGPoint(x: sumX / Double(pts.count), y: sumY / Double(pts.count))
                return toFramePoint(avg)
            }

            if let landmarks = face.landmarks {
                leftEyePoint = centroid(landmarks.leftPupil) ?? centroid(landmarks.leftEye)
                rightEyePoint = centroid(landmarks.rightPupil) ?? centroid(landmarks.rightEye)
                nosePoint = centroid(landmarks.noseCrest) ?? centroid(landmarks.nose)

                if let lEye = leftEyePoint, let rEye = rightEyePoint {
                    let iod = hypot(Double(lEye.x - rEye.x), Double(lEye.y - rEye.y))
                    if iod > 0.01 {
                        interOcularDistance = iod
                    }
                    // If roll wasn't populated by Vision, compute it directly from the eye line
                    if faceRollRadians == nil {
                        faceRollRadians = atan2(Double(rEye.y - lEye.y), Double(rEye.x - lEye.x))
                    }
                }
            }

            // Robust scale proxy combining bounding-box size and inter-ocular distance
            let boxSpan = hypot(Double(bbox.width), Double(bbox.height)) * 0.5
            if let iod = interOcularDistance {
                faceScaleProxy = 0.65 * iod + 0.35 * (boxSpan * 0.38)
            } else {
                faceScaleProxy = boxSpan * 0.38
            }
        }

        // 2. Secondary Signal: Body Pose (Used when shoulders are visible and not clipped by the bottom of the frame)
        var leftShoulder: CGPoint? = nil
        var rightShoulder: CGPoint? = nil
        var neckPoint: CGPoint? = nil
        var bodyConfidence: Float = 0.0

        if let bodyObs = bodyPoseRequest.results?.first {
            func jointPoint(_ name: VNHumanBodyPoseObservation.JointName) -> (CGPoint, Float)? {
                guard let point = try? bodyObs.recognizedPoint(name),
                      point.confidence >= minimumBodyJointConfidence else {
                    return nil
                }
                return (CGPoint(x: point.location.x, y: point.location.y), point.confidence)
            }

            if nosePoint == nil, let (bNose, _) = jointPoint(.nose) {
                nosePoint = bNose
            }

            if let (lSh, lConf) = jointPoint(.leftShoulder),
               let (rSh, rConf) = jointPoint(.rightShoulder) {
                let shWidth = hypot(Double(lSh.x - rSh.x), Double(lSh.y - rSh.y))
                // Only trust body shoulders if they are reasonably spaced and below the face/nose
                let noseY = Double(nosePoint?.y ?? faceCenter?.y ?? 0.65)
                let shMidY = Double(lSh.y + rSh.y) * 0.5
                if shWidth > 0.12 && shMidY < noseY - 0.06 {
                    leftShoulder = lSh
                    rightShoulder = rSh
                    bodyConfidence = (lConf + rConf) * 0.5
                }
            }

            if let (neck, _) = jointPoint(.neck) {
                neckPoint = neck
            }
        }

        // Succeed if EITHER the face is detected (even very close up!) OR valid shoulders + nose are detected
        let hasValidFace = (faceBox != nil && faceConfidence >= 0.35)
        let hasValidBody = (leftShoulder != nil && rightShoulder != nil && nosePoint != nil)

        guard hasValidFace || hasValidBody else {
            return nil
        }

        let overallConfidence = hasValidFace ? Double(max(faceConfidence, bodyConfidence)) : Double(bodyConfidence)

        return PoseFrameLandmarks(
            timestamp: Date().timeIntervalSince1970,
            faceBoundingBox: faceBox,
            faceCenter: faceCenter,
            leftEye: leftEyePoint,
            rightEye: rightEyePoint,
            nose: nosePoint ?? faceCenter,
            neck: neckPoint,
            leftShoulder: leftShoulder,
            rightShoulder: rightShoulder,
            interOcularDistance: interOcularDistance,
            faceScaleProxy: faceScaleProxy,
            facePitchRadians: facePitchRadians,
            faceRollRadians: faceRollRadians,
            faceYawRadians: faceYawRadians,
            averageConfidence: overallConfidence
        )
    }
}
