//
//  TimeRange.swift
//  Bridget
//
//  Purpose: Represents a time range for metrics queries
//  Dependencies: Foundation
//  Integration Points:
//    - Used by monitoring services for time-based queries
//    - Used by dashboard views for time range selection
//    - Supports SwiftUI Hashable conformance for Picker usage
//  Key Features:
//    - Start and end date representation
//    - Convenience static properties for common ranges
//    - Sendable and Hashable conformance
//

import Foundation

/// Represents a time range for metrics queries
public struct TimeRange: Codable, Sendable, Hashable {
  public let startDate: Date
  public let endDate: Date

  public init(startDate: Date, endDate: Date) {
    self.startDate = startDate
    self.endDate = endDate
  }

  // MARK: - Convenience Static Properties

  /// Last hour from now
  public static let lastHour = TimeRange(startDate: Date().addingTimeInterval(-60 * 60),
                                         endDate: Date())

  /// Last 24 hours from now
  public static let last24Hours = TimeRange(startDate: Date().addingTimeInterval(-24 * 60 * 60),
                                            endDate: Date())

  /// Last 7 days from now
  public static let last7Days = TimeRange(startDate: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                                          endDate: Date())

  /// Last 30 days from now
  public static let last30Days = TimeRange(startDate: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                                           endDate: Date())

  // MARK: - Utility Methods

  /// Duration of the time range in seconds
  public var duration: TimeInterval {
    return endDate.timeIntervalSince(startDate)
  }

  /// Check if a date falls within this time range
  public func contains(_ date: Date) -> Bool {
    return date >= startDate && date <= endDate
  }

  /// Create a time range with a specific duration ending at the given date
  public static func duration(_ duration: TimeInterval,
                              endingAt endDate: Date) -> TimeRange
  {
    return TimeRange(startDate: endDate.addingTimeInterval(-duration),
                     endDate: endDate)
  }

  /// Create a time range with a specific duration starting from the given date
  public static func duration(_ duration: TimeInterval,
                              startingFrom startDate: Date) -> TimeRange
  {
    return TimeRange(startDate: startDate,
                     endDate: startDate.addingTimeInterval(duration))
  }
}
