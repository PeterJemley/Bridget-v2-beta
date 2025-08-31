//
//  SwiftTestingExample.swift
//  BridgetTests
//
//  Purpose: Demonstrate Swift Testing framework capabilities
//  Dependencies: Swift Testing framework (Xcode 26.0+)
//  Integration Points:
//    - Uses Swift Testing macros and features
//    - Demonstrates property-based testing
//    - Shows async/await testing capabilities
//

import Foundation
import Testing

@testable import Bridget

@Suite("Swift Testing Examples")
struct SwiftTestingExamples {

  @Test("Basic assertion example")
  func basicAssertion() throws {
    let result = 2 + 2
    #expect(result == 4)
    #expect(result > 0)
    #expect(result < 10)
  }

  @Test("String validation example")
  func stringValidation() throws {
    let bridgeID = "1"
    let isValid = SeattleDrawbridges.isCanonicalBridgeID(bridgeID)
    #expect(isValid == true)

    let invalidID = "999"
    let isInvalid = SeattleDrawbridges.isCanonicalBridgeID(invalidID)
    #expect(isInvalid == false)
  }

  @Test("Array validation example")
  func arrayValidation() throws {
    let bridgeIDs = SeattleDrawbridges.BridgeID.allIDs
    #expect(bridgeIDs.count == 7)
    #expect(bridgeIDs.contains("1"))
    #expect(bridgeIDs.contains("29"))
  }

  @Test("Async testing example")
  func asyncTesting() async throws {
    // Simulate some async work
    let result = await performAsyncWork()
    #expect(result == "completed")
  }

  @Test("Throwing function example")
  func throwingFunction() throws {
    let validInput = "valid"
    let result = try processInput(validInput)
    #expect(result == "processed: valid")

    // Test that invalid input throws
    #expect(throws: TestError.invalidInput) {
      try processInput("invalid")
    }
  }

  @Test("Property-based testing example")
  func propertyBasedTesting() throws {
    // Test that all canonical bridge IDs are valid
    for bridgeID in SeattleDrawbridges.BridgeID.allIDs {
      #expect(SeattleDrawbridges.isCanonicalBridgeID(bridgeID))
    }

    // Test that synthetic test IDs are not canonical
    let syntheticIDs = ["bridge1", "bridge2", "bridge999"]
    for syntheticID in syntheticIDs {
      #expect(!SeattleDrawbridges.isCanonicalBridgeID(syntheticID))
      #expect(SeattleDrawbridges.isSyntheticTestBridgeID(syntheticID))
    }
  }

  @Test("Performance testing example")
  func performanceTesting() throws {
    let bridgeIDs = Array(repeating: "1", count: 1000)

    let startTime = Date()
    for _ in 0..<1000 {
      _ = SeattleDrawbridges.isCanonicalBridgeID("1")
    }
    let endTime = Date()

    let duration = endTime.timeIntervalSince(startTime)
    #expect(duration < 1.0)  // Should complete in less than 1 second
  }

  // Helper functions for testing
  private func performAsyncWork() async -> String {
    try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms delay
    return "completed"
  }

  private func processInput(_ input: String) throws -> String {
    if input == "invalid" {
      throw TestError.invalidInput
    }
    return "processed: \(input)"
  }
}

// Custom error for testing
enum TestError: Error {
  case invalidInput
}

// Additional test suite for bridge-specific functionality
@Suite("Bridge Validation Tests")
struct BridgeValidationTests {

  @Test("All bridge IDs are unique")
  func uniqueBridgeIDs() throws {
    let bridgeIDs = SeattleDrawbridges.BridgeID.allIDs
    let uniqueIDs = Set(bridgeIDs)
    #expect(bridgeIDs.count == uniqueIDs.count)
  }

  @Test("Bridge info lookup works for all IDs")
  func bridgeInfoLookup() throws {
    for bridgeID in SeattleDrawbridges.BridgeID.allIDs {
      let info = SeattleDrawbridges.bridgeInfo(for: bridgeID)
      #expect(info != nil)
      #expect(info?.id.rawValue == bridgeID)
    }
  }

  @Test("Synthetic test ID pattern validation")
  func syntheticTestIDPattern() throws {
    let validSyntheticIDs = ["bridge1", "bridge2", "bridge999", "bridge12345"]
    let invalidSyntheticIDs = ["bridge", "bridge1a", "bridge_1", "Bridge1", "BRIDGE1"]

    for validID in validSyntheticIDs {
      #expect(SeattleDrawbridges.isSyntheticTestBridgeID(validID))
    }

    for invalidID in invalidSyntheticIDs {
      #expect(!SeattleDrawbridges.isSyntheticTestBridgeID(invalidID))
    }
  }

  @Test("Policy-based validation works correctly")
  func policyBasedValidation() throws {
    let canonicalID = "1"
    let syntheticID = "bridge1"
    let invalidID = "999"

    // Test with allowSynthetic: false (default)
    #expect(SeattleDrawbridges.isAcceptedBridgeID(canonicalID))
    #expect(!SeattleDrawbridges.isAcceptedBridgeID(syntheticID))
    #expect(!SeattleDrawbridges.isAcceptedBridgeID(invalidID))

    // Test with allowSynthetic: true
    #expect(SeattleDrawbridges.isAcceptedBridgeID(canonicalID, allowSynthetic: true))
    #expect(SeattleDrawbridges.isAcceptedBridgeID(syntheticID, allowSynthetic: true))
    #expect(!SeattleDrawbridges.isAcceptedBridgeID(invalidID, allowSynthetic: true))
  }
}
