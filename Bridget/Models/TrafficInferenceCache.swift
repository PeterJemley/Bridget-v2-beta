//
//  TrafficInferenceCache.swift
//  Bridget
//
//  Purpose: SwiftData model for caching traffic-based bridge status inferences
//  Dependencies: Foundation (Date, TimeInterval), SwiftData framework
//  Integration Points:
//    - Used by traffic monitoring service to cache iOS Maps API results
//    - Stores inferred bridge status based on real-time traffic patterns
//    - Enables offline inference results and reduces API calls
//    - Future: Will integrate with Core ML for improved inference accuracy
//  Key Features:
//    - @Model annotation for SwiftData persistence
//    - Short-term caching of traffic inference results
//    - Confidence scoring for inference accuracy
//    - Automatic expiration and cleanup of stale data
//

import Foundation
import SwiftData

/// A persistent model for caching traffic-based inferences about bridge status.
///
/// This model stores short-term cache of bridge status inferences derived from
/// iOS Maps API traffic data. It enables offline functionality, reduces API calls,
/// and provides historical context for improving inference accuracy.
///
/// ## Overview
///
/// `TrafficInferenceCache` serves as the caching layer for real-time bridge status, enabling:
/// - Short-term persistence of traffic-based bridge status inferences
/// - Reduced iOS Maps API calls through intelligent caching
/// - Confidence tracking for inference quality assessment
/// - Historical data for improving ML inference models
///
/// ## Usage
///
/// ```swift
/// // Cache a bridge status inference
/// let inference = TrafficInferenceCache(
///   bridgeID: "3",
///   isLikelyOpen: true,
///   confidence: 0.85,
///   trafficSpeed: 15.2,
///   normalSpeed: 35.0
/// )
///
/// // Query recent inferences
/// let descriptor = FetchDescriptor<TrafficInferenceCache>(
///   predicate: #Predicate {
///     $0.bridgeID == "3" && $0.timestamp > Date().addingTimeInterval(-300)
///   }
/// )
/// ```
@Model
final class TrafficInferenceCache {
  // MARK: - Core Properties

  /// Unique identifier for this inference record
  var inferenceID: String

  /// The bridge ID this inference applies to (from BridgeID enum)
  var bridgeID: String

  /// Whether the bridge is likely open based on traffic analysis
  var isLikelyOpen: Bool

  /// Confidence score for this inference (0.0 - 1.0)
  var confidence: Double

  /// When this inference was made
  var timestamp: Date

  // MARK: - Traffic Data

  /// Current average traffic speed near the bridge (mph)
  var currentTrafficSpeed: Double?

  /// Normal/baseline traffic speed for this time/day (mph)
  var normalTrafficSpeed: Double?

  /// Number of vehicles detected in the area
  var vehicleCount: Int?

  /// Traffic congestion level (0.0 = free flow, 1.0 = standstill)
  var congestionLevel: Double?

  /// Duration of current traffic pattern (seconds)
  var patternDuration: TimeInterval?

  // MARK: - Inference Metadata

  /// Source of the traffic data (e.g., "iOS Maps", "ML Model")
  var dataSource: String

  /// Version of the inference algorithm used
  var algorithmVersion: String

  /// Whether this inference was validated against actual bridge status
  var isValidated: Bool?

  /// If validated, whether the inference was correct
  var wasCorrect: Bool?

  /// Additional context or notes about this inference
  var notes: String?

  // MARK: - Expiration and Cleanup

  /// When this cache entry expires and should be cleaned up
  var expiresAt: Date

  /// Whether this cache entry is still valid/fresh
  var isExpired: Bool {
    return Date() > expiresAt
  }

  // MARK: - Initialization

  /// Creates a new traffic inference cache entry.
  ///
  /// - Parameters:
  ///   - bridgeID: The bridge ID this inference applies to
  ///   - isLikelyOpen: Whether the bridge is likely open
  ///   - confidence: Confidence score for the inference (0.0 - 1.0)
  ///   - currentTrafficSpeed: Current traffic speed near the bridge
  ///   - normalTrafficSpeed: Normal traffic speed for comparison
  ///   - vehicleCount: Number of vehicles detected
  ///   - congestionLevel: Traffic congestion level (0.0 - 1.0)
  ///   - patternDuration: Duration of current traffic pattern
  ///   - dataSource: Source of the traffic data
  ///   - algorithmVersion: Version of inference algorithm
  ///   - cacheLifetimeMinutes: How long to cache this inference
  ///   - notes: Additional context or notes
  init(
    bridgeID: String,
    isLikelyOpen: Bool,
    confidence: Double,
    currentTrafficSpeed: Double? = nil,
    normalTrafficSpeed: Double? = nil,
    vehicleCount: Int? = nil,
    congestionLevel: Double? = nil,
    patternDuration: TimeInterval? = nil,
    dataSource: String = "iOS Maps",
    algorithmVersion: String = "1.0",
    cacheLifetimeMinutes: Int = 5,
    notes: String? = nil
  ) {
    self.inferenceID = UUID().uuidString
    self.bridgeID = bridgeID
    self.isLikelyOpen = isLikelyOpen
    self.confidence = confidence
    self.timestamp = Date()
    self.currentTrafficSpeed = currentTrafficSpeed
    self.normalTrafficSpeed = normalTrafficSpeed
    self.vehicleCount = vehicleCount
    self.congestionLevel = congestionLevel
    self.patternDuration = patternDuration
    self.dataSource = dataSource
    self.algorithmVersion = algorithmVersion
    self.notes = notes
    self.isValidated = nil
    self.wasCorrect = nil
    self.expiresAt = Date().addingTimeInterval(
      TimeInterval(cacheLifetimeMinutes * 60)
    )
  }

  // MARK: - Convenience Methods

  /// The age of this inference in seconds
  var ageInSeconds: TimeInterval {
    return Date().timeIntervalSince(timestamp)
  }

  /// Whether this inference is still fresh (not expired)
  var isFresh: Bool {
    return !isExpired
  }

  /// Speed ratio compared to normal traffic (1.0 = normal, < 1.0 = slower)
  var speedRatio: Double? {
    guard let current = currentTrafficSpeed,
      let normal = normalTrafficSpeed,
      normal > 0
    else { return nil }
    return current / normal
  }

  /// Validates this inference against actual bridge status
  func validate(actuallyOpen: Bool) {
    isValidated = true
    wasCorrect = (isLikelyOpen == actuallyOpen)
  }

  /// Marks this inference as expired for cleanup
  func markExpired() {
    expiresAt = Date()
  }
}

// MARK: - Bridge Status Inference

extension TrafficInferenceCache {
  /// Inference quality based on confidence and data completeness
  var inferenceQuality: InferenceQuality {
    if confidence >= 0.8 && currentTrafficSpeed != nil
      && normalTrafficSpeed != nil
    {
      return .high
    } else if confidence >= 0.6 && currentTrafficSpeed != nil {
      return .medium
    } else {
      return .low
    }
  }

  /// Enum representing the quality of an inference
  enum InferenceQuality {
    case high
    case medium
    case low

    var description: String {
      switch self {
      case .high: return "High"
      case .medium: return "Medium"
      case .low: return "Low"
      }
    }
  }
}

// MARK: - Factory Methods

extension TrafficInferenceCache {
  /// Creates a high-confidence inference for bridge likely open
  static func bridgeLikelyOpen(
    bridgeID: String,
    currentSpeed: Double,
    normalSpeed: Double,
    confidence: Double = 0.9
  ) -> TrafficInferenceCache {
    return TrafficInferenceCache(
      bridgeID: bridgeID,
      isLikelyOpen: false,  // Slow traffic suggests bridge might be open
      confidence: confidence,
      currentTrafficSpeed: currentSpeed,
      normalTrafficSpeed: normalSpeed,
      congestionLevel: max(
        0.0,
        min(1.0, 1.0 - (currentSpeed / normalSpeed))
      ),
      notes: "Significant traffic slowdown detected"
    )
  }

  /// Creates a high-confidence inference for bridge likely closed
  static func bridgeLikelyClosed(
    bridgeID: String,
    currentSpeed: Double,
    normalSpeed: Double,
    confidence: Double = 0.85
  ) -> TrafficInferenceCache {
    return TrafficInferenceCache(
      bridgeID: bridgeID,
      isLikelyOpen: false,
      confidence: confidence,
      currentTrafficSpeed: currentSpeed,
      normalTrafficSpeed: normalSpeed,
      congestionLevel: max(
        0.0,
        min(1.0, 1.0 - (currentSpeed / normalSpeed))
      ),
      notes: "Normal traffic flow, bridge likely closed"
    )
  }
}
