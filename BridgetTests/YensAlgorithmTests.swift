//
//  YensAlgorithmTests.swift
//  BridgetTests
//
//  Multi-Path Probability Traffic Prediction System - Phase 10
//  Purpose: Test Yen's K-shortest paths algorithm implementation
//  Integration: Tests PathEnumerationService with Yen's algorithm mode
//  Acceptance: Yen's algorithm finds correct K shortest paths efficiently
//  Known Limits: Test graphs only; performance testing in separate suite
//

import XCTest

@testable import Bridget

final class YensAlgorithmTests: XCTestCase {
  var pathEnumerationService: PathEnumerationService!
  var testGraph: Graph!

  override func setUp() {
    super.setUp()

    // Create configuration with Yen's algorithm enabled
    let config = MultiPathConfig(
      pathEnumeration: PathEnumConfig(
        maxPaths: 20,
        maxDepth: 10,
        maxTravelTime: 3600,
        allowCycles: false,
        useBidirectionalSearch: false,
        enumerationMode: .yensKShortest,
        kShortestPaths: 5,
        randomSeed: 42,
        maxTimeOverShortest: 300)
    )

    pathEnumerationService = PathEnumerationService(config: config)

    // Create a test graph with multiple paths
    testGraph = createTestGraph()
  }

  override func tearDown() {
    pathEnumerationService = nil
    testGraph = nil
    super.tearDown()
  }

  // MARK: - Test Graph Creation

  private func createTestGraph() -> Graph {
    let nodes = [
      Node(id: "A", name: "Start", coordinates: (47.6062, -122.3321)),
      Node(id: "B", name: "Bridge1", coordinates: (47.6065, -122.3325)),
      Node(id: "C", name: "Bridge2", coordinates: (47.6068, -122.3328)),
      Node(id: "D", name: "Bridge3", coordinates: (47.6070, -122.3330)),
      Node(id: "E", name: "End", coordinates: (47.6075, -122.3335)),
    ]

    let edges = [
      // Shortest path: A -> B -> E (300 + 200 = 500s)
      Edge(from: "A", to: "B", travelTime: 300, distance: 500, isBridge: true, bridgeID: "bridge1"),
      Edge(from: "B", to: "E", travelTime: 200, distance: 300, isBridge: false),

      // Second shortest: A -> C -> E (400 + 150 = 550s)
      Edge(from: "A", to: "C", travelTime: 400, distance: 600, isBridge: true, bridgeID: "bridge2"),
      Edge(from: "C", to: "E", travelTime: 150, distance: 250, isBridge: false),

      // Third shortest: A -> D -> E (350 + 250 = 600s)
      Edge(from: "A", to: "D", travelTime: 350, distance: 550, isBridge: true, bridgeID: "bridge3"),
      Edge(from: "D", to: "E", travelTime: 250, distance: 400, isBridge: false),

      // Alternative paths
      Edge(from: "B", to: "C", travelTime: 100, distance: 150, isBridge: false),
      Edge(from: "C", to: "D", travelTime: 120, distance: 180, isBridge: false),
      Edge(from: "B", to: "D", travelTime: 180, distance: 220, isBridge: false),
    ]

    return try! Graph(nodes: nodes, edges: edges)
  }

  // MARK: - Yen's Algorithm Tests

  func testYensAlgorithmFindsKShortestPaths() throws {
    // Test that Yen's algorithm finds the correct number of shortest paths
    let paths = try pathEnumerationService.enumeratePaths(
      from: "A",
      to: "E",
      in: testGraph)

    // Should find up to kShortestPaths (5) paths
    XCTAssertLessThanOrEqual(paths.count, 5, "Should not exceed kShortestPaths")
    XCTAssertGreaterThan(paths.count, 0, "Should find at least one path")

    // Verify paths are sorted by travel time (shortest first)
    for i in 1..<paths.count {
      XCTAssertLessThanOrEqual(
        paths[i - 1].totalTravelTime,
        paths[i].totalTravelTime,
        "Paths should be sorted by travel time")
    }
  }

  func testYensAlgorithmCorrectness() throws {
    let paths = try pathEnumerationService.enumeratePaths(
      from: "A",
      to: "E",
      in: testGraph)

    // Verify the shortest path is correct
    guard let shortestPath = paths.first else {
      XCTFail("Should find at least one path")
      return
    }

    // Expected shortest path: A -> B -> E (500s)
    XCTAssertEqual(shortestPath.nodes, ["A", "B", "E"])
    XCTAssertEqual(shortestPath.totalTravelTime, 500.0, accuracy: 0.1)

    // If we have a second path, verify it's the second shortest
    if paths.count > 1 {
      let secondPath = paths[1]
      // Expected second shortest: A -> C -> E (550s)
      XCTAssertEqual(secondPath.nodes, ["A", "C", "E"])
      XCTAssertEqual(secondPath.totalTravelTime, 550.0, accuracy: 0.1)
    }
  }

  func testYensAlgorithmWithDFSComparison() throws {
    // Create DFS configuration for comparison
    let dfsConfig = MultiPathConfig(
      pathEnumeration: PathEnumConfig(
        maxPaths: 20,
        maxDepth: 10,
        maxTravelTime: 3600,
        allowCycles: false,
        useBidirectionalSearch: false,
        enumerationMode: .dfs,
        kShortestPaths: 5,
        randomSeed: 42,
        maxTimeOverShortest: 300)
    )

    let dfsService = PathEnumerationService(config: dfsConfig)

    // Get paths using both algorithms
    let yensPaths = try pathEnumerationService.enumeratePaths(
      from: "A",
      to: "E",
      in: testGraph)

    let dfsPaths = try dfsService.enumeratePaths(
      from: "A",
      to: "E",
      in: testGraph)

    // Both should find valid paths
    XCTAssertGreaterThan(yensPaths.count, 0)
    XCTAssertGreaterThan(dfsPaths.count, 0)

    // Yen's should find the shortest paths correctly
    if let yensShortest = yensPaths.first, let dfsShortest = dfsPaths.first {
      XCTAssertEqual(yensShortest.totalTravelTime, dfsShortest.totalTravelTime, accuracy: 0.1)
    }
  }

  func testYensAlgorithmWithAutoMode() throws {
    // Test auto mode selection
    let autoConfig = MultiPathConfig(
      pathEnumeration: PathEnumConfig(
        maxPaths: 20,
        maxDepth: 10,
        maxTravelTime: 3600,
        allowCycles: false,
        useBidirectionalSearch: false,
        enumerationMode: .auto,
        kShortestPaths: 3,  // Small K should favor Yen's
        randomSeed: 42,
        maxTimeOverShortest: 300)
    )

    let autoService = PathEnumerationService(config: autoConfig)

    let paths = try autoService.enumeratePaths(
      from: "A",
      to: "E",
      in: testGraph)

    // Should find valid paths regardless of algorithm selection
    XCTAssertGreaterThan(paths.count, 0)

    // Verify paths are sorted
    for i in 1..<paths.count {
      XCTAssertLessThanOrEqual(
        paths[i - 1].totalTravelTime,
        paths[i].totalTravelTime,
        "Paths should be sorted by travel time")
    }
  }

  func testYensAlgorithmWithConstraints() throws {
    // Test that constraints are properly applied
    let constrainedConfig = MultiPathConfig(
      pathEnumeration: PathEnumConfig(
        maxPaths: 20,
        maxDepth: 10,
        maxTravelTime: 550,  // Only allow paths up to 550s
        allowCycles: false,
        useBidirectionalSearch: false,
        enumerationMode: .yensKShortest,
        kShortestPaths: 10,
        randomSeed: 42,
        maxTimeOverShortest: 100  // Only allow paths within 100s of shortest
      )
    )

    let constrainedService = PathEnumerationService(config: constrainedConfig)

    let paths = try constrainedService.enumeratePaths(
      from: "A",
      to: "E",
      in: testGraph)

    // All paths should respect the constraints
    for path in paths {
      XCTAssertLessThanOrEqual(path.totalTravelTime, 550.0, "Should respect maxTravelTime")

      if let shortestTime = paths.first?.totalTravelTime {
        let maxAllowedTime = shortestTime + 100
        XCTAssertLessThanOrEqual(
          path.totalTravelTime, maxAllowedTime, "Should respect maxTimeOverShortest")
      }
    }
  }

  func testYensAlgorithmPerformance() throws {
    // Simple performance test to ensure Yen's is reasonably fast
    let startTime = CFAbsoluteTimeGetCurrent()

    _ = try pathEnumerationService.enumeratePaths(
      from: "A",
      to: "E",
      in: testGraph)

    let endTime = CFAbsoluteTimeGetCurrent()
    let executionTime = endTime - startTime

    // Should complete within reasonable time (1 second)
    XCTAssertLessThan(
      executionTime, 1.0, "Yen's algorithm should complete within 1 second for small graphs")
  }

  func testYensAlgorithmWithNoPath() throws {
    // Test behavior when no path exists
    let isolatedNode = Node(id: "Z", name: "Isolated", coordinates: (47.6080, -122.3340))
    let isolatedGraph = try Graph(nodes: [isolatedNode], edges: [])

    // This should throw an error because "A" doesn't exist in the graph
    XCTAssertThrowsError(
      try pathEnumerationService.enumeratePaths(
        from: "A",
        to: "Z",
        in: isolatedGraph)
    ) { error in
      // Should throw nodeNotFound error
      XCTAssertTrue(error is MultiPathError)
    }
  }
}
