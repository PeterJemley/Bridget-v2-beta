import Foundation
import Testing

@testable import Bridget

@Suite("Seattle Performance Tests")
struct SeattlePerformanceTests {

  // MARK: - Test Configuration
  private var testHarness: MultiPathTestHarness
  private var performanceMetrics: PerformanceMetrics

  init() {
    self.performanceMetrics = PerformanceMetrics()
    self.testHarness = MultiPathTestHarness()
  }

  // MARK: - Fixture Integrity & Structure

  @Test("Fixture integrity: node/edge/bridge counts and ID policy")
  func fixtureIntegrity() throws {
    let result = testHarness.fixtureGraph.validate()

    // Basic graph integrity
    #expect(result.isValid, "Fixture graph must be valid: \(result.errors)")
    #expect(result.nodeCount == 4, "Expected 4 nodes in Phase 1 fixture, got \(result.nodeCount)")
    #expect(result.edgeCount == 4, "Expected 4 edges in Phase 1 fixture, got \(result.edgeCount)")
    #expect(
      result.bridgeCount == 2, "Expected 2 bridges in Phase 1 fixture, got \(result.bridgeCount)")

    // Temporary diagnostics: print bridge IDs present in the fixture
    let bridgeEdges = testHarness.fixtureGraph.bridgeEdges
    let bridgeIDs = bridgeEdges.map { $0.bridgeID ?? "<nil>" }
    print("Fixture bridge edges and IDs: \(bridgeIDs)")

    // Bridge ID acceptance policy
    for edge in bridgeEdges {
      let id = edge.bridgeID ?? ""
      #expect(
        !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        "Bridge edge missing ID (isBridge == true requires non-empty bridgeID)"
      )
      #expect(
        SeattleDrawbridges.isAcceptedBridgeID(id, allowSynthetic: true),
        "Bridge ID should be accepted by policy (canonical or synthetic): '\(id)'"
      )
    }
  }

  @Test("Golden path comparison: A -> C matches expected paths")
  func goldenPathComparison() throws {
    let fixture = PathEnumerationService.createPhase1TestFixture()
    let found = try testHarness.pathEnumerationService.enumeratePaths(
      from: "A", to: "C", in: testHarness.fixtureGraph)

    let comparison = testHarness.pathEnumerationService.compareWithGoldenPaths(
      found: found, expected: fixture.expectedPaths)
    #expect(comparison.isSuccess, "Golden comparison failed: \(comparison.description)")
  }

  @Test("Shortest path correctness: A -> C")
  func shortestPathCorrectness() throws {
    let shortest = try testHarness.pathEnumerationService.shortestPath(
      from: "A", to: "C", in: testHarness.fixtureGraph)
    #expect(shortest != nil, "Expected a shortest path A->C")
    // In the fixture, A->D->C is 400 + 150 = 550s, A->B->C is 300 + 200 = 500s (from createPhase1TestFixture)
    // Note: In createPhase1TestFixture, expectedPath1 (A->B->C) is 300+200=500s and expectedPath2 (A->D->C) is 400+150=550s.
    #expect(shortest?.totalTravelTime == 500, "Shortest path should be 500s in fixture")
    #expect(shortest?.nodes == ["A", "B", "C"])
  }

  @Test("No-path pairs return empty results / nil shortest")
  func noPathPairs() throws {
    let pairs: [(String, String)] = [
      ("B", "A"),
      ("C", "A"),
      ("C", "B"),
      ("C", "D"),
    ]

    for (start, end) in pairs {
      let paths = try testHarness.pathEnumerationService.enumeratePaths(
        from: start, to: end, in: testHarness.fixtureGraph)
      #expect(paths.isEmpty, "Expected no paths from \(start) to \(end)")
      let shortest = try testHarness.pathEnumerationService.shortestPath(
        from: start, to: end, in: testHarness.fixtureGraph)
      #expect(shortest == nil, "Expected no shortest path from \(start) to \(end)")
    }
  }

  @Test("Algorithm parity: DFS vs Yen's K-shortest (K=2) on A -> C")
  func algorithmParityDFSvsYen() throws {
    // DFS-configured enumeration service
    var dfsConfig = MultiPathConfig.testing
    dfsConfig.pathEnumeration.enumerationMode = .dfs
    dfsConfig.pathEnumeration.kShortestPaths = 2
    // Set permissive bounds to ensure both valid fixture paths are allowed
    dfsConfig.pathEnumeration.maxTimeOverShortest = 1_000
    dfsConfig.pathEnumeration.maxTravelTime = 10_000
    dfsConfig.pathEnumeration.maxDepth = 10
    dfsConfig.pathEnumeration.maxPaths = 10
    let dfsEnum = PathEnumerationService(config: dfsConfig)

    // Yen-configured enumeration service
    var yensConfig = dfsConfig
    yensConfig.pathEnumeration.enumerationMode = .yensKShortest
    let yensEnum = PathEnumerationService(config: yensConfig)

    let dfsPaths = try dfsEnum.enumeratePaths(from: "A", to: "C", in: testHarness.fixtureGraph)
    let yensPaths = try yensEnum.enumeratePaths(from: "A", to: "C", in: testHarness.fixtureGraph)

    // Compare by sets of node sequences to avoid ordering issues
    let dfsSet = Set(dfsPaths.map { $0.nodes })
    let yensSet = Set(yensPaths.map { $0.nodes })

    #expect(
      dfsSet == yensSet, "DFS and Yen's should return the same set of paths for K=2 on the fixture")
  }

  @Test("Pruning behavior: Tight maxTimeOverShortest leaves only the shortest path")
  func pruningWithTightMaxTimeOverShortest() throws {
    // Configure pruning to allow 0s over shortest; only the shortest should pass
    var config = MultiPathConfig.testing
    config.pathEnumeration.enumerationMode = .dfs
    config.pathEnumeration.maxTimeOverShortest = 0
    let prunedEnum = PathEnumerationService(config: config)

    let prunedPaths = try prunedEnum.enumeratePaths(
      from: "A", to: "C", in: testHarness.fixtureGraph)
    #expect(prunedPaths.count == 1, "Expected only the shortest path to remain with tight pruning")
    #expect(prunedPaths.first?.nodes == ["A", "B", "C"])
  }

  // MARK: - Performance Test Cases (existing)

  @Test("Seattle dataset bridge ID list loads and counts match")
  func seattleDatasetLoadingPerformance() throws {
    let start = CFAbsoluteTimeGetCurrent()
    let bridges = SeattleDrawbridges.allBridgeIDs
    let duration = CFAbsoluteTimeGetCurrent() - start

    #expect(bridges.count == SeattleDrawbridges.count)
    #expect(bridges.count > 0)

    performanceMetrics.record("SeattleDatasetLoading", duration: duration)
  }

  @Test("Memory usage baseline when loading Seattle bridge IDs")
  func memoryUsageBaseline() throws {
    let initialMemory = getCurrentMemoryUsage()
    let bridges = SeattleDrawbridges.allBridgeIDs
    #expect(!bridges.isEmpty)

    let memoryAfterLoad = getCurrentMemoryUsage()
    let memoryIncrease = memoryAfterLoad &- initialMemory

    #expect(memoryIncrease < 100 * 1024 * 1024)
    print(
      "Memory usage - Initial: \(initialMemory / 1024 / 1024)MB, After load: \(memoryAfterLoad / 1024 / 1024)MB, Increase: \(memoryIncrease / 1024 / 1024)MB"
    )
  }

  @Test("Origin-destination path enumeration (sync) on Phase 1 fixture graph")
  func originDestinationPathEnumeration() throws {
    let testCases: [(String, String, Int, Int)] = [
      // expected path counts for the fixture
      ("A", "C", 10, 2),
      ("A", "B", 10, 1),
      ("A", "D", 10, 1),
      ("B", "C", 10, 1),
      ("D", "C", 10, 1),
    ]

    for (start, end, maxPaths, expectedCount) in testCases {
      do {
        let paths = try testHarness.pathEnumerationService.enumeratePaths(
          from: start, to: end, in: testHarness.fixtureGraph)
        let clamped = Array(paths.prefix(maxPaths))
        #expect(
          clamped.count == expectedCount,
          "Expected \(expectedCount) paths from \(start) to \(end), got \(clamped.count)")
        #expect(clamped.allSatisfy { $0.isContiguous() })
      } catch {
        Issue.record("Enumeration failed for \(start) -> \(end): \(error)")
        #expect(Bool(false), "Enumeration should not throw")
      }
    }
  }

  @Test("Algorithm comparison (DFS enumeration) on Phase 1 fixture graph")
  func algorithmComparison() throws {
    let origin = "A"
    let destination = "C"
    let kValues = [1, 2]

    for k in kValues {
      do {
        var config = MultiPathConfig.testing
        config.pathEnumeration.maxPaths = k
        config.pathEnumeration.kShortestPaths = k
        config.pathEnumeration.enumerationMode = .dfs
        let enumSvc = PathEnumerationService(config: config)

        let dfsPaths = try enumSvc.enumeratePaths(
          from: origin, to: destination, in: testHarness.fixtureGraph)
        #expect(dfsPaths.count <= k)
        #expect(dfsPaths.allSatisfy { $0.isContiguous() })
      } catch {
        Issue.record("DFS enumeration failed for k=\(k): \(error)")
        #expect(Bool(false), "DFS enumeration should not throw")
      }
    }
  }

  // MARK: - Cache Performance (isolated feature cache)

  @Test("Cache performance (feature cache only): second run faster and hit rate improves")
  func cachePerformance_featureCacheOnly() async throws {
    // Build a path enumeration service WITHOUT its own memoization to isolate feature cache
    let enumConfig = MultiPathConfig(
      pathEnumeration: PathEnumConfig(maxPaths: 10, maxDepth: 10),
      scoring: ScoringConfig(),
      performance: MultiPathPerformanceConfig(enableCaching: false),  // disable path memoization
      prediction: PredictionConfig()
    )
    let enumService = PathEnumerationService(config: enumConfig)

    // Fresh scoring service so its feature cache starts empty
    let mockHistoricalProvider = MockHistoricalBridgeDataProvider()
    let predictor = BaselinePredictor(
      historicalProvider: mockHistoricalProvider,
      config: BaselinePredictorConfig(),
      supportedBridgeIDs: nil
    )
    let etaEstimator = ETAEstimator(config: MultiPathConfig())
    let scoringService = try PathScoringService(
      predictor: predictor,
      etaEstimator: etaEstimator,
      config: MultiPathConfig()
    )

    // Ensure caches are empty
    scoringService.clearCaches()
    let fixedDeparture = fixedTopOfHour()

    // Warm-up enumerate only (do not score) to avoid pre-filling feature cache
    let warmupPaths = try enumService.enumeratePaths(
      from: "A", to: "C", in: testHarness.fixtureGraph)
    #expect(!warmupPaths.isEmpty)

    // Run 1: cold feature cache
    let t1 = CFAbsoluteTimeGetCurrent()
    let paths1 = try enumService.enumeratePaths(from: "A", to: "C", in: testHarness.fixtureGraph)
    let scores1 = try await scoringService.scorePaths(paths1, departureTime: fixedDeparture)
    let run1 = CFAbsoluteTimeGetCurrent() - t1
    #expect(!scores1.isEmpty)

    // Capture stats after run 1
    let (hitsAfter1, missesAfter1, hitRateAfter1) = scoringService.getCacheStatistics()
    print(
      "Feature cache after run1: hits=\(hitsAfter1), misses=\(missesAfter1), hitRate=\(hitRateAfter1)"
    )

    // Run 2: hot feature cache
    let t2 = CFAbsoluteTimeGetCurrent()
    let paths2 = try enumService.enumeratePaths(from: "A", to: "C", in: testHarness.fixtureGraph)
    let scores2 = try await scoringService.scorePaths(paths2, departureTime: fixedDeparture)
    let run2 = CFAbsoluteTimeGetCurrent() - t2
    #expect(!scores2.isEmpty)
    #expect(paths1.count == paths2.count)
    #expect(scores1.count == scores2.count)

    // Stats should improve (hits increase, hitRate increases)
    let (hitsAfter2, missesAfter2, hitRateAfter2) = scoringService.getCacheStatistics()
    print(
      "Feature cache after run2: hits=\(hitsAfter2), misses=\(missesAfter2), hitRate=\(hitRateAfter2)"
    )

    #expect(hitsAfter2 >= hitsAfter1, "Hits should not decrease")
    #expect(missesAfter2 >= missesAfter1, "Misses are cumulative counters; should not decrease")
    #expect(hitRateAfter2 >= hitRateAfter1, "Hit rate should improve on the second run")

    // Timing with tolerance (small workloads are noisy). Allow 20% margin.
    let tolerance = run1 * 0.2
    #expect(
      run2 <= run1 + tolerance,
      "Expected second run to be faster or within 20% tolerance. run1=\(run1*1000)ms, run2=\(run2*1000)ms"
    )
  }

  // MARK: - Cache Performance (isolated path memoization)

  @Test("Cache performance (path memoization only): hot enumeratePaths faster")
  func cachePerformance_pathMemoizationOnly() throws {
    // Build enumeration with memoization enabled and skip scoring
    let enumConfig = MultiPathConfig(
      pathEnumeration: PathEnumConfig(maxPaths: 10, maxDepth: 10),
      scoring: ScoringConfig(),
      performance: MultiPathPerformanceConfig(enableCaching: true),  // enable path memoization
      prediction: PredictionConfig()
    )
    let enumService = PathEnumerationService(config: enumConfig)

    // Ensure first timed run is a cold miss: do NOT enumerate during warm-up
    // Optional: call a different OD to warm up unrelated work without filling the target key
    _ = try? enumService.enumeratePaths(from: "A", to: "B", in: testHarness.fixtureGraph)

    // Run 1: cold for A->C
    let t1 = CFAbsoluteTimeGetCurrent()
    let paths1 = try enumService.enumeratePaths(from: "A", to: "C", in: testHarness.fixtureGraph)
    let run1 = CFAbsoluteTimeGetCurrent() - t1
    #expect(!paths1.isEmpty)

    // Run 2: hot for A->C
    let t2 = CFAbsoluteTimeGetCurrent()
    let paths2 = try enumService.enumeratePaths(from: "A", to: "C", in: testHarness.fixtureGraph)
    let run2 = CFAbsoluteTimeGetCurrent() - t2
    #expect(paths1.count == paths2.count)

    // Timing with tolerance (20%)
    let tolerance = run1 * 0.2
    #expect(
      run2 <= run1 + tolerance,
      "Expected enumeratePaths second run to be faster or within 20% tolerance. run1=\(run1*1000)ms, run2=\(run2*1000)ms"
    )
  }

  @Test("Memory stability across repeated enumeration + scoring (Phase 1 fixture)")
  func memoryStability() async throws {
    let fixedDeparture = fixedTopOfHour()

    // Warm-up loop to stabilize memory before measuring
    for _ in 0..<3 {
      let warmupPaths = try testHarness.pathEnumerationService.enumeratePaths(
        from: "A", to: "C", in: testHarness.fixtureGraph)
      let _ = try await testHarness.scorePaths(warmupPaths, departureTime: fixedDeparture)
    }

    let initialMemory = getCurrentMemoryUsage()
    var memoryReadings: [UInt64] = [initialMemory]

    // Measure over multiple iterations and average
    for i in 0..<5 {
      let paths = try testHarness.pathEnumerationService.enumeratePaths(
        from: "A", to: "C", in: testHarness.fixtureGraph)
      let scores = try await testHarness.scorePaths(paths, departureTime: fixedDeparture)
      #expect(!paths.isEmpty && !scores.isEmpty)

      let currentMemory = getCurrentMemoryUsage()
      memoryReadings.append(currentMemory)

      // Use safe subtraction and add tolerance margin (20%)
      let memoryIncrease = currentMemory > initialMemory ? currentMemory - initialMemory : 0
      let tolerance = 200 * 1024 * 1024 * 120 / 100  // 20% tolerance
      #expect(memoryIncrease < tolerance, "Memory increase exceeded 240MB (with 20% tolerance)")
      print("Iteration \(i): Memory usage: \(currentMemory / 1024 / 1024)MB")
    }

    if let finalMemory = memoryReadings.last {
      let totalIncrease = finalMemory > initialMemory ? finalMemory - initialMemory : 0
      let tolerance = 50 * 1024 * 1024 * 120 / 100  // 20% tolerance
      #expect(totalIncrease < tolerance, "Final memory increase exceeded 60MB (with 20% tolerance)")
    } else {
      #expect(Bool(false), "Missing final memory reading")
    }
  }

  @Test("End-to-end pipeline: enumeration then scoring on Phase 1 fixture")
  func endToEndPipelinePerformance() async throws {
    let testScenarios: [(String, String, Int)] = [
      ("A", "C", 2),
      ("A", "B", 1),
      ("A", "D", 1),
    ]

    let fixedDeparture = fixedTopOfHour()

    for (start, end, maxPaths) in testScenarios {
      do {
        let paths = try testHarness.pathEnumerationService.enumeratePaths(
          from: start, to: end, in: testHarness.fixtureGraph)
        let clamped = Array(paths.prefix(maxPaths))
        #expect(clamped.count > 0)
        #expect(clamped.count <= maxPaths)

        let startTime = CFAbsoluteTimeGetCurrent()
        let scores = try await testHarness.scorePaths(clamped, departureTime: fixedDeparture)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        #expect(scores.count == clamped.count)

        performanceMetrics.record("EndToEnd(\(start)->\(end))", duration: duration)
      } catch {
        Issue.record("Pipeline failed for \(start) to \(end): \(error)")
        #expect(Bool(false), "End-to-end pipeline should not throw")
      }
    }
  }
}

// MARK: - Test Harness

private struct MultiPathTestHarness {
  let pathScoringService: PathScoringService
  let pathEnumerationService: PathEnumerationService
  let config: MultiPathConfig

  // Expose the Phase 1 fixture graph for tests that need direct access
  let fixtureGraph: Graph

  init() {
    // Use the project’s MockHistoricalBridgeDataProvider
    let mockHistoricalProvider = MockHistoricalBridgeDataProvider()
    let predictor = BaselinePredictor(
      historicalProvider: mockHistoricalProvider,
      config: BaselinePredictorConfig(),
      supportedBridgeIDs: nil
    )
    let etaEstimator = ETAEstimator(config: MultiPathConfig())

    self.config = MultiPathConfig(
      pathEnumeration: PathEnumConfig(maxPaths: 50, maxDepth: 10),
      scoring: ScoringConfig(),
      performance: MultiPathPerformanceConfig(),
      prediction: PredictionConfig()
    )

    self.pathEnumerationService = PathEnumerationService(config: config)
    do {
      self.pathScoringService = try PathScoringService(
        predictor: predictor,
        etaEstimator: etaEstimator,
        config: config
      )
    } catch {
      fatalError("Failed to initialize PathScoringService: \(error)")
    }

    let fixture = PathEnumerationService.createPhase1TestFixture()
    self.fixtureGraph = fixture.graph
  }

  func scorePaths(_ paths: [RoutePath], departureTime: Date) async throws -> [Double] {
    let scores = try await pathScoringService.scorePaths(paths, departureTime: departureTime)
    return scores.map { $0.linearProbability }
  }
}

// MARK: - Performance Metrics

private final class PerformanceMetrics {
  private var measurements: [String: [TimeInterval]] = [:]

  func record(_ operation: String, duration: TimeInterval) {
    if measurements[operation] == nil {
      measurements[operation] = []
    }
    measurements[operation]?.append(duration)
  }

  func summary() -> String {
    var result = "Performance Summary:\n"
    for (operation, times) in measurements {
      let avg = times.reduce(0, +) / Double(times.count)
      let min = times.min() ?? 0
      let max = times.max() ?? 0
      result += "\(operation): avg=\(avg * 1000)ms, min=\(min * 1000)ms, max=\(max * 1000)ms\n"
    }
    return result
  }
}

// MARK: - Memory Helper

private func getCurrentMemoryUsage() -> UInt64 {
  var info = mach_task_basic_info()
  var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

  let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
      task_info(
        mach_task_self_,
        task_flavor_t(MACH_TASK_BASIC_INFO),
        $0,
        &count
      )
    }
  }

  if kerr == KERN_SUCCESS {
    return UInt64(info.resident_size)
  } else {
    return 0
  }
}

// MARK: - Deterministic time helper

private func fixedTopOfHour(reference: Date = Date()) -> Date {
  let cal = Calendar.current
  var comps = cal.dateComponents([.year, .month, .day, .hour], from: reference)
  comps.minute = 0
  comps.second = 0
  comps.nanosecond = 0
  return cal.date(from: comps) ?? reference
}
