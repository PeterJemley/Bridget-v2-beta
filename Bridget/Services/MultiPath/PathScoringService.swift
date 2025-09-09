//
//  PathScoringService.swift
//  Bridget
//
//  Multi-Path Probability Traffic Prediction System
//  Purpose: Score route paths by aggregating bridge opening probabilities using log-domain math
//  Integration: Uses ETAEstimator for arrival times, BridgeOpenPredictor for probabilities
//  Acceptance: Log-domain aggregation, batch processing, robust error handling
//  Known Limits: Requires FeatureVector generation, assumes bridge independence
//

import Foundation

#if canImport(Mach)
  import Mach
#endif

// MARK: - Feature Structures

/// Bridge-specific features for ML prediction
private struct BridgeFeatures {
  let open5m: Double
  let open30m: Double
  let detourDelta: Double
  let crossRate: Double
  let viaRoutable: Double
  let viaPenalty: Double
  let gateAnom: Double
  let detourFrac: Double
  let currentSpeed: Double
  let normalSpeed: Double
}

/// Simple deterministic random number generator for feature generation
private class SimpleDeterministicRandom {
  private var state: UInt64

  init(seed: UInt64) {
    self.state = seed
  }

  /// Generate next random double in [0, 1)
  func nextDouble() -> Double {
    state = state &* 6_364_136_223_846_793_005 &+ 1
    let value = Double(state >> 16) / Double(UInt64.max >> 16)
    return value
  }
}

/// Service for scoring route paths by aggregating bridge opening probabilities
/// Implements log-domain aggregation for numerical stability and batch processing for efficiency
public class PathScoringService {
  private let predictor: BridgeOpenPredictor
  private let etaEstimator: ETAEstimator
  private let config: MultiPathConfig
  private let metricsAggregator: ScoringMetricsAggregator
  private let clock: ClockProtocol

  // MARK: - Caching Infrastructure

  /// Feature cache for bridge-specific features with FIFO eviction
  private var featureCache: [String: [Double]] = [:]
  private var cacheInsertionOrder: [String] = []  // Track insertion order for FIFO eviction
  private let featureCacheQueue = DispatchQueue(label: "feature-cache",
                                                attributes: .concurrent)
  private let featureCacheMaxSize = 1000  // Maximum number of cached feature vectors

  /// Cache statistics for monitoring
  private var cacheStats = CacheStatistics()

  /// Thread-safe cache statistics
  private struct CacheStatistics {
    private let queue = DispatchQueue(label: "cache-stats", qos: .utility)
    private var _hits: Int = 0
    private var _misses: Int = 0

    var hits: Int {
      get { queue.sync { _hits } }
      set { queue.sync { _hits = newValue } }
    }

    var misses: Int {
      get { queue.sync { _misses } }
      set { queue.sync { _misses = newValue } }
    }

    var hitRate: Double {
      let total = hits + misses
      return total > 0 ? Double(hits) / Double(total) : 0.0
    }
  }

  public init(predictor: BridgeOpenPredictor,
              etaEstimator: ETAEstimator,
              config: MultiPathConfig,
              aggregator: ScoringMetricsAggregator = globalScoringMetrics,
              clock: ClockProtocol = SystemClock.shared) throws
  {
    self.predictor = predictor
    self.etaEstimator = etaEstimator
    self.config = config
    self.metricsAggregator = aggregator
    self.clock = clock

    // Validate configuration
    try validateConfiguration()
  }

  /// Validate the service configuration
  /// - Throws: PathScoringError.configurationError if configuration is invalid
  private func validateConfiguration() throws {
    // Validate scoring configuration
    guard config.scoring.minProbability >= 0.0,
          config.scoring.minProbability <= 1.0
    else {
      throw PathScoringError.configurationError(
        "minProbability must be between 0.0 and 1.0, got \(config.scoring.minProbability)"
      )
    }

    guard config.scoring.maxProbability >= 0.0,
          config.scoring.maxProbability <= 1.0
    else {
      throw PathScoringError.configurationError(
        "maxProbability must be between 0.0 and 1.0, got \(config.scoring.maxProbability)"
      )
    }

    guard config.scoring.minProbability <= config.scoring.maxProbability
    else {
      throw PathScoringError.configurationError(
        "minProbability (\(config.scoring.minProbability)) must be <= maxProbability (\(config.scoring.maxProbability))"
      )
    }

    // Validate performance configuration
    guard config.performance.maxScoringTime > 0.0 else {
      throw PathScoringError.configurationError(
        "maxScoringTime must be positive, got \(config.performance.maxScoringTime)"
      )
    }

    // Validate predictor configuration
    guard predictor.maxBatchSize > 0 else {
      throw PathScoringError.configurationError(
        "Predictor maxBatchSize must be positive, got \(predictor.maxBatchSize)"
      )
    }

    print("✅ PathScoringService configuration validated successfully")
  }

  // MARK: - Cache Management

  /// Generate cache key for bridge features
  /// Uses 5-minute time buckets for efficient caching
  private func featureCacheKey(bridgeID: String, eta: Date) -> String {
    let calendar = clock.calendar
    let minuteOfDay =
      calendar.component(.minute, from: eta) + calendar.component(.hour,
                                                                  from: eta) * 60
    let timeBucket = minuteOfDay / 5  // 5-minute buckets
    return "\(bridgeID)_\(timeBucket)"
  }

  /// Get cached features or return nil if not found
  private func getCachedFeatures(for key: String) -> [Double]? {
    return featureCacheQueue.sync {
      if let features = featureCache[key] {
        cacheStats.hits += 1
        return features
      } else {
        cacheStats.misses += 1
        return nil
      }
    }
  }

  /// Cache features with size management using FIFO eviction
  private func cacheFeatures(_ features: [Double], for key: String) {
    featureCacheQueue.async(flags: .barrier) {
      // Add to cache
      self.featureCache[key] = features

      // Update insertion order (remove if already exists, then add to end)
      if let existingIndex = self.cacheInsertionOrder.firstIndex(of: key) {
        self.cacheInsertionOrder.remove(at: existingIndex)
      }
      self.cacheInsertionOrder.append(key)

      // Manage cache size with FIFO eviction
      while self.featureCache.count > self.featureCacheMaxSize {
        if let oldestKey = self.cacheInsertionOrder.first {
          self.featureCache.removeValue(forKey: oldestKey)
          self.cacheInsertionOrder.removeFirst()
        } else {
          break  // Safety check
        }
      }
    }
  }

  /// Get cache statistics for monitoring
  public func getCacheStatistics() -> (hits: Int, misses: Int, hitRate: Double) {
    return (cacheStats.hits, cacheStats.misses, cacheStats.hitRate)
  }

  /// Get current memory usage for performance monitoring
  /// - Returns: Current memory usage in bytes
  private func getCurrentMemoryUsage() -> Int64 {
    #if canImport(Mach)
      var info = mach_task_basic_info()
      var count =
        mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)
          / 4

      let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
          task_info(mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count)
        }
      }

      if kerr == KERN_SUCCESS {
        return Int64(info.resident_size)
      } else {
        return 0
      }
    #else
      // Mach module not available on this platform; return 0 as a safe fallback.
      return 0
    #endif
  }

  /// Calculate standard deviation for statistical analysis
  /// - Parameters:
  ///   - values: Array of values to analyze
  ///   - mean: Pre-calculated mean of the values
  /// - Returns: Standard deviation
  private func calculateStandardDeviation(_ values: [Double], mean: Double)
    -> Double
  {
    guard values.count > 1 else { return 0.0 }

    let squaredDifferences = values.map { pow($0 - mean, 2) }
    let variance =
      squaredDifferences.reduce(0, +) / Double(values.count - 1)
    return sqrt(variance)
  }

  /// Clear all caches (useful for testing and memory management)
  public func clearCaches() {
    featureCacheQueue.async(flags: .barrier) {
      self.featureCache.removeAll()
      self.cacheInsertionOrder.removeAll()
    }
    cacheStats.hits = 0
    cacheStats.misses = 0
  }

  // MARK: - Logging

  /// Gate warnings based on configured verbosity
  private func logWarning(_ message: String) {
    switch config.performance.logVerbosity {
    case .silent:
      return
    case .warnings, .verbose:
      print(message)
    }
  }

  /// Score a single route path by aggregating bridge opening probabilities.
  public func scorePath(_ path: RoutePath,
                        departureTime: Date,
                        recordMetrics: Bool = true) async throws -> PathScore
  {
    let startTime = clock.now
    var etaEstimationTime: TimeInterval = 0.0
    var bridgePredictionTime: TimeInterval = 0.0
    var aggregationTime: TimeInterval = 0.0
    var featureGenerationTime: TimeInterval = 0.0

    // Validate input parameters
    guard !path.nodes.isEmpty else {
      throw PathScoringError.invalidPath("Path contains no nodes")
    }

    // Validate path structure
    do {
      try path.validate()
    } catch let error as MultiPathError {
      throw PathScoringError.invalidPath(error.localizedDescription)
    } catch {
      throw PathScoringError.invalidPath(
        "Unknown validation error: \(error.localizedDescription)"
      )
    }

    // Get bridge ETAs with IDs for prediction
    let etaStartTime = clock.now
    let bridgeETAs = etaEstimator.estimateBridgeETAsWithIDs(for: path,
                                                            departureTime: departureTime)
    etaEstimationTime = clock.now.timeIntervalSince(etaStartTime)

    guard !bridgeETAs.isEmpty else {
      // Path has no bridges, so probability is 1.0 (always passable)
      return PathScore(path: path,
                       logProbability: 0.0,  // log(1.0) = 0.0
                       linearProbability: 1.0,
                       bridgeProbabilities: [:])
    }

    // Defensive accepted-ID check: separate accepted vs policy-rejected bridges
    var acceptedBridgeETAs: [(bridgeID: String, eta: ETA)] = []
    var policyRejected: [String] = []

    for (bridgeID, eta) in bridgeETAs {
      if SeattleDrawbridges.isAcceptedBridgeID(bridgeID,
                                               allowSynthetic: true)
      {
        acceptedBridgeETAs.append((bridgeID: bridgeID, eta: eta))
      } else {
        policyRejected.append(bridgeID)
      }
    }

    // Prepare containers
    var bridgeProbabilities: [String: Double] = [:]
    var probabilities: [Double] = []
    var unsupportedBridges: [String] = []  // predictor-unsupported
    let defaultProbability = predictor.defaultProbability

    // For policy-rejected IDs: assign default probability and do not predict
    if !policyRejected.isEmpty {
      for id in policyRejected {
        bridgeProbabilities[id] = defaultProbability
        probabilities.append(defaultProbability)
      }
    }

    // If no accepted bridges remain, return aggregated result for only policy-rejected
    if acceptedBridgeETAs.isEmpty {
      let (logP, linP) = aggregateProbabilities(probabilities)
      // Log a single warning for policy-rejected IDs
      logWarning(
        "⚠️ Warning: \(policyRejected.count) bridge IDs rejected by policy (neither canonical nor allowed synthetic): \(policyRejected.joined(separator: ", ")). Using default probabilities."
      )
      return PathScore(path: path,
                       logProbability: logP,
                       linearProbability: linP,
                       bridgeProbabilities: bridgeProbabilities)
    }

    // Build prediction inputs for accepted bridges
    let featureStartTime = clock.now
    let predictionInputs: [BridgePredictionInput]
    do {
      predictionInputs = try await buildPredictionInputs(bridgeETAs: acceptedBridgeETAs,
                                                         path: path,
                                                         departureTime: departureTime)
    } catch {
      throw PathScoringError.featureGenerationFailed(
        "Failed to build prediction inputs: \(error.localizedDescription)"
      )
    }
    featureGenerationTime = clock.now.timeIntervalSince(featureStartTime)

    // Validate prediction inputs
    guard !predictionInputs.isEmpty else {
      throw PathScoringError.predictionFailed(
        "No prediction inputs generated"
      )
    }

    // Batch predict bridge opening probabilities for accepted bridges
    let predictionStartTime = clock.now
    let predictionResult: BatchPredictionResult
    do {
      predictionResult = try await predictor.predictBatch(
        predictionInputs
      )
    } catch {
      throw PathScoringError.predictionFailed(
        "Batch prediction failed: \(error.localizedDescription)"
      )
    }
    bridgePredictionTime = clock.now.timeIntervalSince(predictionStartTime)

    // Validate prediction results count
    guard predictionResult.predictions.count == acceptedBridgeETAs.count
    else {
      throw PathScoringError.predictionFailed(
        "Prediction result count (\(predictionResult.predictions.count)) doesn't match accepted bridge count (\(acceptedBridgeETAs.count))"
      )
    }

    // Extract probabilities and create bridge ID mapping with error handling
    for (index, prediction) in predictionResult.predictions.enumerated() {
      let bridgeID = acceptedBridgeETAs[index].bridgeID

      // Check if bridge is supported by predictor
      if !predictor.supports(bridgeID: bridgeID) {
        unsupportedBridges.append(bridgeID)
        bridgeProbabilities[bridgeID] = defaultProbability
        probabilities.append(defaultProbability)
        continue
      }

      // Validate probability value
      guard prediction.openProbability.isFinite else {
        throw PathScoringError.predictionFailed(
          "Invalid probability value for bridge \(bridgeID): \(prediction.openProbability)"
        )
      }

      // Clamp individual bridge probability to configuration bounds
      let probability = max(config.scoring.minProbability,
                            min(config.scoring.maxProbability, prediction.openProbability))
      bridgeProbabilities[bridgeID] = probability
      probabilities.append(probability)
    }

    // Aggregate probabilities using log-domain math for numerical stability
    let aggregationStartTime = clock.now
    let (logProbability, linearProbability) = aggregateProbabilities(
      probabilities
    )
    aggregationTime = clock.now.timeIntervalSince(aggregationStartTime)

    // Validate final probabilities
    guard
      linearProbability.isFinite && linearProbability >= 0.0
      && linearProbability <= 1.0
    else {
      throw PathScoringError.predictionFailed(
        "Invalid aggregated probability: \(linearProbability)"
      )
    }

    // Log warnings for policy-rejected and predictor-unsupported bridges
    if !policyRejected.isEmpty {
      logWarning(
        "⚠️ Warning: \(policyRejected.count) bridge IDs rejected by policy (neither canonical nor allowed synthetic): \(policyRejected.joined(separator: ", ")). Using default probabilities."
      )
    }
    if !unsupportedBridges.isEmpty {
      logWarning(
        "⚠️ Warning: \(unsupportedBridges.count) bridges unsupported by predictor: \(unsupportedBridges.joined(separator: ", ")). Using default probabilities."
      )
    }

    // Record performance metrics if enabled
    if config.performance.enablePerformanceLogging && recordMetrics {
      let totalScoringTime = clock.now.timeIntervalSince(startTime)
      let bridgesProcessed = bridgeETAs.count
      let defaultProbabilityBridges =
        policyRejected.count + unsupportedBridges.count
      let cacheStats = getCacheStatistics()

      let metrics = ScoringMetrics(totalScoringTime: totalScoringTime,
                                   etaEstimationTime: etaEstimationTime,
                                   bridgePredictionTime: bridgePredictionTime,
                                   aggregationTime: aggregationTime,
                                   featureGenerationTime: featureGenerationTime,
                                   pathsScored: 1,
                                   bridgesProcessed: bridgesProcessed,
                                   pathsPerSecond: totalScoringTime > 0
                                     ? 1.0 / totalScoringTime : 0.0,
                                   bridgesPerSecond: totalScoringTime > 0
                                     ? Double(bridgesProcessed) / totalScoringTime : 0.0,
                                   featureCacheHitRate: cacheStats.hitRate,
                                   cacheHits: cacheStats.hits,
                                   cacheMisses: cacheStats.misses,
                                   failedPaths: 0,
                                   defaultProbabilityBridges: defaultProbabilityBridges,
                                   averagePathProbability: linearProbability,
                                   pathProbabilityStdDev: 0.0,
                                   peakMemoryUsage: getCurrentMemoryUsage(),
                                   memoryPerPath: Double(getCurrentMemoryUsage()))

      metricsAggregator.recordMetrics(metrics)
    }

    return PathScore(path: path,
                     logProbability: logProbability,
                     linearProbability: linearProbability,
                     bridgeProbabilities: bridgeProbabilities)
  }

  /// Score multiple paths efficiently using batch processing.
  public func scorePaths(_ paths: [RoutePath],
                         departureTime: Date) async throws -> [PathScore]
  {
    let startTime = clock.now

    // Validate input
    guard !paths.isEmpty else {
      throw PathScoringError.emptyPathSet("No paths provided for scoring")
    }

    // Check for configuration limits
    if paths.count > Int(config.performance.maxScoringTime * 10) {  // Rough estimate: 10 paths per second
      logWarning(
        "⚠️ Warning: Large path set (\(paths.count) paths) may take significant time to process"
      )
    }

    var pathScores: [PathScore] = []
    var failedPaths: [(index: Int, error: Error)] = []
    var totalBridgesProcessed = 0
    var totalDefaultProbabilityBridges = 0
    var pathProbabilities: [Double] = []

    // Process paths with error handling
    for (index, path) in paths.enumerated() {
      do {
        let score = try await scorePath(path,
                                        departureTime: departureTime,
                                        recordMetrics: false  // Disable individual metrics recording for batch
        )
        pathScores.append(score)

        // Collect metrics for batch analysis
        totalBridgesProcessed += path.edges.filter { $0.isBridge }.count
        totalDefaultProbabilityBridges +=
          path.edges.filter {
            $0.isBridge
              && !SeattleDrawbridges.isAcceptedBridgeID($0.bridgeID ?? "",
                                                        allowSynthetic: true)
          }.count
        pathProbabilities.append(score.linearProbability)

      } catch {
        failedPaths.append((index: index, error: error))

        // Continue processing other paths unless this is a critical error
        if error is PathScoringError {
          // For path-specific errors, continue with other paths
          logWarning(
            "⚠️ Warning: Failed to score path \(index): \(error.localizedDescription)"
          )
        } else {
          // For unexpected errors, re-throw
          throw error
        }
      }
    }

    // Validate results
    guard pathScores.count == paths.count else {
      let failureCount = failedPaths.count
      let successCount = pathScores.count
      throw PathScoringError.predictionFailed(
        "Failed to score \(failureCount) out of \(paths.count) paths. Successfully scored: \(successCount)"
      )
    }

    // Record batch performance metrics if enabled
    if config.performance.enablePerformanceLogging {
      let totalScoringTime = clock.now.timeIntervalSince(startTime)
      let averagePathProbability =
        pathProbabilities.isEmpty
          ? 0.0
          : pathProbabilities.reduce(0, +)
          / Double(pathProbabilities.count)
      let pathProbabilityStdDev = calculateStandardDeviation(pathProbabilities,
                                                             mean: averagePathProbability)
      let cacheStats = getCacheStatistics()

      let metrics = ScoringMetrics(totalScoringTime: totalScoringTime,
                                   etaEstimationTime: 0.0,  // Not tracked separately for batch
                                   bridgePredictionTime: 0.0,  // Not tracked separately for batch
                                   aggregationTime: 0.0,  // Not tracked separately for batch
                                   featureGenerationTime: 0.0,  // Not tracked separately for batch
                                   pathsScored: paths.count,
                                   bridgesProcessed: totalBridgesProcessed,
                                   pathsPerSecond: totalScoringTime > 0
                                     ? Double(paths.count) / totalScoringTime : 0.0,
                                   bridgesPerSecond: totalScoringTime > 0
                                     ? Double(totalBridgesProcessed) / totalScoringTime : 0.0,
                                   featureCacheHitRate: cacheStats.hitRate,
                                   cacheHits: cacheStats.hits,
                                   cacheMisses: cacheStats.misses,
                                   failedPaths: failedPaths.count,
                                   defaultProbabilityBridges: totalDefaultProbabilityBridges,
                                   averagePathProbability: averagePathProbability,
                                   pathProbabilityStdDev: pathProbabilityStdDev,
                                   peakMemoryUsage: getCurrentMemoryUsage(),
                                   memoryPerPath: totalScoringTime > 0
                                     ? Double(getCurrentMemoryUsage()) / Double(paths.count)
                                     : 0.0)

      metricsAggregator.recordMetrics(metrics)
    }

    return pathScores
  }

  /// Analyze a complete journey with multiple paths and compute network-level probability.
  public func analyzeJourney(paths: [RoutePath],
                             startNode: NodeID,
                             endNode: NodeID,
                             departureTime: Date) async throws -> JourneyAnalysis
  {
    // Validate node IDs
    guard !startNode.isEmpty else {
      throw PathScoringError.invalidPath("Start node ID is empty")
    }
    guard !endNode.isEmpty else {
      throw PathScoringError.invalidPath("End node ID is empty")
    }

    // Handle empty path set gracefully
    guard !paths.isEmpty else {
      print("📊 Journey Analysis Complete (Empty Path Set):")
      print("   • Start: \(startNode) → End: \(endNode)")
      print("   • Paths analyzed: 0")
      print("   • Network probability: 0.000")
      print("   • Best path probability: 0.000")

      return JourneyAnalysis(startNode: startNode,
                             endNode: endNode,
                             departureTime: departureTime,
                             pathScores: [],
                             networkProbability: 0.0,
                             bestPathProbability: 0.0,
                             totalPathsAnalyzed: 0)
    }

    // Score all paths
    let pathScores: [PathScore]
    do {
      pathScores = try await scorePaths(paths,
                                        departureTime: departureTime)
    } catch {
      throw PathScoringError.predictionFailed(
        "Failed to score paths for journey analysis: \(error.localizedDescription)"
      )
    }

    // Validate path scores
    guard !pathScores.isEmpty else {
      throw PathScoringError.predictionFailed(
        "No valid path scores generated"
      )
    }

    // Compute network-level probability using union formula
    let networkProbability = computeNetworkProbability(pathScores)

    // Validate network probability
    guard
      networkProbability.isFinite && networkProbability >= 0.0
      && networkProbability <= 1.0
    else {
      throw PathScoringError.predictionFailed(
        "Invalid network probability: \(networkProbability)"
      )
    }

    // Find best path probability
    let bestPathProbability =
      pathScores.map { $0.linearProbability }.max() ?? 0.0

    // Validate best path probability
    guard
      bestPathProbability.isFinite && bestPathProbability >= 0.0
      && bestPathProbability <= 1.0
    else {
      throw PathScoringError.predictionFailed(
        "Invalid best path probability: \(bestPathProbability)"
      )
    }

    // Log analysis summary
    print("📊 Journey Analysis Complete:")
    print("   • Start: \(startNode) → End: \(endNode)")
    print("   • Paths analyzed: \(paths.count)")
    print(
      "   • Network probability: \(String(format: "%.3f", networkProbability))"
    )
    print(
      "   • Best path probability: \(String(format: "%.3f", bestPathProbability))"
    )

    return JourneyAnalysis(startNode: startNode,
                           endNode: endNode,
                           departureTime: departureTime,
                           pathScores: pathScores,
                           networkProbability: networkProbability,
                           bestPathProbability: bestPathProbability,
                           totalPathsAnalyzed: paths.count)
  }

  // MARK: - Private Methods

  /// Build prediction inputs for bridge ETAs
  private func buildPredictionInputs(bridgeETAs: [(bridgeID: String, eta: ETA)],
                                     path: RoutePath,
                                     departureTime: Date) async throws -> [BridgePredictionInput]
  {
    var inputs: [BridgePredictionInput] = []

    for (bridgeID, eta) in bridgeETAs {
      // Build feature vector for this bridge at this ETA
      let features = try await buildFeatures(for: bridgeID,
                                             eta: eta.arrivalTime,
                                             path: path,
                                             departureTime: departureTime)

      let input = BridgePredictionInput(bridgeID: bridgeID,
                                        eta: eta.arrivalTime,
                                        features: features)
      inputs.append(input)
    }

    return inputs
  }

  /// Build feature vector for bridge prediction using real feature engineering patterns.
  private func buildFeatures(for bridgeID: String,
                             eta: Date,
                             path: RoutePath,
                             departureTime: Date) async throws -> [Double]
  {
    // Check cache first
    let cacheKey = featureCacheKey(bridgeID: bridgeID, eta: eta)
    if let cachedFeatures = getCachedFeatures(for: cacheKey) {
      return cachedFeatures
    }

    // Generate features if not cached
    let features = try await generateFeatures(for: bridgeID,
                                              eta: eta,
                                              path: path,
                                              departureTime: departureTime)

    // Cache the generated features
    cacheFeatures(features, for: cacheKey)

    return features
  }

  /// Generate feature vector for bridge prediction (uncached version)
  private func generateFeatures(for bridgeID: String,
                                eta: Date,
                                path: RoutePath,
                                departureTime: Date) async throws -> [Double]
  {
    // Extract time-based features using the same patterns as FeatureEngineeringService
    let calendar = clock.calendar
    let minuteOfDay =
      calendar.component(.minute, from: eta) + calendar.component(.hour,
                                                                  from: eta) * 60
    let dayOfWeek = calendar.component(.weekday, from: eta)

    // Cyclical encoding for time features (same as FeatureEngineeringService)
    let (minSin, minCos) = cyc(Double(minuteOfDay), period: 1440.0)
    let (dowSin, dowCos) = cyc(Double(dayOfWeek), period: 7.0)

    // Bridge-specific features based on path context and historical patterns
    let bridgeFeatures = try await computeBridgeFeatures(bridgeID: bridgeID,
                                                         eta: eta,
                                                         path: path,
                                                         departureTime: departureTime)

    return [
      minSin, minCos, dowSin, dowCos,
      bridgeFeatures.open5m, bridgeFeatures.open30m,
      bridgeFeatures.detourDelta, bridgeFeatures.crossRate,
      bridgeFeatures.viaRoutable, bridgeFeatures.viaPenalty,
      bridgeFeatures.gateAnom, bridgeFeatures.detourFrac,
      bridgeFeatures.currentSpeed, bridgeFeatures.normalSpeed,
    ]
  }

  /// Compute bridge-specific features using path context and realistic patterns
  private func computeBridgeFeatures(bridgeID: String,
                                     eta: Date,
                                     path: RoutePath,
                                     departureTime _: Date) async throws -> BridgeFeatures
  {
    // TODO: In production, integrate real data sources

    // Generate realistic features based on time of day and bridge context
    let calendar = clock.calendar
    let hour = calendar.component(.hour, from: eta)
    let isRushHour = (hour >= 7 && hour <= 9) || (hour >= 16 && hour <= 18)
    let isWeekend =
      calendar.component(.weekday, from: eta) == 1
        || calendar.component(.weekday, from: eta) == 7

    // Base features with time-of-day adjustments
    let baseOpenRate = isWeekend ? 0.8 : 0.7
    let rushHourAdjustment = isRushHour ? -0.1 : 0.0

    // Deterministic variation based on bridge ID and time bucket
    let seed = stableDeterministicSeed(bridgeID: bridgeID, eta: eta)
    let random = SimpleDeterministicRandom(seed: seed)

    let open5m = max(0.1,
                     min(0.9,
                         baseOpenRate + rushHourAdjustment + random.nextDouble() * 0.1
                           - 0.05))
    let open30m = max(0.1,
                      min(0.9,
                          baseOpenRate + rushHourAdjustment + random.nextDouble() * 0.16
                            - 0.08))

    // Path-specific features
    let pathLength = path.nodes.count
    let detourDelta =
      Double(pathLength) * 30.0 + 60.0 + random.nextDouble() * 120.0
    let crossRate = max(0.5,
                        min(0.95, 0.8 + random.nextDouble() * 0.2 - 0.1))

    // Traffic speed based on time and path complexity
    let baseSpeed = isRushHour ? 20.0 : 35.0
    let speedVariation = random.nextDouble() * 10.0 - 5.0
    let currentSpeed = max(10.0, min(50.0, baseSpeed + speedVariation))
    let normalSpeed = max(25.0,
                          min(45.0, 35.0 + random.nextDouble() * 6.0 - 3.0))

    return BridgeFeatures(open5m: open5m,
                          open30m: open30m,
                          detourDelta: detourDelta,
                          crossRate: crossRate,
                          viaRoutable: 1.0,
                          viaPenalty: min(1.0, detourDelta / 900.0),  // Normalized to 0-1
                          gateAnom: 1.0 + random.nextDouble() * 0.5,  // Slight anomaly
                          detourFrac: min(1.0, detourDelta / (normalSpeed * 60)),  // Fraction of normal travel time
                          currentSpeed: currentSpeed,
                          normalSpeed: normalSpeed)
  }

  /// Aggregate bridge probabilities using log-domain math for numerical stability
  private func aggregateProbabilities(_ probabilities: [Double]) -> (logProbability: Double, linearProbability: Double) {
    guard !probabilities.isEmpty else {
      return (logProbability: 0.0, linearProbability: 1.0)
    }

    // Convert to log domain and sum (probabilities are already clamped)
    let logProbs = probabilities.map { log($0) }
    let logSum = logProbs.reduce(0, +)

    // Convert back to linear domain
    let linearProb = exp(logSum)

    return (logProbability: logSum, linearProbability: linearProb)
  }

  /// Compute network-level probability using union formula
  private func computeNetworkProbability(_ pathScores: [PathScore]) -> Double {
    guard !pathScores.isEmpty else {
      return 0.0
    }

    // For single path, network probability equals path probability
    if pathScores.count == 1 {
      return pathScores[0].linearProbability
    }

    // For multiple paths, use union formula: 1 - P(all fail)
    let failureProbs = pathScores.map { 1.0 - $0.linearProbability }

    // Convert to log domain (probabilities are already clamped)
    let logFailures = failureProbs.map { log($0) }
    let logFailureSum = logFailures.reduce(0, +)

    // Network probability = 1 - P(all fail)
    let networkProb = 1.0 - exp(logFailureSum)

    return max(0.0, min(1.0, networkProb))
  }
}

// MARK: - Path Scoring Errors

public enum PathScoringError: Error, LocalizedError {
  case invalidPath(String)
  case predictionFailed(String)
  case featureGenerationFailed(String)
  case emptyPathSet(String)
  case unsupportedBridges([String])
  case configurationError(String)

  public var errorDescription: String? {
    switch self {
    case let .invalidPath(reason):
      return "Invalid path: \(reason)"
    case let .predictionFailed(reason):
      return "Prediction failed: \(reason)"
    case let .featureGenerationFailed(reason):
      return "Feature generation failed: \(reason)"
    case let .emptyPathSet(reason):
      return "Empty path set: \(reason)"
    case let .unsupportedBridges(bridges):
      return "Unsupported bridges: \(bridges.joined(separator: ", "))"
    case let .configurationError(reason):
      return "Configuration error: \(reason)"
    }
  }
}

// MARK: - Deterministic Seeding Utilities

private extension PathScoringService {
  /// Compute a stable deterministic seed for feature generation that is consistent across runs/devices.
  /// Combines:
  /// - bridgeID UTF-8 bytes
  /// - 5-minute time bucket derived from ETA
  /// - global config.pathEnumeration.randomSeed as salt
  func stableDeterministicSeed(bridgeID: String, eta: Date)
    -> UInt64
  {
    // Derive a stable 5-minute bucket from ETA (00:00..23:59 -> 0..287)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    let minuteOfDay =
      calendar.component(.hour, from: eta) * 60
        + calendar.component(.minute, from: eta)
    let timeBucket = UInt32(minuteOfDay / 5)

    // Build byte buffer: bridgeID UTF-8 + timeBucket (LE) + global seed (LE)
    var bytes: [UInt8] = Array(bridgeID.utf8)

    var tb = timeBucket
    for _ in 0 ..< 4 {
      bytes.append(UInt8(tb & 0xFF))
      tb >>= 8
    }

    var salt = config.pathEnumeration.randomSeed
    for _ in 0 ..< 8 {
      bytes.append(UInt8(salt & 0xFF))
      salt >>= 8
    }

    return fnv1a64(bytes)
  }

  /// FNV-1a 64-bit hash for stable, fast hashing of small inputs
  func fnv1a64(_ data: [UInt8]) -> UInt64 {
    var hash: UInt64 = 0xCBF2_9CE4_8422_2325  // 1469598103934665603
    let prime: UInt64 = 0x0000_0100_0000_01B3  // 1099511628211
    for byte in data {
      hash ^= UInt64(byte)
      hash &*= prime
    }
    return hash
  }
}
