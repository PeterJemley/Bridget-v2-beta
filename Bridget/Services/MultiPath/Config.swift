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

public struct PathEnumConfig: Codable {
  public var maxPaths: Int
  public var maxDepth: Int
  public var maxTravelTime: TimeInterval
  public var allowCycles: Bool
  public var useBidirectionalSearch: Bool
  public var enumerationMode: PathEnumerationMode
  public var kShortestPaths: Int
  public var randomSeed: UInt64
  public var maxTimeOverShortest: TimeInterval

  public init(
    maxPaths: Int = 100,
    maxDepth: Int = 20,
    maxTravelTime: TimeInterval = 3600,
    allowCycles: Bool = false,
    useBidirectionalSearch: Bool = false,
    enumerationMode: PathEnumerationMode = .dfs,
    kShortestPaths: Int = 10,
    randomSeed: UInt64 = 42,
    maxTimeOverShortest: TimeInterval = 300
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

public enum PathEnumerationMode: String, Codable, CaseIterable {
  case dfs
  case yensKShortest = "yens_k_shortest"
  case auto
}

public struct ClampBounds: Codable {
  public let min: Double
  public let max: Double

  public init(min: Double, max: Double) {
    self.min = min
    self.max = max
  }
}

// MARK: - Scoring Configuration

public struct ScoringConfig: Codable {
  public let minProbability: Double
  public let maxProbability: Double
  public let logThreshold: Double
  public let useLogDomain: Bool
  public let clampBounds: ClampBounds
  public let bridgeWeight: Double
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

public enum LogVerbosity: String, Codable, CaseIterable {
  case silent
  case warnings
  case verbose
}

public struct MultiPathPerformanceConfig: Codable {
  public let maxEnumerationTime: TimeInterval
  public let maxScoringTime: TimeInterval
  public let maxMemoryUsage: Int64
  public let enablePerformanceLogging: Bool
  public let enableCaching: Bool
  public let cacheExpirationTime: TimeInterval
  public let logVerbosity: LogVerbosity

  public init(
    maxEnumerationTime: TimeInterval = 30.0,
    maxScoringTime: TimeInterval = 10.0,
    maxMemoryUsage: Int64 = 100 * 1024 * 1024,
    enablePerformanceLogging: Bool = true,
    enableCaching: Bool = true,
    cacheExpirationTime: TimeInterval = 300,
    logVerbosity: LogVerbosity = .warnings
  ) {
    self.maxEnumerationTime = maxEnumerationTime
    self.maxScoringTime = maxScoringTime
    self.maxMemoryUsage = maxMemoryUsage
    self.enablePerformanceLogging = enablePerformanceLogging
    self.enableCaching = enableCaching
    self.cacheExpirationTime = cacheExpirationTime
    self.logVerbosity = logVerbosity
  }
}

// MARK: - Prediction Configuration

public struct PredictionConfig: Codable {
  public let defaultBridgeProbability: Double
  public let useBatchPrediction: Bool
  public let batchSize: Int
  public let enablePredictionCache: Bool
  public let predictionCacheExpiration: TimeInterval
  public let mockPredictorSeed: UInt64
  public let predictionMode: PredictionMode
  public let priorAlpha: Double
  public let priorBeta: Double
  public let enableMetricsLogging: Bool

  public init(
    defaultBridgeProbability: Double = 0.8,
    useBatchPrediction: Bool = true,
    batchSize: Int = 50,
    enablePredictionCache: Bool = true,
    predictionCacheExpiration: TimeInterval = 60,
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

public enum PredictionMode: String, Codable, CaseIterable {
  case baseline
  case mlModel = "ml_model"
  case auto
}

// MARK: - Default Configurations

extension MultiPathConfig {
  public static let development = MultiPathConfig(
    pathEnumeration: PathEnumConfig(
      maxPaths: 50,
      maxDepth: 10,
      maxTravelTime: 1800,
      randomSeed: 42),
    scoring: ScoringConfig(
      useLogDomain: true,
      bridgeWeight: 0.7,
      timeWeight: 0.3),
    performance: MultiPathPerformanceConfig(
      maxEnumerationTime: 10.0,
      maxScoringTime: 5.0,
      enablePerformanceLogging: true,
      enableCaching: true,
      logVerbosity: .warnings),
    prediction: PredictionConfig(
      defaultBridgeProbability: 0.8,
      useBatchPrediction: true,
      batchSize: 25,
      mockPredictorSeed: 42))

  public static let production = MultiPathConfig(
    pathEnumeration: PathEnumConfig(
      maxPaths: 100,
      maxDepth: 20,
      maxTravelTime: 3600,
      randomSeed: 0),
    scoring: ScoringConfig(
      useLogDomain: true,
      bridgeWeight: 0.7,
      timeWeight: 0.3),
    performance: MultiPathPerformanceConfig(
      maxEnumerationTime: 30.0,
      maxScoringTime: 10.0,
      enablePerformanceLogging: false,
      enableCaching: true,
      logVerbosity: .warnings),
    prediction: PredictionConfig(
      defaultBridgeProbability: 0.8,
      useBatchPrediction: true,
      batchSize: 50,
      enablePredictionCache: true))

  public static let testing = MultiPathConfig(
    pathEnumeration: PathEnumConfig(
      maxPaths: 10,
      maxDepth: 5,
      maxTravelTime: 600,
      randomSeed: 42,
      maxTimeOverShortest: 120),
    scoring: ScoringConfig(
      useLogDomain: true,
      bridgeWeight: 0.5,
      timeWeight: 0.5),
    performance: MultiPathPerformanceConfig(
      maxEnumerationTime: 5.0,
      maxScoringTime: 2.0,
      enablePerformanceLogging: true,
      enableCaching: false,
      logVerbosity: .warnings),
    prediction: PredictionConfig(
      defaultBridgeProbability: 0.5,
      useBatchPrediction: false,
      batchSize: 1,
      enablePredictionCache: false,
      mockPredictorSeed: 42))
}
