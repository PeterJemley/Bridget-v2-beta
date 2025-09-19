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

import Foundation
import Testing

@testable import Bridget

@Suite("Path Enumeration Service - Swift Testing")
struct PathEnumerationServiceTests {
    var service: PathEnumerationService

    init() {
        service = PathEnumerationService(config: .testing)
    }

    // MARK: - Golden Test Fixtures

    @Test
    func phase1SimpleFixture() throws {
        // Test the basic fixture: A -> B -> C and A -> D -> C
        let (graph, expectedPaths) =
            PathEnumerationService.createPhase1TestFixture()

        // Enumerate paths from A to C
        let foundPaths = try service.enumeratePaths(
            from: "A",
            to: "C",
            in: graph
        )

        // Verify we found exactly 2 paths
        #expect(foundPaths.count == 2, "Should find exactly 2 paths")

        // Verify all paths are valid
        #expect(
            service.validatePaths(foundPaths),
            "All paths should be valid"
        )

        // Compare with golden paths
        let comparison = service.compareWithGoldenPaths(
            found: foundPaths,
            expected: expectedPaths
        )
        #expect(
            comparison.isSuccess,
            "Should match golden paths: \(comparison.description)"
        )

        // Verify paths are sorted by travel time (shortest first)
        #expect(foundPaths[0].totalTravelTime < foundPaths[1].totalTravelTime)

        // Verify specific paths exist
        let path1Nodes = foundPaths.map { $0.nodes }
        #expect(
            path1Nodes.contains(["A", "B", "C"]),
            "Should contain A->B->C path"
        )
        #expect(
            path1Nodes.contains(["A", "D", "C"]),
            "Should contain A->D->C path"
        )
    }

    @Test
    func phase1ComplexFixture() throws {
        // Test the complex fixture with multiple paths and cycles
        let (graph, _) = PathEnumerationService.createPhase1ComplexFixture()

        // Enumerate paths from A to D
        let foundPaths = try service.enumeratePaths(
            from: "A",
            to: "D",
            in: graph
        )

        // Verify we found exactly 4 paths
        #expect(foundPaths.count == 4, "Should find exactly 4 paths")

        // Verify all paths are valid
        #expect(
            service.validatePaths(foundPaths),
            "All paths should be valid"
        )

        // Verify paths are sorted by travel time (shortest first)
        for i in 0..<(foundPaths.count - 1) {
            #expect(
                foundPaths[i].totalTravelTime
                    <= foundPaths[i + 1].totalTravelTime
            )
        }

        // Verify specific expected paths exist
        let pathNodes = foundPaths.map { $0.nodes }
        #expect(
            pathNodes.contains(["A", "E", "D"]),
            "Should contain A->E->D path"
        )
        #expect(
            pathNodes.contains(["A", "C", "D"]),
            "Should contain A->C->D path"
        )
        #expect(
            pathNodes.contains(["A", "B", "D"]),
            "Should contain A->B->D path"
        )
        #expect(
            pathNodes.contains(["A", "D"]),
            "Should contain A->D path"
        )
    }

    // MARK: - Path Validation Tests

    @Test
    func pathContiguityValidation() throws {
        let (graph, _) = PathEnumerationService.createPhase1TestFixture()

        let paths = try service.enumeratePaths(from: "A", to: "C", in: graph)

        // All paths should be contiguous
        for path in paths {
            #expect(
                path.isContiguous(),
                "Path \(path.nodes) should be contiguous"
            )
        }
    }

    @Test
    func pathTravelTimeValidation() throws {
        let (graph, _) = PathEnumerationService.createPhase1TestFixture()

        let paths = try service.enumeratePaths(from: "A", to: "C", in: graph)

        // All paths should have positive travel time
        for path in paths {
            #expect(
                path.totalTravelTime > 0,
                "Path \(path.nodes) should have positive travel time"
            )
        }
    }

    @Test
    func pathDistanceValidation() throws {
        let (graph, _) = PathEnumerationService.createPhase1TestFixture()

        let paths = try service.enumeratePaths(from: "A", to: "C", in: graph)

        // All paths should have positive distance
        for path in paths {
            #expect(
                path.totalDistance > 0,
                "Path \(path.nodes) should have positive distance"
            )
        }
    }

    // MARK: - Error Handling Tests

    @Test
    func nodeNotFoundError() throws {
        let (graph, _) = PathEnumerationService.createPhase1TestFixture()

        // Try to find path from non-existent node
        do {
            _ = try service.enumeratePaths(from: "Z", to: "C", in: graph)
            Issue.record("Expected to throw .nodeNotFound for start node Z")
        } catch {
            #expect(error as? MultiPathError == .nodeNotFound("Z"))
        }

        // Try to find path to non-existent node
        do {
            _ = try service.enumeratePaths(from: "A", to: "Z", in: graph)
            Issue.record("Expected to throw .nodeNotFound for end node Z")
        } catch {
            #expect(error as? MultiPathError == .nodeNotFound("Z"))
        }
    }

    @Test
    func noPathExists() throws {
        // Create a disconnected graph
        let nodes = [
            Node(id: "A", name: "Start", coordinates: (0, 0)),
            Node(id: "B", name: "End", coordinates: (1, 1)),
        ]
        let edges: [Edge] = []  // No edges between A and B

        let graph = try Graph(nodes: nodes, edges: edges)

        // Should return empty array (no error, just no paths)
        let paths = try service.enumeratePaths(from: "A", to: "B", in: graph)
        #expect(
            paths.isEmpty,
            "Should return empty array when no path exists"
        )
    }

    // MARK: - Configuration Tests

    @Test
    func maxPathsLimit() throws {
        let (graph, _) = PathEnumerationService.createPhase1ComplexFixture()

        // Create service with very low maxPaths limit
        let limitedService = PathEnumerationService(
            config: MultiPathConfig.testing
        )

        let paths = try limitedService.enumeratePaths(
            from: "A",
            to: "D",
            in: graph
        )

        // Should respect maxPaths limit
        #expect(paths.count <= limitedService.config.pathEnumeration.maxPaths)
    }

    @Test
    func maxDepthLimit() throws {
        // Create a deep graph
        let nodes = (0...10).map { i in
            Node(
                id: "\(i)",
                name: "Node\(i)",
                coordinates: (Double(i), Double(i))
            )
        }

        let edges = (0..<10).map { i in
            Edge(from: "\(i)", to: "\(i + 1)", travelTime: 100, distance: 100)
        }

        let graph = try Graph(nodes: nodes, edges: edges)

        // Create service with low maxDepth
        var config = MultiPathConfig.testing
        config.pathEnumeration.maxDepth = 3
        let limitedService = PathEnumerationService(config: config)

        let paths = try limitedService.enumeratePaths(
            from: "0",
            to: "10",
            in: graph
        )

        // Should find no paths due to depth limit
        #expect(paths.isEmpty, "Should find no paths due to depth limit")
    }

    @Test
    func maxTravelTimeLimit() throws {
        let (graph, _) = PathEnumerationService.createPhase1ComplexFixture()

        // Create service with very low maxTravelTime
        var config = MultiPathConfig.testing
        config.pathEnumeration.maxTravelTime = 100  // Very low limit
        let limitedService = PathEnumerationService(config: config)

        let paths = try limitedService.enumeratePaths(
            from: "A",
            to: "D",
            in: graph
        )

        // All paths should respect travel time limit
        for path in paths {
            #expect(
                path.totalTravelTime <= config.pathEnumeration.maxTravelTime
            )
        }
    }

    // MARK: - Cycle Detection Tests

    @Test
    func cycleDetection() throws {
        let (graph, _) = PathEnumerationService.createPhase1ComplexFixture()

        // Test with cycles allowed
        var cycleAllowedConfig = MultiPathConfig.testing
        cycleAllowedConfig.pathEnumeration.allowCycles = true
        let cycleAllowedService = PathEnumerationService(
            config: cycleAllowedConfig
        )

        let pathsWithCycles = try cycleAllowedService.enumeratePaths(
            from: "A",
            to: "D",
            in: graph
        )

        // Test with cycles not allowed
        var cycleForbiddenConfig = MultiPathConfig.testing
        cycleForbiddenConfig.pathEnumeration.allowCycles = false
        let cycleForbiddenService = PathEnumerationService(
            config: cycleForbiddenConfig
        )

        let pathsWithoutCycles = try cycleForbiddenService.enumeratePaths(
            from: "A",
            to: "D",
            in: graph
        )

        // Should find same number of paths (our test graph doesn't have problematic cycles)
        #expect(pathsWithCycles.count == pathsWithoutCycles.count)
    }

    // MARK: - Shortest Path Tests

    @Test
    func shortestPath() throws {
        let (graph, _) = PathEnumerationService.createPhase1ComplexFixture()

        let shortestPath = try service.shortestPath(
            from: "A",
            to: "D",
            in: graph
        )

        #expect(shortestPath != nil, "Should find shortest path")
        #expect(
            shortestPath?.nodes == ["A", "B", "D"],
            "Shortest path should be A->B->D (500s)"
        )
        #expect(
            shortestPath?.totalTravelTime == 500,
            "Shortest path should have 500s travel time"
        )
    }

    @Test
    func shortestPathNoPathExists() throws {
        // Create disconnected graph
        let nodes = [
            Node(id: "A", name: "Start", coordinates: (0, 0)),
            Node(id: "B", name: "End", coordinates: (1, 1)),
        ]
        let edges: [Edge] = []

        let graph = try Graph(nodes: nodes, edges: edges)

        let shortestPath = try service.shortestPath(
            from: "A",
            to: "B",
            in: graph
        )

        #expect(shortestPath == nil, "Should return nil when no path exists")
    }

    // MARK: - Deterministic Results Tests

    @Test
    func deterministicResults() throws {
        let (graph, _) = PathEnumerationService.createPhase1ComplexFixture()

        // Run enumeration multiple times
        let results1 = try service.enumeratePaths(from: "A", to: "D", in: graph)
        let results2 = try service.enumeratePaths(from: "A", to: "D", in: graph)
        let results3 = try service.enumeratePaths(from: "A", to: "D", in: graph)

        // All results should be identical
        #expect(results1.count == results2.count)
        #expect(results2.count == results3.count)

        for i in 0..<results1.count {
            #expect(results1[i].nodes == results2[i].nodes)
            #expect(results2[i].nodes == results3[i].nodes)
            #expect(results1[i].totalTravelTime == results2[i].totalTravelTime)
            #expect(results2[i].totalTravelTime == results3[i].totalTravelTime)
        }
    }

    // MARK: - Performance Tests (Basic)

    @Test("Performance on tiny graph (sanity check)")
    func performanceOnTinyGraph() throws {
        let (graph, _) = PathEnumerationService.createPhase1TestFixture()

        // Basic elapsed time check; not a micro-benchmark
        let start = Date()
        _ = try service.enumeratePaths(from: "A", to: "C", in: graph)
        let elapsed = Date().timeIntervalSince(start)

        // Sanity bound: tiny graph should enumerate very fast
        #expect(
            elapsed < 0.1,
            "Enumeration on tiny graph should be fast; elapsed=\(elapsed)s"
        )
    }

    // MARK: - Edge Case Tests

    @Test
    func selfLoop() throws {
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
        #expect(paths.count == 1)
        #expect(paths[0].nodes == ["A", "B"])
    }

    @Test
    func emptyGraph() throws {
        let nodes: [Node] = []
        let edges: [Edge] = []

        let graph = try Graph(nodes: nodes, edges: edges)

        // Should throw error when nodes don't exist in empty graph
        do {
            _ = try service.enumeratePaths(from: "A", to: "B", in: graph)
            Issue.record("Expected .nodeNotFound(\"A\") on empty graph")
        } catch {
            #expect(error as? MultiPathError == .nodeNotFound("A"))
        }
    }

    // MARK: - Phase 2 Property Tests

    /// Property test: Increasing maxDepth/maxPaths never reduces valid results
    /// This tests the monotonicity property for Phase 2 pruning
    @Test
    func monotonicityProperty() throws {
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
                    let pathsA = try serviceA.enumeratePaths(
                        from: startNode.id,
                        to: endNode.id,
                        in: graph
                    )
                    let pathsB = try serviceB.enumeratePaths(
                        from: startNode.id,
                        to: endNode.id,
                        in: graph
                    )

                    // All paths found with lower maxDepth should also be found with higher maxDepth
                    for pathA in pathsA {
                        #expect(
                            pathsB.contains { $0.nodes == pathA.nodes },
                            "Path \(pathA.nodes) found with maxDepth \(configA.pathEnumeration.maxDepth) should also be found with maxDepth \(configB.pathEnumeration.maxDepth)"
                        )
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
                    let pathsA = try serviceA.enumeratePaths(
                        from: startNode.id,
                        to: endNode.id,
                        in: graph
                    )
                    let pathsB = try serviceB.enumeratePaths(
                        from: startNode.id,
                        to: endNode.id,
                        in: graph
                    )

                    // All paths found with lower maxPaths should also be found with higher maxPaths
                    for pathA in pathsA {
                        #expect(
                            pathsB.contains { $0.nodes == pathA.nodes },
                            "Path \(pathA.nodes) found with maxPaths \(configA.pathEnumeration.maxPaths) should also be found with maxPaths \(configB.pathEnumeration.maxPaths)"
                        )
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
                    let pathsA = try serviceA.enumeratePaths(
                        from: startNode.id,
                        to: endNode.id,
                        in: graph
                    )
                    let pathsB = try serviceB.enumeratePaths(
                        from: startNode.id,
                        to: endNode.id,
                        in: graph
                    )

                    // All paths found with lower maxTimeOverShortest should also be found with higher maxTimeOverShortest
                    for pathA in pathsA {
                        #expect(
                            pathsB.contains { $0.nodes == pathA.nodes },
                            "Path \(pathA.nodes) found with maxTimeOverShortest \(configA.pathEnumeration.maxTimeOverShortest)s should also be found with maxTimeOverShortest \(configB.pathEnumeration.maxTimeOverShortest)s"
                        )
                    }
                }
            }
        }
    }

    /// Test that Phase 2 pruning actually works by verifying paths are excluded
    @Test
    func phase2PruningEffectiveness() throws {
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
        let restrictivePaths = try restrictiveService.enumeratePaths(
            from: "A",
            to: "D",
            in: graph
        )
        let permissivePaths = try permissiveService.enumeratePaths(
            from: "A",
            to: "D",
            in: graph
        )

        // Restrictive config should find fewer or equal paths
        #expect(
            restrictivePaths.count <= permissivePaths.count,
            "Restrictive pruning should find fewer or equal paths"
        )

        // All paths found with restrictive config should also be found with permissive config
        for restrictivePath in restrictivePaths {
            #expect(
                permissivePaths.contains { $0.nodes == restrictivePath.nodes },
                "Path \(restrictivePath.nodes) found with restrictive pruning should also be found with permissive pruning"
            )
        }
    }
}
