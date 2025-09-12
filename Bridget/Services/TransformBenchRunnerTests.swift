import Foundation
#if canImport(Testing)
import Testing
@testable import Bridget

@Suite("Transform Bench Runner", .serialized)
struct TransformBenchRunner {

    private var shouldRun: Bool {
        ProcessInfo.processInfo.environment["RUN_BENCH"] == "1"
    }

    @Test("Run control + phase5.1 benchmarks", .disabled(if: ProcessInfo.processInfo.environment["RUN_BENCH"] != "1"))
    func runBenchmarks() async throws {
        #require(shouldRun, "Set RUN_BENCH=1 to enable benchmark runner")
        let bench = TransformBench()

        // Ensure benchmarks directory exists
        let fm = FileManager.default
        let dir = "benchmarks"
        if !fm.fileExists(atPath: dir) {
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        // Control-only baseline
        let baseline = try await bench.runControlOnly()
        writeBenchmarksJSON(baseline, to: "benchmarks/baseline.json")

        // Full matrix-only + matrix+point set
        let results = try await bench.runAll()
        writeBenchmarksJSON(results, to: "benchmarks/phase5.1.json")
    }
}

fileprivate func writeBenchmarksJSON<T: Encodable>(_ benchmarks: T, to path: String) {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(benchmarks)
        try data.write(to: URL(fileURLWithPath: path))
    } catch {
        print("Failed to write benchmarks JSON to \(path): \(error)")
    }
}

#endif
