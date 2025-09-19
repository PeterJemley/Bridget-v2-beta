import Foundation

struct BenchResult: Codable {
    let name: String
    let n: Int
    let p50: Double
    let p95: Double
    let throughputPtsPerS: Double
    let notes: String
}

@MainActor
final class TransformBench {
    private let service: DefaultCoordinateTransformService
    private let cache: TransformCache

    init() {
        self.service = DefaultCoordinateTransformService(enableLogging: false)
        self.cache = TransformCache(config: .init(matrixCapacity: 512, pointCapacity: 2048, pointTTLSeconds: 60, enablePointCache: true, quantizePrecision: 6))
    }

    func runAll() async throws -> [BenchResult] {
        let sizes = [1, 64, 1_000, 10_000]
        var results: [BenchResult] = []

        for n in sizes {
            results.append(try await benchSingle(name: "control_no_cache_\(n)", n: n, useMatrixCache: false, usePointCache: false))
            results.append(try await benchSingle(name: "matrix_only_\(n)", n: n, useMatrixCache: true, usePointCache: false))
            results.append(try await benchSingle(name: "matrix_plus_point_\(n)", n: n, useMatrixCache: true, usePointCache: true))
        }
        return results
    }

    func runControlOnly() async throws -> [BenchResult] {
        let sizes = [1, 64, 1_000, 10_000]
        var results: [BenchResult] = []
        for n in sizes {
            results.append(try await benchSingle(name: "control_no_cache_\(n)", n: n, useMatrixCache: false, usePointCache: false))
        }
        return results
    }

    private func benchSingle(name: String, n: Int, useMatrixCache: Bool, usePointCache: Bool) async throws -> BenchResult {
        // Prepare points
        let points = (0..<n).map { i in BatchPoint(lat: 47.5 + Double(i % 1000) * 1e-6, lon: -122.3 - Double(i % 1000) * 1e-6) }

        // Configure service instance according to matrix cache flag
        let svc = DefaultCoordinateTransformService(enableLogging: false, enableMatrixCaching: useMatrixCache)

        // Warmup
        _ = try await svc.transformBatch(points: points, from: .seattleReference, to: .seattleReference, bridgeId: nil, pointCache: usePointCache ? cache : nil, chunkSize: 1024, concurrencyCap: 4)

        // Timed runs
        let runs = 5
        var samples: [Double] = []
        for _ in 0..<runs {
            let t0 = CFAbsoluteTimeGetCurrent()
            _ = try await svc.transformBatch(points: points, from: .seattleReference, to: .seattleReference, bridgeId: nil, pointCache: usePointCache ? cache : nil, chunkSize: 1024, concurrencyCap: 4)
            let dt = CFAbsoluteTimeGetCurrent() - t0
            samples.append(dt)
        }

        samples.sort()
        let p50 = samples[samples.count/2]
        let p95 = samples[Int(Double(samples.count - 1) * 0.95)]
        let throughput = p50 > 0 ? Double(n) / p50 : 0

        return BenchResult(name: name, n: n, p50: p50, p95: p95, throughputPtsPerS: throughput, notes: "ref=seattleReference->seattleReference")
    }
}

@MainActor
func writeBenchmarksJSON(_ results: [BenchResult], to path: String) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
        let data = try encoder.encode(results)
        try data.write(to: URL(fileURLWithPath: path))
        print("✅ Wrote benchmarks to \(path)")
    } catch {
        print("❌ Failed to write benchmarks: \(error)")
    }
}

// Note: This file is now deprecated. Use the standalone TransformBench CLI tool instead.
// The TransformBench CLI tool is located in the TransformBench/ directory and can be run with:
// cd TransformBench && swift run TransformBench
