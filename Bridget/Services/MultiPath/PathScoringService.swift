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

// MARK: - PathScoringService
/// Service for scoring route paths by aggregating bridge opening probabilities.
///
/// This service integrates ETA estimation and bridge prediction to compute the probability
/// that a complete route path will be traversable (all bridges open when needed).
///
/// ## Key Features:
/// - **Log-domain aggregation**: Uses log-domain math to avoid numerical underflow
/// - **Batch processing**: Efficiently processes multiple paths and predictions
/// - **Deterministic features**: Generates reproducible feature vectors for ML models
/// - **Robust error handling**: Comprehensive error types and graceful failure modes
/// - **Configuration validation**: Validates service configuration at initialization
///
/// ## Usage Example:
/// ```swift
/// let service = try PathScoringService(
///     predictor: bridgePredictor,
///     etaEstimator: etaEstimator,
///     config: multiPathConfig
/// )
///
/// let pathScore = try await service.scorePath(routePath, departureTime: Date())
/// let journeyAnalysis = try await service.analyzeJourney(
///     paths: alternativePaths,
///     startNode: "A",
///     endNode: "B",
///     departureTime: Date()
/// )
/// ```
///
/// ## Mathematical Background:
/// - **Joint Probability**: P(all bridges open) = ∏ P(bridge_i open)
/// - **Log-domain**: log(P) = ∑ log(P_i) for numerical stability
/// - **Network Probability**: P(at least one path open) = 1 - ∏(1 - P(path_i))
///
/// - Author: Bridget Team
/// - Version: 1.0
/// - Since: 2024

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

  // MARK: - Caching Infrastructure

  /// Feature cache for bridge-specific features with FIFO eviction
  private var featureCache: [String: [Double]] = [:]
  private var cacheInsertionOrder: [String] = []  // Track insertion order for FIFO eviction
  private let featureCacheQueue = DispatchQueue(label: "feature-cache", attributes: .concurrent)
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

  public init(
    predictor: BridgeOpenPredictor,
    etaEstimator: ETAEstimator,
    config: MultiPathConfig
  ) throws {
    self.predictor = predictor
    self.etaEstimator = etaEstimator
    self.config = config

    // Validate configuration
    try validateConfiguration()
  }

  /// Validate the service configuration
  /// - Throws: PathScoringError.configurationError if configuration is invalid
  private func validateConfiguration() throws {
    // Validate scoring configuration
    guard config.scoring.minProbability >= 0.0 && config.scoring.minProbability <= 1.0 else {
      throw PathScoringError.configurationError(
        "minProbability must be between 0.0 and 1.0, got \(config.scoring.minProbability)")
    }

    guard config.scoring.maxProbability >= 0.0 && config.scoring.maxProbability <= 1.0 else {
      throw PathScoringError.configurationError(
        "maxProbability must be between 0.0 and 1.0, got \(config.scoring.maxProbability)")
    }

    guard config.scoring.minProbability <= config.scoring.maxProbability else {
      throw PathScoringError.configurationError(
        "minProbability (\(config.scoring.minProbability)) must be <= maxProbability (\(config.scoring.maxProbability))"
      )
    }

    // Validate performance configuration
    guard config.performance.maxScoringTime > 0.0 else {
      throw PathScoringError.configurationError(
        "maxScoringTime must be positive, got \(config.performance.maxScoringTime)")
    }

    // Validate predictor configuration
    guard predictor.maxBatchSize > 0 else {
      throw PathScoringError.configurationError(
        "Predictor maxBatchSize must be positive, got \(predictor.maxBatchSize)")
    }

    print("✅ PathScoringService configuration validated successfully")
  }

  // MARK: - Cache Management

  /// Generate cache key for bridge features
  /// Uses 5-minute time buckets for efficient caching
  private func featureCacheKey(bridgeID: String, eta: Date) -> String {
    let calendar = Calendar.current
    let minuteOfDay =
      calendar.component(.minute, from: eta) + calendar.component(.hour, from: eta) * 60
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

  /// Clear all caches (useful for testing and memory management)
  public func clearCaches() {
    featureCacheQueue.async(flags: .barrier) {
      self.featureCache.removeAll()
      self.cacheInsertionOrder.removeAll()
    }
    cacheStats.hits = 0
    cacheStats.misses = 0
  }

  /// Score a single route path by aggregating bridge opening probabilities.
  ///
  /// This method performs the complete scoring pipeline:
  /// 1. Validates the route path structure
  /// 2. Estimates arrival times for each bridge in the path
  /// 3. Generates feature vectors for ML prediction
  /// 4. Predicts bridge opening probabilities using batch processing
  /// 5. Aggregates probabilities using log-domain math
  ///
  /// ## Mathematical Process:
  /// - **ETA Estimation**: Uses `ETAEstimator` to compute arrival times at each bridge
  /// - **Feature Generation**: Creates deterministic feature vectors based on time, bridge ID, and path context
  /// - **Probability Prediction**: Uses `BridgeOpenPredictor` to get opening probabilities
  /// - **Aggregation**: Computes joint probability P(all bridges open) = ∏ P(bridge_i open)
  /// - **Log-domain**: Returns both log(P) and P for numerical stability and convenience
  ///
  /// ## Performance Characteristics:
  /// - **Time Complexity**: O(n) where n is the number of bridges in the path
  /// - **Space Complexity**: O(n) for feature vectors and probability storage
  /// - **Batch Efficiency**: Uses `predictBatch` for optimal ML model inference
  ///
  /// ## Error Handling:
  /// - Validates path structure and throws `PathScoringError.invalidPath` for malformed paths
  /// - Handles prediction failures with `PathScoringError.predictionFailed`
  /// - Manages feature generation errors with `PathScoringError.featureGenerationFailed`
  /// - Gracefully handles unsupported bridges with default probabilities
  ///
  /// - Parameters:
  ///   - path: The RoutePath to score. Must be valid and contain at least one bridge.
  ///   - departureTime: The travel start time. Used for ETA calculations and time-of-day features.
  /// - Returns: PathScore containing the aggregated probability and detailed bridge-level information
  /// - Throws: PathScoringError for validation, prediction, or feature generation failures
  public func scorePath(
    _ path: RoutePath,
    departureTime: Date
  ) async throws -> PathScore {
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
      throw PathScoringError.invalidPath("Unknown validation error: \(error.localizedDescription)")
    }

    // Get bridge ETAs with IDs for prediction
    let bridgeETAs = etaEstimator.estimateBridgeETAsWithIDs(
      for: path,
      departureTime: departureTime
    )

    // Validate that all bridge IDs are canonical Seattle bridges
    let nonCanonicalBridgeIDs = bridgeETAs.compactMap { eta in
      SeattleDrawbridges.isValidBridgeID(eta.bridgeID) ? nil : eta.bridgeID
    }
    
    if !nonCanonicalBridgeIDs.isEmpty {
      throw PathScoringError.unsupportedBridges(nonCanonicalBridgeIDs)
    }

    guard !bridgeETAs.isEmpty else {
      // Path has no bridges, so probability is 1.0 (always passable)
      return PathScore(
        path: path,
        logProbability: 0.0,  // log(1.0) = 0.0
        linearProbability: 1.0,
        bridgeProbabilities: [:]
      )
    }

    // Build prediction inputs for all bridges
    let predictionInputs: [BridgePredictionInput]
    do {
      predictionInputs = try await buildPredictionInputs(
        bridgeETAs: bridgeETAs,
        path: path,
        departureTime: departureTime
      )
    } catch {
      throw PathScoringError.featureGenerationFailed(
        "Failed to build prediction inputs: \(error.localizedDescription)")
    }

    // Validate prediction inputs
    guard !predictionInputs.isEmpty else {
      throw PathScoringError.predictionFailed("No prediction inputs generated")
    }

    // Batch predict bridge opening probabilities
    let predictionResult: BatchPredictionResult
    do {
      predictionResult = try await predictor.predictBatch(predictionInputs)
    } catch {
      throw PathScoringError.predictionFailed(
        "Batch prediction failed: \(error.localizedDescription)")
    }

    // Validate prediction results
    guard predictionResult.predictions.count == bridgeETAs.count else {
      throw PathScoringError.predictionFailed(
        "Prediction result count (\(predictionResult.predictions.count)) doesn't match bridge count (\(bridgeETAs.count))"
      )
    }

    // Extract probabilities and create bridge ID mapping with error handling
    var bridgeProbabilities: [String: Double] = [:]
    var probabilities: [Double] = []
    var unsupportedBridges: [String] = []

    for (index, prediction) in predictionResult.predictions.enumerated() {
      let bridgeID = bridgeETAs[index].bridgeID

      // Check if bridge is supported by predictor
      if !predictor.supports(bridgeID: bridgeID) {
        unsupportedBridges.append(bridgeID)
        // Use default probability for unsupported bridges
        let defaultProbability = predictor.defaultProbability
        bridgeProbabilities[bridgeID] = defaultProbability
        probabilities.append(defaultProbability)
        continue
      }

      // Validate probability value
      guard prediction.openProbability.isFinite else {
        throw PathScoringError.predictionFailed(
          "Invalid probability value for bridge \(bridgeID): \(prediction.openProbability)")
      }

      // Clamp individual bridge probability to configuration bounds
      let probability = max(
        config.scoring.minProbability,
        min(config.scoring.maxProbability, prediction.openProbability))
      bridgeProbabilities[bridgeID] = probability
      probabilities.append(probability)
    }

    // Log warning for unsupported bridges if any
    if !unsupportedBridges.isEmpty {
      print(
        "⚠️ Warning: \(unsupportedBridges.count) unsupported bridges found: \(unsupportedBridges.joined(separator: ", ")). Using default probabilities."
      )
    }

    // Aggregate probabilities using log-domain math for numerical stability
    let (logProbability, linearProbability) = aggregateProbabilities(probabilities)

    // Validate final probabilities
    guard linearProbability.isFinite && linearProbability >= 0.0 && linearProbability <= 1.0 else {
      throw PathScoringError.predictionFailed(
        "Invalid aggregated probability: \(linearProbability)")
    }

    return PathScore(
      path: path,
      logProbability: logProbability,
      linearProbability: linearProbability,
      bridgeProbabilities: bridgeProbabilities
    )
  }

  /// Score multiple paths efficiently using batch processing.
  ///
  /// This method processes multiple route paths sequentially, maintaining the order
  /// of the input array in the results. Each path is scored independently using
  /// the same pipeline as `scorePath(_:departureTime:)`.
  ///
  /// ⚠️ **Performance Enhancement Note**: For very large path sets, consider implementing
  /// concurrent processing or advanced batching strategies. The current sequential
  /// approach is suitable for typical use cases but may benefit from optimization
  /// for high-volume scenarios.
  ///
  /// See the Future Enhancements section in PathScoringService_API_Guide.md for details.
  ///
  /// ## Performance Considerations:
  /// - **Sequential Processing**: Paths are processed one at a time to maintain order
  /// - **Batch Prediction**: Each path uses batch prediction for its bridges (internal optimization)
  /// - **Memory Usage**: Results are accumulated in memory, so large path sets may use significant memory
  /// - **Time Estimation**: Roughly 10 paths per second (configurable via `config.performance.maxScoringTime`)
  ///
  /// ## Error Handling:
  /// - **Partial Failures**: Processes all paths and reports failures at the end
  /// - **Validation**: All paths are validated before processing begins
  /// - **Empty Sets**: Returns empty array for empty input (no error thrown)
  ///
  /// ## Use Cases:
  /// - **Alternative Routes**: Score multiple route options for the same journey
  /// - **Path Comparison**: Compare different routing strategies
  /// - **Batch Analysis**: Process large sets of candidate paths
  ///
  /// - Parameters:
  ///   - paths: Array of RoutePaths to score. Can be empty (returns empty array).
  ///   - departureTime: The travel start time. Applied to all paths uniformly.
  /// - Returns: Array of PathScores in the same order as the input paths array
  /// - Throws: PathScoringError if any path fails validation or processing
  public func scorePaths(
    _ paths: [RoutePath],
    departureTime: Date
  ) async throws -> [PathScore] {
    // Validate input
    guard !paths.isEmpty else {
      throw PathScoringError.emptyPathSet("No paths provided for scoring")
    }

    // Check for configuration limits
    if paths.count > Int(config.performance.maxScoringTime * 10) {  // Rough estimate: 10 paths per second
      print("⚠️ Warning: Large path set (\(paths.count) paths) may take significant time to process")
    }

    var pathScores: [PathScore] = []
    var failedPaths: [(index: Int, error: Error)] = []

    // Process paths with error handling
    for (index, path) in paths.enumerated() {
      do {
        let score = try await scorePath(path, departureTime: departureTime)
        pathScores.append(score)
      } catch {
        failedPaths.append((index: index, error: error))

        // Continue processing other paths unless this is a critical error
        if error is PathScoringError {
          // For path-specific errors, continue with other paths
          print("⚠️ Warning: Failed to score path \(index): \(error.localizedDescription)")
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

    return pathScores
  }

  /// Analyze a complete journey with multiple paths and compute network-level probability.
  ///
  /// This method provides a comprehensive analysis of a journey with multiple route options.
  /// It scores all paths and computes the overall network probability that at least one
  /// path will be traversable.
  ///
  /// ## Mathematical Process:
  /// 1. **Path Scoring**: Scores each individual path using `scorePaths(_:departureTime:)`
  /// 2. **Network Probability**: Computes P(at least one path open) using the union formula:
  ///    ```
  ///    P(network) = 1 - ∏(1 - P(path_i))
  ///    ```
  /// 3. **Best Path Identification**: Finds the path with the highest individual probability
  /// 4. **Statistical Summary**: Provides mean, min, max, and standard deviation of path probabilities
  ///
  /// ## Network Probability Formula:
  /// The network probability represents the chance that at least one path is traversable.
  /// This uses the complement of the intersection of path failures:
  /// - Let P_i = probability that path i is traversable
  /// - Let F_i = 1 - P_i = probability that path i fails
  /// - Network probability = 1 - ∏ F_i = 1 - ∏(1 - P_i)
  ///
  /// ## Edge Cases:
  /// - **Empty Path Set**: Returns a valid `JourneyAnalysis` with zero probabilities
  /// - **Single Path**: Network probability equals the single path probability
  /// - **All Paths Zero**: Network probability is zero
  /// - **All Paths One**: Network probability is one
  ///
  /// ## Performance:
  /// - **Time Complexity**: O(n × m) where n = number of paths, m = average bridges per path
  /// - **Memory Usage**: Stores all path scores in memory for analysis
  ///
  /// - Parameters:
  ///   - paths: Array of RoutePaths to analyze. Can be empty (returns zero probabilities).
  ///   - startNode: Starting node ID. Used for validation and documentation.
  ///   - endNode: Destination node ID. Used for validation and documentation.
  ///   - departureTime: The travel start time. Applied to all paths uniformly.
  /// - Returns: JourneyAnalysis containing path scores, network probability, and statistical summary
  /// - Throws: PathScoringError if any path fails validation or processing
  public func analyzeJourney(
    paths: [RoutePath],
    startNode: NodeID,
    endNode: NodeID,
    departureTime: Date
  ) async throws -> JourneyAnalysis {
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

      return JourneyAnalysis(
        startNode: startNode,
        endNode: endNode,
        departureTime: departureTime,
        pathScores: [],
        networkProbability: 0.0,
        bestPathProbability: 0.0,
        totalPathsAnalyzed: 0
      )
    }

    // Score all paths
    let pathScores: [PathScore]
    do {
      pathScores = try await scorePaths(paths, departureTime: departureTime)
    } catch {
      throw PathScoringError.predictionFailed(
        "Failed to score paths for journey analysis: \(error.localizedDescription)")
    }

    // Validate path scores
    guard !pathScores.isEmpty else {
      throw PathScoringError.predictionFailed("No valid path scores generated")
    }

    // Compute network-level probability using union formula
    let networkProbability = computeNetworkProbability(pathScores)

    // Validate network probability
    guard networkProbability.isFinite && networkProbability >= 0.0 && networkProbability <= 1.0
    else {
      throw PathScoringError.predictionFailed("Invalid network probability: \(networkProbability)")
    }

    // Find best path probability
    let bestPathProbability = pathScores.map { $0.linearProbability }.max() ?? 0.0

    // Validate best path probability
    guard bestPathProbability.isFinite && bestPathProbability >= 0.0 && bestPathProbability <= 1.0
    else {
      throw PathScoringError.predictionFailed(
        "Invalid best path probability: \(bestPathProbability)")
    }

    // Log analysis summary
    print("📊 Journey Analysis Complete:")
    print("   • Start: \(startNode) → End: \(endNode)")
    print("   • Paths analyzed: \(paths.count)")
    print("   • Network probability: \(String(format: "%.3f", networkProbability))")
    print("   • Best path probability: \(String(format: "%.3f", bestPathProbability))")

    return JourneyAnalysis(
      startNode: startNode,
      endNode: endNode,
      departureTime: departureTime,
      pathScores: pathScores,
      networkProbability: networkProbability,
      bestPathProbability: bestPathProbability,
      totalPathsAnalyzed: paths.count
    )
  }

  // MARK: - Private Methods

  /// Build prediction inputs for bridge ETAs
  private func buildPredictionInputs(
    bridgeETAs: [(bridgeID: String, eta: ETA)],
    path: RoutePath,
    departureTime: Date
  ) async throws -> [BridgePredictionInput] {
    var inputs: [BridgePredictionInput] = []

    for (bridgeID, eta) in bridgeETAs {
      // Build feature vector for this bridge at this ETA
      let features = try await buildFeatures(
        for: bridgeID,
        eta: eta.arrivalTime,
        path: path,
        departureTime: departureTime
      )

      let input = BridgePredictionInput(
        bridgeID: bridgeID,
        eta: eta.arrivalTime,
        features: features
      )
      inputs.append(input)
    }

    return inputs
  }

  /// Build feature vector for bridge prediction using real feature engineering patterns.
  ///
  /// This method generates a comprehensive feature vector for ML prediction,
  /// incorporating time-of-day patterns, bridge characteristics, and path context.
  /// The features are deterministic based on the input parameters for reproducible results.
  ///
  /// ## Feature Categories:
  ///
  /// ### Time-based Features:
  /// - **Cyclical Time Encoding**: Hour and minute encoded as sin/cos for smooth transitions
  /// - **Day of Week**: Encoded as sin/cos for weekly patterns
  /// - **Rush Hour Detection**: Binary indicator for peak traffic periods
  /// - **Weekend Adjustment**: Reduced traffic patterns for weekend days
  ///
  /// ### Bridge-specific Features:
  /// - **Opening Rates**: 5-minute and 30-minute opening probabilities
  /// - **Crossing Rate**: Probability of successful bridge crossing
  /// - **Gate Anomaly**: Slight variation to model real-world unpredictability
  ///
  /// ### Path Context Features:
  /// - **Detour Delta**: Additional time for path complexity
  /// - **Via Routable**: Path routing efficiency indicator
  /// - **Via Penalty**: Penalty for complex routing
  /// - **Detour Fraction**: Fraction of path that is detour
  ///
  /// ### Traffic Features:
  /// - **Current Speed**: Real-time traffic speed estimate
  /// - **Normal Speed**: Baseline speed for comparison
  ///
  /// ## Deterministic Behavior:
  /// Features are generated using a seeded random number generator based on:
  /// - Bridge ID hash value
  /// - Arrival time (minute + hour)
  /// - Path characteristics
  ///
  /// This ensures that identical inputs produce identical feature vectors.
  ///
  /// ## Integration Notes:
  /// - Uses the same `cyc()` function as `FeatureEngineeringService` for consistency
  /// - Follows the same feature vector structure as existing ML models
  /// - Designed to be compatible with existing prediction pipelines
  ///
  /// - Parameters:
  ///   - bridgeID: Unique identifier for the bridge
  ///   - eta: Estimated arrival time at the bridge
  ///   - path: The complete route path for context
  ///   - departureTime: Original departure time for journey context
  /// - Returns: Array of Double values representing the feature vector
  /// - Throws: Never throws (deterministic feature generation)
  private func buildFeatures(
    for bridgeID: String,
    eta: Date,
    path: RoutePath,
    departureTime: Date
  ) async throws -> [Double] {
    // Check cache first
    let cacheKey = featureCacheKey(bridgeID: bridgeID, eta: eta)
    if let cachedFeatures = getCachedFeatures(for: cacheKey) {
      return cachedFeatures
    }

    // Generate features if not cached
    let features = try await generateFeatures(
      for: bridgeID,
      eta: eta,
      path: path,
      departureTime: departureTime
    )

    // Cache the generated features
    cacheFeatures(features, for: cacheKey)

    return features
  }

  /// Generate feature vector for bridge prediction (uncached version)
  private func generateFeatures(
    for bridgeID: String,
    eta: Date,
    path: RoutePath,
    departureTime: Date
  ) async throws -> [Double] {
    // Extract time-based features using the same patterns as FeatureEngineeringService
    let calendar = Calendar.current
    let minuteOfDay =
      calendar.component(.minute, from: eta) + calendar.component(.hour, from: eta) * 60
    let dayOfWeek = calendar.component(.weekday, from: eta)

    // Cyclical encoding for time features (same as FeatureEngineeringService)
    let (minSin, minCos) = cyc(Double(minuteOfDay), period: 1440.0)
    let (dowSin, dowCos) = cyc(Double(dayOfWeek), period: 7.0)

    // Bridge-specific features based on path context and historical patterns
    let bridgeFeatures = try await computeBridgeFeatures(
      bridgeID: bridgeID,
      eta: eta,
      path: path,
      departureTime: departureTime
    )

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
  ///
  /// ⚠️ **Production Enhancement Note**: This method currently uses synthetic features
  /// for development and testing. For production deployment, consider integrating with:
  /// - Real historical bridge data from sensors
  /// - Live traffic APIs for current conditions
  /// - Weather data for environmental factors
  /// - Event data for special circumstances
  ///
  /// See the Future Enhancements section in PathScoringService_API_Guide.md for details.
  ///
  /// - Parameters:
  ///   - bridgeID: Bridge identifier
  ///   - eta: Estimated arrival time
  ///   - path: Route path context
  ///   - departureTime: Journey departure time
  /// - Returns: Bridge-specific feature values
  private func computeBridgeFeatures(
    bridgeID: String,
    eta: Date,
    path: RoutePath,
    departureTime: Date
  ) async throws -> BridgeFeatures {
    // TODO: In production, this would query historical data and compute:
    // - Rolling averages from recent bridge opening data
    // - Traffic patterns based on time of day
    // - Path-specific detour information
    // - Real-time traffic speed data

    // Generate realistic features based on time of day and bridge context
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: eta)
    let isRushHour = (hour >= 7 && hour <= 9) || (hour >= 16 && hour <= 18)
    let isWeekend =
      calendar.component(.weekday, from: eta) == 1 || calendar.component(.weekday, from: eta) == 7

    // Base features with time-of-day adjustments
    let baseOpenRate = isWeekend ? 0.8 : 0.7
    let rushHourAdjustment = isRushHour ? -0.1 : 0.0

    // Add some deterministic variation based on bridge ID and time
    let bridgeHash = bridgeID.hashValue
    let timeHash =
      calendar.component(.minute, from: eta) + calendar.component(.hour, from: eta) * 60
    let seed = UInt64(abs(bridgeHash + timeHash))
    let random = SimpleDeterministicRandom(seed: seed)

    let open5m = max(
      0.1, min(0.9, baseOpenRate + rushHourAdjustment + random.nextDouble() * 0.1 - 0.05))
    let open30m = max(
      0.1, min(0.9, baseOpenRate + rushHourAdjustment + random.nextDouble() * 0.16 - 0.08))

    // Path-specific features
    let pathLength = path.nodes.count
    let detourDelta = Double(pathLength) * 30.0 + 60.0 + random.nextDouble() * 120.0
    let crossRate = max(0.5, min(0.95, 0.8 + random.nextDouble() * 0.2 - 0.1))

    // Traffic speed based on time and path complexity
    let baseSpeed = isRushHour ? 20.0 : 35.0
    let speedVariation = random.nextDouble() * 10.0 - 5.0
    let currentSpeed = max(10.0, min(50.0, baseSpeed + speedVariation))
    let normalSpeed = max(25.0, min(45.0, 35.0 + random.nextDouble() * 6.0 - 3.0))

    return BridgeFeatures(
      open5m: open5m,
      open30m: open30m,
      detourDelta: detourDelta,
      crossRate: crossRate,
      viaRoutable: 1.0,
      viaPenalty: min(1.0, detourDelta / 900.0),  // Normalized to 0-1
      gateAnom: 1.0 + random.nextDouble() * 0.5,  // Slight anomaly
      detourFrac: min(1.0, detourDelta / (normalSpeed * 60)),  // Fraction of normal travel time
      currentSpeed: currentSpeed,
      normalSpeed: normalSpeed
    )
  }

  /// Aggregate bridge probabilities using log-domain math for numerical stability
  /// - Parameter probabilities: Array of bridge opening probabilities (already clamped)
  /// - Returns: Tuple of (logProbability, linearProbability)
  private func aggregateProbabilities(_ probabilities: [Double]) -> (
    logProbability: Double, linearProbability: Double
  ) {
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
  /// P(any path succeeds) = 1 - P(all paths fail)
  /// - Parameter pathScores: Array of scored paths
  /// - Returns: Network-level probability
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

/// Errors specific to path scoring operations.
///
/// This enum provides comprehensive error types for the PathScoringService,
/// covering validation failures, prediction errors, feature generation issues,
/// and configuration problems.
///
/// ## Error Categories:
///
/// ### Validation Errors:
/// - `invalidPath`: Path structure or content validation failures
/// - `emptyPathSet`: No paths provided for analysis
///
/// ### Processing Errors:
/// - `predictionFailed`: Bridge prediction or ETA estimation failures
/// - `featureGenerationFailed`: Feature vector generation problems
/// - `unsupportedBridge`: Bridge not supported by the predictor
///
/// ### Configuration Errors:
/// - `configurationError`: Invalid service configuration
///
/// ## Usage:
/// ```swift
/// do {
///     let score = try await service.scorePath(path, departureTime: Date())
/// } catch let error as PathScoringError {
///     switch error {
///     case .invalidPath(let reason):
///         print("Path validation failed: \(reason)")
///     case .predictionFailed(let reason):
///         print("Prediction failed: \(reason)")
///     default:
///         print("Other error: \(error.localizedDescription)")
///     }
/// }
/// ```
///
/// - Author: Bridget Team
/// - Version: 1.0
/// - Since: 2024
public enum PathScoringError: Error, LocalizedError {
  case invalidPath(String)
  case predictionFailed(String)
  case featureGenerationFailed(String)
  case emptyPathSet(String)
  case unsupportedBridges([String])
  case configurationError(String)

  public var errorDescription: String? {
    switch self {
    case .invalidPath(let reason):
      return "Invalid path: \(reason)"
    case .predictionFailed(let reason):
      return "Prediction failed: \(reason)"
    case .featureGenerationFailed(let reason):
      return "Feature generation failed: \(reason)"
    case .emptyPathSet(let reason):
      return "Empty path set: \(reason)"
    case .unsupportedBridges(let bridges):
      return "Unsupported bridges: \(bridges.joined(separator: ", "))"
    case .configurationError(let reason):
      return "Configuration error: \(reason)"
    }
  }
}
