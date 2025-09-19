import Foundation
import Dispatch

// MARK: - Keys

/// Metric keys used for transform metrics.
public enum TransformMetricKey: String, CaseIterable, Sendable {
    case transformLatencySeconds
    case transformThroughputCount
    case cacheMatrixHits
    case cacheMatrixMisses
    case cacheMatrixEvictions
    case cacheMatrixItems
    case cacheMatrixMemoryBytes
    case cacheHitCount
    case cacheMissCount
    case cacheEvictionCount
    case cacheItemsGauge
    case cacheMemoryBytesGauge
}

// MARK: - Accuracy Diagnostics

/// Keys for accuracy metric bucketing.
public enum AccuracyMetricKey: Hashable, Sendable {
    case global
    case byPair(from: String, to: String)
    case byBridge(String)

    public var key: String {
        switch self {
        case .global: return "global"
        case let .byPair(from, to): return "pair:\(from)->\(to)"
        case let .byBridge(b): return "bridge:\(b)"
        }
    }
}

// MARK: - Metrics Data Structures

/// Latency statistics snapshot.
public struct LatencyStats: Sendable {
    public let count: Int
    public let mean: Double
    public let p50: Double
    public let p90: Double
    public let p95: Double
    public let p99: Double?
    public let min: Double
    public let max: Double
    public let stddev: Double
    public let isStable: Bool

    public init(count: Int, mean: Double, p50: Double, p90: Double, p95: Double, p99: Double?, min: Double, max: Double, stddev: Double, isStable: Bool) {
        self.count = count
        self.mean = mean
        self.p50 = p50
        self.p90 = p90
        self.p95 = p95
        self.p99 = p99
        self.min = min
        self.max = max
        self.stddev = stddev
        self.isStable = isStable
    }
}

/// Snapshot of all metrics at a point in time.
public struct MetricsSnapshot: Sendable {
    public let counters: [TransformMetricKey: Int64]
    public let gauges: [TransformMetricKey: Int64]
    public let latencyStats: [TransformMetricKey: LatencyStats]

    public init(
        counters: [TransformMetricKey: Int64],
        gauges: [TransformMetricKey: Int64],
        latencyStats: [TransformMetricKey: LatencyStats]
    ) {
        self.counters = counters
        self.gauges = gauges
        self.latencyStats = latencyStats
    }
}

/// Histogram bin for distribution visualization.
public struct HistogramBin: Sendable {
    public let lowerBound: Double
    public let upperBound: Double
    public let count: Int
    
    public init(lowerBound: Double, upperBound: Double, count: Int) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.count = count
    }
}

/// Accuracy statistics snapshot.
public struct AccuracyStats: Sendable {
    public struct Bucket: Sendable {
        public let count: Int
        public let mean: Double
        public let median: Double
        public let p90: Double
        public let p95: Double
        public let p99: Double?
        public let min: Double
        public let max: Double
        public let stddev: Double
        public let skewness: Double
        public let isStable: Bool  // true if sample size >= minimum threshold
        public let histogram: [HistogramBin]  // For UI visualization
        
        public init(count: Int, mean: Double, median: Double, p90: Double, p95: Double, p99: Double?, min: Double, max: Double, stddev: Double, skewness: Double, isStable: Bool, histogram: [HistogramBin]) {
            self.count = count
            self.mean = mean
            self.median = median
            self.p90 = p90
            self.p95 = p95
            self.p99 = p99
            self.min = min
            self.max = max
            self.stddev = stddev
            self.skewness = skewness
            self.isStable = isStable
            self.histogram = histogram
        }
    }
    
    public let buckets: [String: Bucket]
    
    public init(buckets: [String: Bucket]) {
        self.buckets = buckets
    }
}

#if DEBUG
/// Debug snapshot for white-box testing (DEBUG only).
public struct DebugSnapshot: Sendable {
    public let counters: [String: Int64]
    public let gauges: [String: Double]
    public let timers: [String: [Double]]
    public let accuracyEnabled: Bool
    public let residuals: [String: [Double]]
    
    public init(counters: [String: Int64], gauges: [String: Double], timers: [String: [Double]], accuracyEnabled: Bool, residuals: [String: [Double]]) {
        self.counters = counters
        self.gauges = gauges
        self.timers = timers
        self.accuracyEnabled = accuracyEnabled
        self.residuals = residuals
    }
}
#endif

// MARK: - Protocols

/// Backend interface for metrics.
public protocol MetricsBackend: Sendable {
    /// Increment counter for key by amount.
    func counter(_ key: TransformMetricKey, by amount: Int64) async

    /// Set gauge for key to value.
    func gauge(_ key: TransformMetricKey, set value: Int64) async

    /// Start a timer for the given key.
    func timerStart(_ key: TransformMetricKey) async -> TimerToken

    /// Stop timer and return elapsed duration in seconds.
    func timerStop(_ token: TimerToken) -> Double

    /// Record a duration sample in seconds for the given key.
    func recordDuration(_ key: TransformMetricKey, seconds: Double) async

    /// Capture a snapshot of the current metrics.
    func snapshot() async -> MetricsSnapshot
    
    // MARK: - String-based API Support
    
    /// Increment counter by name.
    func counter(name: String, by amount: Int64) async
    
    /// Set gauge by name.
    func gauge(name: String, value: Double) async
    
    /// Record timing by name.
    func timing(name: String, seconds: Double) async
    
    // MARK: - Accuracy Diagnostics
    
    /// Record residual for accuracy diagnostics.
    func recordResidual(_ meters: Double, key: AccuracyMetricKey) async
    
    /// Enable/disable accuracy diagnostics.
    func setAccuracyDiagnosticsEnabled(_ enabled: Bool) async
    
    /// Get accuracy snapshot.
    func accuracySnapshot() async -> AccuracyStats
    
    /// Get accuracy snapshot for a specific time window.
    func accuracySnapshot(window: TimeInterval) async -> AccuracyStats
    
    /// Get metrics snapshot for a specific time window.
    func snapshot(window: TimeInterval) async -> MetricsSnapshot
    
    /// Reset all metrics to clean state (for test isolation).
    func reset() async
    
    #if DEBUG
    /// Debug snapshot for white-box testing (DEBUG only).
    func debugSnapshot() async -> DebugSnapshot
    #endif
}

/// A token returned by MetricsBackend.timerStart and used for timerStop.
public struct TimerToken: Sendable {
    public let key: TransformMetricKey
    public let startUptime: UInt64

    public init(key: TransformMetricKey, startUptime: UInt64) {
        self.key = key
        self.startUptime = startUptime
    }
}

// MARK: - TransformMetrics Namespace

/// Namespace for transform metrics helpers.
public enum TransformMetrics {
    /// The global metrics backend instance.
    public static var backend: any MetricsBackend = InMemoryMetricsBackend()
    
    /// Enable/disable flag for metrics collection.
    public static var enabled = true

    /// Measure and record duration under `.transformLatencySeconds` and increment `.transformThroughputCount` by 1.
    ///
    /// Outer timer is for SLOs.
    @inline(__always)
    public static func timeOuter<T>(_ body: () -> T) async -> T {
        let token = await backend.timerStart(.transformLatencySeconds)
        let result = body()
        let seconds = backend.timerStop(token)
        await backend.recordDuration(.transformLatencySeconds, seconds: seconds)
        await backend.counter(.transformThroughputCount, by: 1)
        return result
    }

    /// Measure and record duration under `.transformLatencySeconds` only (no throughput increment).
    ///
    /// Inner timer is for diagnostics only.
    @inline(__always)
    public static func timeInner<T>(_ body: () -> T) async -> T {
        let token = await backend.timerStart(.transformLatencySeconds)
        let result = body()
        let seconds = backend.timerStop(token)
        await backend.recordDuration(.transformLatencySeconds, seconds: seconds)
        return result
    }

    /// Increment cache hit count by 1.
    @inline(__always)
    public static func hit() async {
        await backend.counter(.cacheHitCount, by: 1)
    }

    /// Increment cache miss count by 1.
    @inline(__always)
    public static func miss() async {
        await backend.counter(.cacheMissCount, by: 1)
    }

    /// Increment cache eviction count by 1.
    @inline(__always)
    public static func eviction() async {
        await backend.counter(.cacheEvictionCount, by: 1)
    }

    /// Set the cache items gauge to the specified count.
    @inline(__always)
    public static func setItems(_ n: Int) async {
        await backend.gauge(.cacheItemsGauge, set: Int64(n))
    }

    /// Set the cache memory bytes gauge to the specified value.
    @inline(__always)
    public static func setMemoryBytes(_ n: Int64) async {
        await backend.gauge(.cacheMemoryBytesGauge, set: n)
    }

    /// Return current metrics snapshot.
    public static func snapshot() async -> MetricsSnapshot {
        await backend.snapshot()
    }
    
    // MARK: - String-based API (for compatibility with instrumentation)
    
    /// Increment counter by name.
    public static func incr(_ name: String, by n: Int = 1) async {
        guard enabled else { return }
        await backend.counter(name: name, by: Int64(n))
    }
    
    /// Set gauge by name.
    public static func gauge(_ name: String, _ value: Double) async {
        guard enabled else { return }
        await backend.gauge(name: name, value: value)
    }
    
    /// Record timing by name.
    public static func timing(_ name: String, seconds: Double) async {
        guard enabled else { return }
        await backend.timing(name: name, seconds: seconds)
    }
    
    /// Convenience wrapper to time a synchronous block.
    @discardableResult
    public static func time<T>(_ name: String, _ work: () throws -> T) rethrows -> T {
        guard enabled else { return try work() }
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - t0
            Task {
                await timing(name, seconds: elapsed)
            }
        }
        return try work()
    }
    
    /// Async timing helper.
    @discardableResult
    public static func timeAsync<T>(_ name: String, _ work: () async throws -> T) async rethrows -> T {
        guard enabled else { return try await work() }
        let t0 = CFAbsoluteTimeGetCurrent()
        let result = try await work()
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        await timing(name, seconds: elapsed)
        return result
    }
    
    // MARK: - Accuracy Diagnostics
    
    /// Enable/disable accuracy diagnostics.
    public static func setAccuracyDiagnosticsEnabled(_ enabled: Bool) async {
        await backend.setAccuracyDiagnosticsEnabled(enabled)
    }
    
    /// Record residual for accuracy diagnostics.
    public static func recordResidual(_ meters: Double, key: AccuracyMetricKey = .global) async {
        await backend.recordResidual(meters, key: key)
    }
    
    /// Get accuracy snapshot.
    public static func accuracySnapshot() async -> AccuracyStats {
        await backend.accuracySnapshot()
    }
    
    /// Get accuracy statistics snapshot for a specific time window.
    /// - Parameter window: Time window in seconds (e.g., 3600 for last hour)
    public static func accuracySnapshot(window: TimeInterval) async -> AccuracyStats {
        await backend.accuracySnapshot(window: window)
    }
    
    /// Get metrics snapshot for a specific time window.
    /// - Parameter window: Time window in seconds (e.g., 3600 for last hour)
    public static func snapshot(window: TimeInterval) async -> MetricsSnapshot {
        await backend.snapshot(window: window)
    }
    
    // MARK: - Debug and Test Support
    
    /// Enable metrics collection (default: true).
    public static func enable() {
        enabled = true
    }
    
    /// Disable metrics collection.
    public static func disable() {
        enabled = false
    }
    
    /// Reset all metrics to clean state (for test isolation).
    public static func reset() async {
        await backend.reset()
    }
    
    #if DEBUG
    /// Debug snapshot for white-box testing (DEBUG only).
    public static func debugSnapshot() async -> DebugSnapshot {
        await backend.debugSnapshot()
    }
    #endif
}

// MARK: - InMemoryMetricsBackend Implementation

/// NOTE:
/// Swift 6 enforces stricter rules for Sendable types. This actor uses isolated
/// mutable state and is thread-safe by design, no need for explicit locking.
public actor InMemoryMetricsBackend: @preconcurrency MetricsBackend {

    // MARK: Internal RingBuffer

    internal struct RingBuffer: Sendable {
        private(set) var values: [Double]
        private(set) var timestamps: [Date]
        private(set) var index: Int
        let capacity: Int

        init(capacity: Int) {
            self.capacity = capacity
            self.values = []
            self.timestamps = []
            self.index = 0
            self.values.reserveCapacity(capacity)
            self.timestamps.reserveCapacity(capacity)
        }

        mutating func append(_ x: Double) {
            let now = Date()
            if values.count < capacity {
                values.append(x)
                timestamps.append(now)
            } else {
                values[index] = x
                timestamps[index] = now
            }
            index = (index + 1) % capacity
        }
        
        /// Returns values within the specified time window.
        func valuesInWindow(_ window: TimeInterval) -> [Double] {
            let cutoffTime = Date().addingTimeInterval(-window)
            return zip(values, timestamps).compactMap { value, timestamp in
                timestamp >= cutoffTime ? value : nil
            }
        }
        
        /// Returns all values (for lifetime snapshots).
        var allValues: [Double] { values }
    }

    // MARK: Private State

    private var counters: [TransformMetricKey: Int64] = [:]
    private var gauges: [TransformMetricKey: Int64] = [:]
    private var latencySamples: [TransformMetricKey: RingBuffer] = [:]
    
    // String-based metrics
    private var stringCounters: [String: Int64] = [:]
    private var stringGauges: [String: Double] = [:]
    private var stringTimers: [String: RingBuffer] = [:]
    
    // Accuracy diagnostics
    private var accuracyEnabled = false
    private var residualsByKey: [String: RingBuffer] = [:]

    private static let latencySamplesCapacity = 1024
    
    // Statistical stability thresholds
    private static let minimumSampleSizeForP99 = 500  // P99 requires more samples for stability
    private static let minimumSampleSizeForStableStats = 100  // General stability threshold

    // MARK: Init

    public init() {
        // Initialize latencySamples dictionary with empty buffers for all keys
        for key in TransformMetricKey.allCases {
            latencySamples[key] = RingBuffer(capacity: Self.latencySamplesCapacity)
        }
    }

    // MARK: MetricsBackend

    public func counter(_ key: TransformMetricKey, by amount: Int64) async {
        counters[key, default: 0] += amount
    }

    public func gauge(_ key: TransformMetricKey, set value: Int64) async {
        gauges[key] = value
    }

    public func timerStart(_ key: TransformMetricKey) async -> TimerToken {
        let start = DispatchTime.now().uptimeNanoseconds
        return TimerToken(key: key, startUptime: start)
    }

    public nonisolated func timerStop(_ token: TimerToken) -> Double {
        let end = DispatchTime.now().uptimeNanoseconds
        let delta = Double(end &- token.startUptime) / 1_000_000_000.0
        return max(0, delta)
    }

    public func recordDuration(_ key: TransformMetricKey, seconds: Double) async {
        guard seconds >= 0 else { return }
        if latencySamples[key] == nil {
            latencySamples[key] = RingBuffer(capacity: Self.latencySamplesCapacity)
        }
        latencySamples[key]!.append(seconds)
    }

    public func snapshot() async -> MetricsSnapshot {
        let countersCopy = counters
        let gaugesCopy = gauges
        let latencySamplesCopy = latencySamples

        var latencyStats: [TransformMetricKey: LatencyStats] = [:]

        for (key, ringBuffer) in latencySamplesCopy {
            let samples = ringBuffer.allValues
            guard !samples.isEmpty else {
                latencyStats[key] = LatencyStats(
                    count: 0, mean: 0, p50: 0, p90: 0, p95: 0, p99: nil,
                    min: 0, max: 0, stddev: 0, isStable: false
                )
                continue
            }

            let count = samples.count
            let sortedSamples = samples.sorted()
            
            // Calculate all statistical measures
            let meanValue = mean(samples)
            let p50 = percentile(sortedSamples, percentile: 0.50)
            let p90 = percentile(sortedSamples, percentile: 0.90)
            let p95 = percentile(sortedSamples, percentile: 0.95)
            let minValue = sortedSamples.first ?? 0
            let maxValue = sortedSamples.last ?? 0
            let stddevValue = stddev(samples)
            
            // Calculate P99 only if we have sufficient samples for stability
            let p99Value: Double? = count >= Self.minimumSampleSizeForP99 ? 
                percentile(sortedSamples, percentile: 0.99) : nil
            
            // Determine if stats are stable based on sample size
            let isStable = count >= Self.minimumSampleSizeForStableStats

            latencyStats[key] = LatencyStats(
                count: count, mean: meanValue, p50: p50, p90: p90, p95: p95, p99: p99Value,
                min: minValue, max: maxValue, stddev: stddevValue, isStable: isStable
            )
        }

        return MetricsSnapshot(counters: countersCopy, gauges: gaugesCopy, latencyStats: latencyStats)
    }
    
    // MARK: - String-based API Implementation
    
    public func counter(name: String, by amount: Int64) async {
        stringCounters[name, default: 0] += amount
    }
    
    public func gauge(name: String, value: Double) async {
        stringGauges[name] = value
    }
    
    public func timing(name: String, seconds: Double) async {
        guard seconds >= 0 else { return }
        if stringTimers[name] == nil {
            stringTimers[name] = RingBuffer(capacity: Self.latencySamplesCapacity)
        }
        stringTimers[name]!.append(seconds)
    }
    
    // MARK: - Accuracy Diagnostics Implementation
    
    public func setAccuracyDiagnosticsEnabled(_ enabled: Bool) async {
        accuracyEnabled = enabled
        if !enabled {
            residualsByKey.removeAll()
        }
    }
    
    public func recordResidual(_ meters: Double, key: AccuracyMetricKey) async {
        guard accuracyEnabled else { return }
        let keyString = key.key
        if residualsByKey[keyString] == nil {
            residualsByKey[keyString] = RingBuffer(capacity: Self.latencySamplesCapacity)
        }
        residualsByKey[keyString]!.append(meters)
    }
    
    public func accuracySnapshot() async -> AccuracyStats {
        let residualsCopy = residualsByKey
        var buckets: [String: AccuracyStats.Bucket] = [:]
        
        for (key, ringBuffer) in residualsCopy {
            let samples = ringBuffer.allValues
            guard !samples.isEmpty else {
                buckets[key] = AccuracyStats.Bucket(
                    count: 0, mean: 0, median: 0, p90: 0, p95: 0, p99: nil,
                    min: 0, max: 0, stddev: 0, skewness: 0, isStable: false,
                    histogram: []
                )
                continue
            }
            
            let count = samples.count
            let sortedSamples = samples.sorted()
            
            // Calculate basic statistical measures (always available)
            let meanValue = mean(samples)
            let median = percentile(sortedSamples, percentile: 0.50)
            let p90 = percentile(sortedSamples, percentile: 0.90)
            let p95 = percentile(sortedSamples, percentile: 0.95)
            let minValue = sortedSamples.first ?? 0
            let maxValue = sortedSamples.last ?? 0
            let stddevValue = stddev(samples)
            let skewnessValue = skewness(samples)
            
            // Calculate P99 only if we have sufficient samples for stability
            let p99Value: Double? = count >= Self.minimumSampleSizeForP99 ? 
                percentile(sortedSamples, percentile: 0.99) : nil
            
            // Determine if stats are stable based on sample size
            let isStable = count >= Self.minimumSampleSizeForStableStats
            
            // Generate histogram for UI visualization (only for stable samples)
            let histogram = isStable ? generateHistogram(samples) : []
            
            buckets[key] = AccuracyStats.Bucket(
                count: count,
                mean: meanValue,
                median: median,
                p90: p90,
                p95: p95,
                p99: p99Value,
                min: minValue,
                max: maxValue,
                stddev: stddevValue,
                skewness: skewnessValue,
                isStable: isStable,
                histogram: histogram
            )
        }
        
        return AccuracyStats(buckets: buckets)
    }
    
    public func accuracySnapshot(window: TimeInterval) async -> AccuracyStats {
        let residualsCopy = residualsByKey
        var buckets: [String: AccuracyStats.Bucket] = [:]
        
        for (key, ringBuffer) in residualsCopy {
            let samples = ringBuffer.valuesInWindow(window)
            guard !samples.isEmpty else {
                buckets[key] = AccuracyStats.Bucket(
                    count: 0, mean: 0, median: 0, p90: 0, p95: 0, p99: nil,
                    min: 0, max: 0, stddev: 0, skewness: 0, isStable: false,
                    histogram: []
                )
                continue
            }
            
            let count = samples.count
            let sortedSamples = samples.sorted()
            
            // Calculate basic statistical measures (always available)
            let meanValue = mean(samples)
            let median = percentile(sortedSamples, percentile: 0.50)
            let p90 = percentile(sortedSamples, percentile: 0.90)
            let p95 = percentile(sortedSamples, percentile: 0.95)
            let minValue = sortedSamples.first ?? 0
            let maxValue = sortedSamples.last ?? 0
            let stddevValue = stddev(samples)
            let skewnessValue = skewness(samples)
            
            // Calculate P99 only if we have sufficient samples for stability
            let p99Value: Double? = count >= Self.minimumSampleSizeForP99 ? 
                percentile(sortedSamples, percentile: 0.99) : nil
            
            // Determine if stats are stable based on sample size
            let isStable = count >= Self.minimumSampleSizeForStableStats
            
            // Generate histogram for UI visualization (only for stable samples)
            let histogram = isStable ? generateHistogram(samples) : []
            
            buckets[key] = AccuracyStats.Bucket(
                count: count,
                mean: meanValue,
                median: median,
                p90: p90,
                p95: p95,
                p99: p99Value,
                min: minValue,
                max: maxValue,
                stddev: stddevValue,
                skewness: skewnessValue,
                isStable: isStable,
                histogram: histogram
            )
        }
        
        return AccuracyStats(buckets: buckets)
    }
    
    public func snapshot(window: TimeInterval) async -> MetricsSnapshot {
        let countersCopy = counters
        let gaugesCopy = gauges
        let latencySamplesCopy = latencySamples

        var latencyStats: [TransformMetricKey: LatencyStats] = [:]

        for (key, ringBuffer) in latencySamplesCopy {
            let samples = ringBuffer.valuesInWindow(window)
            guard !samples.isEmpty else {
                latencyStats[key] = LatencyStats(
                    count: 0, mean: 0, p50: 0, p90: 0, p95: 0, p99: nil,
                    min: 0, max: 0, stddev: 0, isStable: false
                )
                continue
            }

            let count = samples.count
            let sortedSamples = samples.sorted()
            
            // Calculate all statistical measures
            let meanValue = mean(samples)
            let p50 = percentile(sortedSamples, percentile: 0.50)
            let p90 = percentile(sortedSamples, percentile: 0.90)
            let p95 = percentile(sortedSamples, percentile: 0.95)
            let minValue = sortedSamples.first ?? 0
            let maxValue = sortedSamples.last ?? 0
            let stddevValue = stddev(samples)
            
            // Calculate P99 only if we have sufficient samples for stability
            let p99Value: Double? = count >= Self.minimumSampleSizeForP99 ? 
                percentile(sortedSamples, percentile: 0.99) : nil
            
            // Determine if stats are stable based on sample size
            let isStable = count >= Self.minimumSampleSizeForStableStats

            latencyStats[key] = LatencyStats(
                count: count, mean: meanValue, p50: p50, p90: p90, p95: p95, p99: p99Value,
                min: minValue, max: maxValue, stddev: stddevValue, isStable: isStable
            )
        }

        return MetricsSnapshot(counters: countersCopy, gauges: gaugesCopy, latencyStats: latencyStats)
    }
    
    // MARK: - Debug and Test Support Implementation
    
    public func reset() async {
        counters.removeAll()
        gauges.removeAll()
        latencySamples.removeAll()
        stringCounters.removeAll()
        stringGauges.removeAll()
        stringTimers.removeAll()
        accuracyEnabled = false
        residualsByKey.removeAll()
        
        // Reinitialize latency samples for typed keys
        for key in TransformMetricKey.allCases {
            latencySamples[key] = RingBuffer(capacity: Self.latencySamplesCapacity)
        }
    }
    
    #if DEBUG
    public func debugSnapshot() async -> DebugSnapshot {
        let stringTimersCopy = stringTimers
        let residualsCopy = residualsByKey
        
        var timerValues: [String: [Double]] = [:]
        for (name, ringBuffer) in stringTimersCopy {
            timerValues[name] = ringBuffer.values
        }
        
        var residualValues: [String: [Double]] = [:]
        for (key, ringBuffer) in residualsCopy {
            residualValues[key] = ringBuffer.values
        }
        
        return DebugSnapshot(
            counters: stringCounters,
            gauges: stringGauges,
            timers: timerValues,
            accuracyEnabled: accuracyEnabled,
            residuals: residualValues
        )
    }
    #endif
}

// MARK: - Helpers

/// Computes the p-th percentile from a sorted array of Double.
/// p is a fraction between 0 and 1.
private func percentile(_ sorted: [Double], percentile p: Double) -> Double {
    guard !sorted.isEmpty else { return 0 }
    let n = Double(sorted.count)
    let rank = p * (n - 1)
    let lowerIndex = Int(floor(rank))
    let upperIndex = Int(ceil(rank))
    if lowerIndex == upperIndex {
        return sorted[lowerIndex]
    } else {
        let weight = rank - Double(lowerIndex)
        return sorted[lowerIndex] * (1 - weight) + sorted[upperIndex] * weight
    }
}

/// Computes mean of an array of Double values.
private func mean(_ data: [Double]) -> Double {
    guard !data.isEmpty else { return 0 }
    return data.reduce(0, +) / Double(data.count)
}

/// Computes standard deviation of an array of Double values.
private func stddev(_ data: [Double]) -> Double {
    guard data.count > 1 else { return 0 }
    let m = mean(data)
    let variance = data.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(data.count)
    return sqrt(variance)
}

/// Computes skewness (Fisher-Pearson standardized moment coefficient) of an array of Double values.
private func skewness(_ data: [Double]) -> Double {
    guard data.count > 2 else { return 0 }
    let m = mean(data)
    let sd = stddev(data)
    guard sd > 0 else { return 0 }
    let n = Double(data.count)
    let m3 = data.map { pow($0 - m, 3) }.reduce(0, +) / n
    return m3 / pow(sd, 3)
}

/// Generates histogram bins for distribution visualization.
private func generateHistogram(_ data: [Double], numBins: Int = 20) -> [HistogramBin] {
    guard !data.isEmpty, numBins > 0 else { return [] }
    
    let sortedData = data.sorted()
    let min = sortedData.first!
    let max = sortedData.last!
    
    // Use log-scaled bins for better visualization of wide ranges
    let logMin = log10(Swift.max(min, 1e-12))  // Avoid log(0)
    let logMax = log10(max)
    let binWidth = (logMax - logMin) / Double(numBins)
    
    var bins: [HistogramBin] = []
    var binCounts = Array(repeating: 0, count: numBins)
    
    for value in data {
        let logValue = log10(Swift.max(value, 1e-12))
        let binIndex = Swift.min(Int((logValue - logMin) / binWidth), numBins - 1)
        binCounts[binIndex] += 1
    }
    
    for i in 0..<numBins {
        let lowerBound = pow(10, logMin + Double(i) * binWidth)
        let upperBound = pow(10, logMin + Double(i + 1) * binWidth)
        bins.append(HistogramBin(lowerBound: lowerBound, upperBound: upperBound, count: binCounts[i]))
    }
    
    return bins
}
