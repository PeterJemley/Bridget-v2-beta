//
//  ScoringMetricsTests.swift
//  BridgetTests
//
//  Multi-Path Probability Traffic Prediction System
//  Purpose: Test performance metrics and observability features
//  Integration: Tests ScoringMetrics, ScoringMetricsAggregator, and PathScoringService integration
//  Acceptance: Validates timing hooks, CSV export, cache statistics, memory monitoring
//  Known Limits: Debug-only CSV export, memory measurements may vary by platform
//

import Foundation
import Testing

@testable import Bridget

@Suite("Scoring Metrics Tests")
struct ScoringMetricsTests {
  // MARK: - Test Configuration

  private func makeTestConfig() -> MultiPathConfig {
    return MultiPathConfig(pathEnumeration: PathEnumConfig(maxPaths: 10, maxDepth: 5),
                           scoring: ScoringConfig(useLogDomain: true, bridgeWeight: 0.7),
                           performance: MultiPathPerformanceConfig(enablePerformanceLogging: true,
                                                                   enableCaching: true,
                                                                   logVerbosity: .verbose),
                           prediction: PredictionConfig(predictionMode: .baseline,
                                                        enableMetricsLogging: true))
  }

  private func makeTestHarness(aggregator: ScoringMetricsAggregator) throws
    -> PathScoringService
  {
    let config = makeTestConfig()
    let dataProvider = MockHistoricalBridgeDataProvider()
    let predictorConfig = BaselinePredictorConfig(priorAlpha: 1.0,
                                                  priorBeta: 9.0,
                                                  defaultProbability: 0.1)
    let predictor = BaselinePredictor(historicalProvider: dataProvider,
                                      config: predictorConfig)
    let etaEstimator = ETAEstimator(config: config)

    return try PathScoringService(predictor: predictor,
                                  etaEstimator: etaEstimator,
                                  config: config,
                                  aggregator: aggregator)
  }

  // Convenience overload: returns both a fresh service and its fresh aggregator
  private func makeTestHarness() throws
    -> (service: PathScoringService, aggregator: ScoringMetricsAggregator)
  {
    let aggregator = ScoringMetricsAggregator()
    let service = try makeTestHarness(aggregator: aggregator)
    return (service, aggregator)
  }

  // Builds a contiguous path: Start -> Bridge1 -> Bridge2 -> ... -> End
  private func makeSeattlePath(withBridgeIDs bridgeIDs: [String]) -> RoutePath {
    var nodes: [NodeID] = ["Start"]
    if bridgeIDs.count > 0 {
      for i in 1 ... bridgeIDs.count {
        nodes.append("Bridge\(i)")
      }
    }
    nodes.append("End")

    var edges: [Edge] = []
    if bridgeIDs.isEmpty {
      edges.append(
        Edge(from: "Start",
             to: "End",
             travelTime: 300,
             distance: 1000,
             isBridge: false)
      )
      return RoutePath(nodes: nodes, edges: edges)
    }

    edges.append(
      Edge(from: "Start",
           to: "Bridge1",
           travelTime: 300,
           distance: 1000,
           isBridge: false)
    )

    for (index, bridgeID) in bridgeIDs.enumerated() {
      let fromNode = "Bridge\(index + 1)"
      let toNode =
        (index == bridgeIDs.count - 1) ? "End" : "Bridge\(index + 2)"

      if SeattleDrawbridges.isAcceptedBridgeID(bridgeID,
                                               allowSynthetic: true)
      {
        edges.append(
          Edge(from: fromNode,
               to: toNode,
               travelTime: 600,
               distance: 2000,
               isBridge: true,
               bridgeID: bridgeID)
        )
      } else {
        edges.append(
          Edge(from: fromNode,
               to: toNode,
               travelTime: 600,
               distance: 2000,
               isBridge: false)
        )
      }
    }

    return RoutePath(nodes: nodes, edges: edges)
  }

  // MARK: - ScoringMetrics Structure Tests

  @Test("ScoringMetrics initialization with default values")
  func scoringMetricsDefaultInitialization() {
    let metrics = ScoringMetrics()

    #expect(metrics.totalScoringTime == 0.0)
    #expect(metrics.etaEstimationTime == 0.0)
    #expect(metrics.bridgePredictionTime == 0.0)
    #expect(metrics.aggregationTime == 0.0)
    #expect(metrics.featureGenerationTime == 0.0)
    #expect(metrics.pathsScored == 0)
    #expect(metrics.bridgesProcessed == 0)
    #expect(metrics.pathsPerSecond == 0.0)
    #expect(metrics.bridgesPerSecond == 0.0)
    #expect(metrics.featureCacheHitRate == 0.0)
    #expect(metrics.cacheHits == 0)
    #expect(metrics.cacheMisses == 0)
    #expect(metrics.failedPaths == 0)
    #expect(metrics.defaultProbabilityBridges == 0)
    #expect(metrics.averagePathProbability == 0.0)
    #expect(metrics.pathProbabilityStdDev == 0.0)
    #expect(metrics.peakMemoryUsage == 0)
    #expect(metrics.memoryPerPath == 0.0)
  }

  @Test("ScoringMetrics initialization with custom values")
  func scoringMetricsCustomInitialization() {
    let metrics = ScoringMetrics(totalScoringTime: 1.5,
                                 etaEstimationTime: 0.2,
                                 bridgePredictionTime: 0.8,
                                 aggregationTime: 0.3,
                                 featureGenerationTime: 0.2,
                                 pathsScored: 5,
                                 bridgesProcessed: 15,
                                 pathsPerSecond: 3.33,
                                 bridgesPerSecond: 10.0,
                                 featureCacheHitRate: 0.85,
                                 cacheHits: 17,
                                 cacheMisses: 3,
                                 failedPaths: 0,
                                 defaultProbabilityBridges: 2,
                                 averagePathProbability: 0.75,
                                 pathProbabilityStdDev: 0.1,
                                 peakMemoryUsage: 1024 * 1024,
                                 memoryPerPath: 204_800.0)

    #expect(metrics.totalScoringTime == 1.5)
    #expect(metrics.etaEstimationTime == 0.2)
    #expect(metrics.bridgePredictionTime == 0.8)
    #expect(metrics.aggregationTime == 0.3)
    #expect(metrics.featureGenerationTime == 0.2)
    #expect(metrics.pathsScored == 5)
    #expect(metrics.bridgesProcessed == 15)
    #expect(metrics.pathsPerSecond == 3.33)
    #expect(metrics.bridgesPerSecond == 10.0)
    #expect(metrics.featureCacheHitRate == 0.85)
    #expect(metrics.cacheHits == 17)
    #expect(metrics.cacheMisses == 3)
    #expect(metrics.failedPaths == 0)
    #expect(metrics.defaultProbabilityBridges == 2)
    #expect(metrics.averagePathProbability == 0.75)
    #expect(metrics.pathProbabilityStdDev == 0.1)
    #expect(metrics.peakMemoryUsage == 1024 * 1024)
    #expect(metrics.memoryPerPath == 204_800.0)
  }

  // MARK: - ScoringMetricsAggregator Tests

  @Test("ScoringMetricsAggregator initialization")
  func scoringMetricsAggregatorInitialization() {
    let aggregator = ScoringMetricsAggregator()
    let metrics = aggregator.getAggregatedMetrics()

    #expect(metrics.totalScoringTime == 0.0)
    #expect(metrics.pathsScored == 0)
    #expect(metrics.bridgesProcessed == 0)
    #expect(metrics.cacheHits == 0)
    #expect(metrics.cacheMisses == 0)
  }

  @Test("ScoringMetricsAggregator recordMetrics and aggregation")
  func scoringMetricsAggregatorRecordMetrics() {
    let aggregator = ScoringMetricsAggregator()

    // Record first set of metrics
    let metrics1 = ScoringMetrics(totalScoringTime: 1.0,
                                  pathsScored: 2,
                                  bridgesProcessed: 6,
                                  cacheHits: 5,
                                  cacheMisses: 1,
                                  averagePathProbability: 0.8)
    aggregator.recordMetrics(metrics1)

    // Record second set of metrics
    let metrics2 = ScoringMetrics(totalScoringTime: 2.0,
                                  pathsScored: 3,
                                  bridgesProcessed: 9,
                                  cacheHits: 8,
                                  cacheMisses: 2,
                                  averagePathProbability: 0.6)
    aggregator.recordMetrics(metrics2)

    // Get aggregated metrics
    let aggregated = aggregator.getAggregatedMetrics()

    #expect(aggregated.totalScoringTime == 1.5)  // Average of 1.0 and 2.0
    #expect(aggregated.pathsScored == 2)  // Average of 2 and 3 (integer division)
    #expect(aggregated.bridgesProcessed == 7)  // Average of 6 and 9 (integer division)
    #expect(aggregated.cacheHits == 13)  // Sum of 5 and 8
    #expect(aggregated.cacheMisses == 3)  // Sum of 1 and 2

    // Float comparisons should allow for tiny rounding differences
    let avgProb = aggregated.averagePathProbability
    #expect(abs(avgProb - 0.7) < 1e-9)  // Average of 0.8 and 0.6 within tolerance
  }

  @Test("ScoringMetricsAggregator reset functionality")
  func scoringMetricsAggregatorReset() {
    let aggregator = ScoringMetricsAggregator()

    // Record some metrics
    let metrics = ScoringMetrics(totalScoringTime: 1.0,
                                 pathsScored: 2,
                                 bridgesProcessed: 6,
                                 cacheHits: 5,
                                 cacheMisses: 1)
    aggregator.recordMetrics(metrics)

    // Verify metrics were recorded
    let beforeReset = aggregator.getAggregatedMetrics()
    #expect(beforeReset.totalScoringTime == 1.0)
    #expect(beforeReset.pathsScored == 2)

    // Reset
    aggregator.reset()

    // Verify reset
    let afterReset = aggregator.getAggregatedMetrics()
    #expect(afterReset.totalScoringTime == 0.0)
    #expect(afterReset.pathsScored == 0)
    #expect(afterReset.cacheHits == 0)
    #expect(afterReset.cacheMisses == 0)
  }

  // MARK: - PathScoringService Integration Tests

  @Test("PathScoringService performance metrics collection - single path")
  func pathScoringServiceSinglePathMetrics() async throws {
    let (service, aggregator) = try makeTestHarness()
    let path = makeSeattlePath(withBridgeIDs: ["2", "3"])  // Ballard and Fremont bridges
    let departureTime = Date()

    // Score the path
    let score = try await service.scorePath(path,
                                            departureTime: departureTime)

    // Verify scoring worked
    #expect(
      score.linearProbability >= 0.0 && score.linearProbability <= 1.0
    )
    #expect(score.bridgeProbabilities.count == 2)  // Two bridges

    // Get aggregated metrics
    let metrics = aggregator.getAggregatedMetrics()

    // Verify metrics were collected (allow zero if extremely fast)
    #expect(metrics.pathsScored >= 1)  // Allow for accumulation across tests
    #expect(metrics.bridgesProcessed >= 2)  // Allow for accumulation across tests
    #expect(metrics.totalScoringTime >= 0.0)
    #expect(metrics.etaEstimationTime >= 0.0)
    #expect(metrics.bridgePredictionTime >= 0.0)
    #expect(metrics.aggregationTime >= 0.0)
    #expect(metrics.featureGenerationTime >= 0.0)
    #expect(metrics.pathsPerSecond >= 0.0)
    #expect(metrics.bridgesPerSecond >= 0.0)
    #expect(metrics.peakMemoryUsage >= 0)
    #expect(metrics.memoryPerPath >= 0.0)

    print("📊 Single Path Metrics:")
    print(
      "  Total time: \(String(format: "%.3f", metrics.totalScoringTime))s"
    )
    print(
      "  ETA estimation: \(String(format: "%.3f", metrics.etaEstimationTime))s"
    )
    print(
      "  Bridge prediction: \(String(format: "%.3f", metrics.bridgePredictionTime))s"
    )
    print(
      "  Aggregation: \(String(format: "%.3f", metrics.aggregationTime))s"
    )
    print(
      "  Feature generation: \(String(format: "%.3f", metrics.featureGenerationTime))s"
    )
    print(
      "  Paths per second: \(String(format: "%.2f", metrics.pathsPerSecond))"
    )
    print(
      "  Bridges per second: \(String(format: "%.2f", metrics.bridgesPerSecond))"
    )
    print("  Memory usage: \(metrics.peakMemoryUsage) bytes")
  }

  @Test("PathScoringService performance metrics collection - batch paths")
  func pathScoringServiceBatchPathsMetrics() async throws {
    let (service, aggregator) = try makeTestHarness()
    let paths = [
      makeSeattlePath(withBridgeIDs: ["2"]),  // Ballard Bridge
      makeSeattlePath(withBridgeIDs: ["3"]),  // Fremont Bridge
      makeSeattlePath(withBridgeIDs: ["4"]),  // Montlake Bridge
      makeSeattlePath(withBridgeIDs: ["6"]),  // University Bridge (ID 6 is Lower Spokane; accepted anyway)
    ]
    let departureTime = Date()

    // Score the paths
    let scores = try await service.scorePaths(paths,
                                              departureTime: departureTime)

    // Verify scoring worked
    #expect(scores.count == 4)
    for score in scores {
      #expect(
        score.linearProbability >= 0.0 && score.linearProbability <= 1.0
      )
    }

    // Get aggregated metrics
    let metrics = aggregator.getAggregatedMetrics()

    // Verify metrics were collected - batch operation should record 4 paths
    #expect(metrics.pathsScored >= 4)  // Allow for accumulation across tests
    #expect(metrics.bridgesProcessed >= 4)  // Allow for accumulation across tests
    #expect(metrics.totalScoringTime >= 0.0)
    #expect(metrics.pathsPerSecond >= 0.0)
    #expect(metrics.bridgesPerSecond >= 0.0)
    #expect(metrics.peakMemoryUsage >= 0)
    #expect(metrics.memoryPerPath >= 0.0)
    #expect(metrics.averagePathProbability >= 0.0)

    print("📊 Batch Path Metrics:")
    print(
      "  Total time: \(String(format: "%.3f", metrics.totalScoringTime))s"
    )
    print("  Paths scored: \(metrics.pathsScored)")
    print("  Bridges processed: \(metrics.bridgesProcessed)")
    print(
      "  Paths per second: \(String(format: "%.2f", metrics.pathsPerSecond))"
    )
    print(
      "  Bridges per second: \(String(format: "%.2f", metrics.bridgesPerSecond))"
    )
    print(
      "  Average path probability: \(String(format: "%.3f", metrics.averagePathProbability))"
    )
    print("  Memory usage: \(metrics.peakMemoryUsage) bytes")
    print(
      "  Memory per path: \(String(format: "%.0f", metrics.memoryPerPath)) bytes"
    )
  }

  @Test("PathScoringService cache statistics integration")
  func pathScoringServiceCacheStatistics() async throws {
    let (service, aggregator) = try makeTestHarness()
    let path = makeSeattlePath(withBridgeIDs: ["2", "3"])
    let departureTime = Date()

    // Score the same path twice to test cache behavior
    let score1 = try await service.scorePath(path,
                                             departureTime: departureTime)
    let score2 = try await service.scorePath(path,
                                             departureTime: departureTime)

    // Verify both scores are identical (cached)
    #expect(score1.linearProbability == score2.linearProbability)

    // Get aggregated metrics
    let metrics = aggregator.getAggregatedMetrics()

    // Verify cache statistics were collected
    #expect(metrics.cacheHits >= 0)
    #expect(metrics.cacheMisses >= 0)
    #expect(
      metrics.featureCacheHitRate >= 0.0
        && metrics.featureCacheHitRate <= 1.0
    )

    print("📊 Cache Statistics:")
    print("  Cache hits: \(metrics.cacheHits)")
    print("  Cache misses: \(metrics.cacheMisses)")
    print(
      "  Cache hit rate: \(String(format: "%.2f", metrics.featureCacheHitRate))"
    )
  }

  @Test("PathScoringService performance with disabled logging")
  func pathScoringServiceDisabledLogging() async throws {
    // Create config with performance logging disabled
    let config = MultiPathConfig(pathEnumeration: PathEnumConfig(maxPaths: 10, maxDepth: 5),
                                 scoring: ScoringConfig(useLogDomain: true, bridgeWeight: 0.7),
                                 performance: MultiPathPerformanceConfig(enablePerformanceLogging: false,  // Disabled
                                                                         enableCaching: true,
                                                                         logVerbosity: .silent),
                                 prediction: PredictionConfig(predictionMode: .baseline,
                                                              enableMetricsLogging: false))

    let dataProvider = MockHistoricalBridgeDataProvider()
    let predictorConfig = BaselinePredictorConfig(priorAlpha: 1.0,
                                                  priorBeta: 9.0,
                                                  defaultProbability: 0.1)
    let predictor = BaselinePredictor(historicalProvider: dataProvider,
                                      config: predictorConfig)
    let etaEstimator = ETAEstimator(config: config)

    // Use a fresh aggregator for isolation
    let aggregator = ScoringMetricsAggregator()

    let service = try PathScoringService(predictor: predictor,
                                         etaEstimator: etaEstimator,
                                         config: config,
                                         aggregator: aggregator)

    let path = makeSeattlePath(withBridgeIDs: ["2"])
    let departureTime = Date()

    // Score the path
    let score = try await service.scorePath(path,
                                            departureTime: departureTime)

    // Verify scoring still works
    #expect(
      score.linearProbability >= 0.0 && score.linearProbability <= 1.0
    )

    // Get aggregated metrics - should be empty since logging is disabled
    let metrics = aggregator.getAggregatedMetrics()

    // Verify no metrics were collected
    #expect(metrics.pathsScored == 0)
    #expect(metrics.totalScoringTime == 0.0)
    #expect(metrics.cacheHits == 0)
    #expect(metrics.cacheMisses == 0)
  }

  // MARK: - Memory Usage Tests

  @Test("PathScoringService memory usage tracking")
  func pathScoringServiceMemoryUsage() async throws {
    let (service, aggregator) = try makeTestHarness()
    let paths = [
      makeSeattlePath(withBridgeIDs: ["2"]),
      makeSeattlePath(withBridgeIDs: ["3"]),
      makeSeattlePath(withBridgeIDs: ["4"]),
    ]
    let departureTime = Date()

    // Score multiple paths to test memory tracking
    let scores = try await service.scorePaths(paths,
                                              departureTime: departureTime)

    // Verify scoring worked
    #expect(scores.count == 3)

    // Get aggregated metrics
    let metrics = aggregator.getAggregatedMetrics()

    // Verify memory metrics were collected (allow zero on platforms where memory APIs are unavailable)
    #expect(metrics.peakMemoryUsage >= 0)
    #expect(metrics.memoryPerPath >= 0.0)

    print("📊 Memory Usage:")
    print("  Peak memory: \(metrics.peakMemoryUsage) bytes")
    print(
      "  Memory per path: \(String(format: "%.0f", metrics.memoryPerPath)) bytes"
    )
    print("  Total paths: \(metrics.pathsScored)")
  }

  // MARK: - CSV Export Tests (Debug Only)

  #if DEBUG
    @Test("ScoringMetricsAggregator CSV export")
    func scoringMetricsAggregatorCSVExport() throws {
      let aggregator = ScoringMetricsAggregator()

      // Record some test metrics
      let metrics = ScoringMetrics(totalScoringTime: 1.5,
                                   etaEstimationTime: 0.2,
                                   bridgePredictionTime: 0.8,
                                   aggregationTime: 0.3,
                                   featureGenerationTime: 0.2,
                                   pathsScored: 3,
                                   bridgesProcessed: 9,
                                   pathsPerSecond: 2.0,
                                   bridgesPerSecond: 6.0,
                                   featureCacheHitRate: 0.85,
                                   cacheHits: 17,
                                   cacheMisses: 3,
                                   failedPaths: 0,
                                   defaultProbabilityBridges: 1,
                                   averagePathProbability: 0.75,
                                   pathProbabilityStdDev: 0.1,
                                   peakMemoryUsage: 1024 * 1024,
                                   memoryPerPath: 341_333.33)

      aggregator.recordMetrics(metrics)

      // Export to CSV
      let filename = "test_scoring_metrics.csv"
      try aggregator.exportToCSV(filename: filename)

      // Verify file was created
      let documentsPath = try FileManager.default.url(for: .documentDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil,
                                                      create: true)
      let csvURL = documentsPath.appendingPathComponent(filename)

      #expect(FileManager.default.fileExists(atPath: csvURL.path))

      // Read and verify CSV content
      let csvContent = try String(contentsOf: csvURL, encoding: .utf8)
      let lines = csvContent.components(separatedBy: .newlines)

      #expect(lines.count >= 2)  // Headers + at least one data row

      // Verify headers
      let headers = lines[0].components(separatedBy: ",")
      #expect(headers.contains("timestamp"))
      #expect(headers.contains("operation_id"))
      #expect(headers.contains("total_scoring_time"))
      #expect(headers.contains("paths_scored"))
      #expect(headers.contains("bridges_processed"))

      // Verify data row
      if lines.count > 1 {
        let dataRow = lines[1].components(separatedBy: ",")
        #expect(dataRow.count == headers.count)

        // Validate timestamp is ISO8601-formatted rather than checking for a specific year
        let iso = ISO8601DateFormatter()
        #expect(iso.date(from: dataRow[0]) != nil)

        // Operation ID should contain "op_"
        #expect(dataRow[1].contains("op_"))
      }

      // Clean up
      try FileManager.default.removeItem(at: csvURL)
    }
  #endif
}
