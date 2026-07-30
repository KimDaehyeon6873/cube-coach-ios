import CubeCoachCore
import Foundation

struct TimerScrambleCatalogLoader: Sendable {
    private let loadCatalog: @Sendable () async throws -> TNoodleScrambleCatalog

    init(loadCatalog: @escaping @Sendable () async throws -> TNoodleScrambleCatalog) {
        self.loadCatalog = loadCatalog
    }

    func load() async throws -> TNoodleScrambleCatalog {
        try await loadCatalog()
    }

    static let bundled = TimerScrambleCatalogLoader {
        try await BundledTNoodleCatalogCache.shared.load()
    }
}

/// Keeps the validated catalog in memory across timer screen navigation.
///
/// The file reads, SHA-256 validation, and parsing are performed by a detached
/// task, never by the main actor. A failed load is deliberately not cached so
/// the user can retry after a transient resource or memory-pressure failure.
private actor BundledTNoodleCatalogCache {
    static let shared = BundledTNoodleCatalogCache()

    private var catalog: TNoodleScrambleCatalog?
    private var inFlight: Task<TNoodleScrambleCatalog, any Error>?

    func load() async throws -> TNoodleScrambleCatalog {
        if let catalog {
            return catalog
        }
        if let inFlight {
            return try await inFlight.value
        }

        let task = Task.detached(priority: .userInitiated) {
            try TNoodleScrambleCatalog.loadBundled()
        }
        inFlight = task

        do {
            let loaded = try await task.value
            catalog = loaded
            inFlight = nil
            return loaded
        } catch {
            inFlight = nil
            throw error
        }
    }
}

/// Walks the validated bundled catalog with a full-cycle stride so one app
/// session does not repeat a scramble until every catalog entry is visited.
final class TimerScrambleGenerator: @unchecked Sendable {
    private let catalog: TNoodleScrambleCatalog
    private let lock = NSLock()
    private var nextIndex: Int
    private let stride: Int

    init(catalog: TNoodleScrambleCatalog, seed: UInt64) {
        self.catalog = catalog
        self.nextIndex = catalog.catalogIndex(seed: seed)
        self.stride = Self.coprimeStride(for: catalog.count)
    }

    func make() -> String {
        lock.withLock {
            let scramble = catalog.scramble3x3(at: nextIndex).notation
            nextIndex = (nextIndex + stride) % catalog.count
            return scramble
        }
    }

    private static func coprimeStride(for count: Int) -> Int {
        var candidate = min(7_919, max(1, count - 1))
        while greatestCommonDivisor(candidate, count) != 1 {
            candidate -= 1
        }
        return candidate
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = lhs
        var b = rhs
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return a
    }
}
