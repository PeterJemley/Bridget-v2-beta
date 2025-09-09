# Phase 4.2 - Monitoring & Alerting

@Metadata {
    @TechnologyRoot
}

## Overview

Phase 4.2 implements comprehensive monitoring and alerting for the coordinate transformation system. This provides real-time visibility into system performance and automatic alerts when issues arise.

## Key Components

### CoordinateTransformationMonitoringService

The core monitoring service tracks transformation events and generates alerts:

```swift
@MainActor
public final class DefaultCoordinateTransformationMonitoringService: CoordinateTransformationMonitoringProtocol, Sendable {
    // Event recording and aggregation
    // Performance metrics calculation
    // Alert generation and management
    // Data export functionality
}
```

### CoordinateTransformationDashboard

SwiftUI dashboard for real-time monitoring:

```swift
@MainActor
struct CoordinateTransformationDashboard: View {
    // Real-time metrics display
    // Alert management interface
    // Time range selection
    // Bridge-specific metrics
}
```

## Monitoring Features

### Event Recording

Tracks all coordinate transformation events:

```swift
// Successful transformations
monitoringService.recordSuccessfulTransformation(
    bridgeId: bridgeId,
    sourceSystem: "SeattleAPI",
    targetSystem: "SeattleReference",
    confidence: 0.95,
    processingTimeMs: 5.2,
    distanceImprovementMeters: 150.0,
    userId: userId
)

// Failed transformations
monitoringService.recordFailedTransformation(
    bridgeId: bridgeId,
    sourceSystem: "SeattleAPI",
    targetSystem: "SeattleReference",
    errorMessage: "Transformation matrix not found",
    processingTimeMs: 2.1,
    userId: userId
)
```

### Performance Metrics

Calculates aggregated metrics over time ranges:

- **Success Rate**: Percentage of successful transformations
- **Processing Time**: Average time per transformation
- **Confidence**: Average confidence scores
- **Distance Improvement**: Average improvement in accuracy

### Bridge-Specific Metrics

Individual bridge performance tracking:

```swift
let bridgeMetrics = monitoringService.getBridgeMetrics(
    bridgeId: "bridge-1",
    timeRange: TimeRange.last24Hours
)
```

## Alert System

### Alert Types

Five types of alerts are supported:

1. **Low Success Rate**: When success rate falls below threshold
2. **High Processing Time**: When average processing time exceeds limit
3. **Low Confidence**: When confidence scores are too low
4. **Failure Spike**: When failure rate suddenly increases
5. **Accuracy Degradation**: When distance improvements decline

### Alert Configuration

Configurable thresholds and cooldown periods:

```swift
let alertConfig = AlertConfig(
    minimumSuccessRate: 0.9,        // 90% success rate required
    maximumProcessingTimeMs: 10.0,  // 10ms max processing time
    minimumConfidence: 0.8,         // 80% confidence required
    alertCooldownSeconds: 300       // 5 minute cooldown
)
```

### Alert Generation

Automatic alert checking with cooldown protection:

```swift
let alerts = monitoringService.checkAlerts()
for alert in alerts {
    print("🚨 \(alert.alertType.description): \(alert.message)")
}
```

## Dashboard Features

### Real-Time Metrics

- **Performance Cards**: Success rate, processing time, total events
- **Bridge Metrics**: Individual bridge performance
- **Alert Status**: Recent alerts and their severity
- **Feature Flag Status**: Current rollout and A/B test status

### Time Range Selection

- **Last Hour**: Real-time monitoring
- **Last 24 Hours**: Daily performance
- **Last 7 Days**: Weekly trends
- **Last 30 Days**: Monthly analysis

### Interactive Features

- **Refresh**: Pull-to-refresh for latest data
- **Alert Configuration**: Adjust alert thresholds
- **Data Export**: Export monitoring data for analysis

## Integration Points

### BridgeRecordValidator

The validator records monitoring events:

```swift
// Record successful transformation
monitoringService.recordSuccessfulTransformation(
    bridgeId: record.entityid,
    sourceSystem: "SeattleAPI",
    targetSystem: "SeattleReference",
    confidence: transformationResult.confidence,
    processingTimeMs: processingTimeMs,
    distanceImprovementMeters: distanceImprovement,
    userId: record.entityid
)
```

### Feature Flag Integration

Monitoring includes feature flag context:

- **Variant Tracking**: Control vs treatment performance
- **Rollout Metrics**: Performance by rollout percentage
- **A/B Test Analysis**: Statistical comparison

## Data Management

### Event Storage

- **In-Memory Storage**: Fast access for recent events
- **Event Limits**: Configurable maximum event count
- **Automatic Cleanup**: Old events removed automatically

### Data Export

JSON export for external analysis:

```swift
let exportData = monitoringService.exportMonitoringData(
    timeRange: TimeRange.last7Days
)
```

### Time Range Support

Flexible time range queries:

```swift
// Custom time range
let customRange = TimeRange(
    startDate: Date().addingTimeInterval(-2 * 60 * 60), // 2 hours ago
    endDate: Date()
)

// Convenience ranges
let lastHour = TimeRange.lastHour
let last24Hours = TimeRange.last24Hours
let last7Days = TimeRange.last7Days
let last30Days = TimeRange.last30Days
```

## Alert Management

### Alert Lifecycle

1. **Detection**: Automatic monitoring detects issues
2. **Generation**: Alerts created with context
3. **Cooldown**: Prevents alert spam
4. **Storage**: Alerts stored for history
5. **Display**: Dashboard shows recent alerts

### Alert Configuration

Dynamic threshold adjustment:

```swift
// Update alert configuration
monitoringService.updateAlertConfig(AlertConfig(
    minimumSuccessRate: 0.95,       // Stricter success rate
    maximumProcessingTimeMs: 5.0,    // Faster processing required
    minimumConfidence: 0.9,          // Higher confidence required
    alertCooldownSeconds: 600        // 10 minute cooldown
))
```

## Testing

### Unit Tests

Comprehensive test coverage:

- Event recording and retrieval
- Metrics calculation accuracy
- Alert generation logic
- Bridge-specific metrics
- Data export functionality

### Integration Tests

- Dashboard UI functionality
- Real-time updates
- Alert configuration
- Data export

## Performance Considerations

### Memory Management

- **Event Limits**: Configurable maximum events (default: 50,000)
- **Alert Limits**: Maximum alerts stored (default: 1,000)
- **Automatic Cleanup**: Old data removed automatically

### Processing Efficiency

- **Lazy Calculation**: Metrics calculated on-demand
- **Caching**: Recent metrics cached for dashboard
- **Background Processing**: Heavy calculations in background

## Safety Features

### Alert Cooldown

Prevents alert spam during temporary issues:

```swift
// 5-minute cooldown between similar alerts
alertConfig.alertCooldownSeconds = 300
```

### Graceful Degradation

- **Service Unavailable**: Dashboard shows offline state
- **Data Unavailable**: Graceful handling of missing data
- **Export Failures**: Error handling for export issues

## Usage Examples

### Basic Monitoring

```swift
// Get current metrics
let metrics = monitoringService.getMetrics(timeRange: TimeRange.lastHour)
if let metrics = metrics {
    print("Success Rate: \(metrics.successRate * 100)%")
    print("Avg Processing Time: \(metrics.averageProcessingTimeMs)ms")
}
```

### Alert Checking

```swift
// Check for alerts
let alerts = monitoringService.checkAlerts()
for alert in alerts {
    switch alert.alertType {
    case .lowSuccessRate:
        // Handle low success rate
    case .highProcessingTime:
        // Handle high processing time
    case .lowConfidence:
        // Handle low confidence
    default:
        // Handle other alerts
    }
}
```

### Data Export

```swift
// Export monitoring data
if let exportData = monitoringService.exportMonitoringData(
    timeRange: TimeRange.last7Days
) {
    // Save to file or send to external system
    try exportData.write(to: fileURL)
}
```

## Next Steps

Phase 4.2 provides the foundation for:

- **Phase 5**: Advanced Analytics
- **Production Monitoring**: 24/7 system monitoring
- **Alert Integration**: External alerting systems
- **Performance Optimization**: Data-driven improvements

## Related Documentation

- [CoordinateTransformationPlan](CoordinateTransformationPlan)
- [Phase4_1_FeatureFlag_Implementation](Phase4_1_FeatureFlag_Implementation)
- [BridgeRecordValidator](BridgeRecordValidator)

