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

import Foundation
import Testing

@testable import Bridget

@Suite("Yen's Algorithm Tests")
struct YensAlgorithmTests {
  // Stored per-test since @Suite structs are value types
  private func makeYensConfig() -> MultiPathConfig {
    MultiPathConfig(
      pathEnumeration: PathEnumConfig(maxPaths: 20,
                                      maxDepth: 10,
                                      maxTravelTime: 3600,
                                      allowCycles: false,
                                      useBidirectionalSearch: false,
                                      enumerationMode: .yensKShortest,
                                      kShortestPaths: 5,
                                      randomSeed: 42,
                                      maxTimeOverShortest: 300)
    )
  }

  private func makeDFSConfig() -> MultiPathConfig {
    MultiPathConfig(
      pathEnumeration: PathEnumConfig(maxPaths: 20,
                                      maxDepth: 10,
                                      maxTravelTime: 3600,
                                      allowCycles: false,
                                      useBidirectionalSearch: false,
                                      enumerationMode: .dfs,
                                      kShortestPaths: 5,
                                      randomSeed: 42,
                                      maxTimeOverShortest: 300)
    )
  }

  private func makeAutoConfig() -> MultiPathConfig {
    MultiPathConfig(
      pathEnumeration: PathEnumConfig(maxPaths: 20,
                                      maxDepth: 10,
                                      maxTravelTime: 3600,
                                      allowCycles: false,
                                      useBidirectionalSearch: false,
                                      enumerationMode: .auto,
                                      kShortestPaths: 3,
                                      randomSeed: 42,
                                      maxTimeOverShortest: 300)
    )
  }

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
      Edge(from: "A",
           to: "B",
           travelTime: 300,
           distance: 500,
           isBridge: true,
           bridgeID: "bridge1"),
      Edge(from: "B",
           to: "E",
           travelTime: 200,
           distance: 300,
           isBridge: false),

      // Second shortest: A -> C -> E (400 + 150 = 550s)
      Edge(from: "A",
           to: "C",
           travelTime: 400,
           distance: 600,
           isBridge: true,
           bridgeID: "bridge2"),
      Edge(from: "C",
           to: "E",
           travelTime: 150,
           distance: 250,
           isBridge: false),

      // Third shortest: A -> D -> E (350 + 250 = 600s)
      Edge(from: "A",
           to: "D",
           travelTime: 350,
           distance: 550,
           isBridge: true,
           bridgeID: "bridge3"),
      Edge(from: "D",
           to: "E",
           travelTime: 250,
           distance: 400,
           isBridge: false),

      // Alternative paths
      Edge(from: "B",
           to: "C",
           travelTime: 100,
           distance: 150,
           isBridge: false),
      Edge(from: "C",
           to: "D",
           travelTime: 120,
           distance: 180,
           isBridge: false),
      Edge(from: "B",
           to: "D",
           travelTime: 180,
           distance: 220,
           isBridge: false),
    ]

    return try! Graph(nodes: nodes, edges: edges)
  }

  // MARK: - Yen's Algorithm Tests

  @Test("Yen finds up to K shortest paths and they are sorted")
  func yensFindsKSortedPaths() throws {
    let config = makeYensConfig()
    let pathEnumerationService = PathEnumerationService(config: config)
    let testGraph = createTestGraph()

    let paths = try pathEnumerationService.enumeratePaths(from: "A",
                                                          to: "E",
                                                          in: testGraph)

    #expect(paths.count <= 5, "Should not exceed kShortestPaths")
    #expect(paths.count > 0, "Should find at least one path")

    // Sorted by travel time ascending
    for i in 1 ..< paths.count {
      #expect(paths[i - 1].totalTravelTime <= paths[i].totalTravelTime,
              "Paths should be sorted by travel time")
    }
  }

  @Test("Yen correctness: shortest and second-shortest match expectations")
  func yensCorrectness() throws {
    let config = makeYensConfig()
    let pathEnumerationService = PathEnumerationService(config: config)
    let testGraph = createTestGraph()

    let paths = try pathEnumerationService.enumeratePaths(from: "A",
                                                          to: "E",
                                                          in: testGraph)

    let shortestPath = try #require(paths.first,
                                    "Should find at least one path")

    // Expected shortest: A -> B -> E (500s)
    #expect(shortestPath.nodes == ["A", "B", "E"])
    #expect(abs(shortestPath.totalTravelTime - 500.0) <= 0.1)

    if paths.count > 1 {
      let secondPath = paths[1]
      // Expected second shortest: A -> C -> E (550s)
      #expect(secondPath.nodes == ["A", "C", "E"])
      #expect(abs(secondPath.totalTravelTime - 550.0) <= 0.1)
    }
  }

  @Test("Yen vs DFS: shortest path parity")
  func yensWithDFSComparison() throws {
    let yensService = PathEnumerationService(config: makeYensConfig())
    let dfsService = PathEnumerationService(config: makeDFSConfig())
    let testGraph = createTestGraph()

    let yensPaths = try yensService.enumeratePaths(from: "A",
                                                   to: "E",
                                                   in: testGraph)
    let dfsPaths = try dfsService.enumeratePaths(from: "A",
                                                 to: "E",
                                                 in: testGraph)

    #expect(yensPaths.count > 0)
    #expect(dfsPaths.count > 0)

    if let yensShortest = yensPaths.first, let dfsShortest = dfsPaths.first {
      #expect(
        abs(yensShortest.totalTravelTime - dfsShortest.totalTravelTime)
          <= 0.1
      )
    }
  }

  @Test("Auto mode yields valid, sorted paths")
  func yensWithAutoMode() throws {
    let autoService = PathEnumerationService(config: makeAutoConfig())
    let testGraph = createTestGraph()

    let paths = try autoService.enumeratePaths(from: "A",
                                               to: "E",
                                               in: testGraph)

    #expect(paths.count > 0)

    for i in 1 ..< paths.count {
      #expect(paths[i - 1].totalTravelTime <= paths[i].totalTravelTime,
              "Paths should be sorted by travel time")
    }
  }

  @Test("Constraints: respects maxTravelTime and maxTimeOverShortest")
  func yensWithConstraints() throws {
    let constrainedConfig = MultiPathConfig(pathEnumeration: PathEnumConfig(maxPaths: 20,
                                                                            maxDepth: 10,
                                                                            maxTravelTime: 550,  // Only allow paths up to 550s
                                                                            allowCycles: false,
                                                                            useBidirectionalSearch: false,
                                                                            enumerationMode: .yensKShortest,
                                                                            kShortestPaths: 10,
                                                                            randomSeed: 42,
                                                                            maxTimeOverShortest: 100)  // Only within 100s of shortest
    )
    let constrainedService = PathEnumerationService(
      config: constrainedConfig
    )
    let testGraph = createTestGraph()

    let paths = try constrainedService.enumeratePaths(from: "A",
                                                      to: "E",
                                                      in: testGraph)

    for path in paths {
      #expect(path.totalTravelTime <= 550.0,
              "Should respect maxTravelTime")

      if let shortestTime = paths.first?.totalTravelTime {
        let maxAllowed = shortestTime + 100
        #expect(path.totalTravelTime <= maxAllowed,
                "Should respect maxTimeOverShortest")
      }
    }
  }

  @Test("Performance: small graph completes within 1 second")
  func yensPerformance() throws {
    let service = PathEnumerationService(config: makeYensConfig())
    let testGraph = createTestGraph()

    let startTime = CFAbsoluteTimeGetCurrent()
    _ = try service.enumeratePaths(from: "A", to: "E", in: testGraph)
    let endTime = CFAbsoluteTimeGetCurrent()
    let exec = endTime - startTime

    #expect(exec < 1.0,
            "Yen's algorithm should complete within 1 second for small graphs")
  }

  @Test("No path / invalid nodes: throws MultiPathError.nodeNotFound")
  func yensNoPath() {
    let service = PathEnumerationService(config: makeYensConfig())
    let isolatedNode = Node(id: "Z",
                            name: "Isolated",
                            coordinates: (47.6080, -122.3340))
    let isolatedGraph = try! Graph(nodes: [isolatedNode], edges: [])

    #expect(throws: MultiPathError.nodeNotFound("A")) {
      _ = try service.enumeratePaths(from: "A",
                                     to: "Z",
                                     in: isolatedGraph)
    }
  }
}
