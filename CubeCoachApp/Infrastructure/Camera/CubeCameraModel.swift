import SwiftUI
@preconcurrency import AVFoundation

@MainActor
public final class CubeCameraModel: ObservableObject {
    @Published public private(set) var availability: CubeCameraAvailability = .idle
    @Published public private(set) var liveRectangleCandidateCount = 0
    @Published public private(set) var liveCaptureAssessment: CubeLiveCaptureAssessment?
    @Published public private(set) var analysisWarning: String?
    @Published public private(set) var isRunning = false
    @Published public private(set) var isCapturing = false

    let engine: CubeCameraSessionEngine

    public init() {
        let engine = CubeCameraSessionEngine()
        self.engine = engine
        engine.onRectangleCandidates = { [weak self] count in
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                self.liveRectangleCandidateCount = count
                self.analysisWarning = nil
            }
        }
        engine.onLiveCaptureAssessment = { [weak self] assessment in
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                self.liveCaptureAssessment = assessment
            }
        }
        engine.onVisionAnalysisFailure = { [weak self] in
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                self.liveCaptureAssessment = nil
                self.analysisWarning = "화면 분석을 다시 시도하고 있어요."
            }
        }
    }

    public func prepare() async {
        guard availability != .requestingPermission else { return }
        if availability == .ready {
            analysisWarning = nil
            start()
            return
        }

        #if targetEnvironment(simulator)
        clearLiveAnalysis()
        availability = .unavailable("시뮬레이터에서는 카메라를 사용할 수 없어요.")
        return
        #else
        let isAuthorized: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            availability = .requestingPermission
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }

        guard isAuthorized else {
            clearLiveAnalysis()
            availability = .denied
            return
        }

        availability = .requestingPermission
        analysisWarning = nil
        do {
            try await engine.configure()
            availability = .ready
            start()
        } catch let error as CubeCameraSessionError {
            clearLiveAnalysis()
            availability = .unavailable(error.localizedDescription)
        } catch {
            clearLiveAnalysis()
            availability = .failed("카메라를 준비하지 못했어요.\n전개도에 직접 입력할 수 있어요.")
        }
        #endif
    }

    public func start() {
        guard availability == .ready else { return }
        clearLiveAnalysis()
        engine.start()
        isRunning = true
    }

    public func stop() {
        engine.stop()
        isRunning = false
        clearLiveAnalysis()
    }

    #if DEBUG
    /// Displays the camera guide against an empty preview in simulator UI QA.
    /// This never runs in release builds and does not configure capture input.
    public func showGuidePreviewForUITesting() {
        clearLiveAnalysis()
        availability = .ready
    }
    #endif

    public func capture() async throws -> CubePhotoAnalysis {
        guard availability == .ready else {
            throw CubeCameraSessionError.notReady
        }
        guard !isCapturing else {
            throw CubeCameraSessionError.captureInProgress
        }
        isCapturing = true
        defer { isCapturing = false }
        return try await engine.capturePhoto()
    }

    /// Captures and samples the three faces positioned inside the portrait
    /// guide. It does not search the full image for an arbitrary cube.
    public func capture(pose: CubeCapturePose) async throws -> CubePhotoAnalysis {
        guard availability == .ready else {
            throw CubeCameraSessionError.notReady
        }
        guard !isCapturing else {
            throw CubeCameraSessionError.captureInProgress
        }
        isCapturing = true
        defer { isCapturing = false }
        return try await engine.capturePhoto(pose: pose)
    }

    /// Captures the requested face head-on using its standard top-edge
    /// orientation and the central square portrait guide.
    public func capture(face: CubeFace) async throws -> CubePhotoAnalysis {
        guard availability == .ready else {
            throw CubeCameraSessionError.notReady
        }
        guard !isCapturing else {
            throw CubeCameraSessionError.captureInProgress
        }
        isCapturing = true
        defer { isCapturing = false }
        return try await engine.capturePhoto(face: face)
    }

    private func clearLiveAnalysis() {
        liveRectangleCandidateCount = 0
        liveCaptureAssessment = nil
        analysisWarning = nil
    }
}

public struct CubeCameraPreview: UIViewRepresentable {
    @ObservedObject private var camera: CubeCameraModel

    public init(camera: CubeCameraModel) {
        self.camera = camera
    }

    public func makeUIView(context: Context) -> CubeCameraPreviewView {
        let view = CubeCameraPreviewView()
        view.previewLayer.session = camera.engine.session
        return view
    }

    public func updateUIView(_ uiView: CubeCameraPreviewView, context: Context) {
        uiView.previewLayer.session = camera.engine.session
    }
}

public final class CubeCameraPreviewView: UIView {
    public override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    public var previewLayer: AVCaptureVideoPreviewLayer {
        let layer = layer as! AVCaptureVideoPreviewLayer
        layer.videoGravity = .resizeAspectFill
        return layer
    }
}
