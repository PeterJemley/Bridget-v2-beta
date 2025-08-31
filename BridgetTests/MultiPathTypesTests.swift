//
//  MultiPathTypesTests.swift
//  BridgetTests
//
//  Multi-Path Probability Traffic Prediction System Tests
//  Purpose: Validate foundational types and basic functionality
//  Integration: Tests Types.swift, Graph.swift, Config.swift
//  Acceptance: All tests pass, types work as expected
//  Known Limits: Basic validation only, comprehensive tests in later phases
//

import XCTest

@testable import Bridget

final class MultiPathTypesTests: XCTestCase {
  // MARK: - Node Tests

  func testNodeCreation() {
    let node = Node(
      id: "test_node",
      name: "Test Node",
      coordinates: (47.6062, -122.3321))

    XCTAssertEqual(node.id, "test_node")
    XCTAssertEqual(node.name, "Test Node")
    XCTAssertEqual(node.coordinates.latitude, 47.6062)
    XCTAssertEqual(node.coordinates.longitude, -122.3321)
  }

  func testNodeHashable() {
    let node1 = Node(id: "A", name: "Node A", coordinates: (0, 0))
    let node2 = Node(id: "A", name: "Node A", coordinates: (0, 0))
    let node3 = Node(id: "B", name: "Node B", coordinates: (0, 0))

    XCTAssertEqual(node1, node2)
    XCTAssertNotEqual(node1, node3)
    XCTAssertEqual(node1.hashValue, node2.hashValue)
    XCTAssertNotEqual(node1.hashValue, node3.hashValue)
  }

  // MARK: - Edge Tests

  func testEdgeCreation() {
    let edge = Edge(
      from: "A",
      to: "B",
      travelTime: 300,
      distance: 500,
      isBridge: true,
      bridgeID: "bridge1")

    XCTAssertEqual(edge.from, "A")
    XCTAssertEqual(edge.to, "B")
    XCTAssertEqual(edge.travelTime, 300)
    XCTAssertEqual(edge.distance, 500)
    XCTAssertTrue(edge.isBridge)
    XCTAssertEqual(edge.bridgeID, "bridge1")
  }

  func testEdgeHashable() {
    let edge1 = Edge(from: "A", to: "B", travelTime: 300, distance: 500)
    let edge2 = Edge(from: "A", to: "B", travelTime: 300, distance: 500)
    let edge3 = Edge(from: "A", to: "C", travelTime: 300, distance: 500)

    XCTAssertEqual(edge1, edge2)
    XCTAssertNotEqual(edge1, edge3)
    XCTAssertEqual(edge1.hashValue, edge2.hashValue)
    XCTAssertNotEqual(edge1.hashValue, edge3.hashValue)
  }

  // MARK: - RoutePath Tests

  func testRoutePathCreation() {
    let nodes = ["A", "B", "C"]
    let edges = [
      Edge(from: "A", to: "B", travelTime: 300, distance: 500),
      Edge(from: "B", to: "C", travelTime: 200, distance: 300),
    ]

    let path = RoutePath(nodes: nodes, edges: edges)

    XCTAssertEqual(path.nodes, nodes)
    XCTAssertEqual(path.edges, edges)
    XCTAssertEqual(path.totalTravelTime, 500)
    XCTAssertEqual(path.totalDistance, 800)
    XCTAssertEqual(path.bridgeCount, 0)
  }

  func testRoutePathWithBridges() {
    let nodes = ["A", "B", "C"]
    let edges = [
      Edge(from: "A", to: "B", travelTime: 300, distance: 500, isBridge: true, bridgeID: "bridge1"),
      Edge(from: "B", to: "C", travelTime: 200, distance: 300, isBridge: false),
    ]

    let path = RoutePath(nodes: nodes, edges: edges)

    XCTAssertEqual(path.bridgeCount, 1)
  }

  func testPathContiguityValidation() {
    // Golden path - should pass
    let validNodes = ["A", "B", "C"]
    let validEdges = [
      Edge(from: "A", to: "B", travelTime: 300, distance: 500),
      Edge(from: "B", to: "C", travelTime: 200, distance: 300),
    ]
    let validPath = RoutePath(nodes: validNodes, edges: validEdges)

    XCTAssertTrue(validPath.isContiguous())
    XCTAssertNoThrow(try validPath.validate())

    // Crafted bad path - should fail (disconnected)
    let invalidNodes = ["A", "B", "C"]
    let invalidEdges = [
      Edge(from: "A", to: "B", travelTime: 300, distance: 500),
      Edge(from: "A", to: "C", travelTime: 200, distance: 300),  // Should be B->C
    ]
    let invalidPath = RoutePath(nodes: invalidNodes, edges: invalidEdges)

    XCTAssertFalse(invalidPath.isContiguous())
    XCTAssertThrowsError(try invalidPath.validate())

    // Another bad path - wrong node sequence
    let badNodes = ["A", "C", "B"]  // Wrong order
    let badEdges = [
      Edge(from: "A", to: "B", travelTime: 300, distance: 500),
      Edge(from: "B", to: "C", travelTime: 200, distance: 300),
    ]
    let badPath = RoutePath(nodes: badNodes, edges: badEdges)

    XCTAssertFalse(badPath.isContiguous())
    XCTAssertThrowsError(try badPath.validate())

    // Edge case - single node path
    let singleNodePath = RoutePath(nodes: ["A"], edges: [])
    XCTAssertFalse(singleNodePath.isContiguous())

    // Edge case - empty path
    let emptyPath = RoutePath(nodes: [], edges: [])
    XCTAssertFalse(emptyPath.isContiguous())
  }

  // MARK: - Graph Tests

  func testGraphCreation() throws {
    let nodes = [
      Node(id: "A", name: "Start", coordinates: (0, 0)),
      Node(id: "B", name: "End", coordinates: (1, 1)),
    ]

    let edges = [
      Edge(from: "A", to: "B", travelTime: 300, distance: 500)
    ]

    let graph = try Graph(nodes: nodes, edges: edges)

    XCTAssertEqual(graph.nodes.count, 2)
    XCTAssertEqual(graph.allEdges.count, 1)
    XCTAssertEqual(graph.outgoingEdges(from: "A").count, 1)
    XCTAssertEqual(graph.outgoingEdges(from: "B").count, 0)
  }

  func testGraphValidation() {
    let nodes = [
      Node(id: "A", name: "Start", coordinates: (0, 0)),
      Node(id: "B", name: "End", coordinates: (1, 1)),
    ]

    // Valid graph
    let validEdges = [
      Edge(from: "A", to: "B", travelTime: 300, distance: 500)
    ]

    XCTAssertNoThrow(try Graph(nodes: nodes, edges: validEdges))

    // Invalid graph - edge references non-existent node
    let invalidEdges = [
      Edge(from: "A", to: "C", travelTime: 300, distance: 500)
    ]

    XCTAssertThrowsError(try Graph(nodes: nodes, edges: invalidEdges))
  }

  func testTinyTestGraph() {
    let graph = Graph.createTinyTestGraph()

    XCTAssertEqual(graph.nodes.count, 3)
    XCTAssertEqual(graph.allEdges.count, 4)  // 2 bidirectional edges
    XCTAssertTrue(graph.pathExists(from: "A", to: "C"))

    if let shortestPath = graph.shortestPath(from: "A", to: "C") {
      XCTAssertEqual(shortestPath.nodes, ["A", "B", "C"])
      XCTAssertEqual(shortestPath.totalTravelTime, 500)  // 300 + 200
    } else {
      XCTFail("Should find path from A to C")
    }
  }

  func testSmallTestGraph() {
    let graph = Graph.createSmallTestGraph()

    XCTAssertEqual(graph.nodes.count, 4)
    XCTAssertEqual(graph.allEdges.count, 8)  // 4 bidirectional edges
    XCTAssertTrue(graph.pathExists(from: "A", to: "D"))

    // Should find multiple paths
    let paths = graph.outgoingEdges(from: "A")
    XCTAssertEqual(paths.count, 2)  // A->B and A->C
  }

  // MARK: - Configuration Tests

  func testConfigurationDefaults() {
    let config = MultiPathConfig()

    XCTAssertEqual(config.pathEnumeration.maxPaths, 100)
    XCTAssertEqual(config.pathEnumeration.maxDepth, 20)
    XCTAssertEqual(config.pathEnumeration.maxTravelTime, 3600)
    XCTAssertFalse(config.pathEnumeration.allowCycles)
    XCTAssertFalse(config.pathEnumeration.useBidirectionalSearch)
    XCTAssertEqual(config.pathEnumeration.randomSeed, 42)

    XCTAssertEqual(config.scoring.minProbability, 1e-10)
    XCTAssertEqual(config.scoring.maxProbability, 1.0 - 1e-10)
    XCTAssertTrue(config.scoring.useLogDomain)
    XCTAssertEqual(config.scoring.bridgeWeight, 0.7)
    XCTAssertEqual(config.scoring.timeWeight, 0.3)
  }

  func testConfigurationPresets() {
    let devConfig = MultiPathConfig.development
    let prodConfig = MultiPathConfig.production
    let testConfig = MultiPathConfig.testing

    XCTAssertLessThan(devConfig.pathEnumeration.maxPaths, prodConfig.pathEnumeration.maxPaths)
    XCTAssertLessThan(testConfig.pathEnumeration.maxPaths, devConfig.pathEnumeration.maxPaths)

    XCTAssertTrue(devConfig.performance.enablePerformanceLogging)
    XCTAssertFalse(prodConfig.performance.enablePerformanceLogging)
    XCTAssertTrue(testConfig.performance.enablePerformanceLogging)
  }

  // MARK: - ETA Tests

  func testETACreation() {
    let date = Date()
    let eta = ETA(
      nodeID: "A",
      arrivalTime: date,
      travelTimeFromStart: 300)

    XCTAssertEqual(eta.nodeID, "A")
    XCTAssertEqual(eta.arrivalTime, date)
    XCTAssertEqual(eta.travelTimeFromStart, 300)
  }

  func testETAWindowCreation() {
    let date = Date()
    let eta = ETA(nodeID: "A", arrivalTime: date, travelTimeFromStart: 300)
    let window = ETAWindow(expectedETA: eta)

    XCTAssertEqual(window.expectedETA, eta)
    XCTAssertNil(window.minETA)
    XCTAssertNil(window.maxETA)
  }

  // MARK: - Error Tests

  func testMultiPathErrorDescriptions() {
    let graphError = MultiPathError.invalidGraph("Test error")
    let nodeError = MultiPathError.nodeNotFound("test_node")
    let pathError = MultiPathError.noPathExists("A", "B")

    XCTAssertTrue(graphError.errorDescription?.contains("Invalid graph") ?? false)
    XCTAssertTrue(nodeError.errorDescription?.contains("Node not found") ?? false)
    XCTAssertTrue(pathError.errorDescription?.contains("No path exists") ?? false)
  }

  func testBridgePredictionErrorDescriptions() {
    let unsupportedError = BridgePredictionError.unsupportedBridge("test_bridge")
    let invalidError = BridgePredictionError.invalidFeatures("Test features")
    let batchError = BridgePredictionError.batchSizeExceeded(100, 50)

    XCTAssertTrue(unsupportedError.errorDescription?.contains("Bridge not supported") ?? false)
    XCTAssertTrue(invalidError.errorDescription?.contains("Invalid features") ?? false)
    XCTAssertTrue(
      batchError.errorDescription?.contains("Batch size 100 exceeds maximum 50") ?? false)
  }
}
