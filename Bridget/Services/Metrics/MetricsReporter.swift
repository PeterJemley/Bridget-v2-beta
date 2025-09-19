import Foundation

public struct DashboardReport: Codable {
    public struct LatencySummary: Codable {
        public let p50: Double
        public let p95: Double
        public let mean: Double
        public let min: Double
        public let max: Double
        public let stable: Double
    }

    public struct CacheSummary: Codable {
        public let items: Int
        public let bytes: Int
        public let hits: Int
        public let misses: Int
        public let evictions: Int
        public var hitRate: Double {
            let total = hits + misses
            return total > 0 ? Double(hits) / Double(total) : 0
        }
    }

    public struct AccuracyBucket: Codable {
        public let name: String
        public let count: Int
        public let median: Double
        public let p95: Double
        public let max: Double
        public let p99: Double?
    }

    public let latency: LatencySummary
    public let cache: CacheSummary
    public let accuracyBuckets: [AccuracyBucket]

    public init(
        latency: LatencySummary,
        cache: CacheSummary,
        accuracyBuckets: [AccuracyBucket]
    ) {
        self.latency = latency
        self.cache = cache
        self.accuracyBuckets = accuracyBuckets
    }
}

public actor MetricsReporter {
    public init() {}

    public func makeReport(window: TimeInterval? = nil) async -> DashboardReport {
        // Fetch latency snapshot
        let latencySnapshot: TransformMetrics.Snapshot
        if let window = window {
            latencySnapshot = await TransformMetrics.snapshot(window: window)
        } else {
            latencySnapshot = await TransformMetrics.snapshot()
        }

        // Fetch accuracy snapshot
        let accuracySnapshot: TransformMetrics.AccuracySnapshot
        if let window = window {
            accuracySnapshot = await TransformMetrics.accuracySnapshot(window: window)
        } else {
            accuracySnapshot = await TransformMetrics.accuracySnapshot()
        }

        // Extract latency summary
        // Prefer typed keys from TransformMetricKey if available
        func value<T: Numeric & Comparable>(_ key: TransformMetricKey<T>) -> Double {
            latencySnapshot[key]?.toDouble() ?? 0
        }

        // Helper extension to convert numeric metric values to Double
        extension Optional where Wrapped: Numeric {
            func toDouble() -> Double {
                if let v = self as? Double { return v }
                if let v = self as? Float { return Double(v) }
                if let v = self as? Int { return Double(v) }
                if let v = self as? Int64 { return Double(v) }
                if let v = self as? UInt { return Double(v) }
                if let v = self as? UInt64 { return Double(v) }
                return 0
            }
        }

        // Unfortunately we cannot add extensions inside function scope in Swift,
        // so move this extension outside the function:
        // We'll do that below, outside the actor.

        // Since we cannot call value<T>(_:) above directly because we don't know the keys,
        // fallback to string-based keys if typed keys not available:
        // Use string metric names only when typed keys are not accessible.
        // Assuming TransformMetrics.Snapshot subscript supports String keys.
        func stringValue(_ key: String) -> Double {
            if let val = latencySnapshot[key] as? Double { return val }
            if let val = latencySnapshot[key] as? Float { return Double(val) }
            if let val = latencySnapshot[key] as? Int { return Double(val) }
            if let val = latencySnapshot[key] as? Int64 { return Double(val) }
            if let val = latencySnapshot[key] as? UInt { return Double(val) }
            if let val = latencySnapshot[key] as? UInt64 { return Double(val) }
            return 0
        }

        // LatencySummary values: p50, p95, mean, min, max, stable
        // Try typed keys, else fallback to string keys
        let p50 = value(TransformMetricKey<Double>("latency.p50")) ?? stringValue("latency.p50")
        let p95 = value(TransformMetricKey<Double>("latency.p95")) ?? stringValue("latency.p95")
        let mean = value(TransformMetricKey<Double>("latency.mean")) ?? stringValue("latency.mean")
        let minV = value(TransformMetricKey<Double>("latency.min")) ?? stringValue("latency.min")
        let maxV = value(TransformMetricKey<Double>("latency.max")) ?? stringValue("latency.max")
        let stable = value(TransformMetricKey<Double>("latency.stable")) ?? stringValue("latency.stable")

        let latencySummary = DashboardReport.LatencySummary(
            p50: p50,
            p95: p95,
            mean: mean,
            min: minV,
            max: maxV,
            stable: stable
        )

        // Cache summary keys: items, bytes, hits, misses, evictions
        let items = Int(value(TransformMetricKey<Int>("cache.items")) ?? Double(stringValue("cache.items")))
        let bytes = Int(value(TransformMetricKey<Int>("cache.bytes")) ?? Double(stringValue("cache.bytes")))
        let hits = Int(value(TransformMetricKey<Int>("cache.hits")) ?? Double(stringValue("cache.hits")))
        let misses = Int(value(TransformMetricKey<Int>("cache.misses")) ?? Double(stringValue("cache.misses")))
        let evictions = Int(value(TransformMetricKey<Int>("cache.evictions")) ?? Double(stringValue("cache.evictions")))

        let cacheSummary = DashboardReport.CacheSummary(
            items: items,
            bytes: bytes,
            hits: hits,
            misses: misses,
            evictions: evictions
        )

        // Map accuracy buckets
        let accuracyBuckets: [DashboardReport.AccuracyBucket] = accuracySnapshot.buckets.map { bucket in
            DashboardReport.AccuracyBucket(
                name: bucket.name,
                count: bucket.count,
                median: bucket.median,
                p95: bucket.p95,
                max: bucket.max,
                p99: bucket.p99
            )
        }

        return DashboardReport(
            latency: latencySummary,
            cache: cacheSummary,
            accuracyBuckets: accuracyBuckets
        )
    }

    public func exportJSON(to url: URL, window: TimeInterval? = nil) async throws {
        let report = await makeReport(window: window)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        let tempURL = url.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: .atomic)
        try FileManager.default.replaceItem(at: url, withItemAt: tempURL)
    }

    public func exportToBenchmarks() async throws {
        let currentDir = FileManager.default.currentDirectoryPath
        let benchmarksDir = URL(fileURLWithPath: currentDir).appendingPathComponent("benchmarks", isDirectory: true)
        try FileManager.default.createDirectory(at: benchmarksDir, withIntermediateDirectories: true)
        let fileURL = benchmarksDir.appendingPathComponent("metrics_latest.json")
        try await exportJSON(to: fileURL)
    }
}

// MARK: - Helpers

private extension Optional where Wrapped == Any {
    func toDouble() -> Double {
        switch self {
        case let val as Double: return val
        case let val as Float: return Double(val)
        case let val as Int: return Double(val)
        case let val as Int64: return Double(val)
        case let val as UInt: return Double(val)
        case let val as UInt64: return Double(val)
        default: return 0
        }
    }
}

private extension Optional where Wrapped: Numeric {
    func toDouble() -> Double {
        if let v = self as? Double { return v }
        if let v = self as? Float { return Double(v) }
        if let v = self as? Int { return Double(v) }
        if let v = self as? Int64 { return Double(v) }
        if let v = self as? UInt { return Double(v) }
        if let v = self as? UInt64 { return Double(v) }
        return 0
    }
}
