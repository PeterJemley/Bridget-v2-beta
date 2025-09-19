# TransformMetrics Guide

@Metadata {
    @TechnologyRoot
}

## 🎯 **Overview**

The `TransformMetrics` system provides comprehensive observability and accuracy tracking for coordinate transformation operations. It includes performance metrics, cache statistics, and advanced accuracy diagnostics to ensure transformation reliability and performance.

**Real-World Usage**: Metrics are automatically collected during bridge data processing when the `coordinateTransformation` feature flag is enabled, specifically during Seattle API to Seattle Reference coordinate system transformations in the `BridgeRecordValidator`.

---

## 📊 **Core Metrics**

### **Performance Metrics**
- **Latency**: Transformation operation duration (p50, p95, mean)
- **Throughput**: Number of transformations per second
- **Cache Performance**: Hit/miss rates and eviction counts

### **Accuracy Metrics**
- **Residual Tracking**: Differences between baseline and instrumented results
- **Exact Match Rates**: Percentage of perfect transformations
- **Statistical Analysis**: Median, p95, and maximum residuals by category

---

## 🔄 **Data Flow & Integration**

### **Automatic Collection**
Metrics are automatically collected during these operations:

1. **Bridge Record Validation** (`BridgeRecordValidator.swift`)
   - Seattle API coordinates → Seattle Reference transformation
   - Feature flag controlled: Only when `coordinateTransformation` enabled
   - A/B testing: Performance comparison between control/treatment groups

2. **Coordinate Transformation Service** (`CoordinateTransformService.swift`)
   - Every `transform()` call triggers metrics collection
   - Error tracking for invalid inputs, unsupported systems, matrix unavailability
   - Cache performance monitoring for matrix lookups
   - Request timing and throughput measurement

3. **Dashboard & Monitoring** (`CoordinateTransformationDashboard.swift`)
   - Real-time display of collected metrics
   - Export functionality for analysis
   - Alert configuration and monitoring

### **Feature Flag Control**
- Metrics only collected when `coordinateTransformation` feature flag is enabled
- A/B testing variants control whether transformation (and metrics) are used
- Graceful fallback to threshold-based validation when disabled

---

## 🔧 **API Reference**

### **Basic Metrics Collection**

```swift
// Timing operations
let result = await TransformMetrics.timeOuter {
    // Your transformation code
}

// Cache metrics
await TransformMetrics.hit()      // Record cache hit
await TransformMetrics.miss()     // Record cache miss
await TransformMetrics.eviction() // Record cache eviction

// Gauge metrics
await TransformMetrics.setItems(100)        // Set cache item count
await TransformMetrics.setMemoryBytes(1024) // Set memory usage
```

### **Accuracy Diagnostics**

```swift
// Enable accuracy tracking
TransformMetrics.setAccuracyDiagnosticsEnabled(true)

// Record residuals
await TransformMetrics.recordResidual(
    latResidual: 0.0001,
    lonResidual: 0.0002,
    sourceSystem: .seattleAPI,
    targetSystem: .seattleReference,
    bridgeId: "1"
)

// Record exact matches
await TransformMetrics.recordExactMatch(
    latExact: true,
    lonExact: true,
    sourceSystem: .seattleAPI,
    targetSystem: .seattleReference,
    bridgeId: "1"
)
```

### **Analytics and Reporting**

```swift
// Get comprehensive metrics snapshot
let snapshot = await TransformMetrics.snapshot()

// Get accuracy statistics
let accuracyStats = await TransformMetrics.accuracySnapshot()

// Get exact match rates
let exactMatchRates = await TransformMetrics.exactMatchFractions()
```

---

## 🎯 **Accuracy Tracking Features**

### **Residual Bucketing**
The system tracks accuracy residuals across multiple dimensions:

- **Global**: Overall accuracy across all transformations
- **By System Pair**: Accuracy for specific coordinate system combinations
- **By Bridge**: Accuracy for specific bridge transformations

### **Statistical Analysis**
For each bucket, the system provides:

- **Median Residual**: 50th percentile of accuracy differences
- **P95 Residual**: 95th percentile of accuracy differences  
- **Maximum Residual**: Worst-case accuracy difference
- **Sample Count**: Number of measurements in each bucket

### **Exact Match Tracking**
Tracks the percentage of transformations that produce identical results:

- **Latitude Exact Matches**: Perfect latitude transformations
- **Longitude Exact Matches**: Perfect longitude transformations
- **Combined Exact Matches**: Both coordinates perfect

---

## 🧪 **Testing Integration**

### **Accuracy Guard Test**
The system includes comprehensive accuracy validation with stratified assertions:

```swift
@Test("Gate G: Accuracy guard — median/p95 residual unchanged")
@MainActor
func testGateGAccuracyGuardResiduals() async throws {
    // Enable accuracy diagnostics for enhanced tracking
    TransformMetrics.setAccuracyDiagnosticsEnabled(true)
    defer { TransformMetrics.setAccuracyDiagnosticsEnabled(false) }
    
    // Test ensures metrics/caching don't affect accuracy
    // Validates median ≤ 1e-12 and p95 ≤ 1e-10
    
    // Global accuracy validation
    // System pair accuracy validation (catches localized regressions)
    // Bridge-specific accuracy validation
    // Exact match rate validation (≥95% for deterministic pipeline)
}
```

**Key Features:**
- **Stratified Assertions**: Validates accuracy by system pair (`.residualLatByPair(from:to:)`) and bridge (`.residualLatByBridge(bridgeId)`)
- **Localized Regression Detection**: Catches issues in specific coordinate systems
- **Cross-Validation**: Compares local calculations with TransformMetrics
- **Test Isolation**: Proper cleanup to prevent cross-test contamination
- **Tunable Thresholds**: Start strict (1e-12/1e-10) and relax only for legitimate FP jitter

### **Test Isolation**
- **Diagnostics Toggle**: Enable/disable accuracy tracking per test
- **Storage Reset**: Clean state between tests to prevent cross-test contamination
- **Deterministic Results**: Consistent metrics across test runs

---

## 📈 **Performance Characteristics**

### **Memory Usage**
- **Latency Samples**: Ring buffer with 1024 sample capacity
- **Residual Storage**: Configurable per-bucket storage
- **Gauge Updates**: Real-time memory and item count tracking

### **Computational Overhead**
- **Minimal Impact**: Metrics collection adds <1% overhead
- **Async Operations**: Non-blocking metric recording
- **Efficient Storage**: Optimized data structures for high-frequency updates

---

## 🔍 **Monitoring and Alerting**

### **Key Metrics to Monitor**
1. **Latency P95**: Should remain under performance budget
2. **Cache Hit Rate**: Should be >80% for optimal performance
3. **Accuracy Residuals**: Should remain near zero (≤1e-10)
4. **Exact Match Rate**: Should be >95% for critical transformations

### **Alert Thresholds**
- **Latency P95 > 10ms**: Performance degradation
- **Cache Hit Rate < 70%**: Cache efficiency issues
- **Accuracy P95 > 1e-8**: Potential accuracy drift
- **Exact Match Rate < 90%**: Transformation reliability issues

---

## 🛠️ **Configuration**

### **Metrics Backend**
```swift
// Default: InMemoryMetricsBackend
TransformMetrics.backend = InMemoryMetricsBackend()

// Custom backend for production
TransformMetrics.backend = ProductionMetricsBackend()
```

### **Accuracy Diagnostics**
```swift
// Enable for development/testing
TransformMetrics.setAccuracyDiagnosticsEnabled(true)

// Disable for production (reduces overhead)
TransformMetrics.setAccuracyDiagnosticsEnabled(false)
```

---

## 📚 **Best Practices**

### **Development**
1. **Enable Diagnostics**: Use accuracy tracking during development
2. **Monitor Residuals**: Watch for accuracy drift during changes
3. **Test Coverage**: Include accuracy guard tests in CI/CD

### **Production**
1. **Disable Diagnostics**: Reduce overhead in production
2. **Monitor Key Metrics**: Set up alerts for performance/accuracy
3. **Regular Validation**: Periodic accuracy checks in production

### **Testing**
1. **Test Isolation**: Reset diagnostics between tests with `defer` cleanup
2. **Deterministic Results**: Use fixed seeds for reproducible tests
3. **Comprehensive Coverage**: Test all system pairs and bridges
4. **Stratified Validation**: Use bucketed accuracy checks for localized regression detection
5. **Threshold Tuning**: Start with strict tolerances (1e-12/1e-10) and relax only for legitimate FP jitter
6. **Cross-Validation**: Compare local calculations with TransformMetrics for consistency

---

## 🔗 **Related Documentation**

- [CoordinateTransformationPlanPhase5.md](CoordinateTransformationPlanPhase5.md) - Overall transformation strategy
- [CachingStrategy.md](CachingStrategy.md) - Cache implementation details
- [TestingWorkflow.md](TestingWorkflow.md) - Testing best practices
- [BenchmarkingGuide.md](BenchmarkingGuide.md) - Performance benchmarking

---

## 📝 **Changelog**

### **Phase 5 - Enhanced Accuracy Tracking**
- Added `AccuracyMetricKey` enum for residual bucketing
- Added diagnostics toggle and storage management
- Added residual recording and exact-match tracking
- Added comprehensive accuracy analytics
- Added test isolation and cleanup functionality
- **Enhanced Accuracy Guard Test**: Added stratified assertions for system pairs and bridges
- **Corrected Enum Usage**: Fixed to use proper `.residualLatByPair(from:to:)` and `.residualLatByBridge(bridgeId)` enum cases
- **Localized Regression Detection**: Catches accuracy issues in specific coordinate systems
- **Cross-Validation**: Compares local calculations with TransformMetrics for consistency
- **Tunable Thresholds**: Clear guidance for threshold tuning based on FP jitter

### **Phase 5 - Core Metrics Implementation**
- Implemented basic performance metrics (latency, throughput)
- Implemented cache metrics (hits, misses, evictions)
- Implemented gauge metrics (items, memory usage)
- Added in-memory metrics backend
- Added comprehensive test coverage
