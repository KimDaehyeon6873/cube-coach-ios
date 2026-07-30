import Testing
@testable import CubeCoachCore

@Test func parsesAndNormalizesWcaNotation() throws {
    let algorithm = try WCAParser.parse("  R U2  Rw’ x'  z2 ")
    #expect(algorithm.normalized == "R U2 Rw' x' z2")
    #expect(algorithm.moves.count == 5)
    #expect(algorithm.moves[2].isWide)
}

@Test func parserReportsCharacterPosition() {
    do {
        _ = try WCAParser.parse("R U Q F")
        Issue.record("expected parser failure")
    } catch let error as WCAParseError {
        #expect(error.position == 4)
        #expect(error.reason == .unexpectedSymbol("Q"))
    } catch { Issue.record("unexpected error: \(error)") }
}

@Test func parserRejectsInvalidModifiersAtTheirPosition() {
    #expect(throws: WCAParseError(position: 2, reason: .duplicateModifier)) {
        try WCAParser.parse("R''")
    }
    #expect(throws: WCAParseError(position: 1, reason: .wideModifierRequiresFace)) {
        try WCAParser.parse("xw")
    }
}

@Test func acceptsExplicitTwoLayerWideTurns() throws {
    let algorithm = try WCAParser.parse("2Rw 2Uw' 2Fw2")
    #expect(algorithm.normalized == "2Rw 2Uw' 2Fw2")
    #expect(algorithm.moves.allSatisfy { $0.layerCount == 2 && $0.isWide })
}

@Test func rejectsInvalidLayerPrefixesAndSuffixesWithPositions() {
    #expect(throws: WCAParseError(position: 0, reason: .invalidLayerPrefix("1"))) { try WCAParser.parse("1Rw") }
    #expect(throws: WCAParseError(position: 0, reason: .invalidLayerPrefix("3"))) { try WCAParser.parse("3Rw") }
    #expect(throws: WCAParseError(position: 1, reason: .invalidLayerPrefix("3"))) { try WCAParser.parse("R3") }
    #expect(throws: WCAParseError(position: 2, reason: .duplicateModifier)) { try WCAParser.parse("R2'") }
}
