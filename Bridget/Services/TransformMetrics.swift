/// Lightweight metrics shim. Replace implementations with real metrics as needed.
enum TransformMetrics {
    /// Record a counter metric.
    static func incr(_ name: String, by n: Int = 1) {
        // No-op shim. Integrate with your metrics backend here.
    }

    /// Record an observation/timer value in seconds.
    static func observe(_ name: String, _ value: Double) {
        // No-op shim. Integrate with your metrics backend here.
    }

    /// Record a gauge value.
    static func gauge(_ name: String, _ value: Double) {
        // No-op shim. Integrate with your metrics backend here.
    }
}
