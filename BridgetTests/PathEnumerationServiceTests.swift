//
//  PathEnumerationServiceTests.swift
//  BridgetTests
//
//  Multi-Path Probability Traffic Prediction System Tests - Phase 1
//  Purpose: Test path enumeration service with tiny subgraphs and fixtures
//  Integration: Tests PathEnumerationService with deterministic fixtures
//  Acceptance: Golden test paths exist and are contiguous, deterministic results
//  Known Limits: Toy network only; not performance-representative
//

import XCTest

@testable import Bridget

final class PathEnumerationServiceTests: XCTestCase {
  var service: PathEnumerationService!

  override func setUp() {
    super.setUp()
    service = PathEnumerationService(config: .testing)
  }

  override func tearDown() {
    service = nil
    super.tearDown()
  }

  // MARK: - Golden Test Fixtures

  func testPhase1SimpleFixture() throws {
    // Test the basic fixture: A -> B -> C and A -> D -> C
    let (graph, expectedPaths) =
      PathEnumerationService.createPhase1TestFixture()

    // Enumerate paths from A to C
    let foundPaths = try service.enumeratePaths(from: "A",
                                                to: "C",
                                                in: graph)

    // Verify we found exactly 2 paths
    XCTAssertEqual(foundPaths.count, 2, "Should find exactly 2 paths")

    // Verify all paths are valid
    XCTAssertTrue(service.validatePaths(foundPaths),
                  "All paths should be valid")

    // Compare with golden paths
    let comparison = service.compareWithGoldenPaths(found: foundPaths,
                                                    expected: expectedPaths)
    XCTAssertTrue(comparison.isSuccess,
                  "Should match golden paths: \(comparison.description)")

    // Verify paths are sorted by travel time (shortest first)
    XCTAssertLessThan(foundPaths[0].totalTravelTime,
                      foundPaths[1].totalTravelTime)

    // Verify specific paths exist
    let path1Nodes = foundPaths.map { $0.nodes }
    XCTAssertTrue(path1Nodes.contains(["A", "B", "C"]),
                  "Should contain A->B->C path")
    XCTAssertTrue(path1Nodes.contains(["A", "D", "C"]),
                  "Should contain A->D->C path")
  }

  func testPhase1ComplexFixture() throws {
    // Test the complex fixture with multiple paths and cycles
    let (graph, _) = PathEnumerationService.createPhase1ComplexFixture()

    // Enumerate paths from A to D
    let foundPaths = try service.enumeratePaths(from: "A",
                                                to: "D",
                                                in: graph)

    // Verify we found exactly 4 paths
    XCTAssertEqual(foundPaths.count, 4, "Should find exactly 4 paths")

    // Verify all paths are valid
    XCTAssertTrue(service.validatePaths(foundPaths),
                  "All paths should be valid")

    // Verify paths are sorted by travel time (shortest first)
    for i in 0 ..< (foundPaths.count - 1) {
      XCTAssertLessThanOrEqual(foundPaths[i].totalTravelTime,
                               foundPaths[i + 1].totalTravelTime)
    }

    // Verify specific expected paths exist
    let pathNodes = foundPaths.map { $0.nodes }
    XCTAssertTrue(pathNodes.contains(["A", "E", "D"]),
                  "Should contain A->E->D path")
    XCTAssertTrue(pathNodes.contains(["A", "C", "D"]),
                  "Should contain A->C->D path")
    XCTAssertTrue(pathNodes.contains(["A", "B", "D"]),
                  "Should contain A->B->D path")
    XCTAssertTrue(pathNodes.contains(["A", "D"]),
                  "Should contain A->D path")
  }

  // MARK: - Path Validation Tests

  func testPathContiguityValidation() throws {
    let (graph, _) = PathEnumerationService.createPhase1TestFixture()

    let paths = try service.enumeratePaths(from: "A", to: "C", in: graph)

    // All paths should be contiguous
    for path in paths {
      XCTAssertTrue(path.isContiguous(),
                    "Path \(path.nodes) should be contiguous")
    }
  }

  func testPathTravelTimeValidation() throws {
    let (graph, _) = PathEnumerationService.createPhase1TestFixture()

    let paths = try service.enumeratePaths(from: "A", to: "C", in: graph)

    // All paths should have positive travel time
    for path in paths {
      XCTAssertGreaterThan(path.totalTravelTime,
                           0,
                           "Path \(path.nodes) should have positive travel time")
    }
  }

  func testPathDistanceValidation() throws {
    let (graph, _) = PathEnumerationService.createPhase1TestFixture()

    let paths = try service.enumeratePaths(from: "A", to: "C", in: graph)

    // All paths should have positive distance
    for path in paths {
      XCTAssertGreaterThan(path.totalDistance,
                           0,
                           "Path \(path.nodes) should have positive distance")
    }
  }

  // MARK: - Error Handling Tests

  func testNodeNotFoundError() throws {
    let (graph, _) = PathEnumerationService.createPhase1TestFixture()

    // Try to find path from non-existent node
    XCTAssertThrowsError(
      try service.enumeratePaths(from: "Z", to: "C", in: graph)
    ) { error in
      XCTAssertEqual(error as? MultiPathError, .nodeNotFound("Z"))
    }

    // Try to find path to non-existent node
    XCTAssertThrowsError(
      try service.enumeratePaths(from: "A", to: "Z", in: graph)
    ) { error in
      XCTAssertEqual(error as? MultiPathError, .nodeNotFound("Z"))
    }
  }

  func testNoPathExists() throws {
    // Create a disconnected graph
    let nodes = [
      Node(id: "A", name: "Start", coordinates: (0, 0)),
      Node(id: "B", name: "End", coordinates: (1, 1)),
    ]
    let edges: [Edge] = []  // No edges between A and B

    let graph = try Graph(nodes: nodes, edges: edges)

    // Should return empty array (no error, just no paths)
    let paths = try service.enumeratePaths(from: "A", to: "B", in: graph)
    XCTAssertTrue(paths.isEmpty,
                  "Should return empty array when no path exists")
  }

  // MARK: - Configuration Tests

  func testMaxPathsLimit() throws {
    let (graph, _) = PathEnumerationService.createPhase1ComplexFixture()

    // Create service with very low maxPaths limit
    let limitedService = PathEnumerationService(
      config: MultiPathConfig.testing
    )

    let paths = try limitedService.enumeratePaths(from: "A",
                                                  to: "D",
                                                  in: graph)

    // Should respect maxPaths limit
    XCTAssertLessThanOrEqual(paths.count,
                             limitedService.config.pathEnumeration.maxPaths)
  }

  func testMaxDepthLimit() throws {
    // Create a deep graph
    let nodes = (0 ... 10).map { i in
      Node(id: "\(i)",
           name: "Node\(i)",
           coordinates: (Double(i), Double(i)))
    }

    let edges = (0 ..< 10).map { i in
      Edge(from: "\(i)", to: "\(i + 1)", travelTime: 100, distance: 100)
    }

    let graph = try Graph(nodes: nodes, edges: edges)

    // Create service with low maxDepth
    var config = MultiPathConfig.testing
    config.pathEnumeration.maxDepth = 3
    let limitedService = PathEnumerationService(config: config)

    let paths = try limitedService.enumeratePaths(from: "0",
                                                  to: "10",
                                                  in: graph)

    // Should find no paths due to depth limit
    XCTAssertTrue(paths.isEmpty, "Should find no paths due to depth limit")
  }

  func testMaxTravelTimeLimit() throws {
    let (graph, _) = PathEnumerationService.createPhase1ComplexFixture()

    // Create service with very low maxTravelTime
    var config = MultiPathConfig.testing
    config.pathEnumeration.maxTravelTime = 100  // Very low limit
    let limitedService = PathEnumerationService(config: config)

    let paths = try limitedService.enumeratePaths(from: "A",
                                                  to: "D",
                                                  in: graph)

    // All paths should respect travel time limit
    for path in paths {
      XCTAssertLessThanOrEqual(path.totalTravelTime,
                               config.pathEnumeration.maxTravelTime)
    }
  }

  // MARK: - Cycle Detection Tests

  func testCycleDetection() throws {
    let (graph, _) = PathEnumerationService.createPhase1ComplexFixture()

    // Test with cycles allowed
    var cycleAllowedConfig = MultiPathConfig.testing
    cycleAllowedConfig.pathEnumeration.allowCycles = true
    let cycleAllowedService = PathEnumerationService(
      config: cycleAllowedConfig
    )

    let pathsWithCycles = try cycleAllowedService.enumeratePaths(from: "A",
                                                                 to: "D",
                                                                 in: graph)

    // Test with cycles not allowed
    var cycleForbiddenConfig = MultiPathConfig.testing
    cycleForbiddenConfig.pathEnumeration.allowCycles = false
    let cycleForbiddenService = PathEnumerationService(
      config: cycleForbiddenConfig
    )

    let pathsWithoutCycles = try cycleForbiddenService.enumeratePaths(from: "A",
                                                                      to: "D",
                                                                      in: graph)

    // Should find same number of paths (our test graph doesn't have problematic cycles)
    XCTAssertEqual(pathsWithCycles.count, pathsWithoutCycles.count)
  }

  // MARK: - Shortest Path Tests

  func testShortestPath() throws {
    let (graph, _) = PathEnumerationService.createPhase1ComplexFixture()

    let shortestPath = try service.shortestPath(from: "A",
                                                to: "D",
                                                in: graph)

    XCTAssertNotNil(shortestPath, "Should find shortest path")
    XCTAssertEqual(shortestPath?.nodes,
                   ["A", "B", "D"],
                   "Shortest path should be A->B->D (500s)")
    XCTAssertEqual(shortestPath?.totalTravelTime,
                   500,
                   "Shortest path should have 500s travel time")
  }

  func testShortestPathNoPathExists() throws {
    // Create disconnected graph
    let nodes = [
      Node(id: "A", name: "Start", coordinates: (0, 0)),
      Node(id: "B", name: "End", coordinates: (1, 1)),
    ]
    let edges: [Edge] = []

    let graph = try Graph(nodes: nodes, edges: edges)

    let shortestPath = try service.shortestPath(from: "A",
                                                to: "B",
                                                in: graph)

    XCTAssertNil(shortestPath, "Should return nil when no path exists")
  }

  // MARK: - Deterministic Results Tests

  func testDeterministicResults() throws {
    let (graph, _) = PathEnumerationService.createPhase1ComplexFixture()

    // Run enumeration multiple times
    let results1 = try service.enumeratePaths(from: "A", to: "D", in: graph)
    let results2 = try service.enumeratePaths(from: "A", to: "D", in: graph)
    let results3 = try service.enumeratePaths(from: "A", to: "D", in: graph)

    // All results should be identical
    XCTAssertEqual(results1.count, results2.count)
    XCTAssertEqual(results2.count, results3.count)

    for i in 0 ..< results1.count {
      XCTAssertEqual(results1[i].nodes, results2[i].nodes)
      XCTAssertEqual(results2[i].nodes, results3[i].nodes)
      XCTAssertEqual(results1[i].totalTravelTime,
                     results2[i].totalTravelTime)
      XCTAssertEqual(results2[i].totalTravelTime,
                     results3[i].totalTravelTime)
    }
  }

  // MARK: - Performance Tests (Basic)

  func testPerformanceOnTinyGraph() throws {
    let (graph, _) = PathEnumerationService.createPhase1TestFixture()

    measure {
      do {
        _ = try service.enumeratePaths(from: "A", to: "C", in: graph)
      } catch {
        XCTFail("Performance test failed: \(error)")
      }
    }
  }

  // MARK: - Edge Case Tests

  func testSelfLoop() throws {
    // Create graph with self-loop
    let nodes = [
      Node(id: "A", name: "Start", coordinates: (0, 0)),
      Node(id: "B", name: "End", coordinates: (1, 1)),
    ]
    let edges = [
      Edge(from: "A", to: "B", travelTime: 100, distance: 100),
      Edge(from: "A", to: "A", travelTime: 50, distance: 50),  // Self-loop
    ]

    let graph = try Graph(nodes: nodes, edges: edges)

    let paths = try service.enumeratePaths(from: "A", to: "B", in: graph)

    // Should find the direct path A->B
    XCTAssertEqual(paths.count, 1)
    XCTAssertEqual(paths[0].nodes, ["A", "B"])
  }

  func testEmptyGraph() throws {
    let nodes: [Node] = []
    let edges: [Edge] = []

    let graph = try Graph(nodes: nodes, edges: edges)

    // Should throw error when nodes don't exist in empty graph
    XCTAssertThrowsError(
      try service.enumeratePaths(from: "A", to: "B", in: graph)
    ) { error in
      XCTAssertEqual(error as? MultiPathError, .nodeNotFound("A"))
    }
  }

  // MARK: - Phase 2 Property Tests

  /// Property test: Increasing maxDepth/maxPaths never reduces valid results
  /// This tests the monotonicity property for Phase 2 pruning
  func testMonotonicityProperty() throws {
    // Test with existing fixtures
    let testCases = [
      PathEnumerationService.createPhase1TestFixture(),
      PathEnumerationService.createPhase1ComplexFixture(),
    ]

    for (graph, _) in testCases {
      // Test monotonicity for maxDepth
      try testMonotonicityForMaxDepth(graph: graph)

      // Test monotonicity for maxPaths
      try testMonotonicityForMaxPaths(graph: graph)

      // Test monotonicity for maxTimeOverShortest
      try testMonotonicityForMaxTimeOverShortest(graph: graph)
    }
  }

  private func testMonotonicityForMaxDepth(graph: Graph) throws {
    // Test that increasing maxDepth never reduces results
    let configA = MultiPathConfig.testing
    var configB = MultiPathConfig.testing

    // Set different maxDepth values
    configB.pathEnumeration.maxDepth = configA.pathEnumeration.maxDepth + 2

    let serviceA = PathEnumerationService(config: configA)
    let serviceB = PathEnumerationService(config: configB)

    // Test for all node pairs in the graph
    for startNode in graph.nodes {
      for endNode in graph.nodes {
        if startNode.id != endNode.id {
          let pathsA = try serviceA.enumeratePaths(from: startNode.id,
                                                   to: endNode.id,
                                                   in: graph)
          let pathsB = try serviceB.enumeratePaths(from: startNode.id,
                                                   to: endNode.id,
                                                   in: graph)

          // All paths found with lower maxDepth should also be found with higher maxDepth
          for pathA in pathsA {
            XCTAssertTrue(pathsB.contains { $0.nodes == pathA.nodes },
                          "Path \(pathA.nodes) found with maxDepth \(configA.pathEnumeration.maxDepth) should also be found with maxDepth \(configB.pathEnumeration.maxDepth)")
          }
        }
      }
    }
  }

  private func testMonotonicityForMaxPaths(graph: Graph) throws {
    // Test that increasing maxPaths never reduces results
    let configA = MultiPathConfig.testing
    var configB = MultiPathConfig.testing

    // Set different maxPaths values
    configB.pathEnumeration.maxPaths = configA.pathEnumeration.maxPaths + 5

    let serviceA = PathEnumerationService(config: configA)
    let serviceB = PathEnumerationService(config: configB)

    // Test for all node pairs in the graph
    for startNode in graph.nodes {
      for endNode in graph.nodes {
        if startNode.id != endNode.id {
          let pathsA = try serviceA.enumeratePaths(from: startNode.id,
                                                   to: endNode.id,
                                                   in: graph)
          let pathsB = try serviceB.enumeratePaths(from: startNode.id,
                                                   to: endNode.id,
                                                   in: graph)

          // All paths found with lower maxPaths should also be found with higher maxPaths
          for pathA in pathsA {
            XCTAssertTrue(pathsB.contains { $0.nodes == pathA.nodes },
                          "Path \(pathA.nodes) found with maxPaths \(configA.pathEnumeration.maxPaths) should also be found with maxPaths \(configB.pathEnumeration.maxPaths)")
          }
        }
      }
    }
  }

  private func testMonotonicityForMaxTimeOverShortest(graph: Graph) throws {
    // Test that increasing maxTimeOverShortest never reduces results
    let configA = MultiPathConfig.testing
    var configB = MultiPathConfig.testing

    // Set different maxTimeOverShortest values
    configB.pathEnumeration.maxTimeOverShortest =
      configA.pathEnumeration.maxTimeOverShortest + 60  // Add 1 minute

    let serviceA = PathEnumerationService(config: configA)
    let serviceB = PathEnumerationService(config: configB)

    // Test for all node pairs in the graph
    for startNode in graph.nodes {
      for endNode in graph.nodes {
        if startNode.id != endNode.id {
          let pathsA = try serviceA.enumeratePaths(from: startNode.id,
                                                   to: endNode.id,
                                                   in: graph)
          let pathsB = try serviceB.enumeratePaths(from: startNode.id,
                                                   to: endNode.id,
                                                   in: graph)

          // All paths found with lower maxTimeOverShortest should also be found with higher maxTimeOverShortest
          for pathA in pathsA {
            XCTAssertTrue(pathsB.contains { $0.nodes == pathA.nodes },
                          "Path \(pathA.nodes) found with maxTimeOverShortest \(configA.pathEnumeration.maxTimeOverShortest)s should also be found with maxTimeOverShortest \(configB.pathEnumeration.maxTimeOverShortest)s")
          }
        }
      }
    }
  }

  /// Test that Phase 2 pruning actually works by verifying paths are excluded
  func testPhase2PruningEffectiveness() throws {
    let (graph, _) = PathEnumerationService.createPhase1ComplexFixture()

    // Create config with very restrictive maxTimeOverShortest
    var restrictiveConfig = MultiPathConfig.testing
    restrictiveConfig.pathEnumeration.maxTimeOverShortest = 50  // Very restrictive (50 seconds)

    let restrictiveService = PathEnumerationService(
      config: restrictiveConfig
    )

    // Create config with very permissive maxTimeOverShortest
    var permissiveConfig = MultiPathConfig.testing
    permissiveConfig.pathEnumeration.maxTimeOverShortest = 1000  // Very permissive (1000 seconds)

    let permissiveService = PathEnumerationService(config: permissiveConfig)

    // Test A to D path enumeration
    let restrictivePaths = try restrictiveService.enumeratePaths(from: "A",
                                                                 to: "D",
                                                                 in: graph)
    let permissivePaths = try permissiveService.enumeratePaths(from: "A",
                                                               to: "D",
                                                               in: graph)

    // Restrictive config should find fewer or equal paths
    XCTAssertLessThanOrEqual(restrictivePaths.count,
                             permissivePaths.count,
                             "Restrictive pruning should find fewer or equal paths")

    // All paths found with restrictive config should also be found with permissive config
    for restrictivePath in restrictivePaths {
      XCTAssertTrue(permissivePaths.contains { $0.nodes == restrictivePath.nodes },
                    "Path \(restrictivePath.nodes) found with restrictive pruning should also be found with permissive pruning")
    }
  }
}
