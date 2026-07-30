import Foundation

public enum SolvePenalty: String, Codable, Sendable, Equatable, CaseIterable {
    case none
    case plusTwo
    case dnf
}

public enum InspectionPenalty: String, Codable, Sendable, Equatable {
    case none
    case plusTwo
    case dnf

    public static func at(elapsed: TimeInterval) -> InspectionPenalty {
        if elapsed >= 17 { return .dnf }
        if elapsed >= 15 { return .plusTwo }
        return .none
    }

    public var solvePenalty: SolvePenalty {
        switch self {
        case .none: .none
        case .plusTwo: .plusTwo
        case .dnf: .dnf
        }
    }
}

public struct SolveTiming: Codable, Sendable, Equatable {
    /// High-precision measured duration. Official display values are derived separately.
    public let rawDuration: TimeInterval
    public let inspectionElapsed: TimeInterval
    public let penalty: SolvePenalty

    public init(rawDuration: TimeInterval, inspectionElapsed: TimeInterval, penalty: SolvePenalty) {
        self.rawDuration = max(0, rawDuration)
        self.inspectionElapsed = max(0, inspectionElapsed)
        self.penalty = penalty
    }

    public var finalDuration: TimeInterval? {
        switch penalty {
        case .none: rawDuration
        case .plusTwo: rawDuration + 2
        case .dnf: nil
        }
    }

    /// WCA-style result in centiseconds: measurement is truncated, never rounded.
    public var officialCentiseconds: Int? {
        guard penalty != .dnf else { return nil }
        return Int((rawDuration * 100).rounded(.down)) + (penalty == .plusTwo ? 200 : 0)
    }

    public var officialDisplay: String {
        guard let centiseconds = officialCentiseconds else { return "DNF" }
        return String(format: "%d.%02d", centiseconds / 100, centiseconds % 100)
    }
}

public enum SolveTimerPhaseKind: String, Codable, Sendable, Equatable {
    case inspection, holding, armed, running, stopped
}

public enum SolveTimerPhase: Codable, Sendable, Equatable {
    case inspection(startedAt: TimeInterval)
    case holding(inspectionStartedAt: TimeInterval, holdStartedAt: TimeInterval)
    case armed(inspectionStartedAt: TimeInterval, holdStartedAt: TimeInterval)
    case running(startedAt: TimeInterval, inspectionElapsed: TimeInterval, penalty: SolvePenalty)
    case stopped(SolveTiming)

    public var kind: SolveTimerPhaseKind {
        switch self {
        case .inspection: .inspection
        case .holding: .holding
        case .armed: .armed
        case .running: .running
        case .stopped: .stopped
        }
    }
}

public enum SolveTimerError: Error, Sendable, Equatable {
    case invalidTransition(from: SolveTimerPhaseKind, action: String)
    case timeMovedBackwards
}

public struct SolveTimerMachine: Codable, Sendable, Equatable {
    public private(set) var phase: SolveTimerPhase
    public let armDuration: TimeInterval

    public static func inspection(startedAt: TimeInterval, armDuration: TimeInterval = 0.55) -> SolveTimerMachine {
        SolveTimerMachine(phase: .inspection(startedAt: startedAt), armDuration: armDuration)
    }

    public init(phase: SolveTimerPhase, armDuration: TimeInterval = 0.55) {
        self.phase = phase
        self.armDuration = max(0, armDuration)
    }

    public mutating func press(at time: TimeInterval) throws {
        guard case let .inspection(startedAt) = phase else {
            throw SolveTimerError.invalidTransition(from: phase.kind, action: "press")
        }
        guard time >= startedAt else { throw SolveTimerError.timeMovedBackwards }
        phase = .holding(inspectionStartedAt: startedAt, holdStartedAt: time)
    }

    public mutating func advance(to time: TimeInterval) throws {
        guard case let .holding(inspectionStartedAt, holdStartedAt) = phase else { return }
        guard time >= holdStartedAt else { throw SolveTimerError.timeMovedBackwards }
        if time - holdStartedAt >= armDuration {
            phase = .armed(inspectionStartedAt: inspectionStartedAt, holdStartedAt: holdStartedAt)
        }
    }

    public mutating func release(at time: TimeInterval) throws {
        switch phase {
        case let .holding(inspectionStartedAt, holdStartedAt):
            guard time >= holdStartedAt else { throw SolveTimerError.timeMovedBackwards }
            phase = .inspection(startedAt: inspectionStartedAt)
        case let .armed(inspectionStartedAt, holdStartedAt):
            guard time >= holdStartedAt else { throw SolveTimerError.timeMovedBackwards }
            let elapsed = time - inspectionStartedAt
            phase = .running(startedAt: time, inspectionElapsed: elapsed, penalty: InspectionPenalty.at(elapsed: elapsed).solvePenalty)
        default:
            throw SolveTimerError.invalidTransition(from: phase.kind, action: "release")
        }
    }

    public mutating func stop(at time: TimeInterval) throws {
        guard case let .running(startedAt, inspectionElapsed, penalty) = phase else {
            throw SolveTimerError.invalidTransition(from: phase.kind, action: "stop")
        }
        guard time >= startedAt else { throw SolveTimerError.timeMovedBackwards }
        phase = .stopped(SolveTiming(rawDuration: time - startedAt, inspectionElapsed: inspectionElapsed, penalty: penalty))
    }

    public mutating func resetInspection(at time: TimeInterval) {
        phase = .inspection(startedAt: time)
    }
}
