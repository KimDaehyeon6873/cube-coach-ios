import Foundation
@preconcurrency import AVFoundation
@preconcurrency import CoreImage
@preconcurrency import Vision

public enum CubeCameraSessionError: LocalizedError, Sendable {
    case noCamera
    case configurationFailed
    case notReady
    case captureInProgress
    case captureFailed
    case visionAnalysisFailed
    case guidedFaceExtractionFailed

    public var errorDescription: String? {
        switch self {
        case .noCamera: "사용 가능한 후면 카메라가 없어요."
        case .configurationFailed: "카메라 구성을 완료하지 못했어요."
        case .notReady: "카메라가 아직 준비되지 않았어요."
        case .captureInProgress: "이미 촬영한 색상을 읽고 있어요."
        case .captureFailed: "사진 품질을 확인하지 못했어요.\n다시 촬영해 주세요."
        case .visionAnalysisFailed: "사진에서 큐브 면을 찾지 못했어요.\n안내선에 맞춰 다시 촬영해 주세요."
        case .guidedFaceExtractionFailed:
            "3×3 전체를 안내선에 맞춰 주세요.\n네 모서리를 확인한 뒤 다시 촬영해 주세요."
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

public enum CubeSingleFaceExtractionError: LocalizedError, Equatable, Sendable {
    case invalidImageData
    case invalidPortraitImage(width: Int, height: Int)
    case invalidGuideRegion
    case perspectiveCorrectionFailed
    case renderFailed

    public var errorDescription: String? {
        switch self {
        case .invalidImageData:
            "촬영 이미지를 읽지 못했어요."
        case .invalidPortraitImage:
            "촬영 이미지의 세로 방향을 확인하지 못했어요."
        case .invalidGuideRegion:
            "한 면 촬영 가이드 구성이 올바르지 않아요."
        case .perspectiveCorrectionFailed, .renderFailed:
            "정면 가이드 영역의 색상 표본을 만들지 못했어요."
        }
    }
}

/// Perspective-corrects and samples the one face explicitly positioned in the
/// central portrait guide. It does not attempt arbitrary object recognition.
public enum CubeSingleFaceExtractor {
    public static func extract(
        jpegData: Data,
        face: CubeFace,
        layout: CubeSingleFaceGuideLayout = .portraitCentralSquare,
        orientation: CubeSingleFaceCaptureOrientation? = nil
    ) throws -> CubeSingleFaceObservation {
        let options: [CIImageOption: Any] = [.applyOrientationProperty: true]
        guard let image = CIImage(data: jpegData, options: options) else {
            throw CubeSingleFaceExtractionError.invalidImageData
        }
        let extent = image.extent.integral
        guard extent.width >= 6, extent.height >= 6, extent.height >= extent.width else {
            throw CubeSingleFaceExtractionError.invalidPortraitImage(
                width: Int(extent.width),
                height: Int(extent.height)
            )
        }
        let guide = layout.quadrilateral
        let normalized = [guide.topLeft, guide.topRight, guide.bottomRight, guide.bottomLeft]
        guard normalized.allSatisfy({
            $0.x.isFinite && $0.y.isFinite &&
            (0...1).contains($0.x) && (0...1).contains($0.y)
        }) else {
            throw CubeSingleFaceExtractionError.invalidGuideRegion
        }
        func point(_ value: CubeNormalizedGuidePoint) -> CGPoint {
            CGPoint(
                x: extent.minX + value.x * extent.width,
                y: extent.maxY - value.y * extent.height
            )
        }
        let topLeft = point(guide.topLeft)
        let topRight = point(guide.topRight)
        let bottomRight = point(guide.bottomRight)
        let bottomLeft = point(guide.bottomLeft)
        let edgeLengths = [
            hypot(topRight.x - topLeft.x, topRight.y - topLeft.y),
            hypot(bottomRight.x - bottomLeft.x, bottomRight.y - bottomLeft.y),
            hypot(bottomLeft.x - topLeft.x, bottomLeft.y - topLeft.y),
            hypot(bottomRight.x - topRight.x, bottomRight.y - topRight.y),
        ]
        guard edgeLengths.min() ?? 0 >= 6 else {
            throw CubeSingleFaceExtractionError.invalidGuideRegion
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            throw CubeSingleFaceExtractionError.perspectiveCorrectionFailed
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        guard let corrected = filter.outputImage else {
            throw CubeSingleFaceExtractionError.perspectiveCorrectionFailed
        }
        let correctedExtent = corrected.extent.integral
        guard correctedExtent.width.isFinite,
              correctedExtent.height.isFinite,
              correctedExtent.width >= 6,
              correctedExtent.height >= 6 else {
            throw CubeSingleFaceExtractionError.perspectiveCorrectionFailed
        }
        let scale = min(1, 240 / max(correctedExtent.width, correctedExtent.height))
        let translated = corrected.transformed(by: .init(
            translationX: -correctedExtent.minX,
            y: -correctedExtent.minY
        ))
        let scaled = translated.transformed(by: .init(scaleX: scale, y: scale))
        let scaledExtent = scaled.extent.integral
        let width = Int(scaledExtent.width)
        let height = Int(scaledExtent.height)
        guard width >= 6, height >= 6 else {
            throw CubeSingleFaceExtractionError.renderFailed
        }
        var bytes = Array(repeating: UInt8(0), count: width * height * 4)
        CIContext(options: [.cacheIntermediates: false]).render(
            scaled,
            toBitmap: &bytes,
            rowBytes: width * 4,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
        let pixels = stride(from: 0, to: bytes.count, by: 4).map { offset in
            CubeRGBSample(
                red: Double(bytes[offset]) / 255,
                green: Double(bytes[offset + 1]) / 255,
                blue: Double(bytes[offset + 2]) / 255
            )
        }
        guard pixels.count == width * height else {
            throw CubeSingleFaceExtractionError.renderFailed
        }
        let measurements = try CubeFaceGridSampler.measurements(
            from: .init(width: width, height: height, pixels: pixels)
        )
        return CubeSingleFaceObservation(
            face: face,
            samples: measurements.map(\.sample),
            cellColorDispersions: measurements.map(\.dispersion),
            orientation: orientation
        )
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
    private enum CaptureTarget {
        case unguided
        case pose(CubeCapturePose)
        case face(CubeSingleFaceCaptureOrientation)
    }

    private struct PendingCapture {
        let target: CaptureTarget
        let continuation: CheckedContinuation<CubePhotoAnalysis, Error>
    }

    let session = AVCaptureSession()
    var onRectangleCandidates: (@Sendable (Int) -> Void)?
    var onLiveCaptureAssessment: (@Sendable (CubeLiveCaptureAssessment) -> Void)?
    var onVisionAnalysisFailure: (@Sendable () -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.cubecoach.camera.session", qos: .userInitiated)
    private let visionQueue = DispatchQueue(label: "com.cubecoach.camera.vision", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let liveFrameContext = CIContext(options: [.cacheIntermediates: false])
    private var isConfigured = false
    private var lastVisionTimestamp: CFTimeInterval = 0
    private var backCamera: AVCaptureDevice?
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
        try configureContinuousCameraAdjustment(camera)

        let input = try AVCaptureDeviceInput(device: camera)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard session.canAddInput(input), session.canAddOutput(photoOutput), session.canAddOutput(videoOutput) else {
            throw CubeCameraSessionError.configurationFailed
        }

        session.addInput(input)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .balanced
        videoOutput.alwaysDiscardsLateVideoFrames = true
        session.addOutput(videoOutput)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        backCamera = camera
        isConfigured = true
    }

    private func configureContinuousCameraAdjustment(_ camera: AVCaptureDevice) throws {
        try camera.lockForConfiguration()
        defer { camera.unlockForConfiguration() }

        let guideCenter = CGPoint(x: 0.5, y: 0.5)
        if camera.isFocusPointOfInterestSupported {
            camera.focusPointOfInterest = guideCenter
        }
        if camera.isFocusModeSupported(.continuousAutoFocus) {
            camera.focusMode = .continuousAutoFocus
        }
        if camera.isExposurePointOfInterestSupported {
            camera.exposurePointOfInterest = guideCenter
        }
        if camera.isExposureModeSupported(.continuousAutoExposure) {
            camera.exposureMode = .continuousAutoExposure
        }
        if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            camera.whiteBalanceMode = .continuousAutoWhiteBalance
        }
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
        try await capturePhoto(target: .unguided)
    }

    func capturePhoto(pose: CubeCapturePose) async throws -> CubePhotoAnalysis {
        try await capturePhoto(target: .pose(pose))
    }

    func capturePhoto(face: CubeFace) async throws -> CubePhotoAnalysis {
        try await capturePhoto(target: .face(.standard(for: face)))
    }

    func capturePhoto(orientation: CubeSingleFaceCaptureOrientation) async throws -> CubePhotoAnalysis {
        try await capturePhoto(target: .face(orientation))
    }

    private func capturePhoto(target: CaptureTarget) async throws -> CubePhotoAnalysis {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                guard isConfigured else {
                    continuation.resume(throwing: CubeCameraSessionError.notReady)
                    return
                }
                let settings = AVCapturePhotoSettings(format: [
                    AVVideoCodecKey: AVVideoCodecType.jpeg
                ])
                settings.photoQualityPrioritization = .balanced
                pendingLock.withLock {
                    pendingCaptures[settings.uniqueID] = PendingCapture(
                        target: target,
                        continuation: continuation
                    )
                }
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private static func rectangleObservations(
        in pixelBuffer: CVPixelBuffer
    ) throws -> [VNRectangleObservation] {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 18
        request.minimumSize = 0.045
        request.minimumAspectRatio = 0.55
        request.maximumAspectRatio = 1
        request.quadratureTolerance = 25
        try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right).perform([request])
        return request.results ?? []
    }

    static func rectangleCount(in data: Data) throws -> Int {
        try rectangleObservations(in: data).count
    }

    private static func rectangleObservations(in data: Data) throws -> [VNRectangleObservation] {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 18
        request.minimumSize = 0.045
        request.minimumAspectRatio = 0.55
        request.maximumAspectRatio = 1
        request.quadratureTolerance = 25
        try VNImageRequestHandler(data: data, orientation: .right).perform([request])
        return request.results ?? []
    }

    private static func portraitDisplayQuadrilateral(
        from observation: VNRectangleObservation
    ) -> CubeNormalizedGuideQuadrilateral {
        func displayPoint(_ point: CGPoint) -> CubeNormalizedGuidePoint {
            // Vision observations use a bottom-left origin after applying `.right`.
            // The preview guide uses portrait display coordinates with a top-left origin.
            CubeNormalizedGuidePoint(x: point.x, y: 1 - point.y)
        }
        return CubeNormalizedGuideQuadrilateral(
            topLeft: displayPoint(observation.topLeft),
            topRight: displayPoint(observation.topRight),
            bottomRight: displayPoint(observation.bottomRight),
            bottomLeft: displayPoint(observation.bottomLeft)
        )
    }

    private static func guideMatch(
        for observations: [VNRectangleObservation]
    ) -> CubeSingleFaceGuideMatch? {
        CubeSingleFaceGuideAlignmentScorer.match(
            observations.map(portraitDisplayQuadrilateral(from:))
        )
    }

    private func liveGuideImage(
        from pixelBuffer: CVPixelBuffer,
        layout: CubeSingleFaceGuideLayout
    ) throws -> CubeRectifiedFaceImage {
        let portraitImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        let extent = portraitImage.extent
        let guide = layout.quadrilateral

        func imagePoint(_ point: CubeNormalizedGuidePoint) -> CGPoint {
            CGPoint(
                x: extent.minX + point.x * extent.width,
                y: extent.maxY - point.y * extent.height
            )
        }

        guard let correction = CIFilter(name: "CIPerspectiveCorrection") else {
            throw CubeCameraSessionError.visionAnalysisFailed
        }
        correction.setValue(portraitImage, forKey: kCIInputImageKey)
        correction.setValue(CIVector(cgPoint: imagePoint(guide.topLeft)), forKey: "inputTopLeft")
        correction.setValue(CIVector(cgPoint: imagePoint(guide.topRight)), forKey: "inputTopRight")
        correction.setValue(
            CIVector(cgPoint: imagePoint(guide.bottomRight)),
            forKey: "inputBottomRight"
        )
        correction.setValue(
            CIVector(cgPoint: imagePoint(guide.bottomLeft)),
            forKey: "inputBottomLeft"
        )
        guard let corrected = correction.outputImage else {
            throw CubeCameraSessionError.visionAnalysisFailed
        }

        let correctedExtent = corrected.extent.integral
        guard correctedExtent.width >= 9, correctedExtent.height >= 9 else {
            throw CubeCameraSessionError.visionAnalysisFailed
        }
        let maximumDimension = 90.0
        let scale = min(1, maximumDimension / max(correctedExtent.width, correctedExtent.height))
        let normalized = corrected
            .transformed(by: CGAffineTransform(
                translationX: -correctedExtent.minX,
                y: -correctedExtent.minY
            ))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let renderExtent = normalized.extent.integral
        let width = Int(renderExtent.width)
        let height = Int(renderExtent.height)
        guard width >= 9, height >= 9 else {
            throw CubeCameraSessionError.visionAnalysisFailed
        }

        var bytes = Array(repeating: UInt8(0), count: width * height * 4)
        liveFrameContext.render(
            normalized,
            toBitmap: &bytes,
            rowBytes: width * 4,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
        let pixels = stride(from: 0, to: bytes.count, by: 4).map { offset in
            CubeRGBSample(
                red: Double(bytes[offset]) / 255,
                green: Double(bytes[offset + 1]) / 255,
                blue: Double(bytes[offset + 2]) / 255
            )
        }
        return CubeRectifiedFaceImage(width: width, height: height, pixels: pixels)
    }

    private var isCameraSettled: Bool {
        guard let backCamera else { return false }
        return !backCamera.isAdjustingFocus
            && !backCamera.isAdjustingExposure
            && !backCamera.isAdjustingWhiteBalance
    }
}

extension CubeCameraSessionEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastVisionTimestamp >= 0.27,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastVisionTimestamp = now
        do {
            let observations = try Self.rectangleObservations(in: pixelBuffer)
            let count = observations.count
            onRectangleCandidates?(count)
            let guideMatch = Self.guideMatch(for: observations)
            let samplingLayout = CubeSingleFaceGuideLayout(
                quadrilateral: guideMatch?.samplingQuadrilateral
                    ?? CubeSingleFaceGuideLayout.portraitCentralSquare.quadrilateral
            )
            let quality = try CubeLiveFrameQualityAnalyzer.analyze(
                liveGuideImage(from: pixelBuffer, layout: samplingLayout)
            )
            onLiveCaptureAssessment?(CubeLiveCaptureAssessment(
                timestamp: now,
                rectangleCandidateCount: count,
                alignmentConfidence: guideMatch?.alignmentConfidence ?? 0,
                sharpness: quality.sharpness,
                exposure: quality.exposure,
                isCameraSettled: isCameraSettled,
                signature: quality.signature
            ))
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
                let rectangleObservations = try Self.rectangleObservations(in: data)
                let count = rectangleObservations.count
                let guideMatch = Self.guideMatch(for: rectangleObservations)
                let poseObservation: CubePoseObservation?
                let faceObservation: CubeSingleFaceObservation?
                switch pendingCapture.target {
                case .unguided:
                    poseObservation = nil
                    faceObservation = nil
                case let .pose(pose):
                    poseObservation = try CubeGuidedFaceExtractor.extract(jpegData: data, pose: pose)
                    faceObservation = nil
                case let .face(orientation):
                    poseObservation = nil
                    if let guideMatch {
                        faceObservation = try CubeSingleFaceExtractor.extract(
                            jpegData: data,
                            face: orientation.face,
                            layout: CubeSingleFaceGuideLayout(
                                quadrilateral: guideMatch.samplingQuadrilateral
                            ),
                            orientation: orientation
                        )
                    } else {
                        faceObservation = nil
                    }
                }
                pendingCapture.continuation.resume(returning: CubePhotoAnalysis(
                    rectangleCandidateCount: count,
                    confidence: guideMatch?.alignmentConfidence ?? 0,
                    poseObservation: poseObservation,
                    singleFaceObservation: faceObservation
                ))
            } catch is CubeGuidedFaceExtractionError, is CubeSingleFaceExtractionError {
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
