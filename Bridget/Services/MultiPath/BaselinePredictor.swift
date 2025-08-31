//
//  BaselinePredictor.swift
//  Bridget
//
//  Multi-Path Probability Traffic Prediction System
//  Purpose: Provide baseline bridge opening predictions using historical data and Beta smoothing
//  Integration: Conforms to BridgeOpenPredictor, used by PathScoringService
//  Acceptance: Beta smoothing, fallback behavior, batch prediction support
//  Known Limits: Historical data dependency, 5-minute granularity, bridge-specific calibration
//

import Foundation

// MARK: - Configuration

/// Configuration for BaselinePredictor
public struct BaselinePredictorConfig: Codable, Equatable {
  /// Alpha parameter for Beta smoothing (prior belief for "open")
  public let priorAlpha: Double

  /// Beta parameter for Beta smoothing (prior belief for "closed")
  public let priorBeta: Double

  /// Default probability when no historical data is available
  public let defaultProbability: Double

  /// Minimum sample count required for reliable prediction
  public let minSampleCount: Int

  /// Whether to blend historical and default probabilities for sparse data
  public let enableBlending: Bool

  /// Blending weight for historical data (0.0 = use default, 1.0 = use historical)
  public let historicalWeight: Double

  public init(
    priorAlpha: Double = 1.0,
    priorBeta: Double = 9.0,
    defaultProbability: Double = 0.1,
    minSampleCount: Int = 10,
    enableBlending: Bool = true,
    historicalWeight: Double = 0.8
  ) {
    self.priorAlpha = priorAlpha
    self.priorBeta = priorBeta
    self.defaultProbability = max(0.0, min(1.0, defaultProbability))
    self.minSampleCount = minSampleCount
    self.enableBlending = enableBlending
    self.historicalWeight = max(0.0, min(1.0, historicalWeight))
  }
}

// MARK: - Baseline Predictor

/// Baseline predictor that uses historical bridge opening data with Beta smoothing
/// Provides fallback behavior when historical data is sparse or unavailable
public class BaselinePredictor: BridgeOpenPredictor {
  private let historicalProvider: HistoricalBridgeDataProvider
  private let config: BaselinePredictorConfig
  private let supportedBridgeIDs: Set<String>

  public init(
    historicalProvider: HistoricalBridgeDataProvider,
    config: BaselinePredictorConfig = BaselinePredictorConfig(),
    supportedBridgeIDs: Set<String>? = nil
  ) {
    self.historicalProvider = historicalProvider
    self.config = config

    // If no supported bridge IDs provided, use SeattleDrawbridges as the single source of truth
    if let supported = supportedBridgeIDs {
      // Validate that all provided IDs are canonical Seattle bridges
      let canonicalIDs = Set(SeattleDrawbridges.BridgeID.allIDs)
      let nonCanonicalIDs = supported.subtracting(canonicalIDs)

      if !nonCanonicalIDs.isEmpty {
        print(
          "⚠️ BaselinePredictor: Non-canonical bridge IDs detected: \(nonCanonicalIDs). Using canonical Seattle bridges only."
        )
      }

      // Only use IDs that are both supported and canonical
      self.supportedBridgeIDs = supported.intersection(canonicalIDs)
    } else {
      // Default to all canonical Seattle bridges
      self.supportedBridgeIDs = Set(SeattleDrawbridges.BridgeID.allIDs)
    }
  }

  // MARK: - BridgeOpenPredictor Implementation

  public func predictOpenProbability(for bridgeID: String, at time: Date) -> Double {
    guard supports(bridgeID: bridgeID) else {
      return config.defaultProbability
    }

    let bucket = DateBucket(from: time)
    return predictOpenProbability(for: bridgeID, bucket: bucket)
  }

  public func predictBatch(bridgeIDs: [String], at time: Date) -> [String: Double] {
    let bucket = DateBucket(from: time)
    var results: [String: Double] = [:]

    for bridgeID in bridgeIDs {
      results[bridgeID] = predictOpenProbability(for: bridgeID, bucket: bucket)
    }

    return results
  }

  public func predictBatch(_ inputs: [BridgePredictionInput]) async throws -> BatchPredictionResult
  {
    let startTime = Date()
    var predictions: [BridgePredictionResult] = []

    for input in inputs {
      guard supports(bridgeID: input.bridgeID) else {
        // Create a result with default probability for unsupported bridges
        let result = BridgePredictionResult(
          bridgeID: input.bridgeID,
          eta: input.eta,
          openProbability: config.defaultProbability,
          confidence: 0.0
        )
        predictions.append(result)
        continue
      }

      let probability = predictOpenProbability(
        for: input.bridgeID, bucket: DateBucket(from: input.eta))
      let (_, confidence, _) = predictWithConfidence(for: input.bridgeID, at: input.eta)

      let result = BridgePredictionResult(
        bridgeID: input.bridgeID,
        eta: input.eta,
        openProbability: probability,
        confidence: confidence
      )
      predictions.append(result)
    }

    let processingTime = Date().timeIntervalSince(startTime)
    return BatchPredictionResult(
      predictions: predictions,
      processingTime: processingTime,
      batchSize: inputs.count
    )
  }

  public func supports(bridgeID: String) -> Bool {
    return supportedBridgeIDs.contains(bridgeID)
  }

  public var maxBatchSize: Int {
    return 100  // Reasonable batch size for baseline predictions
  }

  /// Default probability for bridges not supported by this predictor
  public var defaultProbability: Double {
    return config.defaultProbability
  }

  // MARK: - Core Prediction Logic

  /// Predict opening probability for a bridge in a specific time bucket
  /// - Parameters:
  ///   - bridgeID: The bridge identifier
  ///   - bucket: The 5-minute time bucket
  /// - Returns: Predicted opening probability (0.0 - 1.0)
  private func predictOpenProbability(for bridgeID: String, bucket: DateBucket) -> Double {
    guard let stats = historicalProvider.getOpeningStats(bridgeID: bridgeID, bucket: bucket) else {
      return config.defaultProbability
    }

    // If we have sufficient data, use Beta-smoothed probability
    if stats.hasSufficientData {
      return stats.smoothedProbability(alpha: config.priorAlpha, beta: config.priorBeta)
    }

    // If blending is enabled and we have some data, blend historical with default
    if config.enableBlending && stats.sampleCount > 0 {
      let historicalProb = stats.smoothedProbability(
        alpha: config.priorAlpha, beta: config.priorBeta)
      let weight = min(
        config.historicalWeight, Double(stats.sampleCount) / Double(config.minSampleCount))
      return historicalProb * weight + config.defaultProbability * (1.0 - weight)
    }

    // Fall back to default probability
    return config.defaultProbability
  }

  // MARK: - Advanced Prediction Methods

  /// Get prediction with confidence for a bridge
  /// - Parameters:
  ///   - bridgeID: The bridge identifier
  ///   - time: The prediction time
  /// - Returns: Tuple of (probability, confidence, dataSource)
  public func predictWithConfidence(for bridgeID: String, at time: Date) -> (
    probability: Double, confidence: Double, dataSource: String
  ) {
    guard supports(bridgeID: bridgeID) else {
      return (config.defaultProbability, 0.0, "default")
    }

    let bucket = DateBucket(from: time)

    guard let stats = historicalProvider.getOpeningStats(bridgeID: bridgeID, bucket: bucket) else {
      return (config.defaultProbability, 0.0, "default")
    }

    let probability = predictOpenProbability(for: bridgeID, bucket: bucket)

    // Calculate confidence based on sample count and data quality
    let sampleConfidence = min(1.0, Double(stats.sampleCount) / Double(config.minSampleCount))
    let recencyConfidence = calculateRecencyConfidence(lastSeen: stats.lastSeen)
    let confidence = (sampleConfidence + recencyConfidence) / 2.0

    let dataSource = stats.hasSufficientData ? "historical" : "blended"

    return (probability, confidence, dataSource)
  }

  /// Get predictions for multiple time buckets (useful for time series analysis)
  /// - Parameters:
  ///   - bridgeID: The bridge identifier
  ///   - startTime: Start time for predictions
  ///   - endTime: End time for predictions
  ///   - intervalMinutes: Interval between predictions (default: 5 minutes)
  /// - Returns: Array of (time, probability, confidence) tuples
  public func predictTimeSeries(
    for bridgeID: String,
    from startTime: Date,
    to endTime: Date,
    intervalMinutes: Int = 5
  ) -> [(time: Date, probability: Double, confidence: Double)] {
    guard supports(bridgeID: bridgeID) else {
      return []
    }

    var results: [(time: Date, probability: Double, confidence: Double)] = []
    var currentTime = startTime

    while currentTime <= endTime {
      let (probability, confidence, _) = predictWithConfidence(for: bridgeID, at: currentTime)

      results.append((time: currentTime, probability: probability, confidence: confidence))

      currentTime =
        Calendar.current.date(byAdding: .minute, value: intervalMinutes, to: currentTime)
        ?? currentTime
    }

    return results
  }

  /// Get prediction summary for a bridge across all time buckets
  /// - Parameter bridgeID: The bridge identifier
  /// - Returns: Summary statistics for the bridge
  public func getPredictionSummary(for bridgeID: String) -> BridgePredictionSummary? {
    guard supports(bridgeID: bridgeID),
      let historicalData = historicalProvider.getHistoricalData(for: bridgeID)
    else {
      return nil
    }

    let buckets = historicalData.bucketsWithData
    guard !buckets.isEmpty else {
      return nil
    }

    var totalProbability = 0.0
    var totalConfidence = 0.0
    var bucketCount = 0

    for bucket in buckets {
      let (probability, confidence, _) = predictWithConfidence(
        for: bridgeID, at: createDateFromBucket(bucket))
      totalProbability += probability
      totalConfidence += confidence
      bucketCount += 1
    }

    let averageProbability = totalProbability / Double(bucketCount)
    let averageConfidence = totalConfidence / Double(bucketCount)

    return BridgePredictionSummary(
      bridgeID: bridgeID,
      averageProbability: averageProbability,
      averageConfidence: averageConfidence,
      bucketCount: bucketCount,
      totalSamples: historicalData.totalSamples,
      lastUpdated: historicalData.lastUpdated)
  }

  // MARK: - Utility Methods

  /// Calculate confidence based on data recency
  /// - Parameter lastSeen: When the data was last updated
  /// - Returns: Confidence score (0.0 - 1.0)
  private func calculateRecencyConfidence(lastSeen: Date?) -> Double {
    guard let lastSeen = lastSeen else {
      return 0.0
    }

    let daysSinceUpdate = Date().timeIntervalSince(lastSeen) / (24 * 60 * 60)

    // Exponential decay: 1.0 for same day, 0.5 for 7 days, 0.1 for 30 days
    let decayRate = 0.1
    return exp(-decayRate * daysSinceUpdate)
  }

  /// Create a Date from a DateBucket (for testing and utility purposes)
  /// - Parameter bucket: The time bucket
  /// - Returns: Date representing the bucket
  private func createDateFromBucket(_ bucket: DateBucket) -> Date {
    let calendar = Calendar.current
    let now = Date()

    var components = calendar.dateComponents([.year, .month, .day], from: now)
    components.hour = bucket.hour
    components.minute = bucket.minute
    components.second = 0
    components.nanosecond = 0

    return calendar.date(from: components) ?? now
  }

  /// Get the current configuration
  public var currentConfig: BaselinePredictorConfig {
    return config
  }

  /// Get supported bridge IDs
  public var availableBridgeIDs: [String] {
    return Array(supportedBridgeIDs)
  }
}

// MARK: - Supporting Types

/// Summary of prediction statistics for a bridge
public struct BridgePredictionSummary: Codable, Equatable {
  public let bridgeID: String
  public let averageProbability: Double
  public let averageConfidence: Double
  public let bucketCount: Int
  public let totalSamples: Int
  public let lastUpdated: Date

  public init(
    bridgeID: String,
    averageProbability: Double,
    averageConfidence: Double,
    bucketCount: Int,
    totalSamples: Int,
    lastUpdated: Date
  ) {
    self.bridgeID = bridgeID
    self.averageProbability = averageProbability
    self.averageConfidence = averageConfidence
    self.bucketCount = bucketCount
    self.totalSamples = totalSamples
    self.lastUpdated = lastUpdated
  }
}

// MARK: - Factory Methods

extension BaselinePredictor {
  /// Create a BaselinePredictor with default configuration
  /// - Parameter historicalProvider: The historical data provider
  /// - Returns: Configured BaselinePredictor instance
  public static func createDefault(historicalProvider: HistoricalBridgeDataProvider)
    -> BaselinePredictor
  {
    return BaselinePredictor(
      historicalProvider: historicalProvider,
      config: BaselinePredictorConfig())
  }

  /// Create a BaselinePredictor with conservative configuration (higher default probability)
  /// - Parameter historicalProvider: The historical data provider
  /// - Returns: Configured BaselinePredictor instance
  public static func createConservative(historicalProvider: HistoricalBridgeDataProvider)
    -> BaselinePredictor
  {
    let config = BaselinePredictorConfig(
      priorAlpha: 2.0,
      priorBeta: 8.0,
      defaultProbability: 0.15,
      minSampleCount: 15,
      enableBlending: true,
      historicalWeight: 0.9)

    return BaselinePredictor(
      historicalProvider: historicalProvider,
      config: config)
  }

  /// Create a BaselinePredictor with aggressive configuration (lower default probability)
  /// - Parameter historicalProvider: The historical data provider
  /// - Returns: Configured BaselinePredictor instance
  public static func createAggressive(historicalProvider: HistoricalBridgeDataProvider)
    -> BaselinePredictor
  {
    let config = BaselinePredictorConfig(
      priorAlpha: 0.5,
      priorBeta: 9.5,
      defaultProbability: 0.05,
      minSampleCount: 5,
      enableBlending: true,
      historicalWeight: 0.7)

    return BaselinePredictor(
      historicalProvider: historicalProvider,
      config: config)
  }
}
