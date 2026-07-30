import CryptoKit
import Foundation
import Testing
@testable import CubeCoachCore

@Test func bundledTNoodleCatalogValidatesEveryEntryAndProvenance() throws {
    let catalog = try TNoodleScrambleCatalog.loadBundled()

    #expect(catalog.count == 32_768)
    #expect(catalog.manifest.count == catalog.count)
    #expect(catalog.manifest.generator == "TNoodle-WCA")
    #expect(catalog.manifest.generatorVersion == "1.2.3")
    #expect(catalog.manifest.generatorSHA256 == TNoodleScrambleCatalog.generatorSHA256)
    #expect(catalog.manifest.signedBuild)
    #expect(catalog.manifest.claim == .tnoodleGeneratedPractice)

    for index in 0..<catalog.count {
        let scramble = catalog.scramble3x3(at: index)
        #expect(throws: Never.self) {
            try WCAParser.parse(scramble.notation)
        }
        #expect(scramble.catalogIndex == index)
        #expect(scramble.claim == .tnoodleGeneratedPractice)
        #expect(scramble.source == .bundledPool(poolSHA256: catalog.manifest.poolSHA256))
    }
}

@Test func catalogSeedMappingIsReproducible() throws {
    let catalog = try TNoodleScrambleCatalog.loadBundled()
    let first = catalog.scramble3x3(seed: 42)
    let second = catalog.scramble3x3(seed: 42)

    #expect(first == second)
    #expect(first.catalogIndex == catalog.catalogIndex(seed: 42))
    #expect(first.event == "333")
    #expect(first.generatorName == "TNoodle-WCA")
    #expect(first.generatorVersion == "1.2.3")
}

@Test func catalogRejectsTamperedPoolData() throws {
    let original = Data("\"R U R'\"\n".utf8)
    let checksum = SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined()
    let manifest = TNoodleScrambleManifest(
        schemaVersion: 1,
        event: "333",
        generator: "TNoodle-WCA",
        generatorVersion: "1.2.3",
        officialReleaseURL: "https://github.com/thewca/tnoodle/releases/tag/v1.2.3",
        generatorSHA256: TNoodleScrambleCatalog.generatorSHA256,
        signedBuild: true,
        count: 1,
        poolSHA256: checksum,
        claim: .tnoodleGeneratedPractice
    )
    let tampered = Data("\"R U2 R'\"\n".utf8)

    #expect(throws: TNoodleScrambleCatalogError.self) {
        try TNoodleScrambleCatalog(manifest: manifest, poolData: tampered)
    }
}

@Test func catalogRejectsInvalidNotationEvenWithMatchingChecksum() {
    let data = Data("\"R Q\"\n".utf8)
    let checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    let manifest = TNoodleScrambleManifest(
        schemaVersion: 1,
        event: "333",
        generator: "TNoodle-WCA",
        generatorVersion: "1.2.3",
        officialReleaseURL: "https://github.com/thewca/tnoodle/releases/tag/v1.2.3",
        generatorSHA256: TNoodleScrambleCatalog.generatorSHA256,
        signedBuild: true,
        count: 1,
        poolSHA256: checksum,
        claim: .tnoodleGeneratedPractice
    )

    #expect(throws: TNoodleScrambleCatalogError.self) {
        try TNoodleScrambleCatalog(manifest: manifest, poolData: data)
    }
}
