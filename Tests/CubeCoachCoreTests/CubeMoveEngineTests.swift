import Testing
@testable import CubeCoachCore

@Test(arguments: [
    ("U", "UUUUUUUUUBBBRRRRRRRRRFFFFFFDDDDDDDDDFFFLLLLLLLLLBBBBBB"),
    ("R", "UUFUUFUUFRRRRRRRRRFFDFFDFFDDDBDDBDDBLLLLLLLLLUBBUBBUBB"),
    ("F", "UUUUUULLLURRURRURRFFFFFFFFFRRRDDDDDDLLDLLDLLDBBBBBBBBB"),
    ("D", "UUUUUUUUURRRRRRFFFFFFFFFLLLDDDDDDDDDLLLLLLBBBBBBBBBRRR"),
    ("L", "BUUBUUBUURRRRRRRRRUFFUFFUFFFDDFDDFDDLLLLLLLLLBBDBBDBBD"),
    ("B", "RRRUUUUUURRDRRDRRDFFFFFFFFFDDDDDDLLLULLULLULLBBBBBBBBB"),
])
func goldenFaceQuarterTurns(notation: String, expected: String) throws {
    let result = try CubeState.solved.applying(WCAParser.parse(notation))
    #expect(result.faceletString == expected)
}

@Test(arguments: ["U", "R", "F", "D", "L", "B"])
func faceTurnsSatisfyInverseAndTurnIdentities(symbol: String) throws {
    let move = try WCAParser.parse(symbol)
    let inverse = move.inverse
    #expect(try CubeState.solved.applying(
        CubeAlgorithm(moves: move.moves + inverse.moves)
    ) == .solved)
    #expect(try CubeState.solved.applying(WCAParser.parse("\(symbol) \(symbol) \(symbol) \(symbol)")) == .solved)
    #expect(try CubeState.solved.applying(WCAParser.parse("\(symbol)2 \(symbol)2")) == .solved)
}

@Test(arguments: ["x", "y", "z"])
func cubeRotationsUseASeparate24OrientationModel(symbol: String) throws {
    let fourTurns = try CubeState.solved.executing(
        WCAParser.parse("\(symbol) \(symbol) \(symbol) \(symbol)")
    )
    #expect(fourTurns.cube == .solved)
    #expect(fourTurns.orientation == .identity)
    #expect(CubeOrientation.all.count == 24)
}

@Test func rotationBearingAPermutationExecutesAndInverts() throws {
    let algorithm = try WCAParser.parse("x R' U R' D2 R U' R' D2 R2 x'")
    let scrambled = try CubeState.solved.applying(algorithm.inverse)
    let execution = try scrambled.executing(algorithm)
    #expect(execution.cube == .solved)
    #expect(execution.orientation == .identity)
}

@Test func playbackIncludesInitialStateAndEveryMove() throws {
    let algorithm = try WCAParser.parse("R U R'")
    let playback = try CubeState.solved.playback(for: algorithm)
    #expect(playback.count == 4)
    #expect(playback.first?.move == nil)
    #expect(playback.last?.moveIndex == 3)
    let expectedEnd = try CubeState.solved.applying(algorithm)
    #expect(playback.last?.executionState.cube == expectedEnd)
}

@Test func projectedFaceletsRespectOrientationWithoutChangingCanonicalCube() throws {
    let execution = try CubeState.solved.executing(WCAParser.parse("x"))
    #expect(execution.cube == .solved)
    #expect(execution.orientation != .identity)
    #expect(execution.projectedFacelets != CubeState.solved.facelets)
    #expect(Set(execution.projectedFacelets) == Set(CubeFace.allCases))
}

@Test(arguments: ["Rw", "Uw", "Fw", "Lw", "Dw", "Bw", "M", "E", "S"])
func wideAndSliceTurnsSatisfyInverseAndFourTurnIdentities(notation: String) throws {
    let algorithm = try WCAParser.parse(notation)
    let inverseExecution = try CubeState.solved.executing(
        CubeAlgorithm(moves: algorithm.moves + algorithm.inverse.moves)
    )
    #expect(inverseExecution.cube == .solved)
    #expect(inverseExecution.orientation == .identity)
    let fourTurnExecution = try CubeState.solved.executing(
        WCAParser.parse("\(notation) \(notation) \(notation) \(notation)")
    )
    #expect(fourTurnExecution.cube == .solved)
    #expect(fourTurnExecution.orientation == .identity)
}
