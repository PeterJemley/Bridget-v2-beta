//
//  UserRouteHistory.swift
//  Bridget
//
//  Purpose: SwiftData model for tracking user route usage and performance history
//  Dependencies: Foundation (Date, TimeInterval), SwiftData framework
//  Integration Points:
//    - Used by route recommendation engine to learn from user behavior
//    - Tracks actual route performance vs. predictions
//    - Enables personalized route scoring based on user experience
//    - Future: Will integrate with Core ML for predictive route recommendations
//  Key Features:
//    - @Model annotation for SwiftData persistence
//    - Tracks route usage patterns and actual performance
//    - Records user satisfaction and route outcomes
//    - Supports machine learning training data collection
//

import Foundation
import SwiftData

/// A persistent model for tracking user route usage history and performance.
///
/// This model records when users select routes, how those routes performed,
/// and user satisfaction with the results. It enables the app to learn from
/// user behavior and improve route recommendations over time.
///
/// ## Overview
///
/// `UserRouteHistory` serves as the learning data for route optimization, enabling:
/// - Tracking of route selection patterns and user preferences
/// - Performance comparison between predicted and actual route outcomes
/// - User satisfaction feedback for route recommendation improvement
/// - Historical data for machine learning model training
///
/// ## Usage
///
/// ```swift
/// // Record a route selection
/// let history = UserRouteHistory(
///   routeID: "route_1",
///   startTime: startDate,
///   endTime: endDate,
///   actualTravelTime: 1200, // 20 minutes
///   predictedTravelTime: 1080, // 18 minutes predicted
///   bridgeDelaysEncountered: 2
/// )
///
/// // Query recent route history
/// let descriptor = FetchDescriptor<UserRouteHistory>(
///   predicate: #Predicate { $0.routeSelectedAt > lastWeek },
///   sortBy: [SortDescriptor(\.routeSelectedAt, order: .reverse)]
/// )
/// ```
@Model
final class UserRouteHistory {
  // MARK: - Core Properties

  /// Unique identifier for this route usage record
  var historyID: String

  /// The route ID that was selected (references RouteModel.routeID)
  var routeID: String

  /// When the user selected this route
  var routeSelectedAt: Date

  /// When the user started the journey
  var journeyStartTime: Date?

  /// When the user completed the journey
  var journeyEndTime: Date?

  /// Whether the journey was completed or abandoned
  var wasCompleted: Bool

  // MARK: - Performance Metrics

  /// Actual travel time in seconds
  var actualTravelTime: TimeInterval?

  /// Predicted travel time in seconds
  var predictedTravelTime: TimeInterval

  /// Number of bridge delays encountered during the journey
  var bridgeDelaysEncountered: Int

  /// Number of traffic delays encountered during the journey
  var trafficDelaysEncountered: Int

  /// Total delay time beyond prediction (seconds)
  var totalDelayTime: TimeInterval?

  /// Whether the route performed better, worse, or as expected
  var performanceRating: PerformanceRating

  // MARK: - User Feedback

  /// User's satisfaction rating for this route (1-5 scale)
  var userSatisfactionRating: Int?

  /// Whether the user would use this route again
  var wouldUseAgain: Bool?

  /// User's reason for abandoning route (if applicable)
  var abandonmentReason: String?

  /// Free-form user feedback about the route
  var userFeedback: String?

  // MARK: - Contextual Data

  /// Day of the week when route was used
  var dayOfWeek: Int // 1 = Sunday, 7 = Saturday

  /// Hour of day when route was started (0-23)
  var hourOfDay: Int

  /// Weather conditions during the journey
  var weatherConditions: String?

  /// Special events or circumstances affecting traffic
  var specialCircumstances: String?

  // MARK: - Bridge-Specific Data

  /// Bridge IDs that were open during the journey
  var bridgesOpenDuringJourney: [String]

  /// Bridge IDs that caused delays
  var problematicBridges: [String]

  /// Bridge IDs that performed better than expected
  var reliableBridges: [String]

  // MARK: - Learning Data

  /// Whether this record has been used for ML training
  var usedForTraining: Bool

  /// Quality score of this data for training purposes
  var dataQualityScore: Double

  /// Version of the prediction algorithm used
  var algorithmVersion: String

  // MARK: - Initialization

  /// Creates a new user route history record.
  ///
  /// - Parameters:
  ///   - routeID: The route ID that was selected
  ///   - predictedTravelTime: The predicted travel time in seconds
  ///   - routeSelectedAt: When the route was selected (defaults to now)
  ///   - algorithmVersion: Version of prediction algorithm used
  init(routeID: String,
       predictedTravelTime: TimeInterval,
       routeSelectedAt: Date = Date(),
       algorithmVersion: String = "1.0")
  {
    self.historyID = UUID().uuidString
    self.routeID = routeID
    self.routeSelectedAt = routeSelectedAt
    self.predictedTravelTime = predictedTravelTime
    self.wasCompleted = false
    self.bridgeDelaysEncountered = 0
    self.trafficDelaysEncountered = 0
    self.performanceRating = .unknown
    self.bridgesOpenDuringJourney = []
    self.problematicBridges = []
    self.reliableBridges = []
    self.usedForTraining = false
    self.dataQualityScore = 0.0
    self.algorithmVersion = algorithmVersion

    let now = Date()
    let calendar = Calendar.current
    self.dayOfWeek = calendar.component(.weekday, from: now)
    self.hourOfDay = calendar.component(.hour, from: now)
  }

  // MARK: - Journey Tracking

  /// Records the start of the journey
  func startJourney() {
    journeyStartTime = Date()
  }

  /// Records the completion of the journey
  func completeJourney() {
    journeyEndTime = Date()
    wasCompleted = true

    if let start = journeyStartTime, let end = journeyEndTime {
      actualTravelTime = end.timeIntervalSince(start)
      updatePerformanceRating()
      calculateDataQuality()
    }
  }

  /// Records abandonment of the journey
  func abandonJourney(reason: String? = nil) {
    journeyEndTime = Date()
    wasCompleted = false
    abandonmentReason = reason
    performanceRating = .muchWorse
    calculateDataQuality()
  }

  // MARK: - Performance Analysis

  /// Travel time prediction accuracy (-1.0 to 1.0, where 0 = perfect)
  var predictionAccuracy: Double? {
    guard let actual = actualTravelTime else { return nil }
    let difference = actual - predictedTravelTime
    return difference / predictedTravelTime
  }

  /// Whether the route performed better than predicted
  var performedBetterThanPredicted: Bool {
    return performanceRating == .better || performanceRating == .muchBetter
  }

  /// Updates performance rating based on actual vs predicted travel time
  private func updatePerformanceRating() {
    guard let accuracy = predictionAccuracy else {
      performanceRating = .unknown
      return
    }

    switch accuracy {
    case ..<(-0.2): performanceRating = .muchBetter
    case -0.2 ..< -0.1: performanceRating = .better
    case -0.1 ... 0.1: performanceRating = .asExpected
    case 0.1 ..< 0.3: performanceRating = .worse
    default: performanceRating = .muchWorse
    }
  }

  /// Calculates data quality score for ML training purposes
  private func calculateDataQuality() {
    var score = 0.0

    // Base score for completion
    if wasCompleted { score += 0.3 }

    // Score for having actual travel time
    if actualTravelTime != nil { score += 0.2 }

    // Score for user feedback
    if userSatisfactionRating != nil { score += 0.2 }

    // Score for bridge delay data
    if !bridgesOpenDuringJourney.isEmpty { score += 0.1 }

    // Score for contextual data
    if weatherConditions != nil { score += 0.1 }

    // Score for reasonable prediction accuracy
    if let accuracy = predictionAccuracy, abs(accuracy) < 0.5 { score += 0.1 }

    dataQualityScore = score
  }
}

// MARK: - Performance Rating Enum

extension UserRouteHistory {
  enum PerformanceRating: String, CaseIterable, Codable {
    case muchBetter = "much_better"
    case better
    case asExpected = "as_expected"
    case worse
    case muchWorse = "much_worse"
    case unknown

    var description: String {
      switch self {
      case .muchBetter: return "Much Better"
      case .better: return "Better"
      case .asExpected: return "As Expected"
      case .worse: return "Worse"
      case .muchWorse: return "Much Worse"
      case .unknown: return "Unknown"
      }
    }

    var numericValue: Double {
      switch self {
      case .muchBetter: return 1.0
      case .better: return 0.5
      case .asExpected: return 0.0
      case .worse: return -0.5
      case .muchWorse: return -1.0
      case .unknown: return 0.0
      }
    }
  }
}

// MARK: - Analytics and Learning

extension UserRouteHistory {
  /// Whether this record is suitable for ML training
  var isSuitableForTraining: Bool {
    return wasCompleted &&
      dataQualityScore >= 0.6 &&
      actualTravelTime != nil &&
      !usedForTraining
  }

  /// Marks this record as used for ML training
  func markUsedForTraining() {
    usedForTraining = true
  }

  /// Creates a summary of bridge performance for this journey
  var bridgePerformanceSummary: [String: String] {
    var summary: [String: String] = [:]

    for bridgeID in bridgesOpenDuringJourney {
      if problematicBridges.contains(bridgeID) {
        summary[bridgeID] = "problematic"
      } else if reliableBridges.contains(bridgeID) {
        summary[bridgeID] = "reliable"
      } else {
        summary[bridgeID] = "neutral"
      }
    }

    return summary
  }
}
