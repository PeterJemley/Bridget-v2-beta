//
//  CoordinateTransformationMonitoringService.swift
//  Bridget
//
//  Purpose: Monitors coordinate transformation performance and generates alerts
//  Dependencies: Foundation
//  Integration Points:
//    - Used by BridgeRecordValidator to record transformation events
//    - Used by CoordinateTransformationDashboard for real-time monitoring
//    - Provides alerting system for performance issues
//  Key Features:
//    - Performance monitoring (processing time, success rate)
//    - Alert generation for performance degradation
//    - Bridge-specific metrics tracking
//    - Data export for analysis
//    - Alert cooldown management
//

import Foundation

// MARK: - Monitoring Event Types

/// Represents a coordinate transformation monitoring event
public struct TransformationMonitoringEvent: Codable, Sendable {
  public let timestamp: Date
  public let bridgeId: String
  public let sourceSystem: String
  public let targetSystem: String
  public let success: Bool
  public let confidence: Double?
  public let processingTimeMs: Double
  public let distanceImprovementMeters: Double?
  public let errorMessage: String?
  public let userId: String

  public init(bridgeId: String,
              sourceSystem: String,
              targetSystem: String,
              success: Bool,
              confidence: Double? = nil,
              processingTimeMs: Double,
              distanceImprovementMeters: Double? = nil,
              errorMessage: String? = nil,
              userId: String)
  {
    self.timestamp = Date()
    self.bridgeId = bridgeId
    self.sourceSystem = sourceSystem
    self.targetSystem = targetSystem
    self.success = success
    self.confidence = confidence
    self.processingTimeMs = processingTimeMs
    self.distanceImprovementMeters = distanceImprovementMeters
    self.errorMessage = errorMessage
    self.userId = userId
  }
}

/// Represents aggregated transformation metrics
public struct TransformationMetrics: Codable, Sendable {
  public let totalEvents: Int
  public let successfulEvents: Int
  public let successRate: Double
  public let averageProcessingTimeMs: Double
  public let averageConfidence: Double?
  public let averageDistanceImprovementMeters: Double?
  public let timeRange: TimeRange

  public init(totalEvents: Int,
              successfulEvents: Int,
              successRate: Double,
              averageProcessingTimeMs: Double,
              averageConfidence: Double? = nil,
              averageDistanceImprovementMeters: Double? = nil,
              timeRange: TimeRange)
  {
    self.totalEvents = totalEvents
    self.successfulEvents = successfulEvents
    self.successRate = successRate
    self.averageProcessingTimeMs = averageProcessingTimeMs
    self.averageConfidence = averageConfidence
    self.averageDistanceImprovementMeters = averageDistanceImprovementMeters
    self.timeRange = timeRange
  }
}

/// Represents bridge-specific transformation metrics
public struct BridgeTransformationMetrics: Codable, Sendable {
  public let bridgeId: String
  public let totalEvents: Int
  public let successfulEvents: Int
  public let successRate: Double
  public let averageProcessingTimeMs: Double
  public let averageConfidence: Double?
  public let averageDistanceImprovementMeters: Double?
  public let timeRange: TimeRange

  public init(bridgeId: String,
              totalEvents: Int,
              successfulEvents: Int,
              successRate: Double,
              averageProcessingTimeMs: Double,
              averageConfidence: Double? = nil,
              averageDistanceImprovementMeters: Double? = nil,
              timeRange: TimeRange)
  {
    self.bridgeId = bridgeId
    self.totalEvents = totalEvents
    self.successfulEvents = successfulEvents
    self.successRate = successRate
    self.averageProcessingTimeMs = averageProcessingTimeMs
    self.averageConfidence = averageConfidence
    self.averageDistanceImprovementMeters = averageDistanceImprovementMeters
    self.timeRange = timeRange
  }
}

// MARK: - Alert System

/// Configuration for alert thresholds
public struct AlertConfig: Codable, Sendable {
  public var minimumSuccessRate: Double
  public var maximumProcessingTimeMs: Double
  public var minimumConfidence: Double
  public var alertCooldownSeconds: TimeInterval

  public init(minimumSuccessRate: Double = 0.9,
              maximumProcessingTimeMs: Double = 10.0,
              minimumConfidence: Double = 0.8,
              alertCooldownSeconds: TimeInterval = 300)
  {
    self.minimumSuccessRate = minimumSuccessRate
    self.maximumProcessingTimeMs = maximumProcessingTimeMs
    self.minimumConfidence = minimumConfidence
    self.alertCooldownSeconds = alertCooldownSeconds
  }
}

/// Types of alerts that can be generated
public enum AlertType: String, CaseIterable, Sendable, Codable {
  case lowSuccessRate = "low_success_rate"
  case highProcessingTime = "high_processing_time"
  case lowConfidence = "low_confidence"
  case failureSpike = "failure_spike"
  case accuracyDegradation = "accuracy_degradation"

  public var description: String {
    switch self {
    case .lowSuccessRate:
      return "Low Success Rate"
    case .highProcessingTime:
      return "High Processing Time"
    case .lowConfidence:
      return "Low Confidence"
    case .failureSpike:
      return "Failure Spike"
    case .accuracyDegradation:
      return "Accuracy Degradation"
    }
  }
}

/// Represents an alert event
public struct AlertEvent: Codable, Sendable {
  public let timestamp: Date
  public let alertType: AlertType
  public let bridgeId: String?
  public let message: String
  public let severity: String
  public let metadata: [String: String]

  public init(alertType: AlertType,
              bridgeId: String? = nil,
              message: String,
              severity: String = "warning",
              metadata: [String: String] = [:])
  {
    self.timestamp = Date()
    self.alertType = alertType
    self.bridgeId = bridgeId
    self.message = message
    self.severity = severity
    self.metadata = metadata
  }
}

// MARK: - Monitoring Service Protocol

/// Protocol for coordinate transformation monitoring
@preconcurrency
public protocol CoordinateTransformationMonitoringProtocol {
  /// Record a transformation event
  @MainActor func recordTransformationEvent(
    _ event: TransformationMonitoringEvent
  )

  /// Record a successful transformation
  @MainActor func recordSuccessfulTransformation(bridgeId: String,
                                                 sourceSystem: String,
                                                 targetSystem: String,
                                                 confidence: Double?,
                                                 processingTimeMs: Double,
                                                 distanceImprovementMeters: Double,
                                                 userId: String)

  /// Record a failed transformation
  @MainActor func recordFailedTransformation(bridgeId: String,
                                             sourceSystem: String,
                                             targetSystem: String,
                                             errorMessage: String,
                                             processingTimeMs: Double,
                                             userId: String)

  /// Get metrics for a time range
  @MainActor func getMetrics(timeRange: TimeRange) -> TransformationMetrics?

  /// Get bridge-specific metrics
  @MainActor func getBridgeMetrics(bridgeId: String, timeRange: TimeRange)
    -> BridgeTransformationMetrics?

  /// Check for alerts
  @MainActor func checkAlerts() -> [AlertEvent]

  /// Export monitoring data
  @MainActor func exportMonitoringData(timeRange: TimeRange) -> Data?

  /// Clear old events
  @MainActor func clearOldEvents(before date: Date)
}

// MARK: - Default Monitoring Service

/// Default implementation of the coordinate transformation monitoring service
@MainActor
public final class DefaultCoordinateTransformationMonitoringService:
  CoordinateTransformationMonitoringProtocol, Sendable
{
  private var monitoringEvents: [TransformationMonitoringEvent] = []
  private var alertEvents: [AlertEvent] = []
  private var alertConfig: AlertConfig
  private var lastAlertTimestamp: Date = .distantPast
  private let maxEvents = 50000
  private let maxAlerts = 1000

  public init(alertConfig: AlertConfig = AlertConfig()) {
    self.alertConfig = alertConfig
  }

  public func recordTransformationEvent(
    _ event: TransformationMonitoringEvent
  ) {
    monitoringEvents.append(event)
    if monitoringEvents.count > maxEvents {
      monitoringEvents.removeFirst()
    }
  }

  public func recordSuccessfulTransformation(bridgeId: String,
                                             sourceSystem: String,
                                             targetSystem: String,
                                             confidence: Double?,
                                             processingTimeMs: Double,
                                             distanceImprovementMeters: Double,
                                             userId: String)
  {
    let event = TransformationMonitoringEvent(bridgeId: bridgeId,
                                              sourceSystem: sourceSystem,
                                              targetSystem: targetSystem,
                                              success: true,
                                              confidence: confidence,
                                              processingTimeMs: processingTimeMs,
                                              distanceImprovementMeters: distanceImprovementMeters,
                                              errorMessage: nil,
                                              userId: userId)
    recordTransformationEvent(event)
  }

  public func recordFailedTransformation(bridgeId: String,
                                         sourceSystem: String,
                                         targetSystem: String,
                                         errorMessage: String,
                                         processingTimeMs: Double,
                                         userId: String)
  {
    let event = TransformationMonitoringEvent(bridgeId: bridgeId,
                                              sourceSystem: sourceSystem,
                                              targetSystem: targetSystem,
                                              success: false,
                                              confidence: nil,
                                              processingTimeMs: processingTimeMs,
                                              distanceImprovementMeters: nil,
                                              errorMessage: errorMessage,
                                              userId: userId)
    recordTransformationEvent(event)
  }

  public func getMetrics(timeRange: TimeRange) -> TransformationMetrics? {
    let relevantEvents = monitoringEvents.filter { event in
      event.timestamp >= timeRange.startDate
        && event.timestamp <= timeRange.endDate
    }

    guard !relevantEvents.isEmpty else { return nil }

    return computeMetrics(from: relevantEvents, timeRange: timeRange)
  }

  public func getBridgeMetrics(bridgeId: String, timeRange: TimeRange)
    -> BridgeTransformationMetrics?
  {
    let relevantEvents = monitoringEvents.filter { event in
      event.timestamp >= timeRange.startDate
        && event.timestamp <= timeRange.endDate
        && event.bridgeId == bridgeId
    }

    guard !relevantEvents.isEmpty else { return nil }

    let metrics = computeMetrics(from: relevantEvents, timeRange: timeRange)
    return BridgeTransformationMetrics(bridgeId: bridgeId,
                                       totalEvents: metrics.totalEvents,
                                       successfulEvents: metrics.successfulEvents,
                                       successRate: metrics.successRate,
                                       averageProcessingTimeMs: metrics.averageProcessingTimeMs,
                                       averageConfidence: metrics.averageConfidence,
                                       averageDistanceImprovementMeters: metrics
                                         .averageDistanceImprovementMeters,
                                       timeRange: timeRange)
  }

  public func checkAlerts() -> [AlertEvent] {
    let now = Date()
    guard
      now.timeIntervalSince(lastAlertTimestamp)
      >= alertConfig.alertCooldownSeconds
    else {
      return []
    }

    var newAlerts: [AlertEvent] = []

    // Get recent metrics (last hour)
    let recentTimeRange = TimeRange(startDate: now.addingTimeInterval(-60 * 60),
                                    endDate: now)
    guard let recentMetrics = getMetrics(timeRange: recentTimeRange) else {
      return []
    }

    // Check success rate
    if recentMetrics.successRate < alertConfig.minimumSuccessRate {
      let alert = AlertEvent(alertType: .lowSuccessRate,
                             message:
                             "Success rate \(String(format: "%.1f", recentMetrics.successRate * 100))% is below threshold \(String(format: "%.1f", alertConfig.minimumSuccessRate * 100))%",
                             severity: "warning")
      newAlerts.append(alert)
    }

    // Check processing time
    if recentMetrics.averageProcessingTimeMs
      > alertConfig.maximumProcessingTimeMs
    {
      let alert = AlertEvent(alertType: .highProcessingTime,
                             message:
                             "Average processing time \(String(format: "%.2f", recentMetrics.averageProcessingTimeMs))ms exceeds threshold \(String(format: "%.2f", alertConfig.maximumProcessingTimeMs))ms",
                             severity: "warning")
      newAlerts.append(alert)
    }

    // Check confidence
    if let averageConfidence = recentMetrics.averageConfidence,
       averageConfidence < alertConfig.minimumConfidence
    {
      let alert = AlertEvent(alertType: .lowConfidence,
                             message:
                             "Average confidence \(String(format: "%.2f", averageConfidence)) is below threshold \(String(format: "%.2f", alertConfig.minimumConfidence))",
                             severity: "warning")
      newAlerts.append(alert)
    }

    // Accuracy degradation (negative improvement means transform made it worse)
    if let avgImprovement = recentMetrics.averageDistanceImprovementMeters,
       avgImprovement < 0
    {
      let alert = AlertEvent(alertType: .accuracyDegradation,
                             message:
                             "Average distance improvement is negative: \(String(format: "%.0f", avgImprovement))m. Transformation may be degrading accuracy.",
                             severity: "warning")
      newAlerts.append(alert)
    }

    // Failure spike: compare last 15 minutes to the prior 15 minutes
    let shortWindow: TimeInterval = 15 * 60
    let prevShortRange = TimeRange(startDate: now.addingTimeInterval(-2 * shortWindow),
                                   endDate: now.addingTimeInterval(-shortWindow))
    if let prevMetrics = getMetrics(timeRange: prevShortRange),
       prevMetrics.totalEvents >= 20, recentMetrics.totalEvents >= 20
    {
      let recentFailureRate = 1.0 - recentMetrics.successRate
      let prevFailureRate = 1.0 - prevMetrics.successRate
      if prevFailureRate > 0,
         recentFailureRate / prevFailureRate >= 2.0,
         recentFailureRate >= 0.10
      {
        let alert = AlertEvent(alertType: .failureSpike,
                               message:
                               "Failure rate spiked from \(String(format: "%.1f", prevFailureRate * 100))% to \(String(format: "%.1f", recentFailureRate * 100))% in the last 15 minutes.",
                               severity: "warning")
        newAlerts.append(alert)
      }
    }

    // Add new alerts to the list
    alertEvents.append(contentsOf: newAlerts)
    if alertEvents.count > maxAlerts {
      alertEvents.removeFirst(max(0, alertEvents.count - maxAlerts))
    }

    lastAlertTimestamp = now
    return newAlerts
  }

  public func exportMonitoringData(timeRange: TimeRange) -> Data? {
    let relevantEvents = monitoringEvents.filter { event in
      event.timestamp >= timeRange.startDate
        && event.timestamp <= timeRange.endDate
    }

    let export = MonitoringExport(events: relevantEvents,
                                  alerts: Array(alertEvents.suffix(200)),
                                  exportTimestamp: Date(),
                                  version: "1.0")

    let encoder = JSONEncoder()
    encoder.outputFormatting = [
      .prettyPrinted, .withoutEscapingSlashes, .sortedKeys,
    ]
    encoder.dateEncodingStrategy = .iso8601
    return try? encoder.encode(export)
  }

  public func clearOldEvents(before date: Date) {
    monitoringEvents.removeAll { $0.timestamp < date }
    alertEvents.removeAll { $0.timestamp < date }
  }

  // MARK: - Private helpers

  private func computeMetrics(from events: [TransformationMonitoringEvent],
                              timeRange: TimeRange) -> TransformationMetrics
  {
    let successfulEvents = events.filter { $0.success }
    let successRate = Double(successfulEvents.count) / Double(events.count)
    let averageProcessingTime =
      events.map { $0.processingTimeMs }.reduce(0, +)
        / Double(events.count)

    let confidences = events.compactMap { $0.confidence }
    let averageConfidence =
      confidences.isEmpty
        ? nil : confidences.reduce(0, +) / Double(confidences.count)

    let improvements = events.compactMap { $0.distanceImprovementMeters }
    let averageImprovement =
      improvements.isEmpty
        ? nil : improvements.reduce(0, +) / Double(improvements.count)

    return TransformationMetrics(totalEvents: events.count,
                                 successfulEvents: successfulEvents.count,
                                 successRate: successRate,
                                 averageProcessingTimeMs: averageProcessingTime,
                                 averageConfidence: averageConfidence,
                                 averageDistanceImprovementMeters: averageImprovement,
                                 timeRange: timeRange)
  }
}

// MARK: - Export Types

private struct MonitoringExport: Codable {
  let events: [TransformationMonitoringEvent]
  let alerts: [AlertEvent]
  let exportTimestamp: Date
  let version: String
}

// MARK: - Convenience Extensions

public extension DefaultCoordinateTransformationMonitoringService {
  /// Shared instance for easy access
  static let shared =
    DefaultCoordinateTransformationMonitoringService()

  /// Update alert configuration
  func updateAlertConfig(_ config: AlertConfig) {
    alertConfig = config
  }

  /// Get recent alerts
  func getRecentAlerts(limit: Int = 10) -> [AlertEvent] {
    return Array(alertEvents.suffix(limit))
  }

  /// Get all bridge IDs that have been monitored
  func getAllBridgeIds() -> Set<String> {
    return Set(monitoringEvents.map { $0.bridgeId })
  }
}
