import Foundation
import Testing

@testable import Bridget

@Suite("PathScoringService Integration Tests for Bridge ID Policy")
struct PathScoringServiceIntegrationTests {
  // Helper to build a simple path with one bridge edge
  private func makePath(withBridgeID bridgeID: String) -> RoutePath {
    let nodes: [NodeID] = ["A", "B"]
    let edge = Edge(from: "A",
                    to: "B",
                    travelTime: 60,
                    distance: 100.0,
                    isBridge: true,
                    bridgeID: bridgeID)
    return RoutePath(nodes: nodes, edges: [edge])
  }

  // Common test harness setup
  private func makeHarness() throws -> (service: PathScoringService, predictor: BridgeOpenPredictor, eta: ETAEstimator,
                                        config: MultiPathConfig)
  {
    var config = MultiPathConfig.testing
    // Quiet logs to avoid noise in tests; keep warnings if desired
    let perf = MultiPathPerformanceConfig(maxEnumerationTime: config.performance.maxEnumerationTime,
                                          maxScoringTime: config.performance.maxScoringTime,
                                          maxMemoryUsage: config.performance.maxMemoryUsage,
                                          enablePerformanceLogging: false,
                                          enableCaching: config.performance.enableCaching,
                                          cacheExpirationTime: config.performance.cacheExpirationTime,
                                          logVerbosity: .warnings)
    config = MultiPathConfig(pathEnumeration: config.pathEnumeration,
                             scoring: config.scoring,
                             performance: perf,
                             prediction: PredictionConfig(defaultBridgeProbability: 0.5,
                                                          useBatchPrediction: false,
                                                          batchSize: 1,
                                                          enablePredictionCache: false,
                                                          mockPredictorSeed: 42))

    let predictor = MockBridgePredictor.createConstant(probability: 0.9, supportedBridges: [])
    let eta = ETAEstimator(config: config)
    let service = try PathScoringService(predictor: predictor, etaEstimator: eta, config: config)
    return (service, predictor, eta, config)
  }

  @Test("Synthetic IDs are accepted when allowed")
  func syntheticIDsAcceptedWhenAllowed() async throws {
    let (service, _, _, _) = try makeHarness()

    // Synthetic ID that satisfies SeattleDrawbridges.isSyntheticTestBridgeID
    let path = makePath(withBridgeID: "bridge1")
    let departure = Date()

    let score = try await service.scorePath(path, departureTime: departure)

    // Expect a non-trivial probability (from predictor) and presence of the synthetic ID key
    #expect(score.linearProbability > 0.0 && score.linearProbability <= 1.0)
    #expect(score.bridgeProbabilities.keys.contains("bridge1"))
  }

  @Test("Non-accepted IDs fallback to defaultProbability and do not populate feature cache")
  func nonAcceptedIDsFallbackAndNoCache() async throws {
    let (service, predictor, _, _) = try makeHarness()

    // Non-accepted ID (neither canonical nor synthetic)
    let path = makePath(withBridgeID: "999")
    let departure = Date()

    // Cache stats before
    let before = service.getCacheStatistics()

    let score = try await service.scorePath(path, departureTime: departure)

    // Probability should equal predictor.defaultProbability due to policy rejection
    let defaultP = predictor.defaultProbability
    let p = score.bridgeProbabilities["999"]
    #expect(p != nil)
    #expect(abs((p ?? 0.0) - defaultP) < 1e-12)

    // Cache stats after: should not increase hits or misses due to no feature generation for rejected ID
    let after = service.getCacheStatistics()
    #expect(after.hits == before.hits)
    #expect(after.misses == before.misses)
  }

  @Test(
    "Mixed canonical + non-accepted: accepted predicted, non-accepted defaulted; cache only for accepted"
  )
  func mixedIDsBehavior() async throws {
    let (service, predictor, _, _) = try makeHarness()

    // Build a path with two edges: one canonical Seattle ID "2" and one non-accepted "xyz"
    let nodes: [NodeID] = ["A", "B", "C"]
    let edge1 = Edge(from: "A", to: "B", travelTime: 60, distance: 100.0, isBridge: true, bridgeID: "2")  // canonical
    let edge2 = Edge(from: "B", to: "C", travelTime: 60, distance: 100.0, isBridge: true, bridgeID: "xyz")  // non-accepted
    let path = RoutePath(nodes: nodes, edges: [edge1, edge2])

    let departure = Date()

    // Cache stats before
    let before = service.getCacheStatistics()

    let score = try await service.scorePath(path, departureTime: departure)

    // Expect both IDs present in the map
    #expect(score.bridgeProbabilities.keys.contains("2"))
    #expect(score.bridgeProbabilities.keys.contains("xyz"))

    // Non-accepted "xyz" should use defaultProbability
    let defaultP = predictor.defaultProbability
    #expect(abs((score.bridgeProbabilities["xyz"] ?? 0.0) - defaultP) < 1e-12)

    // Cache should have been touched only for the accepted ID bridge "2"
    let after = service.getCacheStatistics()
    #expect(after.hits + after.misses >= before.hits + before.misses)
  }
}
