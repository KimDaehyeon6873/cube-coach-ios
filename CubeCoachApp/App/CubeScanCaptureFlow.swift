import Foundation

public enum CubeScanCapturePhase: Int, CaseIterable, Equatable, Sendable {
    case firstCorner
    case oppositeCorner
    case review
}

public struct CubeScanCaptureFlow: Equatable, Sendable {
    public private(set) var phase: CubeScanCapturePhase
    public private(set) var didFailCurrentCapture: Bool

    public init(
        phase: CubeScanCapturePhase = .firstCorner,
        didFailCurrentCapture: Bool = false
    ) {
        self.phase = phase
        self.didFailCurrentCapture = didFailCurrentCapture
    }

    public var manualFallbackIsAvailable: Bool {
        phase != .review
    }

    public mutating func recordCaptureFailure() {
        guard phase != .review else { return }
        didFailCurrentCapture = true
    }

    public mutating func acceptCapture() {
        switch phase {
        case .firstCorner:
            phase = .oppositeCorner
            didFailCurrentCapture = false
        case .oppositeCorner:
            phase = .review
            didFailCurrentCapture = false
        case .review:
            break
        }
    }

    public mutating func startManualReview() {
        phase = .review
        didFailCurrentCapture = false
    }

    public mutating func reset() {
        self = CubeScanCaptureFlow()
    }
}
