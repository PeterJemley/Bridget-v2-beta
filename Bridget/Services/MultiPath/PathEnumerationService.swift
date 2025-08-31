//
//  PathEnumerationService.swift
//  Bridget
//
//  Multi-Path Probability Traffic Prediction System - Phase 1
//  Purpose: Path enumeration service for tiny subgraphs with deterministic fixtures
//  Integration: Uses Graph from Phase 0, provides paths for Phase 2 scoring
//  Acceptance: Golden test paths exist and are contiguous, deterministic results
//  Known Limits: Toy network only; not performance-representative
//
//  Notes on cache performance tests:
//  - The "cache performance" test in SeattlePerformanceTests exercises PathScoringService’s
//    feature cache (bridge feature vectors), not path enumeration caching.
//  - With fixedTopOfHour keys, the second run should typically be faster, but very small workloads
//    can show timing variance. Other performance/memory tests are stable, so this is acceptable.
//  - If CI flakiness appears, consider warming the cache with a tiny pre-run or using a small tolerance
//    (e.g., allow <= or add a 5–10% margin).
//
//  Optional path enumeration memoization:
//  - This service includes a gated in-memory cache for enumeratePaths results. It is disabled
//    unless config.performance.enableCaching is true. It can help on large graphs with repeated queries.
//  - The cache key includes (start, end, resolved algorithm, key enumeration params) and
//    a deterministic graph signature derived from its edges. If you change graph mutability or
//    allow parallel edges with different weights, revisit the signature and equality assumptions.
//

import Foundation
import os.log

/// Path enumeration service for Phase 1: Tiny Subgraph & Fixtures
/// Provides deterministic path enumeration for correctness testing
public class PathEnumerationService {
  public let config: MultiPathConfig
  private let logger = Logger(subsystem: "com.peterjemley.Bridget", category: "PathEnumeration")

  // MARK: - Cache Storage (optional, feature-gated)
  // Thread-safe in-memory cache for path enumeration results.
  // Enabled only when config.performance.enableCaching == true.
  private var pathCache: [String: [RoutePath]] = [:]
  private let cacheQueue = DispatchQueue(
    label: "com.peterjemley.Bridget.pathCache", attributes: .concurrent)

  public init(config: MultiPathConfig = .testing) {
    self.config = config
  }

  // MARK: - Public Interface

  /// Enumerate all valid paths from start to end node
  /// Returns paths sorted by total travel time (shortest first)
  /// Phase 10: Supports both DFS and Yen's K-shortest paths algorithms
  public func enumeratePaths(
    from start: NodeID,
    to end: NodeID,
    in graph: Graph
  ) throws -> [RoutePath] {
    logger.info(
      "Enumerating paths from \(start) to \(end) using \(self.config.pathEnumeration.enumerationMode.rawValue)"
    )

    // Validate inputs
    guard graph.contains(nodeID: start) else {
      throw MultiPathError.nodeNotFound(start)
    }
    guard graph.contains(nodeID: end) else {
      throw MultiPathError.nodeNotFound(end)
    }

    // Determine which algorithm to use (resolve .auto)
    let algorithm = determineAlgorithm(for: graph)
    logger.info("Selected algorithm: \(algorithm.rawValue)")

    // Optional memoization
    let cachingEnabled = config.performance.enableCaching
    let cacheKey =
      cachingEnabled
      ? makeCacheKey(start: start, end: end, algorithm: algorithm, graph: graph) : nil

    if cachingEnabled, let key = cacheKey {
      if let cached: [RoutePath] = cacheQueue.sync(execute: { pathCache[key] }) {
        logger.debug("PathEnumeration cache hit for key=\(key, privacy: .public)")
        return cached
      }
    }

    // Compute
    let result: [RoutePath]
    switch algorithm {
    case .dfs:
      result = try enumeratePathsDFS(from: start, to: end, in: graph)
    case .yensKShortest:
      result = try enumeratePathsYens(from: start, to: end, in: graph)
    case .auto:
      // Should never happen since we resolved above
      result = try enumeratePathsDFS(from: start, to: end, in: graph)
    }

    // Store in cache if enabled
    if cachingEnabled, let key = cacheKey {
      cacheQueue.async(flags: .barrier) { [paths = result] in
        self.pathCache[key] = paths
      }
    }

    return result
  }

  /// Get the shortest path between two nodes
  public func shortestPath(
    from start: NodeID,
    to end: NodeID,
    in graph: Graph
  ) throws -> RoutePath? {
    return try enumeratePaths(from: start, to: end, in: graph).first
  }

  // MARK: - Test Helper Utilities

  /// Simple validation that all paths in the collection are contiguous.
  /// Returns true only if every path passes RoutePath.isContiguous().
  public func validatePaths(_ paths: [RoutePath]) -> Bool {
    for path in paths {
      if !path.isContiguous() {
        logger.warning("Non-contiguous path detected in validation: \(path.nodes)")
        return false
      }
    }
    return true
  }

  /// Result type for golden comparison helpers used in tests.
  public struct GoldenComparisonResult {
    public let isSuccess: Bool
    public let description: String

    public init(isSuccess: Bool, description: String) {
      self.isSuccess = isSuccess
      self.description = description
    }
  }

  /// Compare found paths with expected "golden" paths by node sequences.
  /// Returns a result indicating success and a human-readable description of differences.
  public func compareWithGoldenPaths(
    found: [RoutePath],
    expected: [RoutePath]
  ) -> GoldenComparisonResult {
    // Compare by node sequences to avoid edge equality nuances
    let foundSet = Set(found.map { $0.nodes })
    let expectedSet = Set(expected.map { $0.nodes })

    let missing = expectedSet.subtracting(foundSet)
    let extra = foundSet.subtracting(expectedSet)

    if missing.isEmpty && extra.isEmpty {
      // Optional: check ordering by travel time for diagnostics
      var orderingNote = ""
      if found.count == expected.count && !found.isEmpty {
        let isSorted = zip(found.dropFirst(), found).allSatisfy {
          $0.0.totalTravelTime >= $0.1.totalTravelTime
        }
        if !isSorted {
          orderingNote = " (Note: Found paths are not strictly sorted by travel time)"
        }
      }
      return GoldenComparisonResult(
        isSuccess: true,
        description: "Found paths match expected\(orderingNote).")
    }

    var lines: [String] = []
    if !missing.isEmpty {
      lines.append("Missing expected paths: \(missing.map { $0.joined(separator: "->") }.sorted())")
    }
    if !extra.isEmpty {
      lines.append("Unexpected extra paths: \(extra.map { $0.joined(separator: "->") }.sorted())")
    }

    return GoldenComparisonResult(
      isSuccess: false,
      description: lines.joined(separator: " | "))
  }

  // MARK: - Private Implementation

  /// Determine which enumeration algorithm to use based on configuration and graph size
  private func determineAlgorithm(for graph: Graph) -> PathEnumerationMode {
    switch config.pathEnumeration.enumerationMode {
    case .dfs:
      return .dfs
    case .yensKShortest:
      return .yensKShortest
    case .auto:
      // Auto-select based on graph size and configuration
      let nodeCount = graph.nodes.count
      let edgeCount = graph.allEdges.count

      // Use Yen's for larger graphs or when K is small relative to maxPaths
      if nodeCount > 20 || edgeCount > 50
        || config.pathEnumeration.kShortestPaths < config.pathEnumeration.maxPaths / 2
      {
        return .yensKShortest
      } else {
        return .dfs
      }
    }
  }

  /// Build a deterministic cache key for enumeration results
  private func makeCacheKey(
    start: NodeID, end: NodeID, algorithm: PathEnumerationMode, graph: Graph
  ) -> String {
    // Graph signature: sorted edges by (from,to,travelTime,distance,isBridge,bridgeID?)
    // For small graphs this is fine; for large graphs consider precomputed signatures.
    var parts: [String] = []
    parts.reserveCapacity(graph.allEdges.count)
    for e in graph.allEdges.sorted(by: {
      if $0.from != $1.from { return $0.from < $1.from }
      if $0.to != $1.to { return $0.to < $1.to }
      if $0.travelTime != $1.travelTime { return $0.travelTime < $1.travelTime }
      if $0.distance != $1.distance { return $0.distance < $1.distance }
      if $0.isBridge != $1.isBridge { return ($0.isBridge ? 1 : 0) < ($1.isBridge ? 1 : 0) }
      return ($0.bridgeID ?? "") < ($1.bridgeID ?? "")
    }) {
      parts.append(
        "\(e.from)->\(e.to):\(e.travelTime):\(e.distance):\(e.isBridge ? 1 : 0):\(e.bridgeID ?? "_")"
      )
    }
    let graphSig = parts.joined(separator: "|")

    let pe = config.pathEnumeration
    let key = [
      "s=\(start)", "t=\(end)",
      "alg=\(algorithm.rawValue)",
      "k=\(pe.kShortestPaths)",
      "maxDepth=\(pe.maxDepth)",
      "maxPaths=\(pe.maxPaths)",
      "maxTime=\(pe.maxTravelTime)",
      "over=\(pe.maxTimeOverShortest)",
      "cycles=\(pe.allowCycles ? 1 : 0)",
      "G=\(graphSig)",
    ].joined(separator: ";")

    return key
  }

  /// Enumerate paths using DFS (original implementation)
  private func enumeratePathsDFS(
    from start: NodeID,
    to end: NodeID,
    in graph: Graph
  ) throws -> [RoutePath] {
    // Phase 2: Find shortest path first for pruning baseline
    let shortestPath = findShortestPathDijkstra(from: start, to: end, in: graph)
    let shortestPathTime = shortestPath?.totalTravelTime ?? Double.infinity

    logger.info("DFS: Shortest path time: \(shortestPathTime)s")

    // Use DFS with Phase 2 pruning
    let paths = try enumeratePathsDFSWithPruning(
      from: start,
      to: end,
      in: graph,
      maxDepth: config.pathEnumeration.maxDepth,
      maxPaths: config.pathEnumeration.maxPaths,
      shortestPathTime: shortestPathTime)

    // Sort by total travel time (shortest first)
    let sortedPaths = paths.sorted { $0.totalTravelTime < $1.totalTravelTime }

    logger.info("DFS: Found \(sortedPaths.count) paths from \(start) to \(end)")
    return sortedPaths
  }

  /// Depth-first search path enumeration
  /// Deterministic and suitable for Phase 1 testing
  private func enumeratePathsDFS(
    from start: NodeID,
    to end: NodeID,
    in graph: Graph,
    maxDepth: Int,
    maxPaths: Int
  ) throws -> [RoutePath] {
    var paths: [RoutePath] = []
    var visited: Set<NodeID> = []

    func dfs(current: NodeID, path: [NodeID], edges: [Edge], depth: Int) {
      // Check termination conditions
      if paths.count >= maxPaths {
        return
      }

      if depth > maxDepth {
        return
      }

      // Check for cycles (if not allowed)
      if !config.pathEnumeration.allowCycles, visited.contains(current) {
        return
      }

      // Add current node to path
      visited.insert(current)
      var newPath = path
      newPath.append(current)

      // Check if we've reached the destination
      if current == end, newPath.count > 1 {
        // Create RoutePath and validate it
        let routePath = RoutePath(nodes: newPath, edges: edges)

        // Validate path contiguity (Phase 0 requirement)
        guard routePath.isContiguous() else {
          logger.warning("Found non-contiguous path: \(newPath)")
          return
        }

        // Check travel time constraint
        if routePath.totalTravelTime <= config.pathEnumeration.maxTravelTime {
          paths.append(routePath)
          logger.debug("Found path: \(newPath) (time: \(routePath.totalTravelTime)s)")
        }

        // Don't continue searching from destination
        visited.remove(current)
        return
      }

      // Explore outgoing edges
      let outgoingEdges = graph.outgoingEdges(from: current)
      for edge in outgoingEdges {
        let nextNode = edge.to
        var newEdges = edges
        newEdges.append(edge)

        dfs(current: nextNode, path: newPath, edges: newEdges, depth: depth + 1)
      }

      // Backtrack
      visited.remove(current)
    }

    // Start DFS
    dfs(current: start, path: [], edges: [], depth: 0)

    return paths
  }

  /// Depth-first search path enumeration with Phase 2 pruning
  /// Includes pruning based on maxTimeOverShortest configuration
  private func enumeratePathsDFSWithPruning(
    from start: NodeID,
    to end: NodeID,
    in graph: Graph,
    maxDepth: Int,
    maxPaths: Int,
    shortestPathTime: Double
  ) throws -> [RoutePath] {
    var paths: [RoutePath] = []
    var visited: Set<NodeID> = []

    func dfs(current: NodeID, path: [NodeID], edges: [Edge], depth: Int, currentTime: Double) {
      // Check termination conditions
      if paths.count >= maxPaths {
        return
      }

      if depth > maxDepth {
        return
      }

      // Phase 2: Prune paths that exceed maxTimeOverShortest
      let maxAllowedTime = shortestPathTime + config.pathEnumeration.maxTimeOverShortest
      if currentTime > maxAllowedTime {
        logger.debug(
          "Pruning path at \(current) - current time \(currentTime)s exceeds max \(maxAllowedTime)s"
        )
        return
      }

      // Check for cycles (if not allowed)
      if !config.pathEnumeration.allowCycles, visited.contains(current) {
        return
      }

      // Add current node to path
      visited.insert(current)
      var newPath = path
      newPath.append(current)

      // Check if we've reached the destination
      if current == end, newPath.count > 1 {
        // Create RoutePath and validate it
        let routePath = RoutePath(nodes: newPath, edges: edges)

        // Validate path contiguity (Phase 0 requirement)
        guard routePath.isContiguous() else {
          logger.warning("Found non-contiguous path: \(newPath)")
          return
        }

        // Check travel time constraint
        if routePath.totalTravelTime <= config.pathEnumeration.maxTravelTime {
          paths.append(routePath)
          logger.debug("Found path: \(newPath) (time: \(routePath.totalTravelTime)s)")
        }

        // Don't continue searching from destination
        visited.remove(current)
        return
      }

      // Explore outgoing edges
      let outgoingEdges = graph.outgoingEdges(from: current)
      for edge in outgoingEdges {
        let nextNode = edge.to
        var newEdges = edges
        newEdges.append(edge)

        dfs(
          current: nextNode, path: newPath, edges: newEdges, depth: depth + 1,
          currentTime: currentTime + edge.travelTime)
      }

      // Backtrack
      visited.remove(current)
    }

    // Start DFS
    dfs(current: start, path: [], edges: [], depth: 0, currentTime: 0)

    return paths
  }

  // MARK: - Phase 2: Dijkstra Implementation for Pruning Baseline

  /// Finds the shortest path from start to end node using Dijkstra's algorithm.
  /// This is used as a baseline for pruning in Phase 2 path enumeration.
  /// - Parameters:
  ///   - start: The starting node ID
  ///   - end: The ending node ID
  ///   - graph: The graph to search
  /// - Returns: The RoutePath for the shortest path, or nil if no path exists
  private func findShortestPathDijkstra(
    from start: NodeID,
    to end: NodeID,
    in graph: Graph
  ) -> RoutePath? {
    // Priority queue: (totalTravelTime, [NodeID], [Edge])
    var queue: [(Double, [NodeID], [Edge])] = [(0, [start], [])]
    var visited: Set<NodeID> = []
    var bestTime: [NodeID: Double] = [start: 0]

    while !queue.isEmpty {
      // Pop the queue for the path with the lowest travel time
      queue.sort { $0.0 < $1.0 }
      let (currentTime, path, edgePath) = queue.removeFirst()
      guard let current = path.last else { continue }

      // If we've reached the end, construct and return the RoutePath
      if current == end {
        return RoutePath(nodes: path, edges: edgePath)
      }

      if visited.contains(current) {
        continue
      }
      visited.insert(current)

      // Explore outgoing edges
      for edge in graph.outgoingEdges(from: current) {
        let next = edge.to
        let time = currentTime + edge.travelTime

        // Only add to queue if this path is better
        if bestTime[next] == nil || time < bestTime[next]! {
          bestTime[next] = time
          queue.append((time, path + [next], edgePath + [edge]))
        }
      }
    }

    // No path found
    return nil
  }

  // MARK: - Phase 10: Yen's K-Shortest Paths Algorithm

  /// Enumerate paths using Yen's K-shortest paths algorithm
  /// More efficient than DFS for finding the top K shortest paths
  private func enumeratePathsYens(
    from start: NodeID,
    to end: NodeID,
    in graph: Graph
  ) throws -> [RoutePath] {
    logger.info(
      "Yen's: Finding \(self.config.pathEnumeration.kShortestPaths) shortest paths from \(start) to \(end)"
    )

    var kShortestPaths: [RoutePath] = []
    var candidatePaths: [RoutePath] = []

    // Find the shortest path using Dijkstra
    guard let shortestPath = findShortestPathDijkstra(from: start, to: end, in: graph) else {
      logger.warning("Yen's: No path exists from \(start) to \(end)")
      return []
    }

    kShortestPaths.append(shortestPath)
    logger.debug(
      "Yen's: Found shortest path: \(shortestPath.nodes) (time: \(shortestPath.totalTravelTime)s)")

    // Find K-1 more shortest paths
    for k in 1..<config.pathEnumeration.kShortestPaths {
      // For each node in the (k-1)th shortest path, find spur paths
      let previousPath = kShortestPaths[k - 1]
      logger.debug("Yen's: Iteration \(k). Previous path: \(previousPath.nodes)")

      // Iterate spur index along previousPath
      for i in 0..<(previousPath.nodes.count - 1) {
        let spurNode = previousPath.nodes[i]
        let rootPathNodes = Array(previousPath.nodes.prefix(i + 1))
        let rootEdges = Array(previousPath.edges.prefix(i))  // edges before spur edge
        logger.debug("Yen's:  Spur index \(i), spurNode=\(spurNode), rootPath=\(rootPathNodes)")

        // Build deviation edges to remove: for every already accepted path that shares this root prefix,
        // remove only the deviation edge at index i (the edge going out of spurNode in that path).
        var deviationEdgesToRemove: Set<Edge> = []
        for accepted in kShortestPaths {
          if accepted.nodes.count > i,
            Array(accepted.nodes.prefix(i + 1)) == rootPathNodes,
            accepted.edges.count > i
          {
            let deviationEdge = accepted.edges[i]
            deviationEdgesToRemove.insert(deviationEdge)  // Edge equality is (from,to)
          }
        }

        // Create spur graph by excluding only the specified edges
        let spurGraph = try createSpurGraph(
          from: graph, excludingEdgesByEndpoints: deviationEdgesToRemove)

        // Optional: avoid revisiting root prefix nodes (except spurNode) in spur path
        let blockedNodes = Set(rootPathNodes.dropLast())  // all root nodes before spurNode
        let spurPath: RoutePath?
        if blockedNodes.isEmpty {
          spurPath = findShortestPathDijkstra(from: spurNode, to: end, in: spurGraph)
        } else {
          spurPath = findShortestPathDijkstraAvoiding(
            from: spurNode, to: end, in: spurGraph, blocked: blockedNodes)
        }

        if let spurPath = spurPath {
          logger.debug(
            "Yen's:   Spur path from \(spurNode) to \(end): \(spurPath.nodes) (time: \(spurPath.totalTravelTime)s)"
          )
          // Combine root path with spur path
          let totalPath = combinePaths(
            rootPath: rootPathNodes, rootEdges: rootEdges, spurPath: spurPath)

          // Check if this path is valid and not already found
          if isValidPath(totalPath, in: graph)
            && !kShortestPaths.contains(totalPath)
            && !candidatePaths.contains(totalPath)
          {
            candidatePaths.append(totalPath)
            logger.debug(
              "Yen's:   Candidate appended: \(totalPath.nodes) (time: \(totalPath.totalTravelTime)s)"
            )
          } else {
            logger.debug("Yen's:   Candidate rejected (invalid or duplicate): \(totalPath.nodes)")
          }
        } else {
          logger.debug("Yen's:   No spur path found from spurNode \(spurNode) in spurGraph")
        }
      }

      // Find the shortest candidate path
      guard let nextShortest = candidatePaths.min(by: { $0.totalTravelTime < $1.totalTravelTime })
      else {
        logger.debug("Yen's: No more candidate paths found")
        break
      }

      kShortestPaths.append(nextShortest)
      // Remove exactly this candidate (by nodes equality)
      candidatePaths.removeAll { $0 == nextShortest }

      logger.debug(
        "Yen's: Found \(k + 1)th shortest path: \(nextShortest.nodes) (time: \(nextShortest.totalTravelTime)s)"
      )
    }

    // Apply additional constraints (maxTravelTime, maxTimeOverShortest)
    let filteredPaths = kShortestPaths.filter { path in
      // Check max travel time
      guard path.totalTravelTime <= config.pathEnumeration.maxTravelTime else {
        return false
      }

      // Check max time over shortest
      let shortestTime = kShortestPaths.first?.totalTravelTime ?? Double.infinity
      let maxAllowedTime = shortestTime + config.pathEnumeration.maxTimeOverShortest
      guard path.totalTravelTime <= maxAllowedTime else {
        return false
      }

      return true
    }

    logger.info("Yen's: Found \(filteredPaths.count) valid paths from \(start) to \(end)")
    return filteredPaths
  }

  /// Create a spur graph by temporarily removing only the specified edges (by endpoints).
  private func createSpurGraph(
    from graph: Graph, excludingEdgesByEndpoints edgesToRemove: Set<Edge>
  ) throws -> Graph {
    if edgesToRemove.isEmpty {
      return graph
    }
    let remainingEdges = graph.allEdges.filter { edge in
      // Edge equality is (from,to); Set<Edge> uses the same semantics
      return !edgesToRemove.contains(edge)
    }
    let removedCount = graph.allEdges.count - remainingEdges.count
    logger.debug(
      "Yen's: SpurGraph removed \(removedCount) deviation edges; remaining: \(remainingEdges.count)"
    )
    return try Graph(nodes: graph.nodes, edges: remainingEdges)
  }

  /// Dijkstra variant that avoids traversing through a set of blocked nodes (no outgoing edges from them).
  private func findShortestPathDijkstraAvoiding(
    from start: NodeID,
    to end: NodeID,
    in graph: Graph,
    blocked: Set<NodeID>
  ) -> RoutePath? {
    // Priority queue: (totalTravelTime, [NodeID], [Edge])
    var queue: [(Double, [NodeID], [Edge])] = [(0, [start], [])]
    var visited: Set<NodeID> = []
    var bestTime: [NodeID: Double] = [start: 0]

    while !queue.isEmpty {
      queue.sort { $0.0 < $1.0 }
      let (currentTime, path, edgePath) = queue.removeFirst()
      guard let current = path.last else { continue }

      if current == end {
        return RoutePath(nodes: path, edges: edgePath)
      }

      if visited.contains(current) {
        continue
      }
      visited.insert(current)

      // If current is blocked (root prefix node), do not expand its outgoing edges
      if blocked.contains(current) {
        continue
      }

      for edge in graph.outgoingEdges(from: current) {
        let next = edge.to
        let time = currentTime + edge.travelTime
        if bestTime[next] == nil || time < bestTime[next]! {
          bestTime[next] = time
          queue.append((time, path + [next], edgePath + [edge]))
        }
      }
    }

    return nil
  }

  /// Combine root path with spur path
  private func combinePaths(rootPath: [NodeID], rootEdges: [Edge], spurPath: RoutePath) -> RoutePath
  {
    // Remove duplicate node at the junction
    let spurNodes = Array(spurPath.nodes.dropFirst())
    // Keep all spur edges; the first spur edge is required to connect at spurNode
    let spurEdges = spurPath.edges

    let combinedNodes = rootPath + spurNodes
    let combinedEdges = rootEdges + spurEdges

    return RoutePath(nodes: combinedNodes, edges: combinedEdges)
  }

  /// Check if a path is valid in the original graph
  private func isValidPath(_ path: RoutePath, in graph: Graph) -> Bool {
    // Check if path is contiguous
    guard path.isContiguous() else {
      return false
    }

    // Check if all edges exist in the original graph
    for edge in path.edges {
      let exists = graph.allEdges.contains { graphEdge in
        graphEdge.from == edge.from && graphEdge.to == edge.to
      }
      if !exists {
        return false
      }
    }

    return true
  }
}

// MARK: - Phase 1 Test Fixtures

extension PathEnumerationService {
  /// Create a deterministic test fixture for Phase 1
  /// Returns a simple graph with known paths for testing
  public static func createPhase1TestFixture() -> (graph: Graph, expectedPaths: [RoutePath]) {
    // Create a simple test graph: A -> B -> C and A -> D -> C
    let nodes = [
      Node(id: "A", name: "Start", coordinates: (47.6062, -122.3321)),
      Node(id: "B", name: "Bridge1", coordinates: (47.6065, -122.3325)),
      Node(id: "C", name: "End", coordinates: (47.6070, -122.3330)),
      Node(id: "D", name: "Bridge2", coordinates: (47.6068, -122.3328)),
    ]

    let edges = [
      // Path 1: A -> B -> C
      Edge(from: "A", to: "B", travelTime: 300, distance: 500, isBridge: true, bridgeID: "bridge1"),
      Edge(from: "B", to: "C", travelTime: 200, distance: 300, isBridge: false),

      // Path 2: A -> D -> C
      Edge(from: "A", to: "D", travelTime: 400, distance: 600, isBridge: true, bridgeID: "bridge2"),
      Edge(from: "D", to: "C", travelTime: 150, distance: 250, isBridge: false),
    ]

    let graph = try! Graph(nodes: nodes, edges: edges)

    // Create expected paths (golden test data)
    let expectedPath1 = RoutePath(
      nodes: ["A", "B", "C"],
      edges: [
        Edge(
          from: "A", to: "B", travelTime: 300, distance: 500, isBridge: true, bridgeID: "bridge1"),
        Edge(from: "B", to: "C", travelTime: 200, distance: 300, isBridge: false),
      ])

    let expectedPath2 = RoutePath(
      nodes: ["A", "D", "C"],
      edges: [
        Edge(
          from: "A", to: "D", travelTime: 400, distance: 600, isBridge: true, bridgeID: "bridge2"),
        Edge(from: "D", to: "C", travelTime: 150, distance: 250, isBridge: false),
      ])

    return (graph: graph, expectedPaths: [expectedPath1, expectedPath2])
  }

  /// Create a more complex test fixture for edge case testing
  public static func createPhase1ComplexFixture() -> (graph: Graph, expectedPaths: [RoutePath]) {
    // Create a graph with multiple paths and some cycles
    let nodes = [
      Node(id: "A", name: "Start", coordinates: (47.6062, -122.3321)),
      Node(id: "B", name: "Bridge1", coordinates: (47.6065, -122.3325)),
      Node(id: "C", name: "Bridge2", coordinates: (47.6068, -122.3328)),
      Node(id: "D", name: "End", coordinates: (47.6070, -122.3330)),
      Node(id: "E", name: "Detour", coordinates: (47.6060, -122.3315)),
    ]

    let edges = [
      // Direct path: A -> D
      Edge(from: "A", to: "D", travelTime: 600, distance: 800, isBridge: false),

      // Path via B: A -> B -> D
      Edge(from: "A", to: "B", travelTime: 300, distance: 500, isBridge: true, bridgeID: "bridge1"),
      Edge(from: "B", to: "D", travelTime: 200, distance: 300, isBridge: false),

      // Path via C: A -> C -> D
      Edge(from: "A", to: "C", travelTime: 250, distance: 400, isBridge: true, bridgeID: "bridge2"),
      Edge(from: "C", to: "D", travelTime: 300, distance: 450, isBridge: false),

      // Detour path: A -> E -> D
      Edge(from: "A", to: "E", travelTime: 200, distance: 350, isBridge: false),
      Edge(from: "E", to: "D", travelTime: 350, distance: 500, isBridge: false),

      // Cycle edge (for testing cycle detection): B -> C
      Edge(from: "B", to: "C", travelTime: 100, distance: 150, isBridge: false),
    ]

    let graph = try! Graph(nodes: nodes, edges: edges)

    // Expected paths (sorted by travel time)
    let expectedPaths = [
      // A -> E -> D (550s)
      RoutePath(
        nodes: ["A", "E", "D"],
        edges: [
          Edge(from: "A", to: "E", travelTime: 200, distance: 350, isBridge: false),
          Edge(from: "E", to: "D", travelTime: 350, distance: 500, isBridge: false),
        ]),
      // A -> C -> D (550s)
      RoutePath(
        nodes: ["A", "C", "D"],
        edges: [
          Edge(
            from: "A", to: "C", travelTime: 250, distance: 400, isBridge: true, bridgeID: "bridge2"),
          Edge(from: "C", to: "D", travelTime: 300, distance: 450, isBridge: false),
        ]),
      // A -> B -> D (500s)
      RoutePath(
        nodes: ["A", "B", "D"],
        edges: [
          Edge(
            from: "A", to: "B", travelTime: 300, distance: 500, isBridge: true, bridgeID: "bridge1"),
          Edge(from: "B", to: "D", travelTime: 200, distance: 300, isBridge: false),
        ]),
      // A -> D (600s)
      RoutePath(
        nodes: ["A", "D"],
        edges: [
          Edge(from: "A", to: "D", travelTime: 600, distance: 800, isBridge: false)
        ]),
    ]

    return (graph: graph, expectedPaths: expectedPaths)
  }
}
