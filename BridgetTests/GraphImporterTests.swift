//
//  GraphImporterTests.swift
//  BridgetTests
//

import Foundation
import Testing

@testable import Bridget

@Suite("Graph Importer Tests")
struct GraphImporterTests {
  @Test("Basic graph import builds and validates a tiny graph")
  func basicGraphImport() throws {
    // Create a simple test graph
    let nodes = [
      Node(id: "A",
           name: "Node A",
           coordinates: (latitude: 47.0, longitude: -122.0)),
      Node(id: "B",
           name: "Node B",
           coordinates: (latitude: 47.1, longitude: -122.1)),
    ]

    let edges = [
      Edge(from: "A",
           to: "B",
           travelTime: 300,
           distance: 1000,
           isBridge: false,
           bridgeID: nil),
    ]

    // Create a simple graph
    let graph = try Graph(nodes: nodes, edges: edges)

    // Basic validation
    #expect(graph.nodes.count == 2)
    #expect(graph.allEdges.count == 1)

    // Test graph validation
    let validationResult = graph.validate()
    #expect(validationResult.isValid, "Graph should be valid")
  }

  @Test("JSON decoding for import structs works independently")
  func jSONDecoding() throws {
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
    let bridges = try JSONDecoder().decode([ImportBridge].self,
                                           from: bridgesJSON)

    // Verify decoding worked
    #expect(nodes.count == 2)
    #expect(edges.count == 1)
    #expect(bridges.count == 0)

    // Verify specific values
    #expect(nodes[0].id == "A")
    #expect(edges[0].from == "A")
    #expect(edges[0].to == "B")
  }

  @Test("Importing from a directory with JSON files yields a valid Graph")
  func simpleGraphImporter() throws {
    // Test GraphImporter with simple data
    let tempDir = FileManager.default.temporaryDirectory
    let testDir = tempDir.appendingPathComponent(
      "test_graph_\(UUID().uuidString)"
    )

    // Clean up any existing directory
    try? FileManager.default.removeItem(at: testDir)
    try FileManager.default.createDirectory(at: testDir,
                                            withIntermediateDirectories: true)

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
    try bridgesData.write(
      to: testDir.appendingPathComponent("bridges.json")
    )

    // Try to import
    let graph = try GraphImporter.importGraph(from: testDir)

    // Verify
    #expect(graph.nodes.count == 2)
    #expect(graph.allEdges.count == 1)
  }
}
