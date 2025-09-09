//
//  SeattleDrawbridgesTests.swift
//  BridgetTests
//
//  Tests for SeattleDrawbridges single source of truth
//

import Foundation
import Testing

@testable import Bridget

@Suite("SeattleDrawbridges Tests")
struct SeattleDrawbridgesTests {
  @Test("Bridge count and collections should have exactly 7 items")
  func bridgeCount() {
    #expect(SeattleDrawbridges.count == 7,
            "Should have exactly 7 Seattle drawbridges")
    #expect(SeattleDrawbridges.allBridges.count == 7,
            "All bridges array should have 7 bridges")
    #expect(SeattleDrawbridges.BridgeID.allCases.count == 7,
            "BridgeID enum should have 7 cases")
  }

  @Test("Bridge IDs should contain all expected canonical IDs")
  func bridgeIDs() {
    let actualIDs = SeattleDrawbridges.allBridgeIDs
    #expect(actualIDs.count == 7, "Should have 7 bridge IDs")
    #expect(actualIDs.contains("1"),
            "Should contain First Avenue South Bridge ID")
    #expect(actualIDs.contains("2"), "Should contain Ballard Bridge ID")
    #expect(actualIDs.contains("3"), "Should contain Fremont Bridge ID")
    #expect(actualIDs.contains("4"), "Should contain Montlake Bridge ID")
    #expect(actualIDs.contains("6"),
            "Should contain Lower Spokane Bridge ID")
    #expect(actualIDs.contains("21"), "Should contain University Bridge ID")
    #expect(actualIDs.contains("29"), "Should contain South Park Bridge ID")
  }

  @Test("Bridge names should match actual Seattle drawbridges")
  func bridgeNames() {
    let expectedNames = [
      "First Avenue South Bridge",
      "Ballard Bridge",
      "Fremont Bridge",
      "Montlake Bridge",
      "Lower Spokane Street Bridge",
      "South Park Bridge",
      "University Bridge",
    ].sorted()

    let actualNames = SeattleDrawbridges.allBridges.map { $0.name }.sorted()

    #expect(actualNames == expectedNames,
            "Bridge names should match actual Seattle drawbridges")
  }

  @Test("Bridge info lookup by enum and string ID")
  func bridgeInfoLookup() {
    // Test lookup by enum
    let ballardInfo = SeattleDrawbridges.bridgeInfo(for: .ballard)
    #expect(ballardInfo != nil, "Should find Ballard Bridge info")
    #expect(ballardInfo?.name == "Ballard Bridge")
    #expect(ballardInfo?.connections == "Ballard ⇆ Interbay")

    // Test lookup by string ID
    let fremontInfo = SeattleDrawbridges.bridgeInfo(for: "3")
    #expect(fremontInfo != nil,
            "Should find Fremont Bridge info by string ID")
    #expect(fremontInfo?.name == "Fremont Bridge")
    #expect(fremontInfo?.connections == "Fremont ⇆ Queen Anne")
  }

  @Test("Invalid bridge ID should be rejected and return nil info")
  func invalidBridgeID() {
    let invalidInfo = SeattleDrawbridges.bridgeInfo(for: "999")
    #expect(invalidInfo == nil, "Should return nil for invalid bridge ID")

    #expect(!SeattleDrawbridges.isValidBridgeID("999"),
            "Should reject invalid bridge ID")
    #expect(SeattleDrawbridges.isValidBridgeID("2"),
            "Should accept valid bridge ID")
  }

  @Test("Bridge locations dictionary is correctly populated")
  func bridgeLocationsCompatibility() {
    #expect(SeattleDrawbridges.bridgeLocations.count == 7,
            "Should have 7 bridge locations")

    let ballardLocation = SeattleDrawbridges.bridgeLocations["2"]
    let location = try! #require(ballardLocation,
                                 "Should have Ballard Bridge location")
    #expect(abs(location.lat - 47.6598) < 0.0001,
            "Ballard latitude should match")
    #expect(abs(location.lon - -122.3762) < 0.0001,
            "Ballard longitude should match")
  }

  @Test("Bridge names dictionary is correctly populated")
  func bridgeNamesCompatibility() {
    #expect(SeattleDrawbridges.bridgeNames.count == 7,
            "Should have 7 bridge names")

    let ballardName = SeattleDrawbridges.bridgeNames["2"]
    #expect(ballardName == "Ballard Bridge",
            "Should have correct Ballard Bridge name")
  }

  @Test("BridgeID extensions provide displayName and coordinate")
  func bridgeIDExtensions() {
    let ballardID = SeattleDrawbridges.BridgeID.ballard
    #expect(ballardID.displayName == "Ballard Bridge",
            "Display name should work")

    let coordinate = ballardID.coordinate
    #expect(abs(coordinate.latitude - 47.6598) < 0.0001,
            "Coordinate should work (latitude)")
    #expect(abs(coordinate.longitude - -122.3762) < 0.0001,
            "Coordinate should work (longitude)")
  }

  @Test("BridgeID allIDs set contains all expected values")
  func allIDsSet() {
    let allIDs = SeattleDrawbridges.BridgeID.allIDs
    #expect(allIDs.count == 7, "Should have 7 bridge IDs in set")
    #expect(allIDs.contains("2"), "Should contain Ballard Bridge ID")
    #expect(allIDs.contains("3"), "Should contain Fremont Bridge ID")
  }

  // MARK: - Single Source of Truth Enforcement Tests

  @Test("Non-canonical bridge IDs are rejected and have no info")
  func nonCanonicalBridgeIDRejection() {
    let nonCanonicalIDs = [
      "0", "5", "7", "8", "9", "10", "999", "invalid", "",
    ]

    for nonCanonicalID in nonCanonicalIDs {
      #expect(!SeattleDrawbridges.isValidBridgeID(nonCanonicalID),
              "Non-canonical ID '\(nonCanonicalID)' should be rejected")
      #expect(SeattleDrawbridges.bridgeInfo(for: nonCanonicalID) == nil,
              "Non-canonical ID '\(nonCanonicalID)' should not have bridge info")
    }
  }

  @Test("All canonical bridge IDs are accepted and have info")
  func canonicalBridgeIDAcceptance() {
    for bridgeID in SeattleDrawbridges.BridgeID.allIDs {
      #expect(SeattleDrawbridges.isValidBridgeID(bridgeID),
              "Canonical ID '\(bridgeID)' should be accepted")
      #expect(SeattleDrawbridges.bridgeInfo(for: bridgeID) != nil,
              "Canonical ID '\(bridgeID)' should have bridge info")
    }
  }

  @Test("Bridge ID validation edge cases")
  func bridgeIDValidationEdgeCases() {
    #expect(!SeattleDrawbridges.isValidBridgeID(""),
            "Empty string should be rejected")
    #expect(!SeattleDrawbridges.isValidBridgeID(" "),
            "Whitespace should be rejected")
    #expect(!SeattleDrawbridges.isValidBridgeID("1.0"),
            "Decimal should be rejected")
    #expect(!SeattleDrawbridges.isValidBridgeID("1a"),
            "Alphanumeric should be rejected")
  }

  @Test("All count methods return consistent values")
  func bridgeCountConsistency() {
    let expectedCount = 7
    #expect(SeattleDrawbridges.count == expectedCount)
    #expect(SeattleDrawbridges.allBridges.count == expectedCount)
    #expect(SeattleDrawbridges.BridgeID.allCases.count == expectedCount)
    #expect(SeattleDrawbridges.BridgeID.allIDs.count == expectedCount)
    #expect(SeattleDrawbridges.bridgeLocations.count == expectedCount)
    #expect(SeattleDrawbridges.bridgeNames.count == expectedCount)
  }

  @Test("Single source of truth enforcement for IDs, coordinates, uniqueness")
  func singleSourceOfTruthEnforcement() {
    let expectedBridgeIDs = Set(["1", "2", "3", "4", "6", "21", "29"])
    let actualBridgeIDs = Set(SeattleDrawbridges.BridgeID.allIDs)

    #expect(actualBridgeIDs == expectedBridgeIDs,
            "Bridge IDs should exactly match the canonical set")

    for bridge in SeattleDrawbridges.allBridges {
      #expect(bridge.coordinate.latitude != 0.0,
              "Bridge \(bridge.name) should have non-zero latitude")
      #expect(bridge.coordinate.longitude != 0.0,
              "Bridge \(bridge.name) should have non-zero longitude")
    }

    let allIDs = SeattleDrawbridges.allBridges.map { $0.id.rawValue }
    let uniqueIDs = Set(allIDs)
    #expect(allIDs.count == uniqueIDs.count,
            "All bridge IDs should be unique")
  }

  @Test("Canonical bridge ID validation")
  func canonicalBridgeIDValidation() {
    // Canonical bridge IDs
    #expect(SeattleDrawbridges.isCanonicalBridgeID("1"),
            "First Avenue South Bridge should be canonical")
    #expect(SeattleDrawbridges.isCanonicalBridgeID("2"),
            "Ballard Bridge should be canonical")
    #expect(SeattleDrawbridges.isCanonicalBridgeID("29"),
            "South Park Bridge should be canonical")

    // Non-canonical bridge IDs
    #expect(!SeattleDrawbridges.isCanonicalBridgeID("0"),
            "Non-existent bridge ID should not be canonical")
    #expect(!SeattleDrawbridges.isCanonicalBridgeID("999"),
            "Non-existent bridge ID should not be canonical")
    #expect(!SeattleDrawbridges.isCanonicalBridgeID("bridge1"),
            "Synthetic test ID should not be canonical")
    #expect(!SeattleDrawbridges.isCanonicalBridgeID(""),
            "Empty string should not be canonical")
  }

  @Test("Synthetic test bridge ID validation")
  func syntheticTestBridgeIDValidation() {
    // Synthetic test bridge IDs
    #expect(SeattleDrawbridges.isSyntheticTestBridgeID("bridge1"),
            "bridge1 should be synthetic test ID")
    #expect(SeattleDrawbridges.isSyntheticTestBridgeID("bridge2"),
            "bridge2 should be synthetic test ID")
    #expect(SeattleDrawbridges.isSyntheticTestBridgeID("bridge999"),
            "bridge999 should be synthetic test ID")

    // Non-synthetic bridge IDs
    #expect(!SeattleDrawbridges.isSyntheticTestBridgeID("1"),
            "Canonical bridge ID should not be synthetic")
    #expect(!SeattleDrawbridges.isSyntheticTestBridgeID("bridge"),
            "bridge without number should not be synthetic")
    #expect(!SeattleDrawbridges.isSyntheticTestBridgeID("bridge1a"),
            "bridge1a should not be synthetic")
    #expect(!SeattleDrawbridges.isSyntheticTestBridgeID(""),
            "Empty string should not be synthetic")
  }

  @Test("Accepted bridge ID policy with and without synthetic allowance")
  func acceptedBridgeIDValidation() {
    // Default allowSynthetic: false
    #expect(SeattleDrawbridges.isAcceptedBridgeID("1"),
            "Canonical bridge ID should be accepted")
    #expect(SeattleDrawbridges.isAcceptedBridgeID("29"),
            "Canonical bridge ID should be accepted")
    #expect(!SeattleDrawbridges.isAcceptedBridgeID("bridge1"),
            "Synthetic test ID should not be accepted by default")
    #expect(!SeattleDrawbridges.isAcceptedBridgeID("999"),
            "Non-canonical ID should not be accepted")

    // allowSynthetic: true
    #expect(SeattleDrawbridges.isAcceptedBridgeID("1", allowSynthetic: true),
            "Canonical bridge ID should be accepted")
    #expect(SeattleDrawbridges.isAcceptedBridgeID("bridge1",
                                                  allowSynthetic: true),
            "Synthetic test ID should be accepted when allowed")
    #expect(SeattleDrawbridges.isAcceptedBridgeID("bridge999",
                                                  allowSynthetic: true),
            "Synthetic test ID should be accepted when allowed")
    #expect(!SeattleDrawbridges.isAcceptedBridgeID("999", allowSynthetic: true),
            "Non-canonical, non-synthetic ID should not be accepted")
  }

  @Test("All bridge ID collections contain identical IDs")
  func bridgeIDSetConsistency() {
    let allIDs = Set(SeattleDrawbridges.BridgeID.allIDs)
    let allCases = Set(
      SeattleDrawbridges.BridgeID.allCases.map { $0.rawValue }
    )
    let bridgeInfoIDs = Set(
      SeattleDrawbridges.allBridges.map { $0.id.rawValue }
    )
    let locationKeys = Set(SeattleDrawbridges.bridgeLocations.keys)
    let nameKeys = Set(SeattleDrawbridges.bridgeNames.keys)

    #expect(allIDs == allCases, "allIDs and allCases should be identical")
    #expect(allIDs == bridgeInfoIDs,
            "allIDs and bridgeInfoIDs should be identical")
    #expect(allIDs == locationKeys,
            "allIDs and locationKeys should be identical")
    #expect(allIDs == nameKeys, "allIDs and nameKeys should be identical")
  }
}
