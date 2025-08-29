//
//  ETAEstimator.swift
//  Bridget
//
//  Multi-Path Probability Traffic Prediction System
//  Purpose: Estimate arrival times at each node along a path
//  Integration: Used by PathScoringService to determine bridge crossing times
//  Acceptance: Advance ETA on every edge, canonical time units, ETA windows for future-proofing
//  Known Limits: Simple linear time accumulation, no traffic modeling yet
//

import Foundation

/// Service for estimating arrival times along paths
/// Advances ETA on every edge traversal (regardless of bridge)
public class ETAEstimator {
  private let config: MultiPathConfig

  public init(config: MultiPathConfig) {
    self.config = config
  }

  /// Estimate arrival times for all nodes along a path
  /// Returns array of ETAs in path order
  public func estimateETAs(for path: RoutePath,
                           departureTime: Date) -> [ETA]
  {
    var etas: [ETA] = []
    var currentTime = departureTime
    var accumulatedTime: TimeInterval = 0

    // Add departure node
    if let firstNode = path.nodes.first {
      etas.append(
        ETA(nodeID: firstNode,
            arrivalTime: departureTime,
            travelTimeFromStart: 0))
    }

    // Calculate ETAs for each subsequent node
    for (index, edge) in path.edges.enumerated() {
      accumulatedTime += edge.travelTime
      currentTime = departureTime.addingTimeInterval(accumulatedTime)

      let nextNodeIndex = index + 1
      if nextNodeIndex < path.nodes.count {
        let nextNode = path.nodes[nextNodeIndex]
        etas.append(
          ETA(nodeID: nextNode,
              arrivalTime: currentTime,
              travelTimeFromStart: accumulatedTime))
      }
    }

    return etas
  }

  /// Estimate ETA windows for all nodes along a path
  /// Currently returns single ETA, but extensible for min/max ranges
  public func estimateETAWindows(for path: RoutePath,
                                 departureTime: Date) -> [ETAWindow]
  {
    let etas = estimateETAs(for: path, departureTime: departureTime)

    return etas.map { eta in
      ETAWindow(expectedETA: eta)
      // Future: Add min/max ETA calculation based on traffic conditions
    }
  }

  /// Get ETAs specifically for bridge crossings
  /// Filters path ETAs to only include bridge nodes
  public func estimateBridgeETAs(for path: RoutePath,
                                 departureTime: Date) -> [ETA]
  {
    let allETAs = estimateETAs(for: path, departureTime: departureTime)

    // Find bridge edges and their corresponding ETAs
    var bridgeETAs: [ETA] = []

    for (index, edge) in path.edges.enumerated() {
      if edge.isBridge {
        // Find the ETA for the destination node of this bridge
        let destinationNodeIndex = index + 1
        if destinationNodeIndex < allETAs.count {
          bridgeETAs.append(allETAs[destinationNodeIndex])
        }
      }
    }

    return bridgeETAs
  }

  /// Get bridge ETAs with bridge IDs for prediction
  public func estimateBridgeETAsWithIDs(for path: RoutePath,
                                        departureTime: Date) -> [(bridgeID: String, eta: ETA)]
  {
    let allETAs = estimateETAs(for: path, departureTime: departureTime)
    var bridgeETAs: [(bridgeID: String, eta: ETA)] = []

    for (index, edge) in path.edges.enumerated() {
      if edge.isBridge, let bridgeID = edge.bridgeID {
        // Validate bridge ID against SeattleDrawbridges as single source of truth
        if !SeattleDrawbridges.isValidBridgeID(bridgeID) {
          print("⚠️ ETAEstimator: Non-canonical bridge ID '\(bridgeID)' detected in path. Skipping bridge ETA calculation.")
          continue
        }

        let destinationNodeIndex = index + 1
        if destinationNodeIndex < allETAs.count {
          bridgeETAs.append((bridgeID: bridgeID, eta: allETAs[destinationNodeIndex]))
        }
      }
    }

    return bridgeETAs
  }

  /// Validate that a path's total travel time is within acceptable limits
  public func validatePathTravelTime(_ path: RoutePath) -> Bool {
    return path.totalTravelTime <= config.pathEnumeration.maxTravelTime
  }

  /// Get the expected arrival time at the destination
  public func estimateDestinationETA(for path: RoutePath,
                                     departureTime: Date) -> ETA?
  {
    let etas = estimateETAs(for: path, departureTime: departureTime)
    return etas.last
  }

  /// Calculate travel time statistics for a path
  public func calculatePathStatistics(for path: RoutePath,
                                      departureTime: Date) -> PathTravelStatistics
  {
    let etas = estimateETAs(for: path, departureTime: departureTime)
    let bridgeETAs = estimateBridgeETAs(for: path, departureTime: departureTime)

    let totalTravelTime = path.totalTravelTime
    let averageSpeed = path.totalDistance > 0 ? path.totalDistance / totalTravelTime : 0

    let bridgeCount = path.bridgeCount
    let averageTimeBetweenBridges = bridgeCount > 1 ? totalTravelTime / Double(bridgeCount - 1) : 0

    return PathTravelStatistics(totalTravelTime: totalTravelTime,
                                totalDistance: path.totalDistance,
                                averageSpeed: averageSpeed,
                                bridgeCount: bridgeCount,
                                averageTimeBetweenBridges: averageTimeBetweenBridges,
                                estimatedArrivalTime: etas.last?.arrivalTime,
                                bridgeArrivalTimes: bridgeETAs.map { $0.arrivalTime })
  }

  // MARK: - Phase 3: ETASummary Methods

  /// Estimate arrival times with statistical uncertainty for all nodes along a path
  /// Returns array of ETAEstimate with ETASummary for each node
  public func estimateETAsWithUncertainty(for path: RoutePath,
                                          departureTime: Date) -> [ETAEstimate]
  {
    var estimates: [ETAEstimate] = []
    var currentTime = departureTime
    var accumulatedTime: TimeInterval = 0

    // Add departure node
    if let firstNode = path.nodes.first {
      let departureSummary = ETASummary(mean: 0,
                                        variance: 0,
                                        min: 0,
                                        max: 0)
      estimates.append(
        ETAEstimate(nodeID: firstNode,
                    summary: departureSummary,
                    arrivalTime: departureTime))
    }

    // Calculate ETAs with uncertainty for each subsequent node
    for (index, edge) in path.edges.enumerated() {
      accumulatedTime += edge.travelTime
      currentTime = departureTime.addingTimeInterval(accumulatedTime)

      let nextNodeIndex = index + 1
      if nextNodeIndex < path.nodes.count {
        let nextNode = path.nodes[nextNodeIndex]

        // Enhanced uncertainty modeling using per-edge arrival times
        let edgeArrivalTime = departureTime.addingTimeInterval(accumulatedTime)
        let timeOfDayMultiplier = ETAEstimator.timeOfDayCategory(edgeArrivalTime)
          .travelTimeMultiplier

        // Calculate uncertainty based on edge-specific factors
        let baseVariance = edge.travelTime * 0.1  // 10% of travel time as base variance

        // Adjust variance based on edge characteristics
        var edgeVariance = baseVariance

        // Bridge edges have higher uncertainty
        if edge.isBridge {
          edgeVariance *= 1.5  // 50% more variance for bridges
        }

        // Longer edges have proportionally more variance
        if edge.travelTime > 300 {  // 5+ minutes
          edgeVariance *= 1.2  // 20% more variance for long edges
        }

        // Apply time-of-day multiplier to variance
        let adjustedVariance = edgeVariance * timeOfDayMultiplier

        // Calculate cumulative variance (sum of individual edge variances)
        let cumulativeVariance =
          estimates.isEmpty
            ? adjustedVariance : (estimates.last?.summary.variance ?? 0) + adjustedVariance

        let summary = ETASummary(mean: accumulatedTime,
                                 variance: cumulativeVariance,
                                 min: max(0, accumulatedTime * 0.7),  // 30% below mean, but not negative
                                 max: accumulatedTime * 1.3  // 30% above mean
        )

        estimates.append(
          ETAEstimate(nodeID: nextNode,
                      summary: summary,
                      arrivalTime: currentTime))
      }
    }

    return estimates
  }

  /// Get statistical summary of bridge crossing times for a path
  public func estimateBridgeETAsWithUncertainty(for path: RoutePath,
                                                departureTime: Date) -> [ETAEstimate]
  {
    let allEstimates = estimateETAsWithUncertainty(for: path, departureTime: departureTime)

    // Find bridge edges and their corresponding estimates
    var bridgeEstimates: [ETAEstimate] = []

    for (index, edge) in path.edges.enumerated() {
      if edge.isBridge {
        // Find the estimate for the destination node of this bridge
        let destinationNodeIndex = index + 1
        if destinationNodeIndex < allEstimates.count {
          bridgeEstimates.append(allEstimates[destinationNodeIndex])
        }
      }
    }

    return bridgeEstimates
  }

  /// Calculate comprehensive path statistics with uncertainty
  public func calculatePathStatisticsWithUncertainty(for path: RoutePath,
                                                     departureTime: Date) -> PathTravelStatisticsWithUncertainty
  {
    let estimates = estimateETAsWithUncertainty(for: path, departureTime: departureTime)
    let bridgeEstimates = estimateBridgeETAsWithUncertainty(for: path, departureTime: departureTime)

    // Aggregate travel time statistics
    let travelTimes = estimates.map { $0.summary.mean }
    let travelTimeSummary =
      travelTimes.toETASummary()
        ?? ETASummary(mean: path.totalTravelTime,
                      variance: 0,
                      min: path.totalTravelTime,
                      max: path.totalTravelTime)

    // Calculate speed statistics
    let speeds = estimates.enumerated().compactMap { index, estimate -> Double? in
      guard index > 0, let edge = path.edges[safe: index - 1] else { return nil }
      return edge.distance / estimate.summary.mean
    }
    let speedSummary =
      speeds.toETASummary()
        ?? ETASummary(mean: path.totalDistance / path.totalTravelTime,
                      variance: 0,
                      min: 0,
                      max: 0)

    return PathTravelStatisticsWithUncertainty(totalTravelTime: travelTimeSummary,
                                               totalDistance: path.totalDistance,
                                               averageSpeed: speedSummary,
                                               bridgeCount: path.bridgeCount,
                                               estimatedArrivalTime: estimates.last?.arrivalTime,
                                               bridgeArrivalTimes: bridgeEstimates.map { $0.arrivalTime },
                                               bridgeEstimates: bridgeEstimates)
  }
}

// MARK: - Supporting Types

/// Statistics about travel along a path
public struct PathTravelStatistics: Codable {
  public let totalTravelTime: TimeInterval
  public let totalDistance: Double
  public let averageSpeed: Double  // meters per second
  public let bridgeCount: Int
  public let averageTimeBetweenBridges: TimeInterval
  public let estimatedArrivalTime: Date?
  public let bridgeArrivalTimes: [Date]

  public init(totalTravelTime: TimeInterval,
              totalDistance: Double,
              averageSpeed: Double,
              bridgeCount: Int,
              averageTimeBetweenBridges: TimeInterval,
              estimatedArrivalTime: Date?,
              bridgeArrivalTimes: [Date])
  {
    self.totalTravelTime = totalTravelTime
    self.totalDistance = totalDistance
    self.averageSpeed = averageSpeed
    self.bridgeCount = bridgeCount
    self.averageTimeBetweenBridges = averageTimeBetweenBridges
    self.estimatedArrivalTime = estimatedArrivalTime
    self.bridgeArrivalTimes = bridgeArrivalTimes
  }
}

/// Statistics about travel along a path with uncertainty quantification
/// Phase 3 enhancement providing statistical summaries for all metrics
public struct PathTravelStatisticsWithUncertainty: Codable {
  public let totalTravelTime: ETASummary
  public let totalDistance: Double
  public let averageSpeed: ETASummary
  public let bridgeCount: Int
  public let estimatedArrivalTime: Date?
  public let bridgeArrivalTimes: [Date]
  public let bridgeEstimates: [ETAEstimate]

  public init(totalTravelTime: ETASummary,
              totalDistance: Double,
              averageSpeed: ETASummary,
              bridgeCount: Int,
              estimatedArrivalTime: Date?,
              bridgeArrivalTimes: [Date],
              bridgeEstimates: [ETAEstimate])
  {
    self.totalTravelTime = totalTravelTime
    self.totalDistance = totalDistance
    self.averageSpeed = averageSpeed
    self.bridgeCount = bridgeCount
    self.estimatedArrivalTime = estimatedArrivalTime
    self.bridgeArrivalTimes = bridgeArrivalTimes
    self.bridgeEstimates = bridgeEstimates
  }

  /// Backward compatibility: access mean travel time
  public var meanTotalTravelTime: TimeInterval {
    return totalTravelTime.mean
  }

  /// Backward compatibility: access mean speed
  public var meanAverageSpeed: Double {
    return averageSpeed.mean
  }

  /// Human-readable travel time with confidence interval
  public var formattedTravelTime: String {
    let ci95 = totalTravelTime.confidenceInterval(level: 0.95)
    if let ci = ci95 {
      let meanMinutes = Int(totalTravelTime.mean / 60)
      let marginMinutes = Int(ci.upper - ci.lower) / 120
      return "\(meanMinutes) min (±\(marginMinutes) min)"
    } else {
      let meanMinutes = Int(totalTravelTime.mean / 60)
      return "\(meanMinutes) min"
    }
  }

  /// Human-readable speed with confidence interval
  public var formattedSpeed: String {
    let ci95 = averageSpeed.confidenceInterval(level: 0.95)
    if let ci = ci95 {
      let meanKmh = averageSpeed.mean * 3.6
      let marginKmh = (ci.upper - ci.lower) * 3.6 / 2
      return String(format: "%.1f km/h (±%.1f km/h)", meanKmh, marginKmh)
    } else {
      let meanKmh = averageSpeed.mean * 3.6
      return String(format: "%.1f km/h", meanKmh)
    }
  }
}

// MARK: - ETA Utilities

public extension ETAEstimator {
  /// Format travel time for display
  static func formatTravelTime(_ timeInterval: TimeInterval) -> String {
    let hours = Int(timeInterval) / 3600
    let minutes = Int(timeInterval) % 3600 / 60

    if hours > 0 {
      return "\(hours)h \(minutes)m"
    } else {
      return "\(minutes)m"
    }
  }

  /// Format distance for display
  static func formatDistance(_ distance: Double) -> String {
    if distance >= 1000 {
      return String(format: "%.1f km", distance / 1000)
    } else {
      return String(format: "%.0f m", distance)
    }
  }

  /// Format speed for display
  static func formatSpeed(_ speed: Double) -> String {
    let kmh = speed * 3.6  // convert m/s to km/h
    return String(format: "%.1f km/h", kmh)
  }

  /// Check if a time is during rush hour
  static func isRushHour(_ date: Date) -> Bool {
    let hour = Calendar.current.component(.hour, from: date)
    let weekday = Calendar.current.component(.weekday, from: date)

    // Monday = 2, Sunday = 1
    let isWeekday = weekday >= 2 && weekday <= 6

    if isWeekday {
      return (hour >= 7 && hour <= 9) || (hour >= 16 && hour <= 18)
    }

    return false
  }

  /// Get time of day category
  static func timeOfDayCategory(_ date: Date) -> TimeOfDay {
    let hour = Calendar.current.component(.hour, from: date)

    switch hour {
    case 5 ..< 9:
      return .morningRush
    case 9 ..< 16:
      return .midday
    case 16 ..< 19:
      return .eveningRush
    case 19 ..< 22:
      return .evening
    default:
      return .lateNight
    }
  }
}

/// Time of day categories for traffic analysis
public enum TimeOfDay: String, CaseIterable, Codable {
  case morningRush = "Morning Rush"
  case midday = "Midday"
  case eveningRush = "Evening Rush"
  case evening = "Evening"
  case lateNight = "Late Night"

  /// Base travel time multiplier for this time of day
  public var travelTimeMultiplier: Double {
    switch self {
    case .morningRush, .eveningRush:
      return 1.3  // 30% slower during rush hours
    case .midday:
      return 1.1  // 10% slower during midday
    case .evening:
      return 1.0  // Normal speed
    case .lateNight:
      return 0.9  // 10% faster during late night
    }
  }
}

// MARK: - Helper Extensions

// Note: Array.subscript(safe:) is already defined in Extensions 2.swift
