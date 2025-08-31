# API Migration Guide - Phase 3 Variance Computation Enhancement

## Overview

This document outlines the changes introduced in Phase 3 of the Bridget ML pipeline, which adds comprehensive statistical variance computation and uncertainty quantification capabilities.

## Backward Compatibility

✅ **All changes are backward compatible** - No breaking changes to existing APIs.

### PipelineMetricsData Changes

**Before Phase 3:**
```swift
struct PipelineMetricsData: Codable {
  let timestamp: Date
  let stageDurations: [String: Double]
  let memoryUsage: [String: Int]
  let validationRates: [String: Double]
  let errorCounts: [String: Int]
  let recordCounts: [String: Int]
  let customValidationResults: [String: Bool]?
  // No statisticalMetrics field
}
```

**After Phase 3:**
```swift
struct PipelineMetricsData: Codable {
  let timestamp: Date
  let stageDurations: [String: Double]
  let memoryUsage: [String: Int]
  let validationRates: [String: Double]
  let errorCounts: [String: Int]
  let recordCounts: [String: Int]
  let customValidationResults: [String: Bool]?
  let statisticalMetrics: StatisticalTrainingMetrics? // NEW: Optional field
}
```

### Migration Steps

#### For API Consumers

1. **No immediate action required** - Existing code will continue to work
2. **Optional enhancement** - Access `statisticalMetrics` when available:

```swift
// Safe access pattern
if let stats = pipelineData.statisticalMetrics {
    // Use new statistical metrics
    let confidence = stats.performanceConfidenceIntervals.accuracy95CI
    let variance = stats.trainingLossStats.variance
} else {
    // Fallback for older data or when stats unavailable
    print("Statistical metrics not available")
}
```

#### For UI Components

1. **Conditional rendering** - UI automatically adapts:

```swift
// In SwiftUI views
if let statisticalMetrics = data.statisticalMetrics {
    StatisticalUncertaintySection(metrics: statisticalMetrics)
}
// If nil, section is simply not shown
```

## New Data Structures

### StatisticalTrainingMetrics

```swift
public struct StatisticalTrainingMetrics: Codable, Equatable {
    public let trainingLossStats: ETASummary
    public let validationLossStats: ETASummary
    public let predictionAccuracyStats: ETASummary
    public let etaPredictionVariance: ETASummary
    public let performanceConfidenceIntervals: PerformanceConfidenceIntervals
    public let errorDistribution: ErrorDistributionMetrics
}
```

### PerformanceConfidenceIntervals

```swift
public struct PerformanceConfidenceIntervals: Codable, Equatable {
    public let accuracy95CI: ConfidenceInterval
    public let f1Score95CI: ConfidenceInterval
    public let meanError95CI: ConfidenceInterval
}
```

### ErrorDistributionMetrics

```swift
public struct ErrorDistributionMetrics: Codable, Equatable {
    public let absoluteErrorStats: ETASummary
    public let relativeErrorStats: ETASummary
    public let withinOneStdDev: Double
    public let withinTwoStdDev: Double
}
```

## API Versioning

### Current Version: v1.0
- **Base API**: Unchanged
- **New Features**: Statistical metrics (optional)

### Future Considerations
- **v1.1**: May make statistical metrics required
- **v2.0**: Potential breaking changes for major enhancements

## Testing Migration

### Unit Tests
```swift
// Test backward compatibility
func testBackwardCompatibility() {
    let oldData = PipelineMetricsData(
        timestamp: Date(),
        stageDurations: [:],
        memoryUsage: [:],
        validationRates: [:],
        errorCounts: [:],
        recordCounts: [:],
        customValidationResults: nil
        // statisticalMetrics: nil (implicit)
    )
    
    // Should still work
    XCTAssertNotNil(oldData.timestamp)
    XCTAssertNil(oldData.statisticalMetrics)
}
```

### Integration Tests
```swift
// Test new features don't break old functionality
func testNewFeaturesOptional() {
    let newData = PipelineMetricsData(
        timestamp: Date(),
        stageDurations: [:],
        memoryUsage: [:],
        validationRates: [:],
        errorCounts: [:],
        recordCounts: [:],
        customValidationResults: nil,
        statisticalMetrics: createMockStatisticalMetrics()
    )
    
    // Both old and new features should work
    XCTAssertNotNil(newData.timestamp)
    XCTAssertNotNil(newData.statisticalMetrics)
}
```

## Error Handling

### Graceful Degradation
```swift
// Recommended pattern for consuming applications
func processMetrics(_ data: PipelineMetricsData) {
    // Core functionality (always available)
    processStageMetrics(data.stageMetrics)
    
    // Enhanced functionality (optional)
    if let stats = data.statisticalMetrics {
        processStatisticalMetrics(stats)
    } else {
        log.info("Statistical metrics not available - using basic metrics only")
    }
}
```

## Performance Considerations

### Memory Impact
- **Minimal** - Statistical metrics are only computed when needed
- **Optional loading** - Can be disabled for performance-critical scenarios

### Computation Overhead
- **Training time** - Additional variance computation adds ~5-10% overhead
- **Runtime** - No impact on prediction performance
- **Configurable** - Can be disabled via configuration

## Deprecation Timeline

### Phase 3.0 (Current)
- ✅ Statistical metrics introduced as optional
- ✅ Backward compatibility maintained

### Phase 3.1 (Future)
- ⏳ Statistical metrics become recommended
- ⏳ Deprecation warnings for missing metrics

### Phase 4.0 (Future)
- ⏳ Statistical metrics may become required
- ⏳ Breaking changes documented in advance

## Support

For questions about migration or API usage:
- **Documentation**: See inline code documentation
- **Tests**: Reference `CoreMLTrainingPhase3Tests.swift` for usage examples
- **Issues**: Report via project issue tracker




