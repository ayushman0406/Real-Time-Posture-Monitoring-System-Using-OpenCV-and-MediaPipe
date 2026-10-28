import Foundation
@preconcurrency import AVFoundation
import Combine
import AppKit

/// Manages macOS camera capture with support for both:
/// 1. Continuous Low-FPS mode (1–2 FPS, instant updates, camera light stays on)
/// 2. Periodic Burst mode (opens camera for ~1.2s every 30–60s, powers down completely between checks)
@MainActor
public final class CameraScheduler: NSObject, ObservableObject {
    public static let shared = CameraScheduler()

    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var isCalibrating: Bool = false
    @Published public private(set) var calibrationProgress: Double = 0.0
    @Published public private(set) var calibrationCountdown: Int = 3
    @Published public private(set) var cameraPermissionGranted: Bool = false
    @Published public private(set) var isCameraHardwareActive: Bool = false
    @Published public private(set) var availableCameras: [AVCaptureDevice] = []
    @Published public private(set) var latestLandmarks: PoseFrameLandmarks?
    @Published public private(set) var latestEvaluation: PostureEvaluation

    // Daily Session Statistics
    @Published public private(set) var goodPostureSamples: Int = 0
    @Published public private(set) var totalTrackedSamples: Int = 0

    public var dailyGoodPosturePercentage: Int {
        guard totalTrackedSamples > 0 else { return 100 }
        return Int((Double(goodPostureSamples) / Double(totalTrackedSamples) * 100.0).rounded())
    }

    nonisolated public let captureSession = AVCaptureSession()
    public let mathEngine = PostureMathEngine()
    nonisolated private let visionProcessor = PoseVisionProcessor()
    nonisolated private let sessionQueue = DispatchQueue(label: "com.posturebar.camera.session", qos: .userInitiated)
    nonisolated private let videoOutput = AVCaptureVideoDataOutput()

    private var lastFrameProcessedTime: TimeInterval = 0
    private var burstTimer: Timer?
    private var burstCollectedFrames: [PoseFrameLandmarks] = []
    private var isCollectingBurst: Bool = false

    private var calibrationSamples: [BiomechanicalMetrics] = []
    private let targetCalibrationSamples: Int = 18

    private override init() {
        let initialState: PostureState = mathEngine.baseline == nil ? .uncalibrated : .paused
        self.latestEvaluation = PostureEvaluation(
            timestamp: Date().timeIntervalSince1970,
            rawScore: 100,
            smoothedScore: 100,
            state: initialState,
            primaryIssue: nil,
            activeIssues: [],
            metrics: nil,
            componentPenalties: [:],
            slouchSeverity: 0
        )
        super.init()
        refreshAvailableCameras()
        checkCameraPermission()
    }

    public func refreshAvailableCameras() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discovery.devices
    }

    public func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.cameraPermissionGranted = granted
                }
            }
        default:
            cameraPermissionGranted = false
        }
    }

    public func requestCameraPermissionAndConfigure() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            cameraPermissionGranted = true
            configureSessionIfNeeded()
            return true
        } else if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermissionGranted = granted
            if granted {
                configureSessionIfNeeded()
            }
            return granted
        } else {
            cameraPermissionGranted = false
            return false
        }
    }

    private var isSessionConfigured = false

    private func configureSessionIfNeeded() {
        guard !isSessionConfigured else { return }
        refreshAvailableCameras()

        let preferredID = AppSettings.shared.selectedCameraID
        let selectedDevice = availableCameras.first(where: { $0.uniqueID == preferredID })
            ?? AVCaptureDevice.default(for: .video)
            ?? availableCameras.first

        guard let camera = selectedDevice else { return }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .vga640x480

            for input in self.captureSession.inputs {
                self.captureSession.removeInput(input)
            }

            if let input = try? AVCaptureDeviceInput(device: camera),
               self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }

            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)

            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }

            self.captureSession.commitConfiguration()
            Task { @MainActor in
                self.isSessionConfigured = true
            }
        }
    }

    // MARK: - Start / Stop / Mode Switching

    public func startMonitoring() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let granted = await self.requestCameraPermissionAndConfigure()
            guard granted else { return }

            self.isMonitoring = true
            self.burstTimer?.invalidate()
            self.burstTimer = nil

            let mode = AppSettings.shared.samplingMode
            switch mode {
            case .continuousLowFPS:
                self.startCameraHardware()
            case .periodicBurst:
                self.runSingleBurstCheck()
                let interval = max(10.0, AppSettings.shared.burstIntervalSeconds)
                self.burstTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        self?.runSingleBurstCheck()
                    }
                }
            }
        }
    }

    public func stopMonitoring() {
        isMonitoring = false
        isCollectingBurst = false
        burstTimer?.invalidate()
        burstTimer = nil
        stopCameraHardware()
        FeedbackCoordinator.shared.clearAllActiveAlerts()

        latestEvaluation = PostureEvaluation(
            timestamp: Date().timeIntervalSince1970,
            rawScore: latestEvaluation.rawScore,
            smoothedScore: latestEvaluation.smoothedScore,
            state: mathEngine.baseline == nil ? .uncalibrated : .paused,
            primaryIssue: nil,
            activeIssues: [],
            metrics: latestEvaluation.metrics,
            componentPenalties: [:],
            slouchSeverity: 0
        )
    }

    public func applyUpdatedSamplingSettings() {
        guard isMonitoring else { return }
        startMonitoring()
    }

    // MARK: - 3-Second Guided Baseline Calibration

    public func startGuidedCalibration(completion: (@Sendable (Bool) -> Void)? = nil) {
        Task { @MainActor in
            let granted = await requestCameraPermissionAndConfigure()
            guard granted else {
                completion?(false)
                return
            }

            isCalibrating = true
            calibrationProgress = 0.0
            calibrationCountdown = 3
            calibrationSamples.removeAll()
            startCameraHardware()

            // 3-second countdown before sampling
            for remaining in [3, 2, 1] {
                calibrationCountdown = remaining
                try? await Task.sleep(nanoseconds: 850_000_000)
            }
            calibrationCountdown = 0

            // Wait up to 4 seconds to collect ~18 clean frames
            var waitedIterations = 0
            while isCalibrating && waitedIterations < 45 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                waitedIterations += 1
            }

            if isCalibrating {
                finishCalibration(completion: completion)
            }
        }
    }

    private func finishCalibration(completion: (@Sendable (Bool) -> Void)? = nil) {
        isCalibrating = false
        guard !calibrationSamples.isEmpty else {
            if !isMonitoring { stopCameraHardware() }
            completion?(false)
            return
        }

        _ = mathEngine.calibrate(with: calibrationSamples)
        calibrationProgress = 1.0

        if isMonitoring {
            applyUpdatedSamplingSettings()
        } else {
            startMonitoring()
        }
        completion?(true)
    }

    // MARK: - Periodic Burst Check (1s Active Camera -> Power Down)

    private func runSingleBurstCheck() {
        guard isMonitoring, !isCalibrating else { return }
        isCollectingBurst = true
        burstCollectedFrames.removeAll()
        startCameraHardware()

        // Keep camera active for ~1.25s to allow auto-exposure to settle and collect 5 frames, then shut off hardware
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard self.isCollectingBurst, !self.isCalibrating else { return }
            self.isCollectingBurst = false

            let evaluation = self.mathEngine.evaluateBurst(
                frames: self.burstCollectedFrames,
                sensitivity: AppSettings.shared.sensitivity
            )
            self.recordEvaluation(evaluation)

            if AppSettings.shared.samplingMode == .periodicBurst && !self.isCalibrating {
                self.stopCameraHardware()
            }
        }
    }

    private func startCameraHardware() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
            let running = self.captureSession.isRunning
            Task { @MainActor in
                self.isCameraHardwareActive = running
            }
        }
    }

    private func stopCameraHardware() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            Task { @MainActor in
                self.isCameraHardwareActive = false
            }
        }
    }

    private func recordEvaluation(_ evaluation: PostureEvaluation) {
        self.latestEvaluation = evaluation
        if evaluation.state == .good || evaluation.state == .drifting || evaluation.state == .slouching {
            totalTrackedSamples += 1
            if evaluation.state == .good {
                goodPostureSamples += 1
            }
        }
        FeedbackCoordinator.shared.handlePostureEvaluation(evaluation)
    }
}

extension CameraScheduler: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date().timeIntervalSince1970
        let landmarks = self.visionProcessor.processSampleBuffer(sampleBuffer)

        Task { @MainActor in
            // Determine target frame interval based on state
            let minInterval: TimeInterval = {
                if self.isCalibrating {
                    return 0.10 // 10 FPS during 3-second calibration
                } else if self.isCollectingBurst {
                    return 0.18 // ~5 frames over 1s burst
                } else {
                    let fps = max(0.5, min(5.0, AppSettings.shared.continuousFPS))
                    return 1.0 / fps
                }
            }()

            guard now - self.lastFrameProcessedTime >= minInterval else { return }
            self.lastFrameProcessedTime = now
            self.latestLandmarks = landmarks

            if self.isCalibrating, self.calibrationCountdown == 0 {
                if let lm = landmarks, let metrics = PostureMathEngine.extractMetrics(from: lm) {
                    self.calibrationSamples.append(metrics)
                    self.calibrationProgress = min(1.0, Double(self.calibrationSamples.count) / Double(self.targetCalibrationSamples))
                    if self.calibrationSamples.count >= self.targetCalibrationSamples {
                        self.finishCalibration()
                    }
                }
            } else if self.isCollectingBurst {
                if let lm = landmarks {
                    self.burstCollectedFrames.append(lm)
                }
            } else if self.isMonitoring && AppSettings.shared.samplingMode == .continuousLowFPS {
                let evaluation = self.mathEngine.evaluate(
                    frame: landmarks,
                    sensitivity: AppSettings.shared.sensitivity,
                    slouchGracePeriod: AppSettings.shared.slouchGracePeriodSeconds
                )
                self.recordEvaluation(evaluation)
            }
        }
    }
}
