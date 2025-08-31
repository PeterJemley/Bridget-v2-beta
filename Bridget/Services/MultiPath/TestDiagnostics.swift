//
//  TestDiagnostics.swift
//  BridgetTests
//
//  Purpose: Deterministic, low-noise diagnostics for graph/path parity issues
//

import Foundation

enum TestDiagnostics {
  // Gate verbose output via env var or pass verbose: true explicitly
  static var defaultVerbose: Bool {
    if let v = ProcessInfo.processInfo.environment[
      "BRIDGET_VERBOSE_DIAGNOSTICS"
    ] {
      return (v as NSString).boolValue
    }
    return false
  }

  /// Dump adjacency for nodes reachable from `start`, deterministically sorted.
  static func dumpAdjacency(from start: NodeID,
                            in graph: Graph,
                            verbose: Bool = defaultVerbose)
  {
    guard verbose else { return }
    let reachable = reachableNodes(from: start, in: graph)
    let sortedNodes = reachable.sorted()
    print("Adjacency (reachable from \(start)):")
    for node in sortedNodes {
      let tos = graph.outgoingEdges(from: node).map { $0.to }.sorted()
      print("  \(node) -> [\(tos.joined(separator: ", "))]")
    }
  }

  /// Pretty-print a list of RoutePath instances, sorted by (time, nodes).
  static func dumpPaths(label: String,
                        paths: [RoutePath],
                        verbose: Bool = defaultVerbose)
  {
    guard verbose else { return }
    let sorted = paths.sorted {
      if $0.totalTravelTime == $1.totalTravelTime {
        return $0.nodes.lexicographicallyPrecedes($1.nodes)
      }
      return $0.totalTravelTime < $1.totalTravelTime
    }
    print("\(label): \(sorted.count) paths")
    for p in sorted {
      let edgesDesc = p.edges.map { edgeDescription($0) }.joined(
        separator: ", "
      )
      print(
        "  \(p.nodes.joined(separator: "->"))  time=\(Int(p.totalTravelTime))s  edges=[\(edgesDesc)]"
      )
    }
    // Also print set-style summary for quick diffing
    let sigs = sorted.map {
      "\($0.nodes.joined(separator: "->")) @ \(Int($0.totalTravelTime))s"
    }
    print("\(label) (signatures): \(sigs)")
  }

  // MARK: - Internals

  private static func reachableNodes(from start: NodeID, in graph: Graph)
    -> Set<NodeID>
  {
    var visited: Set<NodeID> = []
    var stack: [NodeID] = [start]
    while let current = stack.popLast() {
      if visited.contains(current) { continue }
      visited.insert(current)
      let nexts = graph.outgoingEdges(from: current).map { $0.to }
      for n in nexts where !visited.contains(n) {
        stack.append(n)
      }
    }
    return visited
  }

  private static func edgeDescription(_ e: Edge) -> String {
    if e.isBridge {
      return
        "\(e.from)->\(e.to) [bridge \(e.bridgeID ?? "?") t:\(Int(e.travelTime)) d:\(Int(e.distance))]"
    } else {
      return
        "\(e.from)->\(e.to) [t:\(Int(e.travelTime)) d:\(Int(e.distance))]"
    }
  }
}
