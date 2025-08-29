//
//  Config.swift
//  Bridget
//
//  Multi-Path Probability Traffic Prediction System
//  Purpose: Centralized configuration for enumeration, scoring, and performance caps
//  Integration: Used by all MultiPath services for consistent behavior
//  Acceptance: All magic numbers eliminated, configurable thresholds, clear defaults
//  Known Limits: Hard caps prevent runaway computation, seeded defaults for reproducibility
//

import Foundation

// MARK: - Main Configuration

/// Main configuration for the multi-path analysis system
public struct MultiPathConfig: Codable {
  public var pathEnumeration: PathEnumConfig
  public let scoring: ScoringConfig
  public let performance: MultiPathPerformanceConfig
  public let prediction: PredictionConfig

  public init(
    pathEnumeration: PathEnumConfig = PathEnumConfig(),
    scoring: ScoringConfig = ScoringConfig(),
    performance: MultiPathPerformanceConfig = MultiPathPerformanceConfig(),
    prediction: PredictionConfig = PredictionConfig()
  ) {
    self.pathEnumeration = pathEnumeration
    self.scoring = scoring
    self.performance = performance
    self.prediction = prediction
  }
}

// MARK: - Path Enumeration Configuration

/// Configuration for path enumeration algorithms
public struct PathEnumConfig: Codable {
  /// Maximum number of paths to enumerate (prevents runaway computation)
  public var maxPaths: Int

  /// Maximum depth (number of edges) for any single path
  public var maxDepth: Int

  /// Maximum travel time for any single path (seconds)
  public var maxTravelTime: TimeInterval

  /// Whether to allow cycles in paths (typically false for routing)
  public var allowCycles: Bool

  /// Whether to use bidirectional search (future optimization)
  public var useBidirectionalSearch: Bool

  /// Path enumeration algorithm to use
  public var enumerationMode: PathEnumerationMode

  /// Number of shortest paths to find (for Yen's algorithm)
  public var kShortestPaths: Int

  /// Seed for deterministic path ordering (for reproducible results)
  public var randomSeed: UInt64

  /// Maximum additional travel time (in seconds) allowed over the shortest path.
  /// Only paths with total travel time ≤ (shortest path time + maxTimeOverShortest) are included.
  /// Set to a positive value to enable pruning. Default is 300 (5 minutes).
  public var maxTimeOverShortest: TimeInterval

  public init(
    maxPaths: Int = 100,
    maxDepth: Int = 20,
    maxTravelTime: TimeInterval = 3600,  // 1 hour
    allowCycles: Bool = false,
    useBidirectionalSearch: Bool = false,
    enumerationMode: PathEnumerationMode = .dfs,
    kShortestPaths: Int = 10,
    randomSeed: UInt64 = 42,
    maxTimeOverShortest: TimeInterval = 300  // 5 minutes
  ) {
    self.maxPaths = maxPaths
    self.maxDepth = maxDepth
    self.maxTravelTime = maxTravelTime
    self.allowCycles = allowCycles
    self.useBidirectionalSearch = useBidirectionalSearch
    self.enumerationMode = enumerationMode
    self.kShortestPaths = kShortestPaths
    self.randomSeed = randomSeed
    self.maxTimeOverShortest = maxTimeOverShortest
  }
}

// MARK: - Supporting Types

/// Path enumeration algorithm modes
public enum PathEnumerationMode: String, Codable, CaseIterable {
  /// Depth-first search enumeration (current implementation)
  case dfs = "dfs"

  /// Yen's K-shortest paths algorithm (more efficient for large networks)
  case yensKShortest = "yens_k_shortest"

  /// Auto-select based on network size and configuration
  case auto = "auto"
}

/// Clamping bounds for probability values
public struct ClampBounds: Codable {
  public let min: Double
  public let max: Double

  public init(min: Double, max: Double) {
    self.min = min
    self.max = max
  }
}

// MARK: - Scoring Configuration

/// Configuration for probability scoring and aggregation
public struct ScoringConfig: Codable {
  /// Minimum probability value (prevents numerical underflow)
  public let minProbability: Double

  /// Maximum probability value (prevents numerical overflow)
  public let maxProbability: Double

  /// Log-domain threshold for numerical stability
  public let logThreshold: Double

  /// Whether to use log-domain aggregation (recommended for numerical stability)
  public let useLogDomain: Bool

  /// Clamping bounds for final probabilities
  public let clampBounds: ClampBounds

  /// Weight for bridge probability vs. travel time in scoring
  public let bridgeWeight: Double

  /// Weight for travel time vs. bridge probability in scoring
  public let timeWeight: Double

  public init(
    minProbability: Double = 1e-10,
    maxProbability: Double = 1.0 - 1e-10,
    logThreshold: Double = -20.0,
    useLogDomain: Bool = true,
    clampBounds: ClampBounds = ClampBounds(min: 0.0, max: 1.0),
    bridgeWeight: Double = 0.7,
    timeWeight: Double = 0.3
  ) {
    self.minProbability = minProbability
    self.maxProbability = maxProbability
    self.logThreshold = logThreshold
    self.useLogDomain = useLogDomain
    self.clampBounds = clampBounds
    self.bridgeWeight = bridgeWeight
    self.timeWeight = timeWeight
  }
}

// MARK: - Performance Configuration

/// Configuration for performance monitoring and limits
public struct MultiPathPerformanceConfig: Codable {
  /// Maximum time for path enumeration (seconds)
  public let maxEnumerationTime: TimeInterval

  /// Maximum time for scoring computation (seconds)
  public let maxScoringTime: TimeInterval

  /// Maximum memory usage for path storage (bytes)
  public let maxMemoryUsage: Int64

  /// Whether to enable performance logging
  public let enablePerformanceLogging: Bool

  /// Whether to enable caching of intermediate results
  public let enableCaching: Bool

  /// Cache expiration time (seconds)
  public let cacheExpirationTime: TimeInterval

  public init(
    maxEnumerationTime: TimeInterval = 30.0,
    maxScoringTime: TimeInterval = 10.0,
    maxMemoryUsage: Int64 = 100 * 1024 * 1024,  // 100MB
    enablePerformanceLogging: Bool = true,
    enableCaching: Bool = true,
    cacheExpirationTime: TimeInterval = 300  // 5 minutes
  ) {
    self.maxEnumerationTime = maxEnumerationTime
    self.maxScoringTime = maxScoringTime
    self.maxMemoryUsage = maxMemoryUsage
    self.enablePerformanceLogging = enablePerformanceLogging
    self.enableCaching = enableCaching
    self.cacheExpirationTime = cacheExpirationTime
  }
}

// MARK: - Prediction Configuration

/// Configuration for bridge opening prediction
public struct PredictionConfig: Codable {
  /// Default prediction for bridges without ML model
  public let defaultBridgeProbability: Double

  /// Whether to use batch prediction (recommended for performance)
  public let useBatchPrediction: Bool

  /// Batch size for predictions
  public let batchSize: Int

  /// Whether to enable prediction caching
  public let enablePredictionCache: Bool

  /// Cache expiration for predictions (seconds)
  public let predictionCacheExpiration: TimeInterval

  /// Seed for mock predictor (for reproducible testing)
  public let mockPredictorSeed: UInt64

  /// Prediction mode to use (baseline vs ML model)
  public let predictionMode: PredictionMode

  /// Alpha parameter for Beta smoothing in baseline predictor
  public let priorAlpha: Double

  /// Beta parameter for Beta smoothing in baseline predictor
  public let priorBeta: Double

  /// Whether to enable metrics logging for predictions
  public let enableMetricsLogging: Bool

  public init(
    defaultBridgeProbability: Double = 0.8,
    useBatchPrediction: Bool = true,
    batchSize: Int = 50,
    enablePredictionCache: Bool = true,
    predictionCacheExpiration: TimeInterval = 60,  // 1 minute
    mockPredictorSeed: UInt64 = 12345,
    predictionMode: PredictionMode = .baseline,
    priorAlpha: Double = 1.0,
    priorBeta: Double = 9.0,
    enableMetricsLogging: Bool = false
  ) {
    self.defaultBridgeProbability = defaultBridgeProbability
    self.useBatchPrediction = useBatchPrediction
    self.batchSize = batchSize
    self.enablePredictionCache = enablePredictionCache
    self.predictionCacheExpiration = predictionCacheExpiration
    self.mockPredictorSeed = mockPredictorSeed
    self.predictionMode = predictionMode
    self.priorAlpha = priorAlpha
    self.priorBeta = priorBeta
    self.enableMetricsLogging = enableMetricsLogging
  }
}

/// Prediction mode for bridge opening probability
public enum PredictionMode: String, Codable, CaseIterable {
  /// Use baseline predictor with historical data
  case baseline = "baseline"

  /// Use ML model for predictions
  case mlModel = "ml_model"

  /// Auto-select based on availability
  case auto = "auto"
}

// MARK: - Default Configurations

extension MultiPathConfig {
  /// Default configuration for development/testing
  public static let development = MultiPathConfig(
    pathEnumeration: PathEnumConfig(
      maxPaths: 50,
      maxDepth: 10,
      maxTravelTime: 1800,  // 30 minutes
      randomSeed: 42
    ),
    scoring: ScoringConfig(
      useLogDomain: true,
      bridgeWeight: 0.7,
      timeWeight: 0.3
    ),
    performance: MultiPathPerformanceConfig(
      maxEnumerationTime: 10.0,
      maxScoringTime: 5.0,
      enablePerformanceLogging: true,
      enableCaching: true
    ),
    prediction: PredictionConfig(
      defaultBridgeProbability: 0.8,
      useBatchPrediction: true,
      batchSize: 25,
      mockPredictorSeed: 42
    )
  )

  /// Default configuration for production
  public static let production = MultiPathConfig(
    pathEnumeration: PathEnumConfig(
      maxPaths: 100,
      maxDepth: 20,
      maxTravelTime: 3600,  // 1 hour
      randomSeed: 0  // will be set at runtime
    ),
    scoring: ScoringConfig(
      useLogDomain: true,
      bridgeWeight: 0.7,
      timeWeight: 0.3
    ),
    performance: MultiPathPerformanceConfig(
      maxEnumerationTime: 30.0,
      maxScoringTime: 10.0,
      enablePerformanceLogging: false,
      enableCaching: true
    ),
    prediction: PredictionConfig(
      defaultBridgeProbability: 0.8,
      useBatchPrediction: true,
      batchSize: 50,
      enablePredictionCache: true
    )
  )

  /// Configuration for testing with deterministic behavior
  public static let testing = MultiPathConfig(
    pathEnumeration: PathEnumConfig(
      maxPaths: 10,
      maxDepth: 5,
      maxTravelTime: 600,  // 10 minutes
      randomSeed: 42,
      maxTimeOverShortest: 120  // 2 minutes for testing
    ),
    scoring: ScoringConfig(
      useLogDomain: true,
      bridgeWeight: 0.5,
      timeWeight: 0.5
    ),
    performance: MultiPathPerformanceConfig(
      maxEnumerationTime: 5.0,
      maxScoringTime: 2.0,
      enablePerformanceLogging: true,
      enableCaching: false
    ),
    prediction: PredictionConfig(
      defaultBridgeProbability: 0.5,
      useBatchPrediction: false,
      batchSize: 1,
      enablePredictionCache: false,
      mockPredictorSeed: 42
    )
  )
}
