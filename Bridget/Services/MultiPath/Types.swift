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
public struct Coordinates: Codable, Hashable, Sendable {
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
public struct Node: Hashable, Codable, Sendable {
    public let id: NodeID
    public let name: String
    public let coordinates: Coordinates

    public init(
        id: NodeID,
        name: String,
        coordinates: (latitude: Double, longitude: Double)
    ) {
        self.id = id
        self.name = name
        self.coordinates = Coordinates(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude
        )
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Node, rhs: Node) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents a directed edge between two nodes
public struct Edge: Hashable, Codable, Sendable {
    public let from: NodeID
    public let to: NodeID
    public let travelTime: TimeInterval
    public let distance: Double
    public let isBridge: Bool
    public let bridgeID: String?

    public enum EdgeInitError: Error, Sendable {
        case selfLoop
        case nonPositiveDistance
        case nonPositiveTravelTime
        case missingBridgeID
        case unexpectedBridgeID
    }

    public init(
        validatingFrom from: NodeID,
        to: NodeID,
        travelTime: TimeInterval,
        distance: Double,
        isBridge: Bool,
        bridgeID: String?
    ) throws {
        guard from != to else { throw EdgeInitError.selfLoop }
        guard distance.isFinite, distance > 0 else {
            throw EdgeInitError.nonPositiveDistance
        }
        guard travelTime.isFinite, travelTime > 0 else {
            throw EdgeInitError.nonPositiveTravelTime
        }
        guard isBridge == (bridgeID != nil) else {
            throw isBridge
                ? EdgeInitError.missingBridgeID
                : EdgeInitError.unexpectedBridgeID
        }

        self.from = from
        self.to = to
        self.travelTime = travelTime
        self.distance = distance
        self.isBridge = isBridge
        self.bridgeID = bridgeID
    }

    public init(
        from: NodeID,
        to: NodeID,
        travelTime: TimeInterval,
        distance: Double,
        isBridge: Bool = false,
        bridgeID: String? = nil
    ) {
        self.from = from
        self.to = to
        self.travelTime = travelTime
        self.distance = distance
        self.isBridge = isBridge

        if isBridge {
            if let bridgeID = bridgeID {
                #if DEBUG
                    if !SeattleDrawbridges.isAcceptedBridgeID(
                        bridgeID,
                        allowSynthetic: true
                    ) {
                        assertionFailure(
                            "Edge: Non-canonical, non-synthetic bridge ID '\(bridgeID)' detected. Must be canonical Seattle bridge or synthetic test ID (bridge1, bridge2, etc.)"
                        )
                    }
                #else
                    if !SeattleDrawbridges.isAcceptedBridgeID(
                        bridgeID,
                        allowSynthetic: true
                    ) {
                        print(
                            "⚠️ Edge: Non-canonical, non-synthetic bridge ID '\(bridgeID)' detected. Must be canonical Seattle bridge or synthetic test ID (bridge1, bridge2, etc.)"
                        )
                    }
                #endif
                self.bridgeID = bridgeID
            } else {
                #if DEBUG
                    assertionFailure("Edge: Bridge edge missing bridgeID")
                #else
                    print(
                        "⚠️ Edge: Bridge edge missing bridgeID. Setting to nil."
                    )
                #endif
                self.bridgeID = nil
            }
        } else {
            self.bridgeID = bridgeID
        }
    }

    public static func road(
        from: NodeID,
        to: NodeID,
        travelTime: TimeInterval,
        distance: Double
    )
        -> Edge
    {
        return Edge(
            from: from,
            to: to,
            travelTime: travelTime,
            distance: distance,
            isBridge: false,
            bridgeID: nil
        )
    }

    public static func bridge(
        from: NodeID,
        to: NodeID,
        travelTime: TimeInterval,
        distance: Double,
        bridgeID: String
    ) -> Edge? {
        guard
            SeattleDrawbridges.isAcceptedBridgeID(
                bridgeID,
                allowSynthetic: true
            )
        else {
            return nil
        }
        return Edge(
            from: from,
            to: to,
            travelTime: travelTime,
            distance: distance,
            isBridge: true,
            bridgeID: bridgeID
        )
    }

    public static func bridgeThrowing(
        from: NodeID,
        to: NodeID,
        travelTime: TimeInterval,
        distance: Double,
        bridgeID: String
    ) throws -> Edge {
        return try Edge(
            validatingFrom: from,
            to: to,
            travelTime: travelTime,
            distance: distance,
            isBridge: true,
            bridgeID: bridgeID
        )
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(from)
        hasher.combine(to)
    }

    public static func == (lhs: Edge, rhs: Edge) -> Bool {
        lhs.from == rhs.from && lhs.to == rhs.to
    }
}

extension Edge.EdgeInitError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .selfLoop:
            return "Edge cannot connect a node to itself"
        case .nonPositiveDistance:
            return "Edge distance must be positive and finite"
        case .nonPositiveTravelTime:
            return "Edge travel time must be positive and finite"
        case .missingBridgeID:
            return "Bridge edge must have a bridge ID"
        case .unexpectedBridgeID:
            return "Non-bridge edge should not have a bridge ID"
        }
    }
}

/// Represents a complete path through the network
public struct RoutePath: Hashable, Codable, Sendable {
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

    public func hash(into hasher: inout Hasher) {
        hasher.combine(nodes)
    }

    public static func == (lhs: RoutePath, rhs: RoutePath) -> Bool {
        lhs.nodes == rhs.nodes
    }

    public func isContiguous() -> Bool {
        guard nodes.count >= 2 && edges.count >= 1 else {
            return false
        }

        for i in 0..<edges.count {
            let edge = edges[i]
            let expectedFrom = nodes[i]
            let expectedTo = nodes[i + 1]

            if edge.from != expectedFrom || edge.to != expectedTo {
                return false
            }
        }

        return true
    }

    public func validate() throws {
        if !isContiguous() {
            throw MultiPathError.invalidPath(
                "Path is not contiguous: edges do not connect nodes in sequence"
            )
        }
    }
}

/// Probability score for a path
public struct PathScore: Codable, Sendable {
    public let path: RoutePath
    public let logProbability: Double
    public let linearProbability: Double
    public let bridgeProbabilities: [String: Double]

    public init(
        path: RoutePath,
        logProbability: Double,
        linearProbability: Double,
        bridgeProbabilities: [String: Double]
    ) {
        self.path = path
        self.logProbability = logProbability
        self.linearProbability = max(0.0, min(1.0, linearProbability))
        self.bridgeProbabilities = bridgeProbabilities
    }
}

/// Journey analysis
public struct JourneyAnalysis: Codable, Sendable {
    public let startNode: NodeID
    public let endNode: NodeID
    public let departureTime: Date
    public let pathScores: [PathScore]
    public let networkProbability: Double
    public let bestPathProbability: Double
    public let totalPathsAnalyzed: Int

    public init(
        startNode: NodeID,
        endNode: NodeID,
        departureTime: Date,
        pathScores: [PathScore],
        networkProbability: Double,
        bestPathProbability: Double,
        totalPathsAnalyzed: Int
    ) {
        self.startNode = startNode
        self.endNode = endNode
        self.departureTime = departureTime
        self.pathScores = pathScores
        self.networkProbability = max(0.0, min(1.0, networkProbability))
        self.bestPathProbability = max(0.0, min(1.0, bestPathProbability))
        self.totalPathsAnalyzed = totalPathsAnalyzed
    }
}

// MARK: - ETA Types

public struct ETA: Codable, Equatable, Sendable {
    public let nodeID: NodeID
    public let arrivalTime: Date
    public let travelTimeFromStart: TimeInterval

    public init(
        nodeID: NodeID,
        arrivalTime: Date,
        travelTimeFromStart: TimeInterval
    ) {
        self.nodeID = nodeID
        self.arrivalTime = arrivalTime
        self.travelTimeFromStart = travelTimeFromStart
    }
}

public struct ETAEstimate: Codable, Equatable, Sendable {
    public let nodeID: NodeID
    public let summary: ETASummary
    public let arrivalTime: Date

    public init(nodeID: NodeID, summary: ETASummary, arrivalTime: Date) {
        self.nodeID = nodeID
        self.summary = summary
        self.arrivalTime = arrivalTime
    }

    public var travelTimeFromStart: TimeInterval {
        return summary.mean
    }

    public var formattedETA: String {
        let ci95 = summary.confidenceInterval(level: 0.95)
        if let ci = ci95 {
            let meanMinutes = Int(summary.mean / 60)
            let marginMinutes = Int(ci.upper - ci.lower) / 120
            return "\(meanMinutes) min (±\(marginMinutes) min)"
        } else {
            let meanMinutes = Int(summary.mean / 60)
            return "\(meanMinutes) min"
        }
    }
}

public struct ETAWindow: Codable, Sendable {
    public let expectedETA: ETA
    public let minETA: ETA?
    public let maxETA: ETA?

    public init(expectedETA: ETA, minETA: ETA? = nil, maxETA: ETA? = nil) {
        self.expectedETA = expectedETA
        self.minETA = minETA
        self.maxETA = maxETA
    }
}

// MARK: - Validation Types

public struct GraphValidationResult: Codable, Sendable {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    public let nodeCount: Int
    public let edgeCount: Int
    public let bridgeCount: Int

    public init(
        isValid: Bool,
        errors: [String] = [],
        warnings: [String] = [],
        nodeCount: Int = 0,
        edgeCount: Int = 0,
        bridgeCount: Int = 0
    ) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
        self.nodeCount = nodeCount
        self.edgeCount = edgeCount
        self.bridgeCount = bridgeCount
    }
}

// MARK: - Error Types

public enum MultiPathError: Error, LocalizedError, Equatable, Sendable {
    case invalidGraph(String)
    case invalidPath(String)
    case nodeNotFound(NodeID)
    case noPathExists(NodeID, NodeID)
    case invalidConfiguration(String)
    case predictionFailed(String)
    case numericalError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidGraph(let reason):
            return "Invalid graph: \(reason)"
        case .invalidPath(let reason):
            return "Invalid path: \(reason)"
        case .nodeNotFound(let nodeID):
            return "Node not found: \(nodeID)"
        case .noPathExists(let from, let to):
            return "No path exists from \(from) to \(to)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .predictionFailed(let reason):
            return "Prediction failed: \(reason)"
        case .numericalError(let reason):
            return "Numerical error: \(reason)"
        }
    }
}
