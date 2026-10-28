import SwiftUI
import AVFoundation

/// Live camera preview with real-time face & upper-body alignment overlay tailored for MacBook webcams.
public struct CameraPreviewView: NSViewRepresentable {
    public let session: AVCaptureSession

    public init(session: AVCaptureSession) {
        self.session = session
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        previewLayer.connection?.isVideoMirrored = true
        view.layer = previewLayer
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        if let layer = nsView.layer as? AVCaptureVideoPreviewLayer {
            layer.session = session
        }
    }
}

/// Draws clean face bounding guides, eye-level horizon line, nose alignment axis, and baseline height reference
/// that work accurately even when sitting very close to the MacBook camera or wearing over-ear headphones.
public struct PoseSkeletonOverlayView: View {
    public let landmarks: PoseFrameLandmarks?
    public let state: PostureState
    public let baselineY: Double?

    public init(landmarks: PoseFrameLandmarks?, state: PostureState, baselineY: Double? = nil) {
        self.landmarks = landmarks
        self.state = state
        self.baselineY = baselineY
    }

    private var strokeColor: Color {
        switch state {
        case .good: return .green
        case .drifting: return .orange
        case .slouching: return .red
        default: return .cyan
        }
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // 1. Draw target calibrated eye-level horizon line if calibrated
            if let refY = baselineY {
                let targetScreenY = (1.0 - CGFloat(refY)) * h
                Path { path in
                    path.move(to: CGPoint(x: 16, y: targetScreenY))
                    path.addLine(to: CGPoint(x: w - 16, y: targetScreenY))
                }
                .stroke(Color.green.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }

            if let lm = landmarks {
                // 2. Face bounding box guide (primary detector for close-up laptop webcams)
                if let bbox = lm.faceBoundingBox {
                    let rect = CGRect(
                        x: bbox.origin.x * w,
                        y: (1.0 - bbox.origin.y - bbox.size.height) * h,
                        width: bbox.size.width * w,
                        height: bbox.size.height * h
                    )
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(strokeColor, style: StrokeStyle(lineWidth: 2.5))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }

                // 3. Eye-line & Nose T-Axis (shows head level, tilt, and pitch clearly without needing ears)
                if let lEye = lm.leftEye, let rEye = lm.rightEye {
                    let lPt = CGPoint(x: lEye.x * w, y: (1.0 - lEye.y) * h)
                    let rPt = CGPoint(x: rEye.x * w, y: (1.0 - rEye.y) * h)
                    let eyeMid = CGPoint(x: (lPt.x + rPt.x) * 0.5, y: (lPt.y + rPt.y) * 0.5)

                    Path { path in
                        path.move(to: lPt)
                        path.addLine(to: rPt)
                        if let nose = lm.nose {
                            let nosePt = CGPoint(x: nose.x * w, y: (1.0 - nose.y) * h)
                            path.move(to: eyeMid)
                            path.addLine(to: nosePt)
                        }
                    }
                    .stroke(strokeColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    Circle().fill(strokeColor).frame(width: 8, height: 8).position(lPt)
                    Circle().fill(strokeColor).frame(width: 8, height: 8).position(rPt)
                }

                if let nose = lm.nose {
                    let nosePt = CGPoint(x: nose.x * w, y: (1.0 - nose.y) * h)
                    Circle().fill(strokeColor).frame(width: 9, height: 9).position(nosePt)
                }

                // 4. Optional Shoulder Line (only drawn when shoulders are genuinely visible in frame)
                if let lSh = lm.leftShoulder, let rSh = lm.rightShoulder {
                    let lShPt = CGPoint(x: lSh.x * w, y: (1.0 - lSh.y) * h)
                    let rShPt = CGPoint(x: rSh.x * w, y: (1.0 - rSh.y) * h)
                    Path { path in
                        path.move(to: lShPt)
                        path.addLine(to: rShPt)
                    }
                    .stroke(strokeColor.opacity(0.75), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    Circle().fill(strokeColor).frame(width: 8, height: 8).position(lShPt)
                    Circle().fill(strokeColor).frame(width: 8, height: 8).position(rShPt)
                }
            }
        }
    }
}
