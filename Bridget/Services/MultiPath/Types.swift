//
//  Types.swift
//  Bridget
//
//  Multi-Path Probability Traffic Prediction System
//  Purpose: Core types for graph-based route enumeration and probability scoring
//  Integration: Used by PathEnumerationService, ETAEstimator, PathScoringService
//  Acceptance: Strong typing, explicit bidirectionality, canonical time units
//  Known Limits: NodeID must be Hashable, all durations in TimeInterval (seconds)
//

import Foundation

// MARK: - Core Types

/// Geographic coordinates
public struct Coordinates: Codable, Hashable {
  public let latitude: Double
  public let longitude: Double

  public init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }
}

/// Unique identifier for a node in the road network
/// Must be Hashable for graph adjacency lookups
public typealias NodeID = String

/// Represents a node (intersection, landmark) in the road network
public struct Node: Hashable, Codable {
  public let id: NodeID
  public let name: String
  public let coordinates: Coordinates

  public init(id: NodeID, name: String, coordinates: (latitude: Double, longitude: Double)) {
    self.id = id
    self.name = name
    self.coordinates = Coordinates(latitude: coordinates.latitude, longitude: coordinates.longitude)
  }

  // MARK: - Hashable

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  public static func == (lhs: Node, rhs: Node) -> Bool {
    lhs.id == rhs.id
  }
}

/// Represents a directed edge between two nodes
/// All durations stored in TimeInterval (seconds) for canonical time units
public struct Edge: Hashable, Codable {
  public let from: NodeID
  public let to: NodeID
  public let travelTime: TimeInterval  // seconds
  public let distance: Double  // meters
  public let isBridge: Bool
  public let bridgeID: String?  // nil if not a bridge

  public init(from: NodeID,
              to: NodeID,
              travelTime: TimeInterval,
              distance: Double,
              isBridge: Bool = false,
              bridgeID: String? = nil)
  {
    self.from = from
    self.to = to
    self.travelTime = travelTime
    self.distance = distance
    self.isBridge = isBridge

    // Validate bridge ID against SeattleDrawbridges as single source of truth
    if isBridge {
      if let bridgeID = bridgeID {
        if !SeattleDrawbridges.isValidBridgeID(bridgeID) {
          print("⚠️ Edge: Non-canonical bridge ID '\(bridgeID)' detected. This should be one of: \(SeattleDrawbridges.BridgeID.allIDs)")
        }
        self.bridgeID = bridgeID
      } else {
        print("⚠️ Edge: Bridge edge missing bridgeID. Setting to nil.")
        self.bridgeID = nil
      }
    } else {
      self.bridgeID = bridgeID
    }
  }

  // MARK: - Hashable

  public func hash(into hasher: inout Hasher) {
    hasher.combine(from)
    hasher.combine(to)
  }

  public static func == (lhs: Edge, rhs: Edge) -> Bool {
    lhs.from == rhs.from && lhs.to == rhs.to
  }
}

/// Represents a complete path through the network
/// Maintains order and includes all edges traversed
public struct RoutePath: Hashable, Codable {
  public let nodes: [NodeID]
  public let edges: [Edge]
  public let totalTravelTime: TimeInterval
  public let totalDistance: Double
  public let bridgeCount: Int

  public init(nodes: [NodeID], edges: [Edge]) {
    self.nodes = nodes
    self.edges = edges
    self.totalTravelTime = edges.reduce(0) { $0 + $1.travelTime }
    self.totalDistance = edges.reduce(0) { $0 + $1.distance }
    self.bridgeCount = edges.filter { $0.isBridge }.count
  }

  // MARK: - Hashable

  public func hash(into hasher: inout Hasher) {
    hasher.combine(nodes)
  }

  public static func == (lhs: RoutePath, rhs: RoutePath) -> Bool {
    lhs.nodes == rhs.nodes
  }

  // MARK: - Path Validation

  /// Validate that the path is contiguous (each edge connects to the next)
  /// Returns true if the path is valid, false otherwise
  public func isContiguous() -> Bool {
    guard nodes.count >= 2 && edges.count >= 1 else {
      return false  // Need at least 2 nodes and 1 edge for a valid path
    }

    // Check that edges connect nodes in sequence
    for i in 0 ..< edges.count {
      let edge = edges[i]
      let expectedFrom = nodes[i]
      let expectedTo = nodes[i + 1]

      if edge.from != expectedFrom || edge.to != expectedTo {
        return false
      }
    }

    return true
  }

  /// Validate path and throw error if invalid
  public func validate() throws {
    if !isContiguous() {
      throw MultiPathError.invalidPath(
        "Path is not contiguous: edges do not connect nodes in sequence")
    }
  }
}

/// Represents the probability score for a complete path
/// Uses log-domain for numerical stability
public struct PathScore: Codable {
  public let path: RoutePath
  public let logProbability: Double  // log-domain probability
  public let linearProbability: Double  // clamped to [0, 1]
  public let bridgeProbabilities: [String: Double]  // bridgeID -> probability

  public init(path: RoutePath,
              logProbability: Double,
              linearProbability: Double,
              bridgeProbabilities: [String: Double])
  {
    self.path = path
    self.logProbability = logProbability
    self.linearProbability = max(0.0, min(1.0, linearProbability))  // clamp
    self.bridgeProbabilities = bridgeProbabilities
  }
}

/// Represents the complete journey analysis
/// Includes all paths and network-level probability
public struct JourneyAnalysis: Codable {
  public let startNode: NodeID
  public let endNode: NodeID
  public let departureTime: Date
  public let pathScores: [PathScore]
  public let networkProbability: Double  // P(any path succeeds)
  public let bestPathProbability: Double
  public let totalPathsAnalyzed: Int

  public init(startNode: NodeID,
              endNode: NodeID,
              departureTime: Date,
              pathScores: [PathScore],
              networkProbability: Double,
              bestPathProbability: Double,
              totalPathsAnalyzed: Int)
  {
    self.startNode = startNode
    self.endNode = endNode
    self.departureTime = departureTime
    self.pathScores = pathScores
    self.networkProbability = max(0.0, min(1.0, networkProbability))  // clamp
    self.bestPathProbability = max(0.0, min(1.0, bestPathProbability))  // clamp
    self.totalPathsAnalyzed = totalPathsAnalyzed
  }
}

// MARK: - ETA Types

/// Represents an estimated time of arrival at a specific node
/// All times in canonical TimeInterval units
public struct ETA: Codable, Equatable {
  public let nodeID: NodeID
  public let arrivalTime: Date
  public let travelTimeFromStart: TimeInterval

  public init(nodeID: NodeID, arrivalTime: Date, travelTimeFromStart: TimeInterval) {
    self.nodeID = nodeID
    self.arrivalTime = arrivalTime
    self.travelTimeFromStart = travelTimeFromStart
  }
}

/// Represents statistical summary of ETA estimates with uncertainty quantification
/// Provides mean, variance, and confidence intervals for arrival time predictions
public struct ETAEstimate: Codable, Equatable {
  public let nodeID: NodeID
  public let summary: ETASummary
  public let arrivalTime: Date  // Mean arrival time for backward compatibility

  public init(nodeID: NodeID, summary: ETASummary, arrivalTime: Date) {
    self.nodeID = nodeID
    self.summary = summary
    self.arrivalTime = arrivalTime
  }

  /// Backward compatibility: access mean travel time
  public var travelTimeFromStart: TimeInterval {
    return summary.mean
  }

  /// Human-readable ETA with confidence interval
  public var formattedETA: String {
    let ci95 = summary.confidenceInterval(level: 0.95)
    if let ci = ci95 {
      let meanMinutes = Int(summary.mean / 60)
      let marginMinutes = Int(ci.upper - ci.lower) / 120  // Half the CI width in minutes
      return "\(meanMinutes) min (±\(marginMinutes) min)"
    } else {
      let meanMinutes = Int(summary.mean / 60)
      return "\(meanMinutes) min"
    }
  }
}

/// Represents ETA windows for future-proofing
/// Currently single ETA, but extensible for min/max ranges
public struct ETAWindow: Codable {
  public let expectedETA: ETA
  public let minETA: ETA?  // future: earliest possible arrival
  public let maxETA: ETA?  // future: latest possible arrival

  public init(expectedETA: ETA, minETA: ETA? = nil, maxETA: ETA? = nil) {
    self.expectedETA = expectedETA
    self.minETA = minETA
    self.maxETA = maxETA
  }
}

// MARK: - Validation Types

/// Represents validation results for graph integrity
public struct GraphValidationResult: Codable {
  public let isValid: Bool
  public let errors: [String]
  public let warnings: [String]
  public let nodeCount: Int
  public let edgeCount: Int
  public let bridgeCount: Int

  public init(isValid: Bool,
              errors: [String] = [],
              warnings: [String] = [],
              nodeCount: Int = 0,
              edgeCount: Int = 0,
              bridgeCount: Int = 0)
  {
    self.isValid = isValid
    self.errors = errors
    self.warnings = warnings
    self.nodeCount = nodeCount
    self.edgeCount = edgeCount
    self.bridgeCount = bridgeCount
  }
}

// MARK: - Error Types

/// Errors specific to multi-path analysis
public enum MultiPathError: Error, LocalizedError, Equatable {
  case invalidGraph(String)
  case invalidPath(String)
  case nodeNotFound(NodeID)
  case noPathExists(NodeID, NodeID)
  case invalidConfiguration(String)
  case predictionFailed(String)
  case numericalError(String)

  public var errorDescription: String? {
    switch self {
    case let .invalidGraph(reason):
      return "Invalid graph: \(reason)"
    case let .invalidPath(reason):
      return "Invalid path: \(reason)"
    case let .nodeNotFound(nodeID):
      return "Node not found: \(nodeID)"
    case let .noPathExists(from, to):
      return "No path exists from \(from) to \(to)"
    case let .invalidConfiguration(reason):
      return "Invalid configuration: \(reason)"
    case let .predictionFailed(reason):
      return "Prediction failed: \(reason)"
    case let .numericalError(reason):
      return "Numerical error: \(reason)"
    }
  }
}
