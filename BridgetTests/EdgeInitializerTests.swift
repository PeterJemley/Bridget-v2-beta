import Foundation
import Testing

@testable import Bridget

@Suite("Edge Initializer Tests")
struct EdgeInitializerTests {
  // MARK: - Valid Edge Creation Tests

  @Test("Valid road edge creation")
  func validRoadEdgeCreation() throws {
    let edge = try Edge(validatingFrom: "A",
                        to: "B",
                        travelTime: 60.0,
                        distance: 100.0,
                        isBridge: false,
                        bridgeID: nil)

    #expect(edge.from == "A")
    #expect(edge.to == "B")
    #expect(edge.travelTime == 60.0)
    #expect(edge.distance == 100.0)
    #expect(edge.isBridge == false)
    #expect(edge.bridgeID == nil)
  }

  @Test("Valid canonical bridge edge creation")
  func validBridgeEdgeCreation() throws {
    let edge = try Edge(validatingFrom: "A",
                        to: "B",
                        travelTime: 120.0,
                        distance: 200.0,
                        isBridge: true,
                        bridgeID: "1")

    #expect(edge.from == "A")
    #expect(edge.to == "B")
    #expect(edge.travelTime == 120.0)
    #expect(edge.distance == 200.0)
    #expect(edge.isBridge == true)
    #expect(edge.bridgeID == "1")
  }

  @Test("Valid synthetic bridge edge creation")
  func validSyntheticBridgeEdgeCreation() throws {
    let edge = try Edge(validatingFrom: "A",
                        to: "B",
                        travelTime: 90.0,
                        distance: 150.0,
                        isBridge: true,
                        bridgeID: "bridge1")

    #expect(edge.from == "A")
    #expect(edge.to == "B")
    #expect(edge.travelTime == 90.0)
    #expect(edge.distance == 150.0)
    #expect(edge.isBridge == true)
    #expect(edge.bridgeID == "bridge1")
  }

  // MARK: - Error Cases Tests

  @Test("Self-loop throws .selfLoop")
  func selfLoopThrowsError() {
    #expect(throws: Edge.EdgeInitError.selfLoop) {
      _ = try Edge(validatingFrom: "A",
                   to: "A",
                   travelTime: 60.0,
                   distance: 100.0,
                   isBridge: false,
                   bridgeID: nil)
    }
  }

  @Test("Non-positive or invalid distance throws .nonPositiveDistance")
  func nonPositiveDistanceThrowsError() {
    // Zero distance
    #expect(throws: Edge.EdgeInitError.nonPositiveDistance) {
      _ = try Edge(validatingFrom: "A",
                   to: "B",
                   travelTime: 60.0,
                   distance: 0.0,
                   isBridge: false,
                   bridgeID: nil)
    }

    // Negative distance
    #expect(throws: Edge.EdgeInitError.nonPositiveDistance) {
      _ = try Edge(validatingFrom: "A",
                   to: "B",
                   travelTime: 60.0,
                   distance: -10.0,
                   isBridge: false,
                   bridgeID: nil)
    }

    // Infinite distance
    #expect(throws: Edge.EdgeInitError.nonPositiveDistance) {
      _ = try Edge(validatingFrom: "A",
                   to: "B",
                   travelTime: 60.0,
                   distance: .infinity,
                   isBridge: false,
                   bridgeID: nil)
    }

    // NaN distance
    #expect(throws: Edge.EdgeInitError.nonPositiveDistance) {
      _ = try Edge(validatingFrom: "A",
                   to: "B",
                   travelTime: 60.0,
                   distance: .nan,
                   isBridge: false,
                   bridgeID: nil)
    }
  }

  @Test("Non-positive or invalid travel time throws .nonPositiveTravelTime")
  func nonPositiveTravelTimeThrowsError() {
    // Zero travel time
    #expect(throws: Edge.EdgeInitError.nonPositiveTravelTime) {
      _ = try Edge(validatingFrom: "A",
                   to: "B",
                   travelTime: 0.0,
                   distance: 100.0,
                   isBridge: false,
                   bridgeID: nil)
    }

    // Negative travel time
    #expect(throws: Edge.EdgeInitError.nonPositiveTravelTime) {
      _ = try Edge(validatingFrom: "A",
                   to: "B",
                   travelTime: -30.0,
                   distance: 100.0,
                   isBridge: false,
                   bridgeID: nil)
    }

    // Infinite travel time
    #expect(throws: Edge.EdgeInitError.nonPositiveTravelTime) {
      _ = try Edge(validatingFrom: "A",
                   to: "B",
                   travelTime: .infinity,
                   distance: 100.0,
                   isBridge: false,
                   bridgeID: nil)
    }

    // NaN travel time
    #expect(throws: Edge.EdgeInitError.nonPositiveTravelTime) {
      _ = try Edge(validatingFrom: "A",
                   to: "B",
                   travelTime: .nan,
                   distance: 100.0,
                   isBridge: false,
                   bridgeID: nil)
    }
  }

  @Test("Missing bridgeID throws .missingBridgeID")
  func missingBridgeIDThrowsError() {
    #expect(throws: Edge.EdgeInitError.missingBridgeID) {
      _ = try Edge(validatingFrom: "A",
                   to: "B",
                   travelTime: 60.0,
                   distance: 100.0,
                   isBridge: true,
                   bridgeID: nil)
    }
  }

  @Test("Unexpected bridgeID throws .unexpectedBridgeID")
  func unexpectedBridgeIDThrowsError() {
    #expect(throws: Edge.EdgeInitError.unexpectedBridgeID) {
      _ = try Edge(validatingFrom: "A",
                   to: "B",
                   travelTime: 60.0,
                   distance: 100.0,
                   isBridge: false,
                   bridgeID: "1")
    }
  }

  // MARK: - Convenience Initializer Tests

  @Test("Road convenience initializer")
  func roadConvenienceInitializer() {
    let edge = Edge.road(from: "A",
                         to: "B",
                         travelTime: 60.0,
                         distance: 100.0)

    #expect(edge.from == "A")
    #expect(edge.to == "B")
    #expect(edge.travelTime == 60.0)
    #expect(edge.distance == 100.0)
    #expect(edge.isBridge == false)
    #expect(edge.bridgeID == nil)
  }

  @Test("Bridge convenience initializer with canonical ID returns non-nil")
  func bridgeConvenienceInitializerWithValidID() {
    let edge = Edge.bridge(from: "A",
                           to: "B",
                           travelTime: 120.0,
                           distance: 200.0,
                           bridgeID: "1")

    #expect(edge != nil)
    #expect(edge?.from == "A")
    #expect(edge?.to == "B")
    #expect(edge?.travelTime == 120.0)
    #expect(edge?.distance == 200.0)
    #expect(edge?.isBridge == true)
    #expect(edge?.bridgeID == "1")
  }

  @Test("Bridge convenience initializer with synthetic ID returns non-nil")
  func bridgeConvenienceInitializerWithSyntheticID() {
    let edge = Edge.bridge(from: "A",
                           to: "B",
                           travelTime: 90.0,
                           distance: 150.0,
                           bridgeID: "bridge1")

    #expect(edge != nil)
    #expect(edge?.from == "A")
    #expect(edge?.to == "B")
    #expect(edge?.travelTime == 90.0)
    #expect(edge?.distance == 150.0)
    #expect(edge?.isBridge == true)
    #expect(edge?.bridgeID == "bridge1")
  }

  @Test("Bridge convenience initializer returns nil for invalid ID")
  func bridgeConvenienceInitializerWithInvalidID() {
    let edge = Edge.bridge(from: "A",
                           to: "B",
                           travelTime: 120.0,
                           distance: 200.0,
                           bridgeID: "invalid")

    #expect(edge == nil)
  }

  @Test("Bridge throwing convenience initializer with canonical ID")
  func bridgeThrowingConvenienceInitializer() throws {
    let edge = try Edge.bridgeThrowing(from: "A",
                                       to: "B",
                                       travelTime: 120.0,
                                       distance: 200.0,
                                       bridgeID: "1")

    #expect(edge.from == "A")
    #expect(edge.to == "B")
    #expect(edge.travelTime == 120.0)
    #expect(edge.distance == 200.0)
    #expect(edge.isBridge == true)
    #expect(edge.bridgeID == "1")
  }

  // MARK: - Error Description Tests

  @Test("EdgeInitError localized descriptions")
  func errorDescriptions() {
    #expect(
      Edge.EdgeInitError.selfLoop.localizedDescription
        == "Edge cannot connect a node to itself"
    )
    #expect(
      Edge.EdgeInitError.nonPositiveDistance.localizedDescription
        == "Edge distance must be positive and finite"
    )
    #expect(
      Edge.EdgeInitError.nonPositiveTravelTime.localizedDescription
        == "Edge travel time must be positive and finite"
    )
    #expect(
      Edge.EdgeInitError.missingBridgeID.localizedDescription
        == "Bridge edge must have a bridge ID"
    )
    #expect(
      Edge.EdgeInitError.unexpectedBridgeID.localizedDescription
        == "Non-bridge edge should not have a bridge ID"
    )
  }

  // MARK: - Backward Compatibility Tests

  @Test("Backward-compatible non-throwing initializer (road)")
  func backwardCompatibleInitializer() {
    let edge = Edge(from: "A",
                    to: "B",
                    travelTime: 60.0,
                    distance: 100.0,
                    isBridge: false,
                    bridgeID: nil)

    #expect(edge.from == "A")
    #expect(edge.to == "B")
    #expect(edge.travelTime == 60.0)
    #expect(edge.distance == 100.0)
    #expect(edge.isBridge == false)
    #expect(edge.bridgeID == nil)
  }

  @Test("Backward-compatible non-throwing initializer (bridge)")
  func backwardCompatibleBridgeInitializer() {
    let edge = Edge(from: "A",
                    to: "B",
                    travelTime: 120.0,
                    distance: 200.0,
                    isBridge: true,
                    bridgeID: "1")

    #expect(edge.from == "A")
    #expect(edge.to == "B")
    #expect(edge.travelTime == 120.0)
    #expect(edge.distance == 200.0)
    #expect(edge.isBridge == true)
    #expect(edge.bridgeID == "1")
  }
}
