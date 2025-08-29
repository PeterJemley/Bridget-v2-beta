# PathScoringService API Guide

## Overview

The `PathScoringService` is a core component of the Bridget Multi-Path Traffic Prediction system. It integrates ETA estimation and bridge prediction to compute the probability that complete route paths will be traversable.

## Key Features

- **Log-domain aggregation**: Uses log-domain math to avoid numerical underflow
- **Batch processing**: Efficiently processes multiple paths and predictions
- **Deterministic features**: Generates reproducible feature vectors for ML models
- **Robust error handling**: Comprehensive error types and graceful failure modes
- **Configuration validation**: Validates service configuration at initialization

## Mathematical Background

### Joint Probability
For a path with bridges B₁, B₂, ..., Bₙ:
```
P(all bridges open) = ∏ P(bridge_i open)
```

### Log-domain Aggregation
To avoid numerical underflow with small probabilities:
```
log(P) = ∑ log(P_i)
```

### Network Probability
For multiple paths P₁, P₂, ..., Pₘ:
```
P(at least one path open) = 1 - ∏(1 - P(path_i))
```

## API Reference

### Initialization

```swift
let service = try PathScoringService(
    predictor: bridgePredictor,
    etaEstimator: etaEstimator,
    config: multiPathConfig
)
```

**Parameters:**
- `predictor`: Bridge opening probability predictor
- `etaEstimator`: ETA estimation service
- `config`: Multi-path configuration

**Throws:** `PathScoringError.configurationError` if configuration is invalid

### Core Methods

#### `scorePath(_:departureTime:)`

Scores a single route path by aggregating bridge opening probabilities.

```swift
let pathScore = try await service.scorePath(routePath, departureTime: Date())
```

**Parameters:**
- `path`: The RoutePath to score (must be valid and contain at least one bridge)
- `departureTime`: The travel start time

**Returns:** `PathScore` containing aggregated probability and bridge-level information

**Throws:** `PathScoringError` for validation, prediction, or feature generation failures

#### `scorePaths(_:departureTime:)`

Scores multiple paths efficiently using batch processing.

```swift
let pathScores = try await service.scorePaths(alternativePaths, departureTime: Date())
```

**Parameters:**
- `paths`: Array of RoutePaths to score (can be empty)
- `departureTime`: The travel start time

**Returns:** Array of `PathScore` in the same order as input paths

**Throws:** `PathScoringError` if any path fails validation or processing

#### `analyzeJourney(paths:startNode:endNode:departureTime:)`

Analyzes a complete journey with multiple paths and computes network-level probability.

```swift
let journeyAnalysis = try await service.analyzeJourney(
    paths: alternativePaths,
    startNode: "A",
    endNode: "B",
    departureTime: Date()
)
```

**Parameters:**
- `paths`: Array of RoutePaths to analyze (can be empty)
- `startNode`: Starting node ID
- `endNode`: Destination node ID
- `departureTime`: The travel start time

**Returns:** `JourneyAnalysis` with path scores, network probability, and statistical summary

**Throws:** `PathScoringError` if any path fails validation or processing

## Data Structures

### PathScore

```swift
public struct PathScore {
    let path: RoutePath
    let departureTime: Date
    let etaEstimates: [ETA]
    let bridgeProbabilities: [String: Double]
    let logProbability: Double
    let linearProbability: Double
}
```

### JourneyAnalysis

```swift
public struct JourneyAnalysis {
    let pathScores: [PathScore]
    let networkProbability: Double
    let bestPathProbability: Double
    let bestPathIndex: Int?
    let pathStatistics: PathStatistics
}
```

### PathStatistics

```swift
public struct PathStatistics {
    let mean: Double
    let min: Double
    let max: Double
    let standardDeviation: Double
}
```

## Error Handling

### PathScoringError Types

```swift
public enum PathScoringError: Error, LocalizedError {
    case invalidPath(String)
    case predictionFailed(String)
    case featureGenerationFailed(String)
    case emptyPathSet(String)
    case unsupportedBridge(String)
    case configurationError(String)
}
```

### Error Handling Example

```swift
do {
    let score = try await service.scorePath(path, departureTime: Date())
    print("Path probability: \(score.linearProbability)")
} catch let error as PathScoringError {
    switch error {
    case .invalidPath(let reason):
        print("Path validation failed: \(reason)")
    case .predictionFailed(let reason):
        print("Prediction failed: \(reason)")
    case .unsupportedBridge(let bridgeID):
        print("Bridge not supported: \(bridgeID)")
    default:
        print("Other error: \(error.localizedDescription)")
    }
}
```

## Feature Engineering

### Feature Categories

The service generates comprehensive feature vectors including:

1. **Time-based Features**
   - Cyclical time encoding (hour/minute as sin/cos)
   - Day of week encoding
   - Rush hour detection
   - Weekend adjustments

2. **Bridge-specific Features**
   - Opening rates (5-minute and 30-minute)
   - Crossing rate
   - Gate anomaly

3. **Path Context Features**
   - Detour delta
   - Via routable
   - Via penalty
   - Detour fraction

4. **Traffic Features**
   - Current speed
   - Normal speed

### Deterministic Behavior

Features are generated using a seeded random number generator based on:
- Bridge ID hash value
- Arrival time (minute + hour)
- Path characteristics

This ensures identical inputs produce identical feature vectors.

## Performance Characteristics

### Time Complexity
- **Single Path**: O(n) where n is the number of bridges
- **Multiple Paths**: O(n × m) where n = number of paths, m = average bridges per path

### Space Complexity
- **Single Path**: O(n) for feature vectors and probability storage
- **Multiple Paths**: O(n × m) for storing all path scores

### Batch Efficiency
- Uses `predictBatch` for optimal ML model inference
- Roughly 10 paths per second (configurable)

## Configuration

### MultiPathConfig Requirements

```swift
struct MultiPathConfig {
    let scoring: ScoringConfig
    let performance: PerformanceConfig
    let prediction: PredictionConfig
}

struct ScoringConfig {
    let minProbability: Double  // Minimum allowed probability (e.g., 0.01)
    let maxProbability: Double  // Maximum allowed probability (e.g., 0.99)
}

struct PerformanceConfig {
    let maxScoringTime: Double  // Maximum time for scoring operations
}
```

## Integration Examples

### Basic Usage

```swift
// Initialize service
let service = try PathScoringService(
    predictor: MockBridgePredictor(seed: 1234),
    etaEstimator: ETAEstimator(config: config),
    config: multiPathConfig
)

// Score a single path
let pathScore = try await service.scorePath(routePath, departureTime: Date())
print("Path probability: \(pathScore.linearProbability)")

// Analyze multiple paths
let journeyAnalysis = try await service.analyzeJourney(
    paths: alternativePaths,
    startNode: "A",
    endNode: "B",
    departureTime: Date()
)
print("Network probability: \(journeyAnalysis.networkProbability)")
```

### Advanced Usage

```swift
// Batch score multiple paths
let pathScores = try await service.scorePaths(paths, departureTime: Date())

// Find best path
let bestPath = pathScores.max { $0.linearProbability < $1.linearProbability }
print("Best path probability: \(bestPath?.linearProbability ?? 0.0)")

// Analyze path statistics
let meanProbability = pathScores.map { $0.linearProbability }.reduce(0, +) / Double(pathScores.count)
print("Mean path probability: \(meanProbability)")
```

## Best Practices

1. **Error Handling**: Always handle `PathScoringError` cases appropriately
2. **Configuration**: Validate configuration parameters for your use case
3. **Performance**: Monitor path set sizes for large-scale operations
4. **Determinism**: Use seeded predictors for reproducible results
5. **Feature Integration**: Ensure feature vectors match your ML model expectations

## Migration Guide

### From Previous Versions

1. **Initialization**: Now requires `try` due to configuration validation
2. **Error Handling**: Enhanced error types with more specific cases
3. **Feature Generation**: Now uses deterministic feature generation
4. **Documentation**: Comprehensive API documentation added

## Troubleshooting

### Common Issues

1. **Configuration Errors**: Ensure `minProbability < maxProbability`
2. **Empty Path Sets**: Handle gracefully in `analyzeJourney`
3. **Unsupported Bridges**: Check bridge support before scoring
4. **Performance Issues**: Monitor path set sizes and scoring times

### Debug Information

The service provides debug output for:
- Large path sets (warning messages)
- Failed path scoring (error details)
- Journey analysis completion (summary statistics)

---

*For more information, see the inline documentation in `PathScoringService.swift`.*

## Future Enhancements

### 1. Real Feature Engineering Integration

**Current State**: The `buildFeatures` method uses synthetic, deterministic feature generation for development and testing.

**Production Recommendation**: Replace synthetic features with real data sources:

```swift
// Current: Synthetic features
let bridgeFeatures = try await computeBridgeFeatures(...)

// Future: Real data integration
let bridgeFeatures = try await realFeatureService.getFeatures(
    for: bridgeID,
    at: eta,
    context: path
)
```

**Data Sources to Consider**:
- **Historical Bridge Data**: Real opening/closing patterns from bridge sensors
- **Traffic APIs**: Real-time traffic speed and congestion data
- **Weather Data**: Impact of weather conditions on bridge operations
- **Event Data**: Special events, construction, maintenance schedules
- **Time-Series Analysis**: Rolling averages, seasonal patterns, trend analysis

**Implementation Strategy**:
1. Create a `RealFeatureService` protocol
2. Implement feature caching for performance
3. Add fallback to synthetic features for missing data
4. Include data quality metrics and validation

### 2. Performance Optimization for Large Path Sets

**Current State**: Sequential processing with basic batch prediction per path.

**Production Recommendation**: Consider advanced optimization strategies:

```swift
// Current: Sequential processing
for path in paths {
    let score = try await scorePath(path, departureTime: departureTime)
    pathScores.append(score)
}

// Future: Concurrent processing (example)
let pathScores = try await withTaskGroup(of: PathScore.self) { group in
    for path in paths {
        group.addTask {
            return try await scorePath(path, departureTime: departureTime)
        }
    }
    return await group.reduce(into: []) { $0.append($1) }
}
```

**Optimization Strategies**:
- **Concurrent Path Scoring**: Process multiple paths simultaneously
- **Advanced Batching**: Group predictions across multiple paths
- **Caching**: Cache ETA calculations and feature vectors
- **Streaming**: Process paths as they become available
- **Priority Queuing**: Score high-priority paths first

**Considerations**:
- Memory usage with large concurrent operations
- Error handling in concurrent scenarios
- Maintaining deterministic results for testing
- Resource management and rate limiting

### 3. Error Propagation and Partial Results

**Current State**: Fail-fast behavior - if one path fails, the entire operation fails.

**Production Recommendation**: Consider allowing partial results for better user experience:

```swift
// Current: Fail-fast
guard pathScores.count == paths.count else {
    throw PathScoringError.predictionFailed("Failed to score \(failureCount) paths")
}

// Future: Partial results with detailed reporting
struct PartialScoringResult {
    let successfulScores: [PathScore]
    let failedPaths: [(index: Int, error: Error)]
    let overallSuccess: Bool
    let completionPercentage: Double
}
```

**Implementation Options**:
- **Configurable Behavior**: Allow users to choose fail-fast vs. partial results
- **Detailed Error Reporting**: Provide specific failure reasons for each path
- **Recovery Strategies**: Retry failed paths with different parameters
- **Graceful Degradation**: Continue with available results

**Policy Considerations**:
- **Data Quality**: How many failures are acceptable?
- **User Experience**: Is partial data better than no data?
- **Debugging**: How to identify and fix systematic failures?
- **Monitoring**: Track failure patterns and success rates

### 4. Additional Production Considerations

#### **Monitoring and Observability**
- Add performance metrics (scoring time, success rates)
- Implement structured logging for debugging
- Create health checks for dependent services
- Monitor feature quality and data freshness

#### **Configuration Management**
- Environment-specific configurations
- Dynamic configuration updates
- A/B testing for different algorithms
- Feature flags for gradual rollouts

#### **Data Pipeline Integration**
- Real-time data ingestion
- Data validation and quality checks
- Historical data archiving
- Backup and disaster recovery

#### **Scalability Planning**
- Horizontal scaling strategies
- Load balancing considerations
- Database optimization for large datasets
- CDN integration for global access

---

*These enhancements should be prioritized based on your specific production requirements and user needs.*
