import Foundation
@preconcurrency import AVFoundation
@preconcurrency import CoreImage
@preconcurrency import Vision

public enum CubeCameraSessionError: LocalizedError, Sendable {
    case noCamera
    case configurationFailed
    case notReady
    case captureFailed
    case visionAnalysisFailed
    case guidedFaceExtractionFailed

    public var errorDescription: String? {
        switch self {
        case .noCamera: "사용 가능한 후면 카메라가 없어요."
        case .configurationFailed: "카메라 구성을 완료하지 못했어요."
        case .notReady: "카메라가 아직 준비되지 않았어요."
        case .captureFailed: "사진 품질을 확인하지 못했어요. 다시 촬영해 주세요."
        case .visionAnalysisFailed: "사진의 사각형 품질 후보를 분석하지 못했어요. 다시 촬영해 주세요."
        case .guidedFaceExtractionFailed:
            "큐브를 촬영 가이드에 맞춰 다시 촬영해 주세요. 이 기능은 가이드 영역만 분석합니다."
        }
    }
}

public enum CubeGuidedFaceExtractionError: LocalizedError, Equatable, Sendable {
    case invalidImageData
    case invalidPortraitImage(width: Int, height: Int)
    case missingGuideRegion(CubePoseFaceSlot)
    case invalidGuideRegion(CubePoseFaceSlot)
    case perspectiveCorrectionFailed(CubePoseFaceSlot)
    case renderFailed(CubePoseFaceSlot)

    public var errorDescription: String? {
        switch self {
        case .invalidImageData:
            "촬영 이미지를 읽지 못했어요."
        case .invalidPortraitImage:
            "촬영 이미지의 세로 방향을 확인하지 못했어요."
        case .missingGuideRegion, .invalidGuideRegion:
            "3면 촬영 가이드 구성이 올바르지 않아요."
        case .perspectiveCorrectionFailed, .renderFailed:
            "가이드 영역의 색상 표본을 만들지 못했어요."
        }
    }
}

/// Extracts only the three quadrilaterals supplied by the portrait capture
/// guide. It intentionally does not claim to locate a cube in an arbitrary photo.
public enum CubeGuidedFaceExtractor {
    public static func extract(
        jpegData: Data,
        pose: CubeCapturePose,
        layout: CubeGuidedFaceLayout = .portraitThreeFace
    ) throws -> CubePoseObservation {
        let options: [CIImageOption: Any] = [.applyOrientationProperty: true]
        guard let orientedImage = CIImage(data: jpegData, options: options) else {
            throw CubeGuidedFaceExtractionError.invalidImageData
        }
        let extent = orientedImage.extent.integral
        guard extent.width >= 6, extent.height >= 6, extent.height >= extent.width else {
            throw CubeGuidedFaceExtractionError.invalidPortraitImage(
                width: Int(extent.width),
                height: Int(extent.height)
            )
        }

        let context = CIContext(options: [.cacheIntermediates: false])
        let faces = try CubePoseFaceSlot.allCases.map { slot in
            guard let quadrilateral = layout.quadrilaterals[slot] else {
                throw CubeGuidedFaceExtractionError.missingGuideRegion(slot)
            }
            let points = try imagePoints(
                for: quadrilateral,
                slot: slot,
                extent: extent
            )
            guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
                throw CubeGuidedFaceExtractionError.perspectiveCorrectionFailed(slot)
            }
            filter.setValue(orientedImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(cgPoint: points.topLeft), forKey: "inputTopLeft")
            filter.setValue(CIVector(cgPoint: points.topRight), forKey: "inputTopRight")
            filter.setValue(CIVector(cgPoint: points.bottomRight), forKey: "inputBottomRight")
            filter.setValue(CIVector(cgPoint: points.bottomLeft), forKey: "inputBottomLeft")
            guard let corrected = filter.outputImage else {
                throw CubeGuidedFaceExtractionError.perspectiveCorrectionFailed(slot)
            }
            let rectified = try render(corrected, slot: slot, context: context)
            return CubeFaceGridSamples(
                slot: slot,
                samples: try CubeFaceGridSampler.samples(from: rectified),
                transform: pose.standardFaceletTransform(for: slot)
            )
        }
        return CubePoseObservation(pose: pose, faces: faces)
    }

    private struct ImagePoints {
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomRight: CGPoint
        let bottomLeft: CGPoint
    }

    private static func imagePoints(
        for quadrilateral: CubeNormalizedGuideQuadrilateral,
        slot: CubePoseFaceSlot,
        extent: CGRect
    ) throws -> ImagePoints {
        let normalized = [
            quadrilateral.topLeft,
            quadrilateral.topRight,
            quadrilateral.bottomRight,
            quadrilateral.bottomLeft,
        ]
        guard normalized.allSatisfy({
            $0.x.isFinite && $0.y.isFinite &&
            (0...1).contains($0.x) && (0...1).contains($0.y)
        }) else {
            throw CubeGuidedFaceExtractionError.invalidGuideRegion(slot)
        }
        func point(_ value: CubeNormalizedGuidePoint) -> CGPoint {
            CGPoint(
                x: extent.minX + value.x * extent.width,
                y: extent.maxY - value.y * extent.height
            )
        }
        let result = ImagePoints(
            topLeft: point(quadrilateral.topLeft),
            topRight: point(quadrilateral.topRight),
            bottomRight: point(quadrilateral.bottomRight),
            bottomLeft: point(quadrilateral.bottomLeft)
        )
        let topWidth = hypot(
            result.topRight.x - result.topLeft.x,
            result.topRight.y - result.topLeft.y
        )
        let bottomWidth = hypot(
            result.bottomRight.x - result.bottomLeft.x,
            result.bottomRight.y - result.bottomLeft.y
        )
        let leftHeight = hypot(
            result.bottomLeft.x - result.topLeft.x,
            result.bottomLeft.y - result.topLeft.y
        )
        let rightHeight = hypot(
            result.bottomRight.x - result.topRight.x,
            result.bottomRight.y - result.topRight.y
        )
        guard min(topWidth, bottomWidth, leftHeight, rightHeight) >= 6 else {
            throw CubeGuidedFaceExtractionError.invalidGuideRegion(slot)
        }
        return result
    }

    private static func render(
        _ image: CIImage,
        slot: CubePoseFaceSlot,
        context: CIContext
    ) throws -> CubeRectifiedFaceImage {
        let extent = image.extent.integral
        guard extent.width.isFinite,
              extent.height.isFinite,
              extent.width >= 6,
              extent.height >= 6 else {
            throw CubeGuidedFaceExtractionError.perspectiveCorrectionFailed(slot)
        }
        let maximumDimension = 240.0
        let scale = min(1, maximumDimension / max(extent.width, extent.height))
        let translated = image.transformed(by: CGAffineTransform(
            translationX: -extent.minX,
            y: -extent.minY
        ))
        let scaled = translated.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let scaledExtent = scaled.extent.integral
        let width = Int(scaledExtent.width)
        let height = Int(scaledExtent.height)
        guard width >= 6, height >= 6 else {
            throw CubeGuidedFaceExtractionError.renderFailed(slot)
        }

        var bytes = Array(repeating: UInt8(0), count: width * height * 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        context.render(
            scaled,
            toBitmap: &bytes,
            rowBytes: width * 4,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            format: .RGBA8,
            colorSpace: colorSpace
        )
        let pixels = stride(from: 0, to: bytes.count, by: 4).map { offset in
            CubeRGBSample(
                red: Double(bytes[offset]) / 255,
                green: Double(bytes[offset + 1]) / 255,
                blue: Double(bytes[offset + 2]) / 255
            )
        }
        guard pixels.count == width * height else {
            throw CubeGuidedFaceExtractionError.renderFailed(slot)
        }
        return CubeRectifiedFaceImage(width: width, height: height, pixels: pixels)
    }
}

/// AVFoundation session work is confined to `sessionQueue` because start/stop and
/// configuration may block. The type is unchecked Sendable only to allow those
/// queue hops; mutable capture state never leaves its owning queues.
final class CubeCameraSessionEngine: NSObject, @unchecked Sendable {
    private struct PendingCapture {
        let pose: CubeCapturePose?
        let continuation: CheckedContinuation<CubePhotoAnalysis, Error>
    }

    let session = AVCaptureSession()
    var onRectangleCandidates: (@Sendable (Int) -> Void)?
    var onVisionAnalysisFailure: (@Sendable () -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.cubecoach.camera.session", qos: .userInitiated)
    private let visionQueue = DispatchQueue(label: "com.cubecoach.camera.vision", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false
    private var lastVisionTimestamp: CFTimeInterval = 0
    private var pendingCaptures: [Int64: PendingCapture] = [:]
    private let pendingLock = NSLock()

    func configure() async throws {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    try configureOnSessionQueue()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func configureOnSessionQueue() throws {
        guard !isConfigured else { return }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CubeCameraSessionError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: camera)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard session.canAddInput(input), session.canAddOutput(photoOutput), session.canAddOutput(videoOutput) else {
            throw CubeCameraSessionError.configurationFailed
        }

        session.addInput(input)
        session.addOutput(photoOutput)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        session.addOutput(videoOutput)
        isConfigured = true
    }

    func start() {
        sessionQueue.async { [self] in
            guard isConfigured, !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    func capturePhoto() async throws -> CubePhotoAnalysis {
        try await capturePhoto(pose: nil)
    }

    func capturePhoto(pose: CubeCapturePose) async throws -> CubePhotoAnalysis {
        try await capturePhoto(pose: Optional(pose))
    }

    private func capturePhoto(pose: CubeCapturePose?) async throws -> CubePhotoAnalysis {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                guard isConfigured else {
                    continuation.resume(throwing: CubeCameraSessionError.notReady)
                    return
                }
                let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                pendingLock.withLock {
                    pendingCaptures[settings.uniqueID] = PendingCapture(
                        pose: pose,
                        continuation: continuation
                    )
                }
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private static func rectangleCount(in pixelBuffer: CVPixelBuffer) throws -> Int {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 18
        request.minimumSize = 0.045
        request.minimumAspectRatio = 0.55
        request.maximumAspectRatio = 1.45
        request.quadratureTolerance = 25
        try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right).perform([request])
        return request.results?.count ?? 0
    }

    static func rectangleCount(in data: Data) throws -> Int {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 18
        request.minimumSize = 0.045
        request.minimumAspectRatio = 0.55
        request.maximumAspectRatio = 1.45
        request.quadratureTolerance = 25
        try VNImageRequestHandler(data: data, orientation: .right).perform([request])
        return request.results?.count ?? 0
    }

    private static func confidence(for count: Int) -> Double {
        // This is a capture-quality heuristic, not cube-state recognition confidence.
        min(0.95, max(0.2, Double(count) / 9.0))
    }
}

extension CubeCameraSessionEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastVisionTimestamp >= 0.45,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastVisionTimestamp = now
        do {
            onRectangleCandidates?(try Self.rectangleCount(in: pixelBuffer))
        } catch {
            onVisionAnalysisFailure?()
        }
    }
}

extension CubeCameraSessionEngine: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let pendingCapture = pendingLock.withLock {
            pendingCaptures.removeValue(forKey: photo.resolvedSettings.uniqueID)
        }
        guard let pendingCapture else { return }
        guard error == nil, let data = photo.fileDataRepresentation() else {
            pendingCapture.continuation.resume(throwing: CubeCameraSessionError.captureFailed)
            return
        }

        visionQueue.async {
            do {
                let count = try Self.rectangleCount(in: data)
                let observation = try pendingCapture.pose.map {
                    try CubeGuidedFaceExtractor.extract(jpegData: data, pose: $0)
                }
                pendingCapture.continuation.resume(returning: CubePhotoAnalysis(
                    rectangleCandidateCount: count,
                    confidence: Self.confidence(for: count),
                    poseObservation: observation
                ))
            } catch is CubeGuidedFaceExtractionError {
                pendingCapture.continuation.resume(
                    throwing: CubeCameraSessionError.guidedFaceExtractionFailed
                )
            } catch {
                pendingCapture.continuation.resume(throwing: CubeCameraSessionError.visionAnalysisFailed)
            }
        }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try operation()
    }
}
