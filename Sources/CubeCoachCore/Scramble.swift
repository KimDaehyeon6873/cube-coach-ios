import CryptoKit
import Foundation

public enum ScrambleClaim: String, Codable, Sendable, Equatable {
    case nonOfficialRandomMovePractice
    case tnoodleGeneratedPractice
}

public enum ScrambleSource: Codable, Sendable, Equatable {
    case bundledPool(poolSHA256: String)
    case cubeCoachService
}

public struct GeneratedScramble: Codable, Sendable, Equatable {
    public let id: UUID
    public let event: String
    public let notation: String
    public let claim: ScrambleClaim
    public let generatorName: String
    public let generatorVersion: String
    public let generatorSHA256: String
    public let source: ScrambleSource
    public let catalogIndex: Int

    public init(
        id: UUID,
        event: String,
        notation: String,
        claim: ScrambleClaim,
        generatorName: String,
        generatorVersion: String,
        generatorSHA256: String,
        source: ScrambleSource,
        catalogIndex: Int
    ) {
        self.id = id
        self.event = event
        self.notation = notation
        self.claim = claim
        self.generatorName = generatorName
        self.generatorVersion = generatorVersion
        self.generatorSHA256 = generatorSHA256
        self.source = source
        self.catalogIndex = catalogIndex
    }

    public static let practiceDisclosure = "TNoodle 1.2.3으로 생성한 연습 스크램블 · 공식 대회용 아님"
}

public struct TNoodleScrambleManifest: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let event: String
    public let generator: String
    public let generatorVersion: String
    public let officialReleaseURL: String
    public let generatorSHA256: String
    public let signedBuild: Bool
    public let count: Int
    public let poolSHA256: String
    public let claim: ScrambleClaim
}

public enum TNoodleScrambleCatalogError: Error, Sendable, Equatable {
    case resourceMissing(String)
    case invalidManifest
    case invalidPoolChecksum(expected: String, actual: String)
    case countMismatch(expected: Int, actual: Int)
    case duplicateScramble(line: Int)
    case invalidNotation(line: Int)
    case indexOutOfBounds(Int)
}

public struct TNoodleScrambleCatalog: Sendable {
    public static let version = "1.2.3"
    public static let generatorSHA256 = "e9ff6a164effee8a7ecdcc5c18111d4aa09d1de471b71de224889a1282d98cd5"

    public let manifest: TNoodleScrambleManifest
    private let scrambles: [String]

    public var count: Int { scrambles.count }

    public static func loadBundled() throws -> TNoodleScrambleCatalog {
        guard let manifestURL = Bundle.module.url(
            forResource: "tnoodle-\(version)-333.manifest",
            withExtension: "json"
        ) else {
            throw TNoodleScrambleCatalogError.resourceMissing("manifest")
        }
        guard let poolURL = Bundle.module.url(
            forResource: "tnoodle-\(version)-333",
            withExtension: "jsonl"
        ) else {
            throw TNoodleScrambleCatalogError.resourceMissing("catalog")
        }

        let manifestData = try Data(contentsOf: manifestURL)
        let poolData = try Data(contentsOf: poolURL)
        let manifest = try JSONDecoder().decode(TNoodleScrambleManifest.self, from: manifestData)
        return try TNoodleScrambleCatalog(manifest: manifest, poolData: poolData)
    }

    public init(manifest: TNoodleScrambleManifest, poolData: Data) throws {
        guard manifest.schemaVersion == 1,
              manifest.event == "333",
              manifest.generator == "TNoodle-WCA",
              manifest.generatorVersion == Self.version,
              manifest.generatorSHA256 == Self.generatorSHA256,
              manifest.signedBuild,
              manifest.claim == .tnoodleGeneratedPractice
        else {
            throw TNoodleScrambleCatalogError.invalidManifest
        }

        let actualChecksum = SHA256.hash(data: poolData).map { String(format: "%02x", $0) }.joined()
        guard actualChecksum == manifest.poolSHA256.lowercased() else {
            throw TNoodleScrambleCatalogError.invalidPoolChecksum(
                expected: manifest.poolSHA256,
                actual: actualChecksum
            )
        }

        let decoder = JSONDecoder()
        var parsed: [String] = []
        parsed.reserveCapacity(manifest.count)
        var seen = Set<String>()
        for (offset, line) in poolData.split(separator: 0x0A).enumerated() {
            let lineNumber = offset + 1
            let notation: String
            do {
                notation = try decoder.decode(String.self, from: Data(line))
                _ = try WCAParser.parse(notation)
            } catch {
                throw TNoodleScrambleCatalogError.invalidNotation(line: lineNumber)
            }
            guard seen.insert(notation).inserted else {
                throw TNoodleScrambleCatalogError.duplicateScramble(line: lineNumber)
            }
            parsed.append(notation)
        }
        guard parsed.count == manifest.count else {
            throw TNoodleScrambleCatalogError.countMismatch(
                expected: manifest.count,
                actual: parsed.count
            )
        }

        self.manifest = manifest
        self.scrambles = parsed
    }

    /// Maps an arbitrary seed to a stable catalog position. Selection does not
    /// change the TNoodle-generated notation stored in the signed-release pool.
    public func catalogIndex(seed: UInt64) -> Int {
        Int(SplitMix64.mixed(seed) % UInt64(scrambles.count))
    }

    public func scramble3x3(seed: UInt64) -> GeneratedScramble {
        scramble3x3(at: catalogIndex(seed: seed))
    }

    public func scramble3x3(at index: Int) -> GeneratedScramble {
        precondition(scrambles.indices.contains(index), "Catalog index out of bounds")
        let identity = "\(manifest.poolSHA256):\(index)"
        let digest = SHA256.hash(data: Data(identity.utf8))
        let bytes = Array(digest.prefix(16))
        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return GeneratedScramble(
            id: uuid,
            event: manifest.event,
            notation: scrambles[index],
            claim: manifest.claim,
            generatorName: manifest.generator,
            generatorVersion: manifest.generatorVersion,
            generatorSHA256: manifest.generatorSHA256,
            source: .bundledPool(poolSHA256: manifest.poolSHA256),
            catalogIndex: index
        )
    }
}

private enum SplitMix64 {
    static func mixed(_ seed: UInt64) -> UInt64 {
        var z = seed &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
