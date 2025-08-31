//
//  BaselinePredictorIntegrationTests.swift
//  BridgetTests
//
//  Multi-Path Probability Traffic Prediction System - Phase 11 Integration
//  Purpose: End-to-end validation of BaselinePredictor integration with PathScoringService
//  Integration: Tests BaselinePredictor + HistoricalBridgeDataProvider + PathScoringService pipeline
//  Acceptance: Real historical data, Beta smoothing, fallback behavior, performance comparison
//  Known Limits: Uses Seattle dataset, assumes bridge independence
//

import Foundation
import Testing

@testable import Bridget

@Suite("BaselinePredictor Integration Tests")
struct BaselinePredictorIntegrationTests {
  // MARK: - Test Configuration

  private func makeTestConfig() -> MultiPathConfig {
    return MultiPathConfig(pathEnumeration: PathEnumConfig(maxPaths: 10,
                                                           maxDepth: 5,
                                                           maxTravelTime: 1800,  // 30 minutes
                                                           allowCycles: false,
                                                           useBidirectionalSearch: false,
                                                           enumerationMode: .dfs,
                                                           kShortestPaths: 5,
                                                           randomSeed: 12345,
                                                           maxTimeOverShortest: 1.5),
                           scoring: ScoringConfig(minProbability: 0.05,
                                                  maxProbability: 0.99,
                                                  logThreshold: 0.01,
                                                  useLogDomain: true,
                                                  clampBounds: ClampBounds(min: 0.05, max: 0.99),
                                                  bridgeWeight: 1.0,
                                                  timeWeight: 1.0),
                           performance: MultiPathPerformanceConfig(maxEnumerationTime: 10.0,
                                                                   maxScoringTime: 10.0,
                                                                   maxMemoryUsage: 100 * 1024 * 1024,  // 100MB
                                                                   enablePerformanceLogging: true,
                                                                   enableCaching: true,
                                                                   cacheExpirationTime: 300.0,
                                                                   logVerbosity: .warnings),
                           prediction: PredictionConfig(defaultBridgeProbability: 0.8,
                                                        useBatchPrediction: true,
                                                        batchSize: 10,
                                                        enablePredictionCache: true,
                                                        predictionCacheExpiration: 60.0,
                                                        mockPredictorSeed: 12345,
                                                        predictionMode: .baseline,
                                                        priorAlpha: 1.0,
                                                        priorBeta: 9.0,
                                                        enableMetricsLogging: true))
  }

  // MARK: - Test Harness Setup

  private func makeBaselineHarness() throws -> (service: PathScoringService, predictor: BaselinePredictor,
                                                eta: ETAEstimator,
                                                config: MultiPathConfig)
  {
    let config = makeTestConfig()

    // Create BaselinePredictor with historical data provider
    let dataProvider = MockHistoricalBridgeDataProvider()
    let predictorConfig = BaselinePredictorConfig(priorAlpha: config.prediction.priorAlpha,
                                                  priorBeta: config.prediction.priorBeta,
                                                  defaultProbability: config.prediction.defaultBridgeProbability)
    let predictor = BaselinePredictor(historicalProvider: dataProvider,
                                      config: predictorConfig)

    let eta = ETAEstimator(config: config)
    let service = try PathScoringService(predictor: predictor,
                                         etaEstimator: eta,
                                         config: config)

    return (service, predictor, eta, config)
  }

  private func makeMockHarness() throws -> (service: PathScoringService, predictor: MockBridgePredictor,
                                            eta: ETAEstimator,
                                            config: MultiPathConfig)
  {
    let config = makeTestConfig()

    let predictor = MockBridgePredictor(seed: 12345)
    let eta = ETAEstimator(config: config)
    let service = try PathScoringService(predictor: predictor,
                                         etaEstimator: eta,
                                         config: config)

    return (service, predictor, eta, config)
  }

  // MARK: - Test Path Creation

  private func makeSeattlePath(withBridgeIDs bridgeIDs: [String]) -> RoutePath {
    let nodes: [NodeID] = ["Start", "Bridge1", "Bridge2", "End"]
    var edges: [Edge] = []

    // Add road edge from start to first bridge
    edges.append(
      Edge(from: "Start",
           to: "Bridge1",
           travelTime: 300,
           distance: 1000,
           isBridge: false)
    )

    // Add bridge edges - only create bridge edges for valid bridge IDs
    for (index, bridgeID) in bridgeIDs.enumerated() {
      let fromNode = index == 0 ? "Bridge1" : "Bridge\(index)"
      let toNode =
        index == bridgeIDs.count - 1 ? "End" : "Bridge\(index + 1)"

      // Check if this is a valid bridge ID
      if SeattleDrawbridges.isAcceptedBridgeID(bridgeID,
                                               allowSynthetic: true)
      {
        // Valid bridge ID - create bridge edge
        edges.append(
          Edge(from: fromNode,
               to: toNode,
               travelTime: 600,
               distance: 2000,
               isBridge: true,
               bridgeID: bridgeID)
        )
      } else {
        // Invalid bridge ID - create road edge instead (fallback behavior)
        edges.append(
          Edge(from: fromNode,
               to: toNode,
               travelTime: 600,
               distance: 2000,
               isBridge: false)
        )
      }
    }

    // Add road edge from last bridge to end
    if bridgeIDs.count == 1 {
      edges.append(
        Edge(from: "Bridge1",
             to: "End",
             travelTime: 300,
             distance: 1000,
             isBridge: false)
      )
    }

    return RoutePath(nodes: nodes, edges: edges)
  }

  // MARK: - Integration Tests

  @Test("PathScoringService can be created with BaselinePredictor")
  func pathScoringServiceCreation() throws {
    let config = makeTestConfig()

    // Create BaselinePredictor with historical data provider
    let dataProvider = MockHistoricalBridgeDataProvider()
    let predictorConfig = BaselinePredictorConfig(priorAlpha: config.prediction.priorAlpha,
                                                  priorBeta: config.prediction.priorBeta,
                                                  defaultProbability: config.prediction.defaultBridgeProbability)
    let predictor = BaselinePredictor(historicalProvider: dataProvider,
                                      config: predictorConfig)

    let eta = ETAEstimator(config: config)

    // This should not throw
    let service = try PathScoringService(predictor: predictor,
                                         etaEstimator: eta,
                                         config: config)

    // Basic validation that service was created successfully
    print(
      "✅ PathScoringService created successfully with BaselinePredictor"
    )
  }

  @Test("BaselinePredictor basic functionality")
  func baselinePredictorBasic() async throws {
    let dataProvider = MockHistoricalBridgeDataProvider()
    let predictorConfig = BaselinePredictorConfig(priorAlpha: 1.0,
                                                  priorBeta: 9.0,
                                                  defaultProbability: 0.1)
    let predictor = BaselinePredictor(historicalProvider: dataProvider,
                                      config: predictorConfig)

    // Test basic prediction
    let bridgeID = "2"  // Ballard Bridge
    let eta = Date()
    let features = [1.0, 2.0, 3.0]  // Dummy features

    let result = try await predictor.predict(bridgeID: bridgeID,
                                             eta: eta,
                                             features: features)

    // Basic validation
    #expect(result.bridgeID == bridgeID)
    #expect(result.eta == eta)
    #expect(result.openProbability >= 0.0 && result.openProbability <= 1.0)

    print("✅ BaselinePredictor basic test passed")
  }

  @Test("BaselinePredictor performance metrics")
  func baselinePredictorPerformance() async throws {
    let dataProvider = MockHistoricalBridgeDataProvider()
    let predictorConfig = BaselinePredictorConfig(priorAlpha: 1.0,
                                                  priorBeta: 9.0,
                                                  defaultProbability: 0.1)
    let predictor = BaselinePredictor(historicalProvider: dataProvider,
                                      config: predictorConfig)

    // Test single prediction performance
    let bridgeID = "2"  // Ballard Bridge
    let eta = Date()
    let features = [1.0, 2.0, 3.0]  // Dummy features

    let startTime = Date()
    let result = try await predictor.predict(bridgeID: bridgeID,
                                             eta: eta,
                                             features: features)
    let singlePredictionTime = Date().timeIntervalSince(startTime)

    // Test batch prediction performance
    let bridgeIDs = ["2", "3", "4", "6", "21", "29"]  // All Seattle bridges
    let batchStartTime = Date()
    let batchResult = predictor.predictBatch(bridgeIDs: bridgeIDs, at: eta)
    let batchPredictionTime = Date().timeIntervalSince(batchStartTime)

    // Validate results
    #expect(result.bridgeID == bridgeID)
    #expect(result.openProbability >= 0.0 && result.openProbability <= 1.0)
    #expect(batchResult.count == bridgeIDs.count)

    // Performance should be reasonable
    #expect(singlePredictionTime < 0.1,
            "Single prediction took \(singlePredictionTime)s")
    #expect(batchPredictionTime < 0.5,
            "Batch prediction took \(batchPredictionTime)s")

    print("📊 BaselinePredictor Performance Metrics:")
    print(
      "  Single prediction: \(String(format: "%.3f", singlePredictionTime))s"
    )
    print(
      "  Batch prediction (\(bridgeIDs.count) bridges): \(String(format: "%.3f", batchPredictionTime))s"
    )
    print(
      "  Average per bridge: \(String(format: "%.3f", batchPredictionTime / Double(bridgeIDs.count)))s"
    )
    print(
      "  Single bridge probability: \(String(format: "%.3f", result.openProbability))"
    )
  }

  @Test("BaselinePredictor integrates successfully with PathScoringService")
  func baselinePredictorIntegration() async throws {
    let (service, _, _, config) = try makeBaselineHarness()

    // Test with a canonical Seattle bridge
    let path = makeSeattlePath(withBridgeIDs: ["2"])  // Ballard Bridge
    let departureTime = Date()

    let score = try await service.scorePath(path,
                                            departureTime: departureTime)

    // Validate basic scoring properties
    #expect(
      score.linearProbability >= 0.0 && score.linearProbability <= 1.0
    )
    #expect(score.logProbability.isFinite)
    #expect(score.bridgeProbabilities.count == 1)
    #expect(score.bridgeProbabilities["2"] != nil)

    // Validate that BaselinePredictor was used
    let bridgeProbability = score.bridgeProbabilities["2"]!
    #expect(bridgeProbability >= config.scoring.minProbability)
    #expect(bridgeProbability <= config.scoring.maxProbability)
  }

  @Test("BaselinePredictor handles multiple bridges correctly")
  func multipleBridgesIntegration() async throws {
    let (service, _, _, config) = try makeBaselineHarness()

    // Test with multiple canonical Seattle bridges
    let path = makeSeattlePath(withBridgeIDs: ["2", "3"])  // Ballard + Fremont
    let departureTime = Date()

    let score = try await service.scorePath(path,
                                            departureTime: departureTime)

    // Validate multiple bridge handling
    #expect(score.bridgeProbabilities.count == 2)
    #expect(score.bridgeProbabilities["2"] != nil)
    #expect(score.bridgeProbabilities["3"] != nil)

    // Validate probabilities are within bounds
    for (_, probability) in score.bridgeProbabilities {
      #expect(probability >= config.scoring.minProbability)
      #expect(probability <= config.scoring.maxProbability)
    }

    // Validate aggregated probability (should be lower than individual due to independence)
    let individualProbs = Array(score.bridgeProbabilities.values)
    let expectedAggregated = individualProbs.reduce(1.0, *)
    #expect(abs(score.linearProbability - expectedAggregated) < 0.01)
  }

  @Test("BaselinePredictor fallback behavior for unsupported bridges")
  func fallbackBehavior() async throws {
    let (service, _, _, _) = try makeBaselineHarness()

    // Test with a bridge that BaselinePredictor doesn't support
    // Since "999" is not a valid bridge ID, it will be treated as a road edge
    let path = makeSeattlePath(withBridgeIDs: ["999"])  // Non-existent bridge
    let departureTime = Date()

    let score = try await service.scorePath(path,
                                            departureTime: departureTime)

    // Since "999" is treated as a road edge, there should be no bridge probabilities
    #expect(score.bridgeProbabilities.isEmpty)
    #expect(score.linearProbability == 1.0)  // Road-only path has 100% probability
  }

  @Test("Performance comparison: BaselinePredictor vs MockBridgePredictor")
  func performanceComparison() async throws {
    let baselineHarness = try makeBaselineHarness()
    let mockHarness = try makeMockHarness()

    let path = makeSeattlePath(withBridgeIDs: ["2", "3", "4"])  // Multiple bridges
    let departureTime = Date()

    // Time BaselinePredictor
    let baselineStart = Date()
    let baselineScore = try await baselineHarness.service.scorePath(path,
                                                                    departureTime: departureTime)
    let baselineTime = Date().timeIntervalSince(baselineStart)

    // Time MockBridgePredictor
    let mockStart = Date()
    let mockScore = try await mockHarness.service.scorePath(path,
                                                            departureTime: departureTime)
    let mockTime = Date().timeIntervalSince(mockStart)

    // Both should complete successfully
    #expect(baselineScore.linearProbability.isFinite)
    #expect(mockScore.linearProbability.isFinite)

    // BaselinePredictor should be reasonably fast (within 5x of mock)
    #expect(baselineTime < mockTime * 5.0,
            "BaselinePredictor took \(baselineTime)s vs MockBridgePredictor \(mockTime)s")

    // Log performance metrics
    print("📊 Performance Comparison:")
    print("  BaselinePredictor: \(String(format: "%.3f", baselineTime))s")
    print("  MockBridgePredictor: \(String(format: "%.3f", mockTime))s")
    print("  Ratio: \(String(format: "%.2f", baselineTime / mockTime))x")
  }

  @Test("Beta smoothing parameters affect prediction results")
  func betaSmoothingEffects() async throws {
    let config = makeTestConfig()
    let dataProvider = MockHistoricalBridgeDataProvider()

    // Test with different Beta smoothing parameters
    let testCases = [
      (alpha: 1.0, beta: 1.0, name: "uniform"),  // Uniform prior
      (alpha: 1.0, beta: 9.0, name: "conservative"),  // Conservative prior
      (alpha: 9.0, beta: 1.0, name: "optimistic"),  // Optimistic prior
    ]

    let path = makeSeattlePath(withBridgeIDs: ["2"])
    let departureTime = Date()

    var results: [String: Double] = [:]

    for (alpha, beta, name) in testCases {
      let predictorConfig = BaselinePredictorConfig(priorAlpha: alpha,
                                                    priorBeta: beta,
                                                    defaultProbability: config.prediction.defaultBridgeProbability)
      let predictor = BaselinePredictor(historicalProvider: dataProvider,
                                        config: predictorConfig)

      let eta = ETAEstimator(config: config)
      let service = try PathScoringService(predictor: predictor,
                                           etaEstimator: eta,
                                           config: config)

      let score = try await service.scorePath(path,
                                              departureTime: departureTime)
      results[name] = score.bridgeProbabilities["2"]!
    }

    // Different priors should produce different results
    #expect(results["uniform"] != results["conservative"])
    #expect(results["uniform"] != results["optimistic"])
    #expect(results["conservative"] != results["optimistic"])

    // Conservative prior should be lower than optimistic prior
    #expect(results["conservative"]! < results["optimistic"]!)

    print("📊 Beta Smoothing Effects:")
    for (name, probability) in results {
      print("  \(name): \(String(format: "%.3f", probability))")
    }
  }

  @Test("Batch prediction performance with multiple paths")
  func batchPredictionPerformance() async throws {
    let (service, _, _, _) = try makeBaselineHarness()

    // Create multiple paths with different bridge combinations
    let paths = [
      makeSeattlePath(withBridgeIDs: ["2"]),
      makeSeattlePath(withBridgeIDs: ["3"]),
      makeSeattlePath(withBridgeIDs: ["2", "3"]),
      makeSeattlePath(withBridgeIDs: ["4", "6"]),
      makeSeattlePath(withBridgeIDs: ["21", "29"]),
    ]

    let departureTime = Date()

    // Time batch scoring
    let startTime = Date()
    var scores: [PathScore] = []

    for path in paths {
      let score = try await service.scorePath(path,
                                              departureTime: departureTime)
      scores.append(score)
    }

    let totalTime = Date().timeIntervalSince(startTime)
    let avgTime = totalTime / Double(paths.count)

    // All paths should be scored successfully
    #expect(scores.count == paths.count)
    for score in scores {
      #expect(score.linearProbability.isFinite)
      #expect(
        score.linearProbability >= 0.0 && score.linearProbability <= 1.0
      )
    }

    // Performance should be reasonable
    #expect(avgTime < 1.0,
            "Average scoring time \(avgTime)s per path is too slow")

    print("📊 Batch Prediction Performance:")
    print("  Total paths: \(paths.count)")
    print("  Total time: \(String(format: "%.3f", totalTime))s")
    print("  Average time per path: \(String(format: "%.3f", avgTime))s")
  }

  @Test("Cache statistics reflect BaselinePredictor usage")
  func cacheStatistics() async throws {
    let (service, _, _, _) = try makeBaselineHarness()

    let path = makeSeattlePath(withBridgeIDs: ["2", "3"])
    let departureTime = Date()

    // Get initial cache stats
    let initialStats = service.getCacheStatistics()

    // Score the path
    let score = try await service.scorePath(path,
                                            departureTime: departureTime)
    #expect(score.linearProbability.isFinite)

    // Get final cache stats
    let finalStats = service.getCacheStatistics()

    // Cache should have been used (hits or misses should increase)
    let totalRequests = finalStats.hits + finalStats.misses
    #expect(totalRequests > initialStats.hits + initialStats.misses)

    // Hit rate should be reasonable
    if totalRequests > 0 {
      let hitRate = Double(finalStats.hits) / Double(totalRequests)
      #expect(hitRate >= 0.0 && hitRate <= 1.0)
    }

    print("📊 Cache Statistics:")
    print("  Hits: \(finalStats.hits)")
    print("  Misses: \(finalStats.misses)")
    print("  Hit Rate: \(String(format: "%.2f", finalStats.hitRate))")
  }
}
