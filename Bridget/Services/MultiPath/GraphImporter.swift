//
//  GraphImporter.swift
//  Bridget
//
//  Multi-Path Probability Traffic Prediction System
//  Purpose: Import graph data from JSON files and validate integrity
//  Integration: Used by tests and performance benchmarks to load Seattle datasets
//  Acceptance: Validates connectivity, bridge references, and data integrity
//  Known Limits: JSON format specific, synchronous loading only
//

import Foundation

// MARK: - Import Data Structures

/// Node data structure for JSON import
public struct ImportNode: Codable {
  public let id: String
  public let name: String
  public let latitude: Double
  public let longitude: Double
  public let type: String

  public init(id: String, name: String, latitude: Double, longitude: Double, type: String) {
    self.id = id
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
    self.type = type
  }
}

/// Edge data structure for JSON import
public struct ImportEdge: Codable {
  public let from: String
  public let to: String
  public let travelTimeSec: TimeInterval
  public let distanceM: Double
  public let isBridge: Bool
  public let bridgeID: String?
  public let laneCount: Int
  public let speedLimit: Int

  public init(from: String,
              to: String,
              travelTimeSec: TimeInterval,
              distanceM: Double,
              isBridge: Bool,
              bridgeID: String?,
              laneCount: Int,
              speedLimit: Int)
  {
    self.from = from
    self.to = to
    self.travelTimeSec = travelTimeSec
    self.distanceM = distanceM
    self.isBridge = isBridge
    self.bridgeID = bridgeID
    self.laneCount = laneCount
    self.speedLimit = speedLimit
  }
}

/// Bridge data structure for JSON import
public struct ImportBridge: Codable {
  public let id: String
  public let name: String
  public let latitude: Double
  public let longitude: Double
  public let type: String
  public let schedule: BridgeSchedule?
  public let notes: String?

  public init(id: String,
              name: String,
              latitude: Double,
              longitude: Double,
              type: String,
              schedule: BridgeSchedule?,
              notes: String?)
  {
    self.id = id
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
    self.type = type
    self.schedule = schedule
    self.notes = notes
  }
}

/// Bridge schedule structure
public struct BridgeSchedule: Codable {
  public let weekday: DaySchedule?
  public let weekend: DaySchedule?

  public init(weekday: DaySchedule?, weekend: DaySchedule?) {
    self.weekday = weekday
    self.weekend = weekend
  }
}

/// Day schedule structure
public struct DaySchedule: Codable {
  public let morningRush: String?
  public let eveningRush: String?
  public let nightOperations: String?
  public let dayOperations: String?

  private enum CodingKeys: String, CodingKey {
    case morningRush = "morning_rush"
    case eveningRush = "evening_rush"
    case nightOperations = "night_operations"
    case dayOperations = "day_operations"
  }

  public init(morningRush: String?, eveningRush: String?, nightOperations: String?, dayOperations: String?) {
    self.morningRush = morningRush
    self.eveningRush = eveningRush
    self.nightOperations = nightOperations
    self.dayOperations = dayOperations
  }
}

/// Dataset manifest structure
public struct DatasetManifest: Codable {
  public let dataset: String
  public let version: String
  public let generated: String
  public let description: String
  public let source: String
  public let statistics: DatasetStatistics
  public let bridges: [String]
  public let testScenarios: [TestScenario]
  public let files: [String]

  private enum CodingKeys: String, CodingKey {
    case dataset, version, generated, description, source, statistics, bridges, files
    case testScenarios = "test_scenarios"
  }

  public init(dataset: String,
              version: String,
              generated: String,
              description: String,
              source: String,
              statistics: DatasetStatistics,
              bridges: [String],
              testScenarios: [TestScenario],
              files: [String])
  {
    self.dataset = dataset
    self.version = version
    self.generated = generated
    self.description = description
    self.source = source
    self.statistics = statistics
    self.bridges = bridges
    self.testScenarios = testScenarios
    self.files = files
  }
}

/// Dataset statistics
public struct DatasetStatistics: Codable {
  public let nodes: Int
  public let edges: Int
  public let bridges: Int
  public let totalDistanceKm: Double
  public let averageDegree: Double

  private enum CodingKeys: String, CodingKey {
    case nodes, edges, bridges
    case totalDistanceKm = "total_distance_km"
    case averageDegree = "average_degree"
  }

  public init(nodes: Int, edges: Int, bridges: Int, totalDistanceKm: Double, averageDegree: Double) {
    self.nodes = nodes
    self.edges = edges
    self.bridges = bridges
    self.totalDistanceKm = totalDistanceKm
    self.averageDegree = averageDegree
  }
}

/// Test scenario structure
public struct TestScenario: Codable {
  public let name: String
  public let start: String
  public let end: String
  public let expectedBridges: [String]
  public let expectedTravelTimeMin: Int

  private enum CodingKeys: String, CodingKey {
    case name, start, end
    case expectedBridges = "expected_bridges"
    case expectedTravelTimeMin = "expected_travel_time_min"
  }

  public init(name: String, start: String, end: String, expectedBridges: [String], expectedTravelTimeMin: Int) {
    self.name = name
    self.start = start
    self.end = end
    self.expectedBridges = expectedBridges
    self.expectedTravelTimeMin = expectedTravelTimeMin
  }
}

// MARK: - Graph Importer

/// Service for importing graph data from JSON files
public class GraphImporter {
  /// Import a complete graph from JSON files
  /// - Parameters:
  ///   - nodesURL: URL to nodes JSON file
  ///   - edgesURL: URL to edges JSON file
  ///   - bridgesURL: URL to bridges JSON file
  /// - Returns: Validated Graph instance
  /// - Throws: MultiPathError if validation fails
  public static func importGraph(nodesURL: URL,
                                 edgesURL: URL,
                                 bridgesURL: URL) throws -> Graph
  {
    // Load JSON data
    let nodesData = try Data(contentsOf: nodesURL)
    let edgesData = try Data(contentsOf: edgesURL)
    let bridgesData = try Data(contentsOf: bridgesURL)

    // Decode JSON
    let importNodes = try JSONDecoder().decode([ImportNode].self, from: nodesData)
    let importEdges = try JSONDecoder().decode([ImportEdge].self, from: edgesData)
    let importBridges = try JSONDecoder().decode([ImportBridge].self, from: bridgesData)

    // Convert to domain types
    let nodes = importNodes.map { importNode in
      Node(id: importNode.id,
           name: importNode.name,
           coordinates: (latitude: importNode.latitude, longitude: importNode.longitude))
    }

    let edges = importEdges.map { importEdge in
      Edge(from: importEdge.from,
           to: importEdge.to,
           travelTime: importEdge.travelTimeSec,
           distance: importEdge.distanceM,
           isBridge: importEdge.isBridge,
           bridgeID: importEdge.bridgeID)
    }

    // Validate data integrity
    try validateImportData(nodes: nodes,
                           edges: edges,
                           bridges: importBridges)

    // Create and return graph
    return try Graph(nodes: nodes, edges: edges)
  }

  /// Import graph from a directory containing the dataset files
  /// - Parameter directoryURL: URL to directory containing nodes.json, edges.json, bridges.json
  /// - Returns: Validated Graph instance
  /// - Throws: MultiPathError if files not found or validation fails
  public static func importGraph(from directoryURL: URL) throws -> Graph {
    let nodesURL = directoryURL.appendingPathComponent("nodes.json")
    let edgesURL = directoryURL.appendingPathComponent("edges.json")
    let bridgesURL = directoryURL.appendingPathComponent("bridges.json")

    return try importGraph(nodesURL: nodesURL, edgesURL: edgesURL, bridgesURL: bridgesURL)
  }

  /// Load manifest from a directory
  /// - Parameter directoryURL: URL to directory containing manifest.json
  /// - Returns: DatasetManifest instance
  /// - Throws: MultiPathError if manifest not found or invalid
  public static func loadManifest(from directoryURL: URL) throws -> DatasetManifest {
    let manifestURL = directoryURL.appendingPathComponent("manifest.json")
    let manifestData = try Data(contentsOf: manifestURL)
    return try JSONDecoder().decode(DatasetManifest.self, from: manifestData)
  }

  // MARK: - Validation

  /// Validate imported data for integrity and consistency
  /// - Parameters:
  ///   - nodes: Array of domain Node objects
  ///   - edges: Array of domain Edge objects
  ///   - bridges: Array of import Bridge objects
  /// - Throws: MultiPathError if validation fails
  private static func validateImportData(nodes: [Node],
                                         edges: [Edge],
                                         bridges: [ImportBridge]) throws
  {
    // Create sets for efficient lookup
    let nodeIDs = Set(nodes.map { $0.id })
    let bridgeIDs = Set(bridges.map { $0.id })

    // Validate edges
    for edge in edges {
      // Check that edge endpoints exist
      if !nodeIDs.contains(edge.from) {
        throw MultiPathError.invalidGraph("Edge references non-existent node: \(edge.from)")
      }
      if !nodeIDs.contains(edge.to) {
        throw MultiPathError.invalidGraph("Edge references non-existent node: \(edge.to)")
      }

      // Check bridge references
      if edge.isBridge {
        guard let bridgeID = edge.bridgeID else {
          throw MultiPathError.invalidGraph(
            "Bridge edge missing bridgeID: \(edge.from) -> \(edge.to)")
        }
        if !bridgeIDs.contains(bridgeID) {
          throw MultiPathError.invalidGraph(
            "Bridge edge references non-existent bridge: \(bridgeID)")
        }
      } else {
        if edge.bridgeID != nil {
          throw MultiPathError.invalidGraph(
            "Non-bridge edge has bridgeID: \(edge.from) -> \(edge.to)")
        }
      }

      // Validate travel time and distance
      if edge.travelTime <= 0 {
        throw MultiPathError.invalidGraph(
          "Edge has non-positive travel time: \(edge.from) -> \(edge.to)")
      }
      if edge.distance < 0 {
        throw MultiPathError.invalidGraph("Edge has negative distance: \(edge.from) -> \(edge.to)")
      }
    }

    // Check for isolated nodes (nodes with no edges)
    let connectedNodeIDs = Set(edges.flatMap { [$0.from, $0.to] })
    let isolatedNodes = nodeIDs.subtracting(connectedNodeIDs)
    if !isolatedNodes.isEmpty {
      print("Warning: Found isolated nodes: \(isolatedNodes)")
    }

    // Validate bridge data
    for bridge in bridges {
      if bridge.latitude < -90 || bridge.latitude > 90 {
        throw MultiPathError.invalidGraph("Invalid bridge latitude: \(bridge.latitude)")
      }
      if bridge.longitude < -180 || bridge.longitude > 180 {
        throw MultiPathError.invalidGraph("Invalid bridge longitude: \(bridge.longitude)")
      }
    }
  }

  /// Generate a dataset report with statistics
  /// - Parameters:
  ///   - nodes: Array of domain Node objects
  ///   - edges: Array of domain Edge objects
  ///   - bridges: Array of import Bridge objects
  /// - Returns: String report with statistics
  public static func generateDatasetReport(nodes: [Node],
                                           edges: [Edge],
                                           bridges: [ImportBridge]) -> String
  {
    let nodeCount = nodes.count
    let edgeCount = edges.count
    let bridgeCount = bridges.count
    let bridgeEdges = edges.filter { $0.isBridge }.count

    let totalDistance = edges.reduce(0) { $0 + $1.distance }
    let totalTravelTime = edges.reduce(0) { $0 + $1.travelTime }

    let averageDegree = Double(edgeCount * 2) / Double(nodeCount)
    let averageSpeed = totalDistance > 0 ? totalDistance / totalTravelTime : 0

    var report = """
    Dataset Report:
    ===============
    Nodes: \(nodeCount)
    Edges: \(edgeCount)
    Bridges: \(bridgeCount)
    Bridge Edges: \(bridgeEdges)
    Total Distance: \(String(format: "%.1f", totalDistance / 1000)) km
    Total Travel Time: \(String(format: "%.1f", totalTravelTime / 60)) minutes
    Average Degree: \(String(format: "%.1f", averageDegree))
    Average Speed: \(String(format: "%.1f", averageSpeed)) m/s

    Bridge Details:
    """

    for bridge in bridges {
      report += "\n- \(bridge.name) (\(bridge.id)): \(bridge.type)"
    }

    return report
  }
}
