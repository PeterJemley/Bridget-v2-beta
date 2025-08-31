//
//  PathScoringServiceTests.swift
//  BridgetTests
//
//  Multi-Path Probability Traffic Prediction System
//  Purpose: Comprehensive tests for PathScoringService integration and log-domain aggregation
//  Integration: Tests ETAEstimator + BridgeOpenPredictor + PathScoringService pipeline
//  Acceptance: Log-domain math, batch processing, edge cases, deterministic results
//  Known Limits: Uses mock predictors and simplified test data
//

import XCTest

@testable import Bridget

@MainActor
final class PathScoringServiceTests: XCTestCase {
  // MARK: - Test Properties

  private var pathScoringService: PathScoringService!
  private var mockPredictor: MockBridgePredictor!
  private var etaEstimator: ETAEstimator!
  private var testConfig: MultiPathConfig!
  private var testGraph: Graph!

  // MARK: - Test Setup

  override func setUp() async throws {
    try await super.setUp()

    // Create test configuration
    testConfig = MultiPathConfig(pathEnumeration: PathEnumConfig(maxPaths: 10,
                                                                 maxDepth: 5,
                                                                 maxTravelTime: 1800,  // 30 minutes
                                                                 allowCycles: false,
                                                                 maxTimeOverShortest: 1.5),
                                 scoring: ScoringConfig(minProbability: 0.05,
                                                        maxProbability: 0.99,
                                                        useLogDomain: true,
                                                        bridgeWeight: 1.0,
                                                        timeWeight: 1.0),
                                 performance: MultiPathPerformanceConfig(maxEnumerationTime: 5.0,
                                                                         maxScoringTime: 5.0,
                                                                         enableCaching: false,
                                                                         cacheExpirationTime: 300.0),
                                 prediction: PredictionConfig(defaultBridgeProbability: 0.8,
                                                              useBatchPrediction: true,
                                                              batchSize: 10,
                                                              enablePredictionCache: false,
                                                              predictionCacheExpiration: 2.0,
                                                              mockPredictorSeed: 12345))

    // Create test graph with bridges
    let nodes = [
      Node(id: "A",
           name: "Start",
           coordinates: (latitude: 47.6062, longitude: -122.3321)),
      Node(id: "B",
           name: "Bridge1",
           coordinates: (latitude: 47.6063, longitude: -122.3322)),
      Node(id: "C",
           name: "Bridge2",
           coordinates: (latitude: 47.6064, longitude: -122.3323)),
      Node(id: "D",
           name: "End",
           coordinates: (latitude: 47.6065, longitude: -122.3324)),
    ]

    let edges = [
      Edge(from: "A",
           to: "B",
           travelTime: 300,
           distance: 1000,
           isBridge: false),
      Edge(from: "B",
           to: "C",
           travelTime: 600,
           distance: 2000,
           isBridge: true,
           bridgeID: "bridge1"),
      Edge(from: "C",
           to: "D",
           travelTime: 300,
           distance: 1000,
           isBridge: true,
           bridgeID: "bridge2"),
    ]

    testGraph = try Graph(nodes: nodes, edges: edges)

    // Create mock predictor with deterministic seed
    mockPredictor = MockBridgePredictor(seed: 12345)

    // Create ETA estimator
    etaEstimator = ETAEstimator(config: testConfig)

    // Create path scoring service
    pathScoringService = try PathScoringService(predictor: mockPredictor,
                                                etaEstimator: etaEstimator,
                                                config: testConfig)
  }

  override func tearDown() async throws {
    pathScoringService = nil
    mockPredictor = nil
    etaEstimator = nil
    testConfig = nil
    testGraph = nil
    try await super.tearDown()
  }

  // MARK: - Single Path Tests

  func testScoreSinglePathOneBridge() async throws {
    // Given: A path with one bridge
    let path = RoutePath(nodes: ["A", "B", "C"],
                         edges: [
                           Edge(from: "A",
                                to: "B",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: false),
                           Edge(from: "B",
                                to: "C",
                                travelTime: 600,
                                distance: 2000,
                                isBridge: true,
                                bridgeID: "bridge1"),
                         ])
    let departureTime = Date()

    // When: Score the path
    let score = try await pathScoringService.scorePath(path,
                                                       departureTime: departureTime)

    // Then: Verify basic properties
    XCTAssertEqual(score.path, path)
    XCTAssertGreaterThan(score.linearProbability, 0.0)
    XCTAssertLessThanOrEqual(score.linearProbability, 1.0)
    XCTAssertEqual(score.bridgeProbabilities.count, 1)
    XCTAssertTrue(score.bridgeProbabilities.keys.contains("bridge1"))

    // Verify log-domain math: log probability should be negative (since probability < 1)
    XCTAssertLessThan(score.logProbability, 0.0)
  }

  func testScoreSinglePathMultipleBridges() async throws {
    // Given: A path with two bridges
    let path = RoutePath(nodes: ["A", "B", "C", "D"],
                         edges: [
                           Edge(from: "A",
                                to: "B",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: false),
                           Edge(from: "B",
                                to: "C",
                                travelTime: 600,
                                distance: 2000,
                                isBridge: true,
                                bridgeID: "bridge1"),
                           Edge(from: "C",
                                to: "D",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: true,
                                bridgeID: "bridge2"),
                         ])
    let departureTime = Date()

    // When: Score the path
    let score = try await pathScoringService.scorePath(path,
                                                       departureTime: departureTime)

    // Then: Verify multiple bridge probabilities
    XCTAssertEqual(score.bridgeProbabilities.count, 2)
    XCTAssertTrue(score.bridgeProbabilities.keys.contains("bridge1"))
    XCTAssertTrue(score.bridgeProbabilities.keys.contains("bridge2"))

    // Verify that path probability is product of individual bridge probabilities (after clamping)
    let expectedProbability = score.bridgeProbabilities.values.reduce(1.0,
                                                                      *)
    XCTAssertEqual(score.linearProbability,
                   expectedProbability,
                   accuracy: 1e-10)
  }

  func testScorePathNoBridges() async throws {
    // Given: A path with no bridges
    let path = RoutePath(nodes: ["A", "B"],
                         edges: [
                           Edge(from: "A",
                                to: "B",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: false),
                         ])
    let departureTime = Date()

    // When: Score the path
    let score = try await pathScoringService.scorePath(path,
                                                       departureTime: departureTime)

    // Then: Should have probability 1.0 (always passable)
    XCTAssertEqual(score.linearProbability, 1.0, accuracy: 1e-10)
    XCTAssertEqual(score.logProbability, 0.0, accuracy: 1e-10)  // log(1.0) = 0.0
    XCTAssertTrue(score.bridgeProbabilities.isEmpty)
  }

  // MARK: - Log-Domain Math Tests

  func testLogDomainAggregationSmallProbabilities() async throws {
    // Given: A path with very small bridge probabilities
    let path = RoutePath(nodes: ["A", "B", "C", "D"],
                         edges: [
                           Edge(from: "A",
                                to: "B",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: false),
                           Edge(from: "B",
                                to: "C",
                                travelTime: 600,
                                distance: 2000,
                                isBridge: true,
                                bridgeID: "bridge1"),
                           Edge(from: "C",
                                to: "D",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: true,
                                bridgeID: "bridge2"),
                         ])
    let departureTime = Date()

    // Create predictor that returns very small probabilities
    let smallProbPredictor = ConstantMockPredictor(probability: 0.01)
    let smallProbService = try PathScoringService(predictor: smallProbPredictor,
                                                  etaEstimator: etaEstimator,
                                                  config: testConfig)

    // When: Score the path
    let score = try await smallProbService.scorePath(path,
                                                     departureTime: departureTime)

    // Then: Should handle small probabilities without underflow
    XCTAssertGreaterThan(score.linearProbability, 0.0)
    XCTAssertLessThan(score.linearProbability, 0.01)  // Should be product of small probs
    XCTAssertLessThan(score.logProbability, -4.0)  // log(0.01^2) = -9.21
  }

  func testLogDomainAggregationLargeProbabilities() async throws {
    // Given: A path with large bridge probabilities
    let path = RoutePath(nodes: ["A", "B", "C"],
                         edges: [
                           Edge(from: "A",
                                to: "B",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: false),
                           Edge(from: "B",
                                to: "C",
                                travelTime: 600,
                                distance: 2000,
                                isBridge: true,
                                bridgeID: "bridge1"),
                         ])
    let departureTime = Date()

    // Create predictor that returns large probabilities
    let largeProbPredictor = ConstantMockPredictor(probability: 0.95)
    let largeProbService = try PathScoringService(predictor: largeProbPredictor,
                                                  etaEstimator: etaEstimator,
                                                  config: testConfig)

    // When: Score the path
    let score = try await largeProbService.scorePath(path,
                                                     departureTime: departureTime)

    // Then: Should handle large probabilities correctly
    XCTAssertGreaterThan(score.linearProbability, 0.9)
    XCTAssertLessThanOrEqual(score.linearProbability, 1.0)
    XCTAssertGreaterThan(score.logProbability, -0.1)  // log(0.95) ≈ -0.051
  }

  // MARK: - Batch Processing Tests

  func testScoreMultiplePathsBatch() async throws {
    // Given: Multiple paths
    let path1 = RoutePath(nodes: ["A", "B"],
                          edges: [
                            Edge(from: "A",
                                 to: "B",
                                 travelTime: 300,
                                 distance: 1000,
                                 isBridge: false),
                          ])
    let path2 = RoutePath(nodes: ["A", "B", "C"],
                          edges: [
                            Edge(from: "A",
                                 to: "B",
                                 travelTime: 300,
                                 distance: 1000,
                                 isBridge: false),
                            Edge(from: "B",
                                 to: "C",
                                 travelTime: 600,
                                 distance: 2000,
                                 isBridge: true,
                                 bridgeID: "bridge1"),
                          ])
    let paths = [path1, path2]
    let departureTime = Date()

    // When: Score multiple paths
    let scores = try await pathScoringService.scorePaths(paths,
                                                         departureTime: departureTime)

    // Then: Should return scores in same order as input
    XCTAssertEqual(scores.count, 2)
    XCTAssertEqual(scores[0].path, path1)
    XCTAssertEqual(scores[1].path, path2)

    // First path should have probability 1.0 (no bridges)
    XCTAssertEqual(scores[0].linearProbability, 1.0, accuracy: 1e-10)

    // Second path should have probability < 1.0 (has bridge)
    XCTAssertLessThan(scores[1].linearProbability, 1.0)
  }

  // MARK: - Journey Analysis Tests

  func testAnalyzeJourneyMultiplePaths() async throws {
    // Given: Multiple paths for a journey
    let path1 = RoutePath(nodes: ["A", "B"],
                          edges: [
                            Edge(from: "A",
                                 to: "B",
                                 travelTime: 300,
                                 distance: 1000,
                                 isBridge: false),
                          ])
    let path2 = RoutePath(nodes: ["A", "B", "C", "D"],
                          edges: [
                            Edge(from: "A",
                                 to: "B",
                                 travelTime: 300,
                                 distance: 1000,
                                 isBridge: false),
                            Edge(from: "B",
                                 to: "C",
                                 travelTime: 600,
                                 distance: 2000,
                                 isBridge: true,
                                 bridgeID: "bridge1"),
                            Edge(from: "C",
                                 to: "D",
                                 travelTime: 300,
                                 distance: 1000,
                                 isBridge: true,
                                 bridgeID: "bridge2"),
                          ])
    let paths = [path1, path2]
    let departureTime = Date()

    // When: Analyze the journey
    let analysis = try await pathScoringService.analyzeJourney(paths: paths,
                                                               startNode: "A",
                                                               endNode: "D",
                                                               departureTime: departureTime)

    // Then: Verify journey analysis properties
    XCTAssertEqual(analysis.startNode, "A")
    XCTAssertEqual(analysis.endNode, "D")
    XCTAssertEqual(analysis.departureTime, departureTime)
    XCTAssertEqual(analysis.pathScores.count, 2)
    XCTAssertEqual(analysis.totalPathsAnalyzed, 2)

    // Network probability should be >= best path probability
    XCTAssertGreaterThanOrEqual(analysis.networkProbability,
                                analysis.bestPathProbability)

    // Network probability should be <= 1.0
    XCTAssertLessThanOrEqual(analysis.networkProbability, 1.0)

    // Network probability should be >= 0.0
    XCTAssertGreaterThanOrEqual(analysis.networkProbability, 0.0)
  }

  func testAnalyzeJourneySinglePath() async throws {
    // Given: Single path for a journey
    let path = RoutePath(nodes: ["A", "B", "C"],
                         edges: [
                           Edge(from: "A",
                                to: "B",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: false),
                           Edge(from: "B",
                                to: "C",
                                travelTime: 600,
                                distance: 2000,
                                isBridge: true,
                                bridgeID: "bridge1"),
                         ])
    let paths = [path]
    let departureTime = Date()

    // When: Analyze the journey
    let analysis = try await pathScoringService.analyzeJourney(paths: paths,
                                                               startNode: "A",
                                                               endNode: "C",
                                                               departureTime: departureTime)

    // Then: Network probability should equal path probability for single path
    XCTAssertEqual(analysis.networkProbability,
                   analysis.bestPathProbability,
                   accuracy: 1e-10)
    XCTAssertEqual(analysis.pathScores.count, 1)
    XCTAssertEqual(analysis.totalPathsAnalyzed, 1)
  }

  // MARK: - Edge Case Tests

  func testHandleEmptyPathSet() async throws {
    // Given: Empty path set
    let paths: [RoutePath] = []
    let departureTime = Date()

    // When: Analyze journey with empty paths
    let analysis = try await pathScoringService.analyzeJourney(paths: paths,
                                                               startNode: "A",
                                                               endNode: "D",
                                                               departureTime: departureTime)

    // Then: Should handle gracefully
    XCTAssertEqual(analysis.networkProbability, 0.0)
    XCTAssertEqual(analysis.bestPathProbability, 0.0)
    XCTAssertEqual(analysis.totalPathsAnalyzed, 0)
    XCTAssertTrue(analysis.pathScores.isEmpty)
  }

  func testHandleInvalidPath() async throws {
    // Given: Invalid path (non-contiguous)
    let invalidPath = RoutePath(nodes: ["A", "C"],  // Missing B
                                edges: [
                                  Edge(from: "A",
                                       to: "B",
                                       travelTime: 300,
                                       distance: 1000,
                                       isBridge: false),
                                  Edge(from: "B",
                                       to: "C",
                                       travelTime: 600,
                                       distance: 2000,
                                       isBridge: true,
                                       bridgeID: "bridge1"),
                                ])
    let departureTime = Date()

    // When/Then: Should throw error for invalid path
    do {
      _ = try await pathScoringService.scorePath(invalidPath,
                                                 departureTime: departureTime)
      XCTFail("Expected error for invalid path")
    } catch {
      XCTAssertTrue(error is PathScoringError)
    }
  }

  // MARK: - Deterministic Results Tests

  func testDeterministicResultsWithSeededPredictor() async throws {
    // Given: Same path and seeded predictor
    let path = RoutePath(nodes: ["A", "B", "C"],
                         edges: [
                           Edge(from: "A",
                                to: "B",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: false),
                           Edge(from: "B",
                                to: "C",
                                travelTime: 600,
                                distance: 2000,
                                isBridge: true,
                                bridgeID: "bridge1"),
                         ])
    let departureTime = Date()

    // Create two services with same seed
    let predictor1 = MockBridgePredictor(seed: 12345)
    let predictor2 = MockBridgePredictor(seed: 12345)

    let service1 = try PathScoringService(predictor: predictor1,
                                          etaEstimator: etaEstimator,
                                          config: testConfig)
    let service2 = try PathScoringService(predictor: predictor2,
                                          etaEstimator: etaEstimator,
                                          config: testConfig)

    // When: Score same path with both services
    let score1 = try await service1.scorePath(path,
                                              departureTime: departureTime)
    let score2 = try await service2.scorePath(path,
                                              departureTime: departureTime)

    // Then: Results should be identical
    XCTAssertEqual(score1.linearProbability,
                   score2.linearProbability,
                   accuracy: 1e-10)
    XCTAssertEqual(score1.logProbability,
                   score2.logProbability,
                   accuracy: 1e-10)
    XCTAssertEqual(score1.bridgeProbabilities, score2.bridgeProbabilities)
  }

  // MARK: - Configuration Tests

  func testRespectScoringConfigurationBounds() async throws {
    // Given: Configuration with specific probability bounds
    let configWithBounds = MultiPathConfig(pathEnumeration: testConfig.pathEnumeration,
                                           scoring: ScoringConfig(minProbability: 0.1,
                                                                  maxProbability: 0.9,
                                                                  useLogDomain: true,
                                                                  bridgeWeight: 1.0,
                                                                  timeWeight: 1.0),
                                           performance: testConfig.performance,
                                           prediction: testConfig.prediction)

    let boundedService = try PathScoringService(predictor: mockPredictor,
                                                etaEstimator: etaEstimator,
                                                config: configWithBounds)

    let path = RoutePath(nodes: ["A", "B", "C"],
                         edges: [
                           Edge(from: "A",
                                to: "B",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: false),
                           Edge(from: "B",
                                to: "C",
                                travelTime: 600,
                                distance: 2000,
                                isBridge: true,
                                bridgeID: "bridge1"),
                         ])
    let departureTime = Date()

    // When: Score path with bounded configuration
    let score = try await boundedService.scorePath(path,
                                                   departureTime: departureTime)

    // Then: Bridge probabilities should respect bounds
    for (_, probability) in score.bridgeProbabilities {
      XCTAssertGreaterThanOrEqual(probability, 0.1)
      XCTAssertLessThanOrEqual(probability, 0.9)
    }
  }

  // MARK: - Cache Tests

  func testFeatureCaching() async throws {
    // Given: A path with multiple bridges
    let path = RoutePath(nodes: ["A", "B", "C", "D"],
                         edges: [
                           Edge(from: "A",
                                to: "B",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: false),
                           Edge(from: "B",
                                to: "C",
                                travelTime: 600,
                                distance: 2000,
                                isBridge: true,
                                bridgeID: "bridge1"),
                           Edge(from: "C",
                                to: "D",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: true,
                                bridgeID: "bridge2"),
                         ])
    let departureTime = Date()

    // When: Score the same path twice
    let score1 = try await pathScoringService.scorePath(path,
                                                        departureTime: departureTime)
    let score2 = try await pathScoringService.scorePath(path,
                                                        departureTime: departureTime)

    // Then: Results should be identical (cached features)
    XCTAssertEqual(score1.linearProbability,
                   score2.linearProbability,
                   accuracy: 1e-10)
    XCTAssertEqual(score1.logProbability,
                   score2.logProbability,
                   accuracy: 1e-10)

    // And: Cache statistics should show hits
    let stats = pathScoringService.getCacheStatistics()
    XCTAssertGreaterThan(stats.hits,
                         0,
                         "Cache should have hits for repeated bridge/time combinations")
    XCTAssertGreaterThan(stats.hitRate,
                         0.0,
                         "Cache hit rate should be positive")
  }

  func testCacheStatistics() async throws {
    // Given: Initial cache statistics
    let initialStats = pathScoringService.getCacheStatistics()
    XCTAssertEqual(initialStats.hits, 0)
    XCTAssertEqual(initialStats.misses, 0)
    XCTAssertEqual(initialStats.hitRate, 0.0)

    // When: Score a path (should miss cache)
    let path = RoutePath(nodes: ["A", "B", "C"],
                         edges: [
                           Edge(from: "A",
                                to: "B",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: false),
                           Edge(from: "B",
                                to: "C",
                                travelTime: 600,
                                distance: 2000,
                                isBridge: true,
                                bridgeID: "bridge1"),
                         ])
    let departureTime = Date()

    _ = try await pathScoringService.scorePath(path,
                                               departureTime: departureTime)

    // Then: Should have misses
    let afterFirstScore = pathScoringService.getCacheStatistics()
    XCTAssertGreaterThan(afterFirstScore.misses, 0)
    XCTAssertEqual(afterFirstScore.hits, 0)

    // When: Score same path again (should hit cache)
    _ = try await pathScoringService.scorePath(path,
                                               departureTime: departureTime)

    // Then: Should have hits
    let afterSecondScore = pathScoringService.getCacheStatistics()
    XCTAssertGreaterThan(afterSecondScore.hits, 0)
    XCTAssertGreaterThan(afterSecondScore.hitRate, 0.0)
  }

  func testCacheClear() async throws {
    // Given: A path that will populate cache
    let path = RoutePath(nodes: ["A", "B", "C"],
                         edges: [
                           Edge(from: "A",
                                to: "B",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: false),
                           Edge(from: "B",
                                to: "C",
                                travelTime: 600,
                                distance: 2000,
                                isBridge: true,
                                bridgeID: "bridge1"),
                         ])
    let departureTime = Date()

    // When: Score path to populate cache
    _ = try await pathScoringService.scorePath(path,
                                               departureTime: departureTime)
    let statsBeforeClear = pathScoringService.getCacheStatistics()
    XCTAssertGreaterThan(statsBeforeClear.misses, 0)

    // When: Clear cache
    pathScoringService.clearCaches()

    // Then: Cache should be empty
    let statsAfterClear = pathScoringService.getCacheStatistics()
    XCTAssertEqual(statsAfterClear.hits, 0)
    XCTAssertEqual(statsAfterClear.misses, 0)
    XCTAssertEqual(statsAfterClear.hitRate, 0.0)

    // When: Score same path again after clear
    _ = try await pathScoringService.scorePath(path,
                                               departureTime: departureTime)

    // Then: Should miss cache again
    let statsAfterReScore = pathScoringService.getCacheStatistics()
    XCTAssertGreaterThan(statsAfterReScore.misses, 0)
    XCTAssertEqual(statsAfterReScore.hits, 0)
  }

  func testTimeBucketCaching() async throws {
    // Given: Same bridge at different departure times that result in same ETA bucket
    let path = RoutePath(nodes: ["A", "B", "C"],
                         edges: [
                           Edge(from: "A",
                                to: "B",
                                travelTime: 300,
                                distance: 1000,
                                isBridge: false),
                           Edge(from: "B",
                                to: "C",
                                travelTime: 600,
                                distance: 2000,
                                isBridge: true,
                                bridgeID: "bridge1"),
                         ])

    let calendar = Calendar.current

    // Create departure times that will result in bridge ETAs in the same 5-minute bucket
    // Bridge ETA = departure + 300s (A->B) + 600s (B->C) = departure + 900s = departure + 15min
    // We want ETAs that fall in the same 5-minute bucket

    // Departure 1: 10:00:00 -> Bridge ETA: 10:15:00 (bucket 1230)
    let departure1 = calendar.date(
      from: DateComponents(year: 2024,
                           month: 1,
                           day: 1,
                           hour: 10,
                           minute: 0,
                           second: 0)
    )!

    // Departure 2: 10:00:30 -> Bridge ETA: 10:15:30 (same bucket 1230)
    let departure2 = calendar.date(
      from: DateComponents(year: 2024,
                           month: 1,
                           day: 1,
                           hour: 10,
                           minute: 0,
                           second: 30)
    )!

    // When: Score with departure1 (should miss cache)
    _ = try await pathScoringService.scorePath(path,
                                               departureTime: departure1)
    let statsAfterFirst = pathScoringService.getCacheStatistics()

    // When: Score with departure2 (should hit cache - same ETA bucket)
    _ = try await pathScoringService.scorePath(path,
                                               departureTime: departure2)
    let statsAfterSecond = pathScoringService.getCacheStatistics()

    // Then: Should have cache hits due to same ETA time bucket
    XCTAssertGreaterThan(statsAfterSecond.hits, statsAfterFirst.hits)
  }
}

// MARK: - Test Helpers

/// Mock predictor that always returns the same probability
private class ConstantMockPredictor: BridgeOpenPredictor {
  private let probability: Double

  init(probability: Double) {
    self.probability = probability
  }

  func predict(bridgeID: String, eta: Date, features _: [Double]) async throws
    -> BridgePredictionResult
  {
    return BridgePredictionResult(bridgeID: bridgeID,
                                  eta: eta,
                                  openProbability: probability,
                                  confidence: 0.8)
  }

  func predictBatch(_ inputs: [BridgePredictionInput]) async throws
    -> BatchPredictionResult
  {
    let predictions = inputs.map { input in
      BridgePredictionResult(bridgeID: input.bridgeID,
                             eta: input.eta,
                             openProbability: probability,
                             confidence: 0.8)
    }
    return BatchPredictionResult(predictions: predictions,
                                 processingTime: 0.1,
                                 batchSize: predictions.count)
  }

  var defaultProbability: Double { probability }

  func supports(bridgeID _: String) -> Bool { true }

  var maxBatchSize: Int { 10 }
}
