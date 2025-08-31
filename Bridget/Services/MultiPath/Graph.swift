//
//  Graph.swift
//  Bridget
//
//  Multi-Path Probability Traffic Prediction System
//  Purpose: Graph representation with adjacency lists and explicit bidirectionality
//  Integration: Used by PathEnumerationService for path finding
//  Acceptance: Adjacency from allEdges, bidirectionality explicit, validation methods
//  Known Limits: O(V+E) adjacency construction, O(1) edge lookup, memory proportional to edge count
//

import Foundation

/// Represents a directed graph for road network analysis
/// Maintains adjacency lists for efficient path enumeration
public struct Graph: Codable {
  /// All nodes in the graph
  public let nodes: [Node]

  /// All edges in the graph (explicit bidirectionality)
  public let allEdges: [Edge]

  /// Adjacency lists: nodeID -> [outgoing edges]
  public let adjacency: [NodeID: [Edge]]

  /// Reverse adjacency for bidirectional search (future optimization)
  public let reverseAdjacency: [NodeID: [Edge]]

  /// Mapping from nodeID to Node for quick lookups
  public let nodeMap: [NodeID: Node]

  /// Mapping from bridgeID to edges for bridge-specific queries
  public let bridgeMap: [String: [Edge]]

  public init(nodes: [Node], edges: [Edge]) throws {
    self.nodes = nodes
    self.allEdges = edges

    // Build node mapping
    var nodeMap: [NodeID: Node] = [:]
    for node in nodes {
      nodeMap[node.id] = node
    }
    self.nodeMap = nodeMap

    // Build adjacency lists
    var adjacency: [NodeID: [Edge]] = [:]
    var reverseAdjacency: [NodeID: [Edge]] = [:]

    for edge in edges {
      // Forward adjacency
      if adjacency[edge.from] == nil {
        adjacency[edge.from] = []
      }
      adjacency[edge.from]?.append(edge)

      // Reverse adjacency (for bidirectional search)
      if reverseAdjacency[edge.to] == nil {
        reverseAdjacency[edge.to] = []
      }
      reverseAdjacency[edge.to]?.append(edge)
    }

    self.adjacency = adjacency
    self.reverseAdjacency = reverseAdjacency

    // Build bridge mapping
    var bridgeMap: [String: [Edge]] = [:]
    for edge in edges {
      if let bridgeID = edge.bridgeID {
        if bridgeMap[bridgeID] == nil {
          bridgeMap[bridgeID] = []
        }
        bridgeMap[bridgeID]?.append(edge)
      }
    }
    self.bridgeMap = bridgeMap

    // Validate graph integrity
    try validateGraph()
  }

  // MARK: - Public Interface

  /// Get all outgoing edges from a node
  public func outgoingEdges(from nodeID: NodeID) -> [Edge] {
    return adjacency[nodeID] ?? []
  }

  /// Get all incoming edges to a node
  public func incomingEdges(to nodeID: NodeID) -> [Edge] {
    return reverseAdjacency[nodeID] ?? []
  }

  /// Get all edges for a specific bridge
  public func edges(for bridgeID: String) -> [Edge] {
    return bridgeMap[bridgeID] ?? []
  }

  /// Check if a node exists in the graph
  public func contains(nodeID: NodeID) -> Bool {
    return nodeMap[nodeID] != nil
  }

  /// Get a node by ID
  public func node(withID nodeID: NodeID) -> Node? {
    return nodeMap[nodeID]
  }

  /// Get all bridge edges in the graph
  public var bridgeEdges: [Edge] {
    return allEdges.filter { $0.isBridge }
  }

  /// Get all non-bridge edges in the graph
  public var roadEdges: [Edge] {
    return allEdges.filter { !$0.isBridge }
  }

  /// Get all bridge IDs in the graph
  public var bridgeIDs: [String] {
    return Array(bridgeMap.keys)
  }

  // MARK: - Validation

  /// Validate graph integrity and return validation result
  public func validate() -> GraphValidationResult {
    var errors: [String] = []
    var warnings: [String] = []

    // Check for orphaned nodes (no incoming or outgoing edges)
    for node in nodes {
      let outgoing = adjacency[node.id] ?? []
      let incoming = reverseAdjacency[node.id] ?? []

      if outgoing.isEmpty && incoming.isEmpty {
        warnings.append("Node '\(node.id)' has no connections")
      }
    }

    // Check for edges with invalid node references
    for edge in allEdges {
      if !contains(nodeID: edge.from) {
        errors.append("Edge references non-existent source node: \(edge.from)")
      }
      if !contains(nodeID: edge.to) {
        errors.append("Edge references non-existent destination node: \(edge.to)")
      }
    }

    // Check for bridge edges without bridgeID
    for edge in allEdges {
      if edge.isBridge && edge.bridgeID == nil {
        errors.append("Bridge edge from \(edge.from) to \(edge.to) missing bridgeID")
      }
    }

    // Check for non-canonical bridge IDs (enforce SeattleDrawbridges as single source of truth)
    // Allow synthetic test IDs (e.g., "bridge1", "bridge2") for testing purposes
    for edge in allEdges {
      if edge.isBridge, let bridgeID = edge.bridgeID {
        if !SeattleDrawbridges.isAcceptedBridgeID(bridgeID, allowSynthetic: true) {
          errors.append(
            "Bridge edge from \(edge.from) to \(edge.to) has non-canonical bridgeID '\(bridgeID)'. Must be one of: \(SeattleDrawbridges.BridgeID.allIDs) or synthetic test IDs (e.g., 'bridge1', 'bridge2')"
          )
        }
      }
    }

    // Check for non-bridge edges with bridgeID
    for edge in allEdges {
      if !edge.isBridge && edge.bridgeID != nil {
        warnings.append("Non-bridge edge from \(edge.from) to \(edge.to) has bridgeID")
      }
    }

    // Check for negative travel times
    for edge in allEdges {
      if edge.travelTime < 0 {
        errors.append("Edge from \(edge.from) to \(edge.to) has negative travel time")
      }
    }

    // Check for negative distances
    for edge in allEdges {
      if edge.distance < 0 {
        errors.append("Edge from \(edge.from) to \(edge.to) has negative distance")
      }
    }

    let isValid = errors.isEmpty
    return GraphValidationResult(isValid: isValid,
                                 errors: errors,
                                 warnings: warnings,
                                 nodeCount: nodes.count,
                                 edgeCount: allEdges.count,
                                 bridgeCount: bridgeEdges.count)
  }

  /// Validate graph and throw error if invalid
  private func validateGraph() throws {
    let result = validate()
    if !result.isValid {
      throw MultiPathError.invalidGraph(
        "Graph validation failed: \(result.errors.joined(separator: "; "))")
    }
  }

  // MARK: - Utility Methods

  /// Create a subgraph containing only specified nodes and their connecting edges
  public func subgraph(containing nodeIDs: Set<NodeID>) -> Graph? {
    let filteredNodes = nodes.filter { nodeIDs.contains($0.id) }
    let filteredEdges = allEdges.filter {
      nodeIDs.contains($0.from) && nodeIDs.contains($0.to)
    }

    do {
      return try Graph(nodes: filteredNodes, edges: filteredEdges)
    } catch {
      return nil
    }
  }

  /// Get the shortest path between two nodes using Dijkstra's algorithm
  /// Returns nil if no path exists
  public func shortestPath(from start: NodeID, to end: NodeID) -> RoutePath? {
    guard contains(nodeID: start), contains(nodeID: end) else {
      return nil
    }

    var distances: [NodeID: TimeInterval] = [:]
    var previous: [NodeID: NodeID?] = [:]
    var unvisited: Set<NodeID> = Set(nodes.map { $0.id })

    // Initialize distances
    for node in nodes {
      distances[node.id] = node.id == start ? 0 : TimeInterval.infinity
      previous[node.id] = nil
    }

    while !unvisited.isEmpty {
      // Find unvisited node with minimum distance
      let current = unvisited.min {
        distances[$0] ?? TimeInterval.infinity < distances[$1] ?? TimeInterval.infinity
      }
      guard let current = current else { break }

      if current == end {
        break  // Found destination
      }

      unvisited.remove(current)

      // Update distances to neighbors
      for edge in outgoingEdges(from: current) {
        let neighbor = edge.to
        if unvisited.contains(neighbor) {
          let newDistance = (distances[current] ?? TimeInterval.infinity) + edge.travelTime
          if newDistance < (distances[neighbor] ?? TimeInterval.infinity) {
            distances[neighbor] = newDistance
            previous[neighbor] = current
          }
        }
      }
    }

    // Reconstruct path
    guard distances[end] != TimeInterval.infinity else {
      return nil  // No path exists
    }

    var path: [NodeID] = []
    var edges: [Edge] = []
    var current = end

    while current != start {
      path.append(current)
      guard let prev = previous[current], let prev = prev else { return nil }

      // Find edge from prev to current
      if let edge = outgoingEdges(from: prev).first(where: { $0.to == current }) {
        edges.append(edge)
      }

      current = prev
    }
    path.append(start)

    // Reverse to get correct order
    path.reverse()
    edges.reverse()

    return RoutePath(nodes: path, edges: edges)
  }

  /// Check if a path exists between two nodes
  public func pathExists(from start: NodeID, to end: NodeID) -> Bool {
    return shortestPath(from: start, to: end) != nil
  }
}

// MARK: - Graph Factory Methods

public extension Graph {
  /// Create a tiny test graph for validation
  static func createTinyTestGraph() -> Graph {
    let nodes = [
      Node(id: "A", name: "Start", coordinates: (47.6062, -122.3321)),
      Node(id: "B", name: "Bridge", coordinates: (47.6065, -122.3325)),
      Node(id: "C", name: "End", coordinates: (47.6070, -122.3330)),
    ]

    let edges = [
      Edge(from: "A", to: "B", travelTime: 300, distance: 500, isBridge: true, bridgeID: "bridge1"),
      Edge(from: "B", to: "C", travelTime: 200, distance: 300, isBridge: false),
      // Bidirectional edges
      Edge(from: "B", to: "A", travelTime: 300, distance: 500, isBridge: true, bridgeID: "bridge1"),
      Edge(from: "C", to: "B", travelTime: 200, distance: 300, isBridge: false),
    ]

    do {
      return try Graph(nodes: nodes, edges: edges)
    } catch {
      fatalError("Failed to create test graph: \(error)")
    }
  }

  /// Create a small test graph with multiple paths
  static func createSmallTestGraph() -> Graph {
    let nodes = [
      Node(id: "A", name: "Start", coordinates: (47.6062, -122.3321)),
      Node(id: "B", name: "Bridge1", coordinates: (47.6065, -122.3325)),
      Node(id: "C", name: "Bridge2", coordinates: (47.6068, -122.3328)),
      Node(id: "D", name: "End", coordinates: (47.6070, -122.3330)),
    ]

    let edges = [
      // Path 1: A -> B -> D
      Edge(from: "A", to: "B", travelTime: 300, distance: 500, isBridge: true, bridgeID: "bridge1"),
      Edge(from: "B", to: "D", travelTime: 400, distance: 600, isBridge: false),

      // Path 2: A -> C -> D
      Edge(from: "A", to: "C", travelTime: 500, distance: 800, isBridge: true, bridgeID: "bridge2"),
      Edge(from: "C", to: "D", travelTime: 200, distance: 300, isBridge: false),

      // Bidirectional edges
      Edge(from: "B", to: "A", travelTime: 300, distance: 500, isBridge: true, bridgeID: "bridge1"),
      Edge(from: "D", to: "B", travelTime: 400, distance: 600, isBridge: false),
      Edge(from: "C", to: "A", travelTime: 500, distance: 800, isBridge: true, bridgeID: "bridge2"),
      Edge(from: "D", to: "C", travelTime: 200, distance: 300, isBridge: false),
    ]

    do {
      return try Graph(nodes: nodes, edges: edges)
    } catch {
      fatalError("Failed to create test graph: \(error)")
    }
  }
}
