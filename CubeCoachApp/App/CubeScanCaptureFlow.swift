import Foundation

public enum CubeScanCapturePhase: Equatable, Sendable {
    case capture
    case review
}

public enum CubeScanFaceCaptureStatus: Equatable, Sendable {
    case pending
    case failed
    case captured
}

/// State machine for capturing each face frontally in U, F, R, D, B, L order.
///
/// Retakes are deliberately modeled separately from the initial pass. A failed
/// or cancelled retake returns to review without discarding the previously
/// accepted face.
public struct CubeScanCaptureFlow: Equatable, Sendable {
    public static let captureOrder: [CubeFace] = [
        .up, .front, .right, .down, .back, .left,
    ]

    public private(set) var phase: CubeScanCapturePhase
    public private(set) var currentFace: CubeFace?
    public private(set) var didFailCurrentCapture: Bool
    public private(set) var isRetaking: Bool

    private var statuses: [CubeFace: CubeScanFaceCaptureStatus]

    public init() {
        phase = .capture
        currentFace = Self.captureOrder.first
        didFailCurrentCapture = false
        isRetaking = false
        statuses = Dictionary(
            uniqueKeysWithValues: Self.captureOrder.map { ($0, .pending) }
        )
    }

    public var manualFallbackIsAvailable: Bool {
        phase == .capture
    }

    public var captureStatuses: [CubeFace: CubeScanFaceCaptureStatus] {
        statuses
    }

    public func status(for face: CubeFace) -> CubeScanFaceCaptureStatus {
        statuses[face] ?? .pending
    }

    public mutating func recordCaptureFailure() {
        guard phase == .capture, let currentFace else { return }

        didFailCurrentCapture = true
        if isRetaking {
            finishRetake()
        } else {
            statuses[currentFace] = .failed
        }
    }

    public mutating func acceptCapture() {
        guard phase == .capture, let currentFace else { return }

        statuses[currentFace] = .captured
        didFailCurrentCapture = false

        if isRetaking {
            finishRetake()
            return
        }

        guard let currentIndex = Self.captureOrder.firstIndex(of: currentFace),
              Self.captureOrder.indices.contains(currentIndex + 1) else {
            enterReview()
            return
        }
        self.currentFace = Self.captureOrder[currentIndex + 1]
    }

    /// Leaves a capture without accepting any replacement data.
    ///
    /// Cancelling a retake returns to review. During the initial pass there is
    /// no prior review state to return to, so cancellation keeps the same face
    /// selected and clears only the transient failure indicator.
    public mutating func cancelCurrentCapture() {
        guard phase == .capture else { return }
        didFailCurrentCapture = false
        if isRetaking {
            finishRetake()
        }
    }

    public mutating func cancelRetake() {
        guard isRetaking else { return }
        cancelCurrentCapture()
    }

    public mutating func startManualReview() {
        enterReview()
    }

    @discardableResult
    public mutating func beginRetake(face: CubeFace) -> Bool {
        guard phase == .review else { return false }
        phase = .capture
        currentFace = face
        didFailCurrentCapture = false
        isRetaking = true
        return true
    }

    public mutating func reset() {
        self = CubeScanCaptureFlow()
    }

    private mutating func enterReview() {
        phase = .review
        currentFace = nil
        didFailCurrentCapture = false
        isRetaking = false
    }

    private mutating func finishRetake() {
        phase = .review
        currentFace = nil
        isRetaking = false
    }
}
