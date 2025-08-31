import XCTest

@testable import Bridget

final class EdgeInitializerTests: XCTestCase {

  // MARK: - Valid Edge Creation Tests

  func testValidRoadEdgeCreation() throws {
    let edge = try Edge(
      validatingFrom: "A", to: "B", travelTime: 60.0, distance: 100.0, isBridge: false,
      bridgeID: nil)

    XCTAssertEqual(edge.from, "A")
    XCTAssertEqual(edge.to, "B")
    XCTAssertEqual(edge.travelTime, 60.0)
    XCTAssertEqual(edge.distance, 100.0)
    XCTAssertFalse(edge.isBridge)
    XCTAssertNil(edge.bridgeID)
  }

  func testValidBridgeEdgeCreation() throws {
    let edge = try Edge(
      validatingFrom: "A", to: "B", travelTime: 120.0, distance: 200.0, isBridge: true,
      bridgeID: "1")

    XCTAssertEqual(edge.from, "A")
    XCTAssertEqual(edge.to, "B")
    XCTAssertEqual(edge.travelTime, 120.0)
    XCTAssertEqual(edge.distance, 200.0)
    XCTAssertTrue(edge.isBridge)
    XCTAssertEqual(edge.bridgeID, "1")
  }

  func testValidSyntheticBridgeEdgeCreation() throws {
    let edge = try Edge(
      validatingFrom: "A", to: "B", travelTime: 90.0, distance: 150.0, isBridge: true,
      bridgeID: "bridge1")

    XCTAssertEqual(edge.from, "A")
    XCTAssertEqual(edge.to, "B")
    XCTAssertEqual(edge.travelTime, 90.0)
    XCTAssertEqual(edge.distance, 150.0)
    XCTAssertTrue(edge.isBridge)
    XCTAssertEqual(edge.bridgeID, "bridge1")
  }

  // MARK: - Error Cases Tests

  func testSelfLoopThrowsError() {
    XCTAssertThrowsError(
      try Edge(
        validatingFrom: "A", to: "A", travelTime: 60.0, distance: 100.0, isBridge: false,
        bridgeID: nil)
    ) { error in
      XCTAssertEqual(error as? Edge.EdgeInitError, .selfLoop)
    }
  }

  func testNonPositiveDistanceThrowsError() {
    // Zero distance
    XCTAssertThrowsError(
      try Edge(
        validatingFrom: "A", to: "B", travelTime: 60.0, distance: 0.0, isBridge: false,
        bridgeID: nil)
    ) { error in
      XCTAssertEqual(error as? Edge.EdgeInitError, .nonPositiveDistance)
    }

    // Negative distance
    XCTAssertThrowsError(
      try Edge(
        validatingFrom: "A", to: "B", travelTime: 60.0, distance: -10.0, isBridge: false,
        bridgeID: nil)
    ) { error in
      XCTAssertEqual(error as? Edge.EdgeInitError, .nonPositiveDistance)
    }

    // Infinite distance
    XCTAssertThrowsError(
      try Edge(
        validatingFrom: "A", to: "B", travelTime: 60.0, distance: Double.infinity, isBridge: false,
        bridgeID: nil)
    ) { error in
      XCTAssertEqual(error as? Edge.EdgeInitError, .nonPositiveDistance)
    }

    // NaN distance
    XCTAssertThrowsError(
      try Edge(
        validatingFrom: "A", to: "B", travelTime: 60.0, distance: Double.nan, isBridge: false,
        bridgeID: nil)
    ) { error in
      XCTAssertEqual(error as? Edge.EdgeInitError, .nonPositiveDistance)
    }
  }

  func testNonPositiveTravelTimeThrowsError() {
    // Zero travel time
    XCTAssertThrowsError(
      try Edge(
        validatingFrom: "A", to: "B", travelTime: 0.0, distance: 100.0, isBridge: false,
        bridgeID: nil)
    ) { error in
      XCTAssertEqual(error as? Edge.EdgeInitError, .nonPositiveTravelTime)
    }

    // Negative travel time
    XCTAssertThrowsError(
      try Edge(
        validatingFrom: "A", to: "B", travelTime: -30.0, distance: 100.0, isBridge: false,
        bridgeID: nil)
    ) { error in
      XCTAssertEqual(error as? Edge.EdgeInitError, .nonPositiveTravelTime)
    }

    // Infinite travel time
    XCTAssertThrowsError(
      try Edge(
        validatingFrom: "A", to: "B", travelTime: TimeInterval.infinity, distance: 100.0,
        isBridge: false, bridgeID: nil)
    ) { error in
      XCTAssertEqual(error as? Edge.EdgeInitError, .nonPositiveTravelTime)
    }

    // NaN travel time
    XCTAssertThrowsError(
      try Edge(
        validatingFrom: "A", to: "B", travelTime: TimeInterval.nan, distance: 100.0,
        isBridge: false, bridgeID: nil)
    ) { error in
      XCTAssertEqual(error as? Edge.EdgeInitError, .nonPositiveTravelTime)
    }
  }

  func testMissingBridgeIDThrowsError() {
    XCTAssertThrowsError(
      try Edge(
        validatingFrom: "A", to: "B", travelTime: 60.0, distance: 100.0, isBridge: true,
        bridgeID: nil)
    ) { error in
      XCTAssertEqual(error as? Edge.EdgeInitError, .missingBridgeID)
    }
  }

  func testUnexpectedBridgeIDThrowsError() {
    XCTAssertThrowsError(
      try Edge(
        validatingFrom: "A", to: "B", travelTime: 60.0, distance: 100.0, isBridge: false,
        bridgeID: "1")
    ) { error in
      XCTAssertEqual(error as? Edge.EdgeInitError, .unexpectedBridgeID)
    }
  }

  // MARK: - Convenience Initializer Tests

  func testRoadConvenienceInitializer() {
    let edge = Edge.road(from: "A", to: "B", travelTime: 60.0, distance: 100.0)

    XCTAssertEqual(edge.from, "A")
    XCTAssertEqual(edge.to, "B")
    XCTAssertEqual(edge.travelTime, 60.0)
    XCTAssertEqual(edge.distance, 100.0)
    XCTAssertFalse(edge.isBridge)
    XCTAssertNil(edge.bridgeID)
  }

  func testBridgeConvenienceInitializerWithValidID() {
    let edge = Edge.bridge(from: "A", to: "B", travelTime: 120.0, distance: 200.0, bridgeID: "1")

    XCTAssertNotNil(edge)
    XCTAssertEqual(edge?.from, "A")
    XCTAssertEqual(edge?.to, "B")
    XCTAssertEqual(edge?.travelTime, 120.0)
    XCTAssertEqual(edge?.distance, 200.0)
    XCTAssertTrue(edge?.isBridge ?? false)
    XCTAssertEqual(edge?.bridgeID, "1")
  }

  func testBridgeConvenienceInitializerWithSyntheticID() {
    let edge = Edge.bridge(
      from: "A", to: "B", travelTime: 90.0, distance: 150.0, bridgeID: "bridge1")

    XCTAssertNotNil(edge)
    XCTAssertEqual(edge?.from, "A")
    XCTAssertEqual(edge?.to, "B")
    XCTAssertEqual(edge?.travelTime, 90.0)
    XCTAssertEqual(edge?.distance, 150.0)
    XCTAssertTrue(edge?.isBridge ?? false)
    XCTAssertEqual(edge?.bridgeID, "bridge1")
  }

  func testBridgeConvenienceInitializerWithInvalidID() {
    let edge = Edge.bridge(
      from: "A", to: "B", travelTime: 120.0, distance: 200.0, bridgeID: "invalid")

    XCTAssertNil(edge)
  }

  func testBridgeThrowingConvenienceInitializer() throws {
    let edge = try Edge.bridgeThrowing(
      from: "A", to: "B", travelTime: 120.0, distance: 200.0, bridgeID: "1")

    XCTAssertEqual(edge.from, "A")
    XCTAssertEqual(edge.to, "B")
    XCTAssertEqual(edge.travelTime, 120.0)
    XCTAssertEqual(edge.distance, 200.0)
    XCTAssertTrue(edge.isBridge)
    XCTAssertEqual(edge.bridgeID, "1")
  }

  // MARK: - Error Description Tests

  func testErrorDescriptions() {
    XCTAssertEqual(
      Edge.EdgeInitError.selfLoop.localizedDescription, "Edge cannot connect a node to itself")
    XCTAssertEqual(
      Edge.EdgeInitError.nonPositiveDistance.localizedDescription,
      "Edge distance must be positive and finite")
    XCTAssertEqual(
      Edge.EdgeInitError.nonPositiveTravelTime.localizedDescription,
      "Edge travel time must be positive and finite")
    XCTAssertEqual(
      Edge.EdgeInitError.missingBridgeID.localizedDescription, "Bridge edge must have a bridge ID")
    XCTAssertEqual(
      Edge.EdgeInitError.unexpectedBridgeID.localizedDescription,
      "Non-bridge edge should not have a bridge ID")
  }

  // MARK: - Backward Compatibility Tests

  func testBackwardCompatibleInitializer() {
    // This should work without throwing
    let edge = Edge(
      from: "A", to: "B", travelTime: 60.0, distance: 100.0, isBridge: false, bridgeID: nil)

    XCTAssertEqual(edge.from, "A")
    XCTAssertEqual(edge.to, "B")
    XCTAssertEqual(edge.travelTime, 60.0)
    XCTAssertEqual(edge.distance, 100.0)
    XCTAssertFalse(edge.isBridge)
    XCTAssertNil(edge.bridgeID)
  }

  func testBackwardCompatibleBridgeInitializer() {
    // This should work without throwing (with warnings in debug)
    let edge = Edge(
      from: "A", to: "B", travelTime: 120.0, distance: 200.0, isBridge: true, bridgeID: "1")

    XCTAssertEqual(edge.from, "A")
    XCTAssertEqual(edge.to, "B")
    XCTAssertEqual(edge.travelTime, 120.0)
    XCTAssertEqual(edge.distance, 200.0)
    XCTAssertTrue(edge.isBridge)
    XCTAssertEqual(edge.bridgeID, "1")
  }
}
