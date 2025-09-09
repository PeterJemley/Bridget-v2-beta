//
//  FeatureFlagMetricsService.swift
//  Bridget
//
//  Purpose: Collects metrics and events from feature flag usage
//  Dependencies: Foundation
//  Integration Points:
//    - Used by BridgeRecordValidator to record validation events
//    - Used by FeatureFlagService to track usage patterns
//    - Provides data for monitoring and alerting systems
//  Key Features:
//    - Event recording for feature flag decisions
//    - A/B test metrics collection
//    - Rollout percentage tracking
//    - Time-based metrics aggregation
//

import Foundation

// MARK: - Event Types

/// Represents a feature flag event
public struct FeatureFlagEvent: Codable, Sendable {
  public let timestamp: Date
  public let flag: String
  public let userId: String
  public let enabled: Bool
  public let variant: String?
  public let metadata: [String: String]

  public init(flag: String,
              userId: String,
              enabled: Bool,
              variant: String? = nil,
              metadata: [String: String] = [:])
  {
    self.timestamp = Date()
    self.flag = flag
    self.userId = userId
    self.enabled = enabled
    self.variant = variant
    self.metadata = metadata
  }
}

/// Represents a validation event
public struct ValidationEvent: Codable, Sendable {
  public let timestamp: Date
  public let bridgeId: String
  public let validationMethod: ValidationMethod
  public let success: Bool
  public let processingTimeMs: Double
  public let distanceMeters: Double?
  public let metadata: [String: String]

  public init(bridgeId: String,
              validationMethod: ValidationMethod,
              success: Bool,
              processingTimeMs: Double,
              distanceMeters: Double? = nil,
              metadata: [String: String] = [:])
  {
    self.timestamp = Date()
    self.bridgeId = bridgeId
    self.validationMethod = validationMethod
    self.success = success
    self.processingTimeMs = processingTimeMs
    self.distanceMeters = distanceMeters
    self.metadata = metadata
  }
}

/// Represents the validation method used
public enum ValidationMethod: String, Codable, Sendable, CaseIterable {
  case threshold
  case transformation
  case fallback

  public var description: String {
    switch self {
    case .threshold:
      return "Threshold-based"
    case .transformation:
      return "Transformation-based"
    case .fallback:
      return "Fallback"
    }
  }
}

// MARK: - Metrics Types

/// A/B test metrics for a specific time period
public struct ABTestMetrics: Codable, Sendable {
  public let controlCount: Int
  public let treatmentCount: Int
  public let controlSuccessRate: Double
  public let treatmentSuccessRate: Double
  public let controlAvgProcessingTime: Double
  public let treatmentAvgProcessingTime: Double
  public let timeRange: TimeRange

  public init(controlCount: Int,
              treatmentCount: Int,
              controlSuccessRate: Double,
              treatmentSuccessRate: Double,
              controlAvgProcessingTime: Double,
              treatmentAvgProcessingTime: Double,
              timeRange: TimeRange)
  {
    self.controlCount = controlCount
    self.treatmentCount = treatmentCount
    self.controlSuccessRate = controlSuccessRate
    self.treatmentSuccessRate = treatmentSuccessRate
    self.controlAvgProcessingTime = controlAvgProcessingTime
    self.treatmentAvgProcessingTime = treatmentAvgProcessingTime
    self.timeRange = timeRange
  }
}

/// Group metrics for a specific user group
public struct GroupMetrics: Codable, Sendable {
  public let groupId: String
  public let totalEvents: Int
  public let successRate: Double
  public let avgProcessingTime: Double
  public let timeRange: TimeRange

  public init(groupId: String,
              totalEvents: Int,
              successRate: Double,
              avgProcessingTime: Double,
              timeRange: TimeRange)
  {
    self.groupId = groupId
    self.totalEvents = totalEvents
    self.successRate = successRate
    self.avgProcessingTime = avgProcessingTime
    self.timeRange = timeRange
  }
}

/// Rollout metrics for gradual rollout tracking
public struct RolloutMetrics: Codable, Sendable {
  public let rolloutPercentage: Int
  public let totalUsers: Int
  public let enabledUsers: Int
  public let successRate: Double
  public let avgProcessingTime: Double
  public let timeRange: TimeRange

  public init(rolloutPercentage: Int,
              totalUsers: Int,
              enabledUsers: Int,
              successRate: Double,
              avgProcessingTime: Double,
              timeRange: TimeRange)
  {
    self.rolloutPercentage = rolloutPercentage
    self.totalUsers = totalUsers
    self.enabledUsers = enabledUsers
    self.successRate = successRate
    self.avgProcessingTime = avgProcessingTime
    self.timeRange = timeRange
  }
}

// MARK: - Metrics Service Protocol

/// Protocol for feature flag metrics collection
@preconcurrency
public protocol FeatureFlagMetricsServiceProtocol {
  /// Record a feature flag event
  @MainActor func recordFeatureFlagEvent(_ event: FeatureFlagEvent)

  /// Record a validation event
  @MainActor func recordValidationEvent(_ event: ValidationEvent)

  /// Get A/B test metrics for a time range
  @MainActor func getABTestMetrics(timeRange: TimeRange) -> ABTestMetrics?

  /// Get group metrics for a specific group
  @MainActor func getGroupMetrics(groupId: String, timeRange: TimeRange)
    -> GroupMetrics?

  /// Get rollout metrics for a specific percentage
  @MainActor func getRolloutMetrics(rolloutPercentage: Int,
                                    timeRange: TimeRange)
    -> RolloutMetrics?

  /// Get all events for a time range
  @MainActor func getEvents(timeRange: TimeRange) -> [FeatureFlagEvent]

  /// Get all validation events for a time range
  @MainActor func getValidationEvents(timeRange: TimeRange)
    -> [ValidationEvent]

  /// Clear old events (older than specified date)
  @MainActor func clearOldEvents(before date: Date)
}

// MARK: - Default Metrics Service

/// Default implementation of the feature flag metrics service
@MainActor
public final class DefaultFeatureFlagMetricsService:
  FeatureFlagMetricsServiceProtocol, Sendable
{
  private var featureFlagEvents: [FeatureFlagEvent] = []
  private var validationEvents: [ValidationEvent] = []
  private let maxEvents = 10000

  public init() {}

  public func recordFeatureFlagEvent(_ event: FeatureFlagEvent) {
    featureFlagEvents.append(event)
    if featureFlagEvents.count > maxEvents {
      featureFlagEvents.removeFirst()
    }
  }

  public func recordValidationEvent(_ event: ValidationEvent) {
    validationEvents.append(event)
    if validationEvents.count > maxEvents {
      validationEvents.removeFirst()
    }
  }

  public func getABTestMetrics(timeRange: TimeRange) -> ABTestMetrics? {
    let relevantEvents = validationEvents.filter { event in
      event.timestamp >= timeRange.startDate
        && event.timestamp <= timeRange.endDate
    }

    let controlEvents = relevantEvents.filter {
      $0.metadata["variant"] == "control"
    }
    let treatmentEvents = relevantEvents.filter {
      $0.metadata["variant"] == "treatment"
    }

    guard !controlEvents.isEmpty || !treatmentEvents.isEmpty else {
      return nil
    }

    let controlSuccessRate =
      controlEvents.isEmpty
        ? 0.0
        : Double(controlEvents.filter { $0.success }.count)
        / Double(controlEvents.count)
    let treatmentSuccessRate =
      treatmentEvents.isEmpty
        ? 0.0
        : Double(treatmentEvents.filter { $0.success }.count)
        / Double(treatmentEvents.count)

    let controlAvgProcessingTime =
      controlEvents.isEmpty
        ? 0.0
        : controlEvents.map { $0.processingTimeMs }.reduce(0, +)
        / Double(controlEvents.count)
    let treatmentAvgProcessingTime =
      treatmentEvents.isEmpty
        ? 0.0
        : treatmentEvents.map { $0.processingTimeMs }.reduce(0, +)
        / Double(treatmentEvents.count)

    return ABTestMetrics(controlCount: controlEvents.count,
                         treatmentCount: treatmentEvents.count,
                         controlSuccessRate: controlSuccessRate,
                         treatmentSuccessRate: treatmentSuccessRate,
                         controlAvgProcessingTime: controlAvgProcessingTime,
                         treatmentAvgProcessingTime: treatmentAvgProcessingTime,
                         timeRange: timeRange)
  }

  public func getGroupMetrics(groupId: String, timeRange: TimeRange)
    -> GroupMetrics?
  {
    let relevantEvents = validationEvents.filter { event in
      event.timestamp >= timeRange.startDate
        && event.timestamp <= timeRange.endDate
        && event.metadata["groupId"] == groupId
    }

    guard !relevantEvents.isEmpty else { return nil }

    let successRate =
      Double(relevantEvents.filter { $0.success }.count)
        / Double(relevantEvents.count)
    let avgProcessingTime =
      relevantEvents.map { $0.processingTimeMs }.reduce(0, +)
        / Double(relevantEvents.count)

    return GroupMetrics(groupId: groupId,
                        totalEvents: relevantEvents.count,
                        successRate: successRate,
                        avgProcessingTime: avgProcessingTime,
                        timeRange: timeRange)
  }

  public func getRolloutMetrics(rolloutPercentage: Int, timeRange: TimeRange)
    -> RolloutMetrics?
  {
    let relevantEvents = validationEvents.filter { event in
      event.timestamp >= timeRange.startDate
        && event.timestamp <= timeRange.endDate
        && event.metadata["rolloutPercentage"] == "\(rolloutPercentage)"
    }

    guard !relevantEvents.isEmpty else { return nil }

    let successRate =
      Double(relevantEvents.filter { $0.success }.count)
        / Double(relevantEvents.count)
    let avgProcessingTime =
      relevantEvents.map { $0.processingTimeMs }.reduce(0, +)
        / Double(relevantEvents.count)

    return RolloutMetrics(rolloutPercentage: rolloutPercentage,
                          totalUsers: relevantEvents.count,
                          enabledUsers: relevantEvents.filter {
                            $0.metadata["enabled"] == "true"
                          }.count,
                          successRate: successRate,
                          avgProcessingTime: avgProcessingTime,
                          timeRange: timeRange)
  }

  public func getEvents(timeRange: TimeRange) -> [FeatureFlagEvent] {
    return featureFlagEvents.filter { event in
      event.timestamp >= timeRange.startDate
        && event.timestamp <= timeRange.endDate
    }
  }

  public func getValidationEvents(timeRange: TimeRange) -> [ValidationEvent] {
    return validationEvents.filter { event in
      event.timestamp >= timeRange.startDate
        && event.timestamp <= timeRange.endDate
    }
  }

  public func clearOldEvents(before date: Date) {
    featureFlagEvents.removeAll { $0.timestamp < date }
    validationEvents.removeAll { $0.timestamp < date }
  }
}

// MARK: - Convenience Extensions

public extension DefaultFeatureFlagMetricsService {
  /// Shared instance for easy access
  static let shared = DefaultFeatureFlagMetricsService()

  /// Record a feature flag decision
  func recordFeatureFlagDecision(flag: String,
                                 userId: String,
                                 enabled: Bool,
                                 variant: String? = nil)
  {
    let event = FeatureFlagEvent(flag: flag,
                                 userId: userId,
                                 enabled: enabled,
                                 variant: variant)
    recordFeatureFlagEvent(event)
  }

  /// Record a validation result
  func recordValidationResult(bridgeId: String,
                              method: ValidationMethod,
                              success: Bool,
                              processingTimeMs: Double,
                              distanceMeters: Double? = nil,
                              variant: String? = nil,
                              rolloutPercentage: Int? = nil)
  {
    var metadata: [String: String] = [:]
    if let variant = variant {
      metadata["variant"] = variant
    }
    if let rolloutPercentage = rolloutPercentage {
      metadata["rolloutPercentage"] = "\(rolloutPercentage)"
    }
    metadata["enabled"] = success ? "true" : "false"

    let event = ValidationEvent(bridgeId: bridgeId,
                                validationMethod: method,
                                success: success,
                                processingTimeMs: processingTimeMs,
                                distanceMeters: distanceMeters,
                                metadata: metadata)
    recordValidationEvent(event)
  }
}
