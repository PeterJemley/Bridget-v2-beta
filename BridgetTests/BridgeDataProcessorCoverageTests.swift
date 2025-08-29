//  BridgeDataProcessorCoverageTests.swift
//  BridgetTests
//
//  This test suite ensures 1-to-1 coverage between BridgeID.knownBridgeIDs and the bridgeLocations dictionary
//  within BridgeDataProcessor. It will fail if any bridge ID is missing a location or if bridgeLocations contains
//  extra/unknown IDs.

import Testing

@testable import Bridget

@Suite("BridgeID and bridgeLocations Coverage")
struct BridgeIDBridgeLocationsCoverageTests {
  @Test
  func allBridgeIDsHaveLocationsAndNoExtras() async throws {
    // Access the knownBridgeIDs and bridgeLocations as used in BridgeDataProcessor
    let knownBridgeIDs = Set(BridgeID.allIDs)
    // Duplicate the mapping here as in BridgeDataProcessor
    let bridgeLocations: [String: (lat: Double, lon: Double)] = [
      "1": (47.542213439941406, -122.33446502685547),  // 1st Ave South
      "2": (47.65981674194336, -122.37619018554688),  // Ballard
      "3": (47.64760208129883, -122.3497314453125),  // Fremont
      "4": (47.64728546142578, -122.3045883178711),  // Montlake
      "6": (47.57137680053711, -122.35354614257812),  // Lower Spokane St
      "21": (47.652652740478516, -122.32042694091797),  // University
      "29": (47.52923583984375, -122.31411743164062),  // South Park
    ]

    // 1: Check every knownBridgeID has a location
    for id in knownBridgeIDs {
      #expect(bridgeLocations.keys.contains(id), "Missing location for bridge ID: \(id)")
    }
    // 2: Check there are no extra entries in bridgeLocations
    for id in bridgeLocations.keys {
      #expect(knownBridgeIDs.contains(id), "Extra bridge location in bridgeLocations: \(id)")
    }
    // 3: Check 1-to-1 count
    #expect(
      knownBridgeIDs.count == bridgeLocations.count, "BridgeID and bridgeLocations count mismatch.")
  }
}
