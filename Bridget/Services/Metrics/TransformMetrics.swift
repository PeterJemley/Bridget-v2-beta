import Foundation
import Dispatch

// MARK: - Keys

/// Metric keys used for transform metrics.
public enum TransformMetricKey: String, CaseIterable, Sendable {
    case transformLatencySeconds
    case transformThroughputCount
    case cacheHitCount
    case cacheMissCount
    case cacheEvictionCount
    case cacheItemsGauge
    case cacheMemoryBytesGauge
}

// MARK: - Metrics Data Structures

/// Latency statistics snapshot.
public struct LatencyStats: Sendable {
    public let count: Int
    public let mean: Double
    public let p50: Double
    public let p95: Double

    public init(count: Int, mean: Double, p50: Double, p95: Double) {
        self.count = count
        self.mean = mean
        self.p50 = p50
        self.p95 = p95
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
}

// MARK: - InMemoryMetricsBackend Implementation

/// NOTE:
/// Swift 6 enforces stricter rules for Sendable types. This actor uses isolated
/// mutable state and is thread-safe by design, no need for explicit locking.
public actor InMemoryMetricsBackend: @preconcurrency MetricsBackend {

    // MARK: Internal RingBuffer

    internal struct RingBuffer: Sendable {
        private(set) var values: [Double]
        private(set) var index: Int
        let capacity: Int

        init(capacity: Int) {
            self.capacity = capacity
            self.values = []
            self.index = 0
            self.values.reserveCapacity(capacity)
        }

        mutating func append(_ x: Double) {
            if values.count < capacity {
                values.append(x)
            } else {
                values[index] = x
            }
            index = (index + 1) % capacity
        }
    }

    // MARK: Private State

    private var counters: [TransformMetricKey: Int64] = [:]
    private var gauges: [TransformMetricKey: Int64] = [:]
    private var latencySamples: [TransformMetricKey: RingBuffer] = [:]

    private static let latencySamplesCapacity = 1024

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
            let samples = ringBuffer.values
            guard !samples.isEmpty else {
                latencyStats[key] = LatencyStats(count: 0, mean: 0, p50: 0, p95: 0)
                continue
            }

            let count = samples.count
            let mean = samples.reduce(0, +) / Double(count)
            let sortedSamples = samples.sorted()
            let p50 = percentile(sortedSamples, percentile: 0.50)
            let p95 = percentile(sortedSamples, percentile: 0.95)

            latencyStats[key] = LatencyStats(count: count, mean: mean, p50: p50, p95: p95)
        }

        return MetricsSnapshot(counters: countersCopy, gauges: gaugesCopy, latencyStats: latencyStats)
    }
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
