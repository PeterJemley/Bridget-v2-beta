import Foundation
import OSLog

// MARK: - Scoring Metrics Structure

/// Performance metrics for path scoring operations
public struct ScoringMetrics {
  // MARK: - Timing Metrics

  /// Total time spent scoring paths
  public let totalScoringTime: TimeInterval

  /// Time spent on ETA estimation
  public let etaEstimationTime: TimeInterval

  /// Time spent on bridge prediction
  public let bridgePredictionTime: TimeInterval

  /// Time spent on probability aggregation
  public let aggregationTime: TimeInterval

  /// Time spent on feature generation
  public let featureGenerationTime: TimeInterval

  // MARK: - Throughput Metrics

  /// Number of paths scored
  public let pathsScored: Int

  /// Number of bridges processed
  public let bridgesProcessed: Int

  /// Paths per second throughput
  public let pathsPerSecond: Double

  /// Bridges per second throughput
  public let bridgesPerSecond: Double

  // MARK: - Cache Performance

  /// Feature cache hit rate
  public let featureCacheHitRate: Double

  /// Number of cache hits
  public let cacheHits: Int

  /// Number of cache misses
  public let cacheMisses: Int

  // MARK: - Quality Metrics

  /// Number of paths that failed scoring
  public let failedPaths: Int

  /// Number of bridges using default probabilities
  public let defaultProbabilityBridges: Int

  /// Average path probability
  public let averagePathProbability: Double

  /// Standard deviation of path probabilities
  public let pathProbabilityStdDev: Double

  // MARK: - Memory Metrics

  /// Peak memory usage during scoring
  public let peakMemoryUsage: Int64

  /// Memory usage per path
  public let memoryPerPath: Double

  // MARK: - Initialization

  public init(totalScoringTime: TimeInterval = 0.0,
              etaEstimationTime: TimeInterval = 0.0,
              bridgePredictionTime: TimeInterval = 0.0,
              aggregationTime: TimeInterval = 0.0,
              featureGenerationTime: TimeInterval = 0.0,
              pathsScored: Int = 0,
              bridgesProcessed: Int = 0,
              pathsPerSecond: Double = 0.0,
              bridgesPerSecond: Double = 0.0,
              featureCacheHitRate: Double = 0.0,
              cacheHits: Int = 0,
              cacheMisses: Int = 0,
              failedPaths: Int = 0,
              defaultProbabilityBridges: Int = 0,
              averagePathProbability: Double = 0.0,
              pathProbabilityStdDev: Double = 0.0,
              peakMemoryUsage: Int64 = 0,
              memoryPerPath: Double = 0.0)
  {
    self.totalScoringTime = totalScoringTime
    self.etaEstimationTime = etaEstimationTime
    self.bridgePredictionTime = bridgePredictionTime
    self.aggregationTime = aggregationTime
    self.featureGenerationTime = featureGenerationTime
    self.pathsScored = pathsScored
    self.bridgesProcessed = bridgesProcessed
    self.pathsPerSecond = pathsPerSecond
    self.bridgesPerSecond = bridgesPerSecond
    self.featureCacheHitRate = featureCacheHitRate
    self.cacheHits = cacheHits
    self.cacheMisses = cacheMisses
    self.failedPaths = failedPaths
    self.defaultProbabilityBridges = defaultProbabilityBridges
    self.averagePathProbability = averagePathProbability
    self.pathProbabilityStdDev = pathProbabilityStdDev
    self.peakMemoryUsage = peakMemoryUsage
    self.memoryPerPath = memoryPerPath
  }
}

// MARK: - Metrics Aggregator

/// Aggregates scoring metrics across multiple operations
public final class ScoringMetricsAggregator {
  private let logger = Logger(subsystem: "Bridget",
                              category: "ScoringMetrics")

  // MARK: - Thread Safety

  private let lock = OSAllocatedUnfairLock()

  // MARK: - Aggregated Metrics

  private var totalScoringTime: TimeInterval = 0.0
  private var totalEtaEstimationTime: TimeInterval = 0.0
  private var totalBridgePredictionTime: TimeInterval = 0.0
  private var totalAggregationTime: TimeInterval = 0.0
  private var totalFeatureGenerationTime: TimeInterval = 0.0
  private var totalPathsScored: Int = 0
  private var totalBridgesProcessed: Int = 0
  private var totalCacheHits: Int = 0
  private var totalCacheMisses: Int = 0
  private var totalFailedPaths: Int = 0
  private var totalDefaultProbabilityBridges: Int = 0
  private var pathProbabilities: [Double] = []
  private var peakMemoryUsage: Int64 = 0

  // MARK: - Operation Counters

  private var operationCount: Int = 0

  // MARK: - CSV Export (Debug Only)

  #if DEBUG
    private var csvData: [String] = []
    private let csvHeaders = [
      "timestamp",
      "operation_id",
      "total_scoring_time",
      "eta_estimation_time",
      "bridge_prediction_time",
      "aggregation_time",
      "feature_generation_time",
      "paths_scored",
      "bridges_processed",
      "paths_per_second",
      "bridges_per_second",
      "cache_hit_rate",
      "cache_hits",
      "cache_misses",
      "failed_paths",
      "default_probability_bridges",
      "average_path_probability",
      "path_probability_std_dev",
      "peak_memory_usage",
      "memory_per_path",
    ]
  #endif

  public init() {
    #if DEBUG
      // Initialize CSV with headers
      csvData.append(csvHeaders.joined(separator: ","))
    #endif
  }

  // MARK: - Metrics Recording

  /// Record metrics from a single scoring operation
  public func recordMetrics(_ metrics: ScoringMetrics) {
    lock.withLock {
      operationCount += 1

      // Aggregate timing metrics
      totalScoringTime += metrics.totalScoringTime
      totalEtaEstimationTime += metrics.etaEstimationTime
      totalBridgePredictionTime += metrics.bridgePredictionTime
      totalAggregationTime += metrics.aggregationTime
      totalFeatureGenerationTime += metrics.featureGenerationTime

      // Aggregate throughput metrics
      totalPathsScored += metrics.pathsScored
      totalBridgesProcessed += metrics.bridgesProcessed

      // Aggregate cache metrics
      totalCacheHits += metrics.cacheHits
      totalCacheMisses += metrics.cacheMisses

      // Aggregate quality metrics
      totalFailedPaths += metrics.failedPaths
      totalDefaultProbabilityBridges += metrics.defaultProbabilityBridges

      // Track path probabilities for statistical analysis
      if metrics.averagePathProbability > 0 {
        pathProbabilities.append(metrics.averagePathProbability)
      }

      // Track peak memory usage
      peakMemoryUsage = max(peakMemoryUsage, metrics.peakMemoryUsage)

      #if DEBUG
        // Record CSV data
        let csvRow = [
          ISO8601DateFormatter().string(from: Date()),
          "op_\(operationCount)",
          String(format: "%.6f", metrics.totalScoringTime),
          String(format: "%.6f", metrics.etaEstimationTime),
          String(format: "%.6f", metrics.bridgePredictionTime),
          String(format: "%.6f", metrics.aggregationTime),
          String(format: "%.6f", metrics.featureGenerationTime),
          String(metrics.pathsScored),
          String(metrics.bridgesProcessed),
          String(format: "%.2f", metrics.pathsPerSecond),
          String(format: "%.2f", metrics.bridgesPerSecond),
          String(format: "%.4f", metrics.featureCacheHitRate),
          String(metrics.cacheHits),
          String(metrics.cacheMisses),
          String(metrics.failedPaths),
          String(metrics.defaultProbabilityBridges),
          String(format: "%.6f", metrics.averagePathProbability),
          String(format: "%.6f", metrics.pathProbabilityStdDev),
          String(metrics.peakMemoryUsage),
          String(format: "%.2f", metrics.memoryPerPath),
        ]
        csvData.append(csvRow.joined(separator: ","))
      #endif
    }

    logger.info(
      "📊 Recorded scoring metrics: \(metrics.pathsScored) paths, \(String(format: "%.3f", metrics.totalScoringTime))s"
    )
  }

  // MARK: - Aggregated Metrics Access

  /// Get aggregated metrics across all recorded operations
  public func getAggregatedMetrics() -> ScoringMetrics {
    return lock.withLock {
      let avgScoringTime =
        operationCount > 0
          ? totalScoringTime / Double(operationCount) : 0.0
      let avgEtaEstimationTime =
        operationCount > 0
          ? totalEtaEstimationTime / Double(operationCount) : 0.0
      let avgBridgePredictionTime =
        operationCount > 0
          ? totalBridgePredictionTime / Double(operationCount) : 0.0
      let avgAggregationTime =
        operationCount > 0
          ? totalAggregationTime / Double(operationCount) : 0.0
      let avgFeatureGenerationTime =
        operationCount > 0
          ? totalFeatureGenerationTime / Double(operationCount) : 0.0

      let avgPathsScored =
        operationCount > 0 ? totalPathsScored / operationCount : 0
      let avgBridgesProcessed =
        operationCount > 0 ? totalBridgesProcessed / operationCount : 0

      let totalCacheRequests = totalCacheHits + totalCacheMisses
      let avgCacheHitRate =
        totalCacheRequests > 0
          ? Double(totalCacheHits) / Double(totalCacheRequests) : 0.0

      let avgFailedPaths =
        operationCount > 0 ? totalFailedPaths / operationCount : 0
      let avgDefaultProbabilityBridges =
        operationCount > 0
          ? totalDefaultProbabilityBridges / operationCount : 0

      let avgPathProbability =
        pathProbabilities.isEmpty
          ? 0.0
          : pathProbabilities.reduce(0, +)
          / Double(pathProbabilities.count)
      let pathProbabilityStdDev = calculateStandardDeviation(pathProbabilities,
                                                             mean: avgPathProbability)

      let avgMemoryPerPath =
        totalPathsScored > 0
          ? Double(peakMemoryUsage) / Double(totalPathsScored) : 0.0

      return ScoringMetrics(totalScoringTime: avgScoringTime,
                            etaEstimationTime: avgEtaEstimationTime,
                            bridgePredictionTime: avgBridgePredictionTime,
                            aggregationTime: avgAggregationTime,
                            featureGenerationTime: avgFeatureGenerationTime,
                            pathsScored: avgPathsScored,
                            bridgesProcessed: avgBridgesProcessed,
                            pathsPerSecond: avgScoringTime > 0
                              ? Double(avgPathsScored) / avgScoringTime : 0.0,
                            bridgesPerSecond: avgScoringTime > 0
                              ? Double(avgBridgesProcessed) / avgScoringTime : 0.0,
                            featureCacheHitRate: avgCacheHitRate,
                            cacheHits: totalCacheHits,
                            cacheMisses: totalCacheMisses,
                            failedPaths: avgFailedPaths,
                            defaultProbabilityBridges: avgDefaultProbabilityBridges,
                            averagePathProbability: avgPathProbability,
                            pathProbabilityStdDev: pathProbabilityStdDev,
                            peakMemoryUsage: peakMemoryUsage,
                            memoryPerPath: avgMemoryPerPath)
    }
  }

  // MARK: - CSV Export (Debug Only)

  #if DEBUG
    /// Export metrics to CSV file
    public func exportToCSV(filename: String = "scoring_metrics.csv") throws {
      let csvContent: String = lock.withLock {
        csvData.joined(separator: "\n")
      }

      let documentsPath = try FileManager.default.url(for: .documentDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil,
                                                      create: true)
      let csvURL = documentsPath.appendingPathComponent(filename)

      try csvContent.write(to: csvURL, atomically: true, encoding: .utf8)

      logger.info("📄 Scoring metrics exported to CSV: \(csvURL.path)")
    }
  #endif

  // MARK: - Utility Methods

  private func calculateStandardDeviation(_ values: [Double], mean: Double)
    -> Double
  {
    guard values.count > 1 else { return 0.0 }

    let squaredDifferences = values.map { pow($0 - mean, 2) }
    let variance =
      squaredDifferences.reduce(0, +) / Double(values.count - 1)
    return sqrt(variance)
  }

  /// Reset all aggregated metrics
  public func reset() {
    lock.withLock {
      totalScoringTime = 0.0
      totalEtaEstimationTime = 0.0
      totalBridgePredictionTime = 0.0
      totalAggregationTime = 0.0
      totalFeatureGenerationTime = 0.0
      totalPathsScored = 0
      totalBridgesProcessed = 0
      totalCacheHits = 0
      totalCacheMisses = 0
      totalFailedPaths = 0
      totalDefaultProbabilityBridges = 0
      pathProbabilities.removeAll()
      peakMemoryUsage = 0
      operationCount = 0

      #if DEBUG
        csvData.removeAll()
        csvData.append(csvHeaders.joined(separator: ","))
      #endif
    }

    logger.info("🔄 Scoring metrics aggregator reset")
  }
}

// MARK: - Global Metrics Instance

/// Global scoring metrics aggregator for application-wide metrics collection
public let globalScoringMetrics = ScoringMetricsAggregator()
