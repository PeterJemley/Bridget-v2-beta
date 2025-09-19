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

import Foundation
import Testing

@testable import Bridget

@Suite("MultiPath Types Tests")
struct MultiPathTypesTests {
    // MARK: - Node Tests

    @Test("Node creation populates fields correctly")
    func nodeCreation() {
        let node = Node(
            id: "test_node",
            name: "Test Node",
            coordinates: (47.6062, -122.3321)
        )

        #expect(node.id == "test_node")
        #expect(node.name == "Test Node")
        #expect(node.coordinates.latitude == 47.6062)
        #expect(node.coordinates.longitude == -122.3321)
    }

    @Test("Node Hashable conformance works")
    func nodeHashable() {
        let node1 = Node(id: "A", name: "Node A", coordinates: (0, 0))
        let node2 = Node(id: "A", name: "Node A", coordinates: (0, 0))
        let node3 = Node(id: "B", name: "Node B", coordinates: (0, 0))

        #expect(node1 == node2)
        #expect(node1 != node3)
        #expect(node1.hashValue == node2.hashValue)
        #expect(node1.hashValue != node3.hashValue)
    }

    // MARK: - Edge Tests

    @Test("Edge creation populates fields correctly")
    func edgeCreation() {
        let edge = Edge(
            from: "A",
            to: "B",
            travelTime: 300,
            distance: 500,
            isBridge: true,
            bridgeID: "bridge1"
        )

        #expect(edge.from == "A")
        #expect(edge.to == "B")
        #expect(edge.travelTime == 300)
        #expect(edge.distance == 500)
        #expect(edge.isBridge)
        #expect(edge.bridgeID == "bridge1")
    }

    @Test("Edge Hashable conformance works")
    func edgeHashable() {
        let edge1 = Edge(from: "A", to: "B", travelTime: 300, distance: 500)
        let edge2 = Edge(from: "A", to: "B", travelTime: 300, distance: 500)
        let edge3 = Edge(from: "A", to: "C", travelTime: 300, distance: 500)

        #expect(edge1 == edge2)
        #expect(edge1 != edge3)
        #expect(edge1.hashValue == edge2.hashValue)
        #expect(edge1.hashValue != edge3.hashValue)
    }

    // MARK: - RoutePath Tests

    @Test("RoutePath creation computes totals and counts")
    func routePathCreation() {
        let nodes = ["A", "B", "C"]
        let edges = [
            Edge(from: "A", to: "B", travelTime: 300, distance: 500),
            Edge(from: "B", to: "C", travelTime: 200, distance: 300),
        ]

        let path = RoutePath(nodes: nodes, edges: edges)

        #expect(path.nodes == nodes)
        #expect(path.edges == edges)
        #expect(path.totalTravelTime == 500)
        #expect(path.totalDistance == 800)
        #expect(path.bridgeCount == 0)
    }

    @Test("RoutePath with bridges counts them")
    func routePathWithBridges() {
        let nodes = ["A", "B", "C"]
        let edges = [
            Edge(
                from: "A",
                to: "B",
                travelTime: 300,
                distance: 500,
                isBridge: true,
                bridgeID: "bridge1"
            ),
            Edge(
                from: "B",
                to: "C",
                travelTime: 200,
                distance: 300,
                isBridge: false
            ),
        ]

        let path = RoutePath(nodes: nodes, edges: edges)

        #expect(path.bridgeCount == 1)
    }

    @Test("Path contiguity validation works and validate() throws on bad paths")
    func pathContiguityValidation() {
        // Golden path - should pass
        let validNodes = ["A", "B", "C"]
        let validEdges = [
            Edge(from: "A", to: "B", travelTime: 300, distance: 500),
            Edge(from: "B", to: "C", travelTime: 200, distance: 300),
        ]
        let validPath = RoutePath(nodes: validNodes, edges: validEdges)

        #expect(validPath.isContiguous())
        do {
            try validPath.validate()
        } catch {
            Issue.record(
                "validate() should not throw for a valid path: \(error)"
            )
        }

        // Crafted bad path - should fail (disconnected)
        let invalidNodes = ["A", "B", "C"]
        let invalidEdges = [
            Edge(from: "A", to: "B", travelTime: 300, distance: 500),
            Edge(from: "A", to: "C", travelTime: 200, distance: 300),  // Should be B->C
        ]
        let invalidPath = RoutePath(nodes: invalidNodes, edges: invalidEdges)

        #expect(invalidPath.isContiguous() == false)
        do {
            try invalidPath.validate()
            Issue.record("validate() should throw for a disconnected path")
        } catch {
            // expected
        }

        // Another bad path - wrong node sequence
        let badNodes = ["A", "C", "B"]  // Wrong order
        let badEdges = [
            Edge(from: "A", to: "B", travelTime: 300, distance: 500),
            Edge(from: "B", to: "C", travelTime: 200, distance: 300),
        ]
        let badPath = RoutePath(nodes: badNodes, edges: badEdges)

        #expect(badPath.isContiguous() == false)
        do {
            try badPath.validate()
            Issue.record("validate() should throw for wrong node sequence")
        } catch {
            // expected
        }

        // Edge case - single node path
        let singleNodePath = RoutePath(nodes: ["A"], edges: [])
        #expect(singleNodePath.isContiguous() == false)

        // Edge case - empty path
        let emptyPath = RoutePath(nodes: [], edges: [])
        #expect(emptyPath.isContiguous() == false)
    }

    // MARK: - Graph Tests

    @Test("Graph creation builds adjacency and queries work")
    func graphCreation() throws {
        let nodes = [
            Node(id: "A", name: "Start", coordinates: (0, 0)),
            Node(id: "B", name: "End", coordinates: (1, 1)),
        ]

        let edges = [
            Edge(from: "A", to: "B", travelTime: 300, distance: 500)
        ]

        let graph = try Graph(nodes: nodes, edges: edges)

        #expect(graph.nodes.count == 2)
        #expect(graph.allEdges.count == 1)
        #expect(graph.outgoingEdges(from: "A").count == 1)
        #expect(graph.outgoingEdges(from: "B").count == 0)
    }

    @Test("Graph validation throws on invalid edges")
    func graphValidation() {
        let nodes = [
            Node(id: "A", name: "Start", coordinates: (0, 0)),
            Node(id: "B", name: "End", coordinates: (1, 1)),
        ]

        // Valid graph
        let validEdges = [
            Edge(from: "A", to: "B", travelTime: 300, distance: 500)
        ]

        do {
            _ = try Graph(nodes: nodes, edges: validEdges)
        } catch {
            Issue.record("Valid graph should not throw: \(error)")
        }

        // Invalid graph - edge references non-existent node
        let invalidEdges = [
            Edge(from: "A", to: "C", travelTime: 300, distance: 500)
        ]

        do {
            _ = try Graph(nodes: nodes, edges: invalidEdges)
            Issue.record(
                "Graph initializer should throw for invalid node references"
            )
        } catch {
            // expected
        }
    }

    @Test("Tiny test graph fixture behaves as expected")
    func tinyTestGraph() {
        let graph = Graph.createTinyTestGraph()

        #expect(graph.nodes.count == 3)
        #expect(graph.allEdges.count == 4)  // 2 bidirectional edges
        #expect(graph.pathExists(from: "A", to: "C"))

        if let shortestPath = graph.shortestPath(from: "A", to: "C") {
            #expect(shortestPath.nodes == ["A", "B", "C"])
            #expect(shortestPath.totalTravelTime == 500)  // 300 + 200
        } else {
            Issue.record("Should find path from A to C")
        }
    }

    @Test("Small test graph fixture behaves as expected")
    func smallTestGraph() {
        let graph = Graph.createSmallTestGraph()

        #expect(graph.nodes.count == 4)
        #expect(graph.allEdges.count == 8)  // 4 bidirectional edges
        #expect(graph.pathExists(from: "A", to: "D"))

        // Should find multiple outgoing edges
        let paths = graph.outgoingEdges(from: "A")
        #expect(paths.count == 2)  // A->B and A->C
    }

    // MARK: - Configuration Tests

    @Test("Configuration defaults have expected values")
    func configurationDefaults() {
        let config = MultiPathConfig()

        #expect(config.pathEnumeration.maxPaths == 100)
        #expect(config.pathEnumeration.maxDepth == 20)
        #expect(config.pathEnumeration.maxTravelTime == 3600)
        #expect(config.pathEnumeration.allowCycles == false)
        #expect(config.pathEnumeration.useBidirectionalSearch == false)
        #expect(config.pathEnumeration.randomSeed == 42)

        #expect(config.scoring.minProbability == 1e-10)
        #expect(config.scoring.maxProbability == 1.0 - 1e-10)
        #expect(config.scoring.useLogDomain == true)
        #expect(config.scoring.bridgeWeight == 0.7)
        #expect(config.scoring.timeWeight == 0.3)
    }

    @Test("Configuration presets differ as expected")
    func configurationPresets() {
        let devConfig = MultiPathConfig.development
        let prodConfig = MultiPathConfig.production
        let testConfig = MultiPathConfig.testing

        #expect(
            devConfig.pathEnumeration.maxPaths
                < prodConfig.pathEnumeration.maxPaths
        )
        #expect(
            testConfig.pathEnumeration.maxPaths
                < devConfig.pathEnumeration.maxPaths
        )

        #expect(devConfig.performance.enablePerformanceLogging == true)
        #expect(prodConfig.performance.enablePerformanceLogging == false)
        #expect(testConfig.performance.enablePerformanceLogging == true)
    }

    // MARK: - ETA Tests

    @Test("ETA creation populates fields correctly")
    func eTACreation() {
        let date = Date()
        let eta = ETA(
            nodeID: "A",
            arrivalTime: date,
            travelTimeFromStart: 300
        )

        #expect(eta.nodeID == "A")
        #expect(eta.arrivalTime == date)
        #expect(eta.travelTimeFromStart == 300)
    }

    @Test("ETAWindow creation defaults min/max to nil")
    func eTAWindowCreation() {
        let date = Date()
        let eta = ETA(nodeID: "A", arrivalTime: date, travelTimeFromStart: 300)
        let window = ETAWindow(expectedETA: eta)

        #expect(window.expectedETA == eta)
        #expect(window.minETA == nil)
        #expect(window.maxETA == nil)
    }

    // MARK: - Error Tests

    @Test("MultiPathError descriptions contain expected text")
    func multiPathErrorDescriptions() {
        let graphError = MultiPathError.invalidGraph("Test error")
        let nodeError = MultiPathError.nodeNotFound("test_node")
        let pathError = MultiPathError.noPathExists("A", "B")

        #expect(graphError.errorDescription?.contains("Invalid graph") ?? false)
        #expect(nodeError.errorDescription?.contains("Node not found") ?? false)
        #expect(pathError.errorDescription?.contains("No path exists") ?? false)
    }

    @Test("BridgePredictionError descriptions contain expected text")
    func bridgePredictionErrorDescriptions() {
        let unsupportedError = BridgePredictionError.unsupportedBridge(
            "test_bridge"
        )
        let invalidError = BridgePredictionError.invalidFeatures(
            "Test features"
        )
        let batchError = BridgePredictionError.batchSizeExceeded(100, 50)

        #expect(
            unsupportedError.errorDescription?.contains("Bridge not supported")
                ?? false
        )
        #expect(
            invalidError.errorDescription?.contains("Invalid features") ?? false
        )
        #expect(
            batchError.errorDescription?.contains(
                "Batch size 100 exceeds maximum 50"
            ) ?? false
        )
    }
}
