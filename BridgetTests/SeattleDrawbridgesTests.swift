//
//  SeattleDrawbridgesTests.swift
//  BridgetTests
//
//  Tests for SeattleDrawbridges single source of truth
//

import XCTest
@testable import Bridget

final class SeattleDrawbridgesTests: XCTestCase {
  
  func testBridgeCount() {
    XCTAssertEqual(SeattleDrawbridges.count, 7, "Should have exactly 7 Seattle drawbridges")
    XCTAssertEqual(SeattleDrawbridges.allBridges.count, 7, "All bridges array should have 7 bridges")
    XCTAssertEqual(SeattleDrawbridges.BridgeID.allCases.count, 7, "BridgeID enum should have 7 cases")
  }
  
  func testBridgeIDs() {
    let actualIDs = SeattleDrawbridges.allBridgeIDs
    XCTAssertEqual(actualIDs.count, 7, "Should have 7 bridge IDs")
    XCTAssertTrue(actualIDs.contains("1"), "Should contain First Avenue South Bridge ID")
    XCTAssertTrue(actualIDs.contains("2"), "Should contain Ballard Bridge ID")
    XCTAssertTrue(actualIDs.contains("3"), "Should contain Fremont Bridge ID")
    XCTAssertTrue(actualIDs.contains("4"), "Should contain Montlake Bridge ID")
    XCTAssertTrue(actualIDs.contains("6"), "Should contain Lower Spokane Bridge ID")
    XCTAssertTrue(actualIDs.contains("21"), "Should contain University Bridge ID")
    XCTAssertTrue(actualIDs.contains("29"), "Should contain South Park Bridge ID")
  }
  
  func testBridgeNames() {
    let expectedNames = [
      "First Avenue South Bridge",
      "Ballard Bridge", 
      "Fremont Bridge",
      "Montlake Bridge",
      "Lower Spokane Street Bridge",
      "South Park Bridge",
      "University Bridge"
    ].sorted()
    
    let actualNames = SeattleDrawbridges.allBridges.map { $0.name }.sorted()
    
    XCTAssertEqual(actualNames, expectedNames, "Bridge names should match actual Seattle drawbridges")
  }
  
  func testBridgeInfoLookup() {
    // Test lookup by enum
    let ballardInfo = SeattleDrawbridges.bridgeInfo(for: .ballard)
    XCTAssertNotNil(ballardInfo, "Should find Ballard Bridge info")
    XCTAssertEqual(ballardInfo?.name, "Ballard Bridge")
    XCTAssertEqual(ballardInfo?.connections, "Ballard ⇆ Interbay")
    
    // Test lookup by string ID
    let fremontInfo = SeattleDrawbridges.bridgeInfo(for: "3")
    XCTAssertNotNil(fremontInfo, "Should find Fremont Bridge info by string ID")
    XCTAssertEqual(fremontInfo?.name, "Fremont Bridge")
    XCTAssertEqual(fremontInfo?.connections, "Fremont ⇆ Queen Anne")
  }
  
  func testInvalidBridgeID() {
    let invalidInfo = SeattleDrawbridges.bridgeInfo(for: "999")
    XCTAssertNil(invalidInfo, "Should return nil for invalid bridge ID")
    
    XCTAssertFalse(SeattleDrawbridges.isValidBridgeID("999"), "Should reject invalid bridge ID")
    XCTAssertTrue(SeattleDrawbridges.isValidBridgeID("2"), "Should accept valid bridge ID")
  }
  
  func testBridgeLocationsCompatibility() {
    // Test that bridgeLocations dictionary is correctly populated
    XCTAssertEqual(SeattleDrawbridges.bridgeLocations.count, 7, "Should have 7 bridge locations")
    
    let ballardLocation = SeattleDrawbridges.bridgeLocations["2"]
    XCTAssertNotNil(ballardLocation, "Should have Ballard Bridge location")
    guard let location = ballardLocation else { return }
    XCTAssertEqual(location.lat, 47.6598, accuracy: 0.0001, "Ballard latitude should match")
    XCTAssertEqual(location.lon, -122.3762, accuracy: 0.0001, "Ballard longitude should match")
  }
  
  func testBridgeNamesCompatibility() {
    // Test that bridgeNames dictionary is correctly populated
    XCTAssertEqual(SeattleDrawbridges.bridgeNames.count, 7, "Should have 7 bridge names")
    
    let ballardName = SeattleDrawbridges.bridgeNames["2"]
    XCTAssertEqual(ballardName, "Ballard Bridge", "Should have correct Ballard Bridge name")
  }
  
  func testBridgeIDExtensions() {
    let ballardID = SeattleDrawbridges.BridgeID.ballard
    XCTAssertEqual(ballardID.displayName, "Ballard Bridge", "Display name should work")
    
    let coordinate = ballardID.coordinate
    XCTAssertEqual(coordinate.latitude, 47.6598, accuracy: 0.0001, "Coordinate should work")
    XCTAssertEqual(coordinate.longitude, -122.3762, accuracy: 0.0001, "Coordinate should work")
  }
  
  func testAllIDsSet() {
    let allIDs = SeattleDrawbridges.BridgeID.allIDs
    XCTAssertEqual(allIDs.count, 7, "Should have 7 bridge IDs in set")
    XCTAssertTrue(allIDs.contains("2"), "Should contain Ballard Bridge ID")
    XCTAssertTrue(allIDs.contains("3"), "Should contain Fremont Bridge ID")
  }
  
  // MARK: - Single Source of Truth Enforcement Tests
  
  func testNonCanonicalBridgeIDRejection() {
    // Test that non-canonical bridge IDs are rejected
    let nonCanonicalIDs = ["0", "5", "7", "8", "9", "10", "999", "invalid", ""]
    
    for nonCanonicalID in nonCanonicalIDs {
      XCTAssertFalse(SeattleDrawbridges.isValidBridgeID(nonCanonicalID), "Non-canonical ID '\(nonCanonicalID)' should be rejected")
      XCTAssertNil(SeattleDrawbridges.bridgeInfo(for: nonCanonicalID), "Non-canonical ID '\(nonCanonicalID)' should not have bridge info")
    }
  }
  
  func testCanonicalBridgeIDAcceptance() {
    // Test that all canonical bridge IDs are accepted
    for bridgeID in SeattleDrawbridges.BridgeID.allIDs {
      XCTAssertTrue(SeattleDrawbridges.isValidBridgeID(bridgeID), "Canonical ID '\(bridgeID)' should be accepted")
      XCTAssertNotNil(SeattleDrawbridges.bridgeInfo(for: bridgeID), "Canonical ID '\(bridgeID)' should have bridge info")
    }
  }
  
  func testBridgeIDValidationEdgeCases() {
    // Test edge cases
    XCTAssertFalse(SeattleDrawbridges.isValidBridgeID(""), "Empty string should be rejected")
    XCTAssertFalse(SeattleDrawbridges.isValidBridgeID(" "), "Whitespace should be rejected")
    XCTAssertFalse(SeattleDrawbridges.isValidBridgeID("1.0"), "Decimal should be rejected")
    XCTAssertFalse(SeattleDrawbridges.isValidBridgeID("1a"), "Alphanumeric should be rejected")
  }
  
  func testBridgeCountConsistency() {
    // Test that all count methods return the same value
    let expectedCount = 7
    XCTAssertEqual(SeattleDrawbridges.count, expectedCount)
    XCTAssertEqual(SeattleDrawbridges.allBridges.count, expectedCount)
    XCTAssertEqual(SeattleDrawbridges.BridgeID.allCases.count, expectedCount)
    XCTAssertEqual(SeattleDrawbridges.BridgeID.allIDs.count, expectedCount)
    XCTAssertEqual(SeattleDrawbridges.bridgeLocations.count, expectedCount)
    XCTAssertEqual(SeattleDrawbridges.bridgeNames.count, expectedCount)
  }
  
  func testSingleSourceOfTruthEnforcement() {
    // Test that SeattleDrawbridges is the single source of truth
    let expectedBridgeIDs = Set(["1", "2", "3", "4", "6", "21", "29"])
    let actualBridgeIDs = Set(SeattleDrawbridges.BridgeID.allIDs)
    
    XCTAssertEqual(actualBridgeIDs, expectedBridgeIDs, "Bridge IDs should exactly match the canonical set")
    
    // Test that all coordinates are valid (non-zero)
    for bridge in SeattleDrawbridges.allBridges {
      XCTAssertNotEqual(bridge.coordinate.latitude, 0.0, "Bridge \(bridge.name) should have non-zero latitude")
      XCTAssertNotEqual(bridge.coordinate.longitude, 0.0, "Bridge \(bridge.name) should have non-zero longitude")
    }
    
    // Test that all bridge IDs are unique
    let allIDs = SeattleDrawbridges.allBridges.map { $0.id.rawValue }
    let uniqueIDs = Set(allIDs)
    XCTAssertEqual(allIDs.count, uniqueIDs.count, "All bridge IDs should be unique")
  }
  
  func testBridgeIDSetConsistency() {
    // Test that all bridge ID collections contain the same IDs
    let allIDs = Set(SeattleDrawbridges.BridgeID.allIDs)
    let allCases = Set(SeattleDrawbridges.BridgeID.allCases.map { $0.rawValue })
    let bridgeInfoIDs = Set(SeattleDrawbridges.allBridges.map { $0.id.rawValue })
    let locationKeys = Set(SeattleDrawbridges.bridgeLocations.keys)
    let nameKeys = Set(SeattleDrawbridges.bridgeNames.keys)
    
    XCTAssertEqual(allIDs, allCases, "allIDs and allCases should be identical")
    XCTAssertEqual(allIDs, bridgeInfoIDs, "allIDs and bridgeInfoIDs should be identical")
    XCTAssertEqual(allIDs, locationKeys, "allIDs and locationKeys should be identical")
    XCTAssertEqual(allIDs, nameKeys, "allIDs and nameKeys should be identical")
  }
}
