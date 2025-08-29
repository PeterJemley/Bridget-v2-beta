//
//  GraphImporterTests.swift
//  BridgetTests
//

import XCTest

@testable import Bridget

final class GraphImporterTests: XCTestCase {
  func testBasicGraphImport() throws {
    // Create a simple test graph
    let nodes = [
      Node(id: "A", name: "Node A", coordinates: (latitude: 47.0, longitude: -122.0)),
      Node(id: "B", name: "Node B", coordinates: (latitude: 47.1, longitude: -122.1)),
    ]

    let edges = [
      Edge(from: "A", to: "B", travelTime: 300, distance: 1000, isBridge: false, bridgeID: nil),
    ]

    // Create a simple graph
    let graph = try Graph(nodes: nodes, edges: edges)

    // Basic validation
    XCTAssertEqual(graph.nodes.count, 2)
    XCTAssertEqual(graph.allEdges.count, 1)

    // Test graph validation
    let validationResult = graph.validate()
    XCTAssertTrue(validationResult.isValid, "Graph should be valid")
  }

  func testJSONDecoding() throws {
    // Test JSON decoding directly to isolate the issue
    let nodesJSON = """
    [
      { "id": "A", "name": "Node A", "latitude": 47.0, "longitude": -122.0, "type": "intersection" },
      { "id": "B", "name": "Node B", "latitude": 47.1, "longitude": -122.1, "type": "intersection" }
    ]
    """.data(using: .utf8)!

    let edgesJSON = """
    [
      { "from": "A", "to": "B", "travelTimeSec": 300, "distanceM": 1000, "isBridge": false, "bridgeID": null, "laneCount": 2, "speedLimit": 25 }
    ]
    """.data(using: .utf8)!

    let bridgesJSON = """
    []
    """.data(using: .utf8)!

    // Try to decode each JSON type
    let nodes = try JSONDecoder().decode([ImportNode].self, from: nodesJSON)
    let edges = try JSONDecoder().decode([ImportEdge].self, from: edgesJSON)
    let bridges = try JSONDecoder().decode([ImportBridge].self, from: bridgesJSON)

    // Verify decoding worked
    XCTAssertEqual(nodes.count, 2)
    XCTAssertEqual(edges.count, 1)
    XCTAssertEqual(bridges.count, 0)

    // Verify specific values
    XCTAssertEqual(nodes[0].id, "A")
    XCTAssertEqual(edges[0].from, "A")
    XCTAssertEqual(edges[0].to, "B")
  }

  func testSimpleGraphImporter() throws {
    // Test GraphImporter with simple data
    let tempDir = FileManager.default.temporaryDirectory
    let testDir = tempDir.appendingPathComponent("test_graph_\(UUID().uuidString)")

    // Clean up any existing directory
    try? FileManager.default.removeItem(at: testDir)
    try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

    defer {
      // Clean up
      try? FileManager.default.removeItem(at: testDir)
    }

    // Create simple test data
    let nodesData = """
    [
      { "id": "A", "name": "Node A", "latitude": 47.0, "longitude": -122.0, "type": "intersection" },
      { "id": "B", "name": "Node B", "latitude": 47.1, "longitude": -122.1, "type": "intersection" }
    ]
    """.data(using: .utf8)!

    let edgesData = """
    [
      { "from": "A", "to": "B", "travelTimeSec": 300, "distanceM": 1000, "isBridge": false, "bridgeID": null, "laneCount": 2, "speedLimit": 25 }
    ]
    """.data(using: .utf8)!

    let bridgesData = """
    []
    """.data(using: .utf8)!

    // Write files
    try nodesData.write(to: testDir.appendingPathComponent("nodes.json"))
    try edgesData.write(to: testDir.appendingPathComponent("edges.json"))
    try bridgesData.write(to: testDir.appendingPathComponent("bridges.json"))

    // Try to import
    let graph = try GraphImporter.importGraph(from: testDir)

    // Verify
    XCTAssertEqual(graph.nodes.count, 2)
    XCTAssertEqual(graph.allEdges.count, 1)
  }
}
