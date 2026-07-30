import Foundation

/// One of the 24 possible ways a cube can be held.
///
/// The orientation maps notation-relative faces (the face currently called U,
/// R, and so on) back to the canonical URFDLB frame used by `CubeState`.
public struct CubeOrientation: Equatable, Hashable, Sendable {
    fileprivate let right: IntVector
    fileprivate let up: IntVector
    fileprivate let front: IntVector

    public static let identity = CubeOrientation(
        right: IntVector(x: 1, y: 0, z: 0),
        up: IntVector(x: 0, y: 1, z: 0),
        front: IntVector(x: 0, y: 0, z: 1)
    )

    /// The complete, unique set of proper cube orientations.
    public static let all: [CubeOrientation] = {
        var discovered: Set<CubeOrientation> = [.identity]
        var queue: [CubeOrientation] = [.identity]
        while let next = queue.first {
            queue.removeFirst()
            for symbol in [MoveSymbol.x, .y, .z] {
                let candidate = next.rotated(symbol: symbol, amount: .clockwise)
                if discovered.insert(candidate).inserted {
                    queue.append(candidate)
                }
            }
        }
        return Array(discovered)
    }()

    public var canonicalUpFace: CubeFace { face(for: up) }
    public var canonicalFrontFace: CubeFace { face(for: front) }

    fileprivate func canonicalVector(for local: IntVector) -> IntVector {
        right * local.x + up * local.y + front * local.z
    }

    fileprivate func localVector(for canonical: IntVector) -> IntVector {
        IntVector(
            x: canonical.dot(right),
            y: canonical.dot(up),
            z: canonical.dot(front)
        )
    }

    fileprivate func rotated(symbol: MoveSymbol, amount: TurnAmount) -> CubeOrientation {
        precondition(symbol.isRotation)
        let turns = switch amount {
        case .clockwise: 1
        case .half: 2
        case .counterclockwise: 3
        }
        // A notation rotation is clockwise about its positive local axis. To
        // keep the cube canonical, update the local-to-canonical frame by its inverse.
        let axis: CubeAxis = symbol.axis
        func transformed(_ vector: IntVector) -> IntVector {
            canonicalVector(for: vector.rotated(around: axis, quarterTurns: turns))
        }
        return CubeOrientation(
            right: transformed(IntVector(x: 1, y: 0, z: 0)),
            up: transformed(IntVector(x: 0, y: 1, z: 0)),
            front: transformed(IntVector(x: 0, y: 0, z: 1))
        )
    }
}

public struct CubeExecutionState: Equatable, Sendable {
    public let cube: CubeState
    public let orientation: CubeOrientation

    public init(cube: CubeState = .solved, orientation: CubeOrientation = .identity) {
        self.cube = cube
        self.orientation = orientation
    }

    public var projectedFacelets: [CubeFace] {
        cube.projectedFacelets(in: orientation)
    }

    public func applying(_ move: CubeMove) throws -> CubeExecutionState {
        if move.isWide || move.symbol.isSlice {
            return try move.primitiveExpansion.reduce(self) { state, primitive in
                try state.applying(primitive)
            }
        }
        if move.symbol.isFace {
            let canonicalFace = face(
                for: orientation.canonicalVector(for: normal(for: move.symbol))
            )
            return CubeExecutionState(
                cube: try cube.applyingCanonicalFaceTurn(canonicalFace, amount: move.amount),
                orientation: orientation
            )
        }
        return CubeExecutionState(
            cube: cube,
            orientation: orientation.rotated(symbol: move.symbol, amount: move.amount)
        )
    }

    public func applying(_ algorithm: CubeAlgorithm) throws -> CubeExecutionState {
        try algorithm.moves.reduce(self) { try $0.applying($1) }
    }
}

public struct CubePlaybackSnapshot: Equatable, Sendable {
    /// Zero for the initial state; otherwise the number of moves already applied.
    public let moveIndex: Int
    public let move: CubeMove?
    public let executionState: CubeExecutionState

    public init(moveIndex: Int, move: CubeMove?, executionState: CubeExecutionState) {
        self.moveIndex = moveIndex
        self.move = move
        self.executionState = executionState
    }
}

private extension CubeMove {
    var primitiveExpansion: [CubeMove] {
        let clockwise: [CubeMove]
        if isWide {
            clockwise = switch symbol {
            case .R: [.rotation(.x), .face(.L)]
            case .L: [.rotation(.x, .counterclockwise), .face(.R)]
            case .U: [.rotation(.y), .face(.D)]
            case .D: [.rotation(.y, .counterclockwise), .face(.U)]
            case .F: [.rotation(.z), .face(.B)]
            case .B: [.rotation(.z, .counterclockwise), .face(.F)]
            case .M, .E, .S, .x, .y, .z:
                preconditionFailure("Only outer face turns may be wide")
            }
        } else {
            clockwise = switch symbol {
            case .M: [.face(.R), .rotation(.x, .counterclockwise), .face(.L, .counterclockwise)]
            case .E: [.face(.U), .rotation(.y, .counterclockwise), .face(.D, .counterclockwise)]
            case .S: [.face(.F, .counterclockwise), .rotation(.z), .face(.B)]
            case .R, .L, .U, .D, .F, .B, .x, .y, .z:
                preconditionFailure("Only slice turns require primitive expansion")
            }
        }

        return switch amount {
        case .clockwise:
            clockwise
        case .half:
            clockwise + clockwise
        case .counterclockwise:
            clockwise.reversed().map(\.inverse)
        }
    }

    static func face(_ symbol: MoveSymbol, _ amount: TurnAmount = .clockwise) -> CubeMove {
        CubeMove(symbol: symbol, amount: amount)
    }

    static func rotation(_ symbol: MoveSymbol, _ amount: TurnAmount = .clockwise) -> CubeMove {
        CubeMove(symbol: symbol, amount: amount)
    }
}

public extension CubeState {
    static let solved: CubeState = try! CubeState(
        facelets: CubeFace.allCases.flatMap { Array(repeating: $0, count: 9) }
    )

    var faceletString: String { String(facelets.map(\.rawValue)) }

    func applying(_ move: CubeMove, orientation: CubeOrientation = .identity) throws -> CubeState {
        try CubeExecutionState(cube: self, orientation: orientation).applying(move).cube
    }

    func applying(_ algorithm: CubeAlgorithm, orientation: CubeOrientation = .identity) throws -> CubeState {
        try CubeExecutionState(cube: self, orientation: orientation).applying(algorithm).cube
    }

    func executing(
        _ algorithm: CubeAlgorithm,
        orientation: CubeOrientation = .identity
    ) throws -> CubeExecutionState {
        try CubeExecutionState(cube: self, orientation: orientation).applying(algorithm)
    }

    func playback(
        for algorithm: CubeAlgorithm,
        orientation: CubeOrientation = .identity
    ) throws -> [CubePlaybackSnapshot] {
        var execution = CubeExecutionState(cube: self, orientation: orientation)
        var snapshots = [
            CubePlaybackSnapshot(moveIndex: 0, move: nil, executionState: execution)
        ]
        for (index, move) in algorithm.moves.enumerated() {
            execution = try execution.applying(move)
            snapshots.append(
                CubePlaybackSnapshot(moveIndex: index + 1, move: move, executionState: execution)
            )
        }
        return snapshots
    }

    func projectedFacelets(in orientation: CubeOrientation) -> [CubeFace] {
        var result = facelets
        for (index, descriptor) in faceletDescriptors.enumerated() {
            let localPosition = orientation.localVector(for: descriptor.position)
            let localNormal = orientation.localVector(for: descriptor.normal)
            result[faceletIndex(position: localPosition, normal: localNormal)] = facelets[index]
        }
        return result
    }

    fileprivate func applyingCanonicalFaceTurn(
        _ face: CubeFace,
        amount: TurnAmount
    ) throws -> CubeState {
        let outward = normal(for: face)
        let axis: CubeAxis
        let sign: Int
        if outward.x != 0 {
            axis = .x
            sign = outward.x
        } else if outward.y != 0 {
            axis = .y
            sign = outward.y
        } else {
            axis = .z
            sign = outward.z
        }
        let clockwiseTurns = switch amount {
        case .clockwise: 1
        case .half: 2
        case .counterclockwise: 3
        }
        let quarterTurns = -sign * clockwiseTurns
        var turned = facelets
        for (sourceIndex, descriptor) in faceletDescriptors.enumerated()
            where descriptor.position.dot(outward) == 1 {
            let destinationPosition = descriptor.position.rotated(
                around: axis,
                quarterTurns: quarterTurns
            )
            let destinationNormal = descriptor.normal.rotated(
                around: axis,
                quarterTurns: quarterTurns
            )
            turned[faceletIndex(position: destinationPosition, normal: destinationNormal)] =
                facelets[sourceIndex]
        }
        return try CubeState(facelets: turned)
    }
}

private struct FaceletDescriptor {
    let position: IntVector
    let normal: IntVector
}

fileprivate struct IntVector: Equatable, Hashable, Sendable {
    let x: Int
    let y: Int
    let z: Int

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func * (lhs: Self, rhs: Int) -> Self {
        Self(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    func dot(_ other: Self) -> Int { x * other.x + y * other.y + z * other.z }

    func rotated(around axis: CubeAxis, quarterTurns: Int) -> Self {
        var result = self
        for _ in 0..<((quarterTurns % 4 + 4) % 4) {
            result = switch axis {
            case .x: Self(x: result.x, y: -result.z, z: result.y)
            case .y: Self(x: result.z, y: result.y, z: -result.x)
            case .z: Self(x: -result.y, y: result.x, z: result.z)
            }
        }
        return result
    }
}

private let faceletDescriptors: [FaceletDescriptor] = CubeFace.allCases.flatMap { face in
    (0..<9).map { index in
        descriptor(face: face, row: index / 3, column: index % 3)
    }
}

private let descriptorToFaceletIndex: [DescriptorKey: Int] = Dictionary(
    uniqueKeysWithValues: faceletDescriptors.enumerated().map {
        (DescriptorKey(position: $0.element.position, normal: $0.element.normal), $0.offset)
    }
)

private struct DescriptorKey: Hashable {
    let position: IntVector
    let normal: IntVector
}

private func faceletIndex(position: IntVector, normal: IntVector) -> Int {
    descriptorToFaceletIndex[DescriptorKey(position: position, normal: normal)]!
}

private func descriptor(face: CubeFace, row: Int, column: Int) -> FaceletDescriptor {
    let across = column - 1
    let down = row - 1
    return switch face {
    case .up:
        FaceletDescriptor(
            position: IntVector(x: across, y: 1, z: down),
            normal: IntVector(x: 0, y: 1, z: 0)
        )
    case .right:
        FaceletDescriptor(
            position: IntVector(x: 1, y: -down, z: -across),
            normal: IntVector(x: 1, y: 0, z: 0)
        )
    case .front:
        FaceletDescriptor(
            position: IntVector(x: across, y: -down, z: 1),
            normal: IntVector(x: 0, y: 0, z: 1)
        )
    case .down:
        FaceletDescriptor(
            position: IntVector(x: across, y: -1, z: -down),
            normal: IntVector(x: 0, y: -1, z: 0)
        )
    case .left:
        FaceletDescriptor(
            position: IntVector(x: -1, y: -down, z: across),
            normal: IntVector(x: -1, y: 0, z: 0)
        )
    case .back:
        FaceletDescriptor(
            position: IntVector(x: -across, y: -down, z: -1),
            normal: IntVector(x: 0, y: 0, z: -1)
        )
    }
}

private func normal(for face: CubeFace) -> IntVector {
    switch face {
    case .up: IntVector(x: 0, y: 1, z: 0)
    case .right: IntVector(x: 1, y: 0, z: 0)
    case .front: IntVector(x: 0, y: 0, z: 1)
    case .down: IntVector(x: 0, y: -1, z: 0)
    case .left: IntVector(x: -1, y: 0, z: 0)
    case .back: IntVector(x: 0, y: 0, z: -1)
    }
}

private func normal(for symbol: MoveSymbol) -> IntVector {
    switch symbol {
    case .U: normal(for: .up)
    case .R: normal(for: .right)
    case .F: normal(for: .front)
    case .D: normal(for: .down)
    case .L: normal(for: .left)
    case .B: normal(for: .back)
    case .M, .E, .S, .x, .y, .z:
        preconditionFailure("Only outer face symbols identify a face normal")
    }
}


private func face(for normal: IntVector) -> CubeFace {
    switch (normal.x, normal.y, normal.z) {
    case (0, 1, 0): .up
    case (1, 0, 0): .right
    case (0, 0, 1): .front
    case (0, -1, 0): .down
    case (-1, 0, 0): .left
    case (0, 0, -1): .back
    default: preconditionFailure("Not a face normal")
    }
}
