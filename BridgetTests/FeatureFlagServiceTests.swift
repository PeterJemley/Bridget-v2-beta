//
//  FeatureFlagServiceTests.swift
//  BridgetTests
//
//  Purpose: Test feature flag service for gradual rollout and A/B testing
//  Dependencies: Bridget, Testing framework
//  Test Coverage:
//    - Feature flag configuration management
//    - Gradual rollout percentages
//    - A/B testing variants
//    - Feature flag persistence
//    - Rollback capabilities
//

import Foundation
import Testing

@Suite struct FeatureFlagServiceTests {
  @Test("Feature flag service initialization")
  func initialization() throws {
    let service = DefaultFeatureFlagService()
    let configs = service.getAllConfigs()

    #expect(configs.count > 0, "Should have default configurations")
    #expect(configs[.coordinateTransformation] != nil, "Should have coordinate transformation config")

    let coordConfig = service.getConfig(for: .coordinateTransformation)
    #expect(coordConfig.enabled == false, "Coordinate transformation should start disabled")
    #expect(coordConfig.rolloutPercentage == .disabled, "Should start with disabled rollout")
  }

  @Test("Feature flag enabled check")
  func featureFlagEnabled() throws {
    let service = DefaultFeatureFlagService()

    // Test with disabled feature
    let isEnabled = service.isEnabled(.coordinateTransformation, for: "test_bridge")
    #expect(isEnabled == false, "Feature should be disabled by default")

    // Enable feature with 100% rollout
    try service.updateConfig(FeatureFlagConfig(flag: .coordinateTransformation,
                                               enabled: true,
                                               rolloutPercentage: .oneHundredPercent))

    let isEnabledAfter = service.isEnabled(.coordinateTransformation, for: "test_bridge")
    #expect(isEnabledAfter == true, "Feature should be enabled with 100% rollout")
  }

  @Test("Gradual rollout percentages")
  func gradualRollout() throws {
    let service = DefaultFeatureFlagService()

    // Test 10% rollout
    try service.updateConfig(FeatureFlagConfig(flag: .coordinateTransformation,
                                               enabled: true,
                                               rolloutPercentage: .tenPercent))

    var enabledCount = 0
    let totalTests = 100

    for i in 0 ..< totalTests {
      let identifier = "bridge_\(i)"
      if service.isEnabled(.coordinateTransformation, for: identifier) {
        enabledCount += 1
      }
    }

    let percentage = Double(enabledCount) / Double(totalTests) * 100
    #expect(percentage >= 5 && percentage <= 15, "10% rollout should result in ~10% enabled (allowing variance)")
  }

  @Test("A/B testing variants")
  func aBTesting() throws {
    let service = DefaultFeatureFlagService()

    // Enable A/B testing
    try service.updateConfig(FeatureFlagConfig(flag: .coordinateTransformation,
                                               enabled: true,
                                               rolloutPercentage: .fiftyPercent,
                                               abTestEnabled: true,
                                               abTestVariant: .treatment))

    // Test consistent variant assignment
    let variant1 = service.getABTestVariant(.coordinateTransformation, for: "bridge_1")
    let variant2 = service.getABTestVariant(.coordinateTransformation, for: "bridge_1")
    #expect(variant1 == variant2, "Same identifier should get same variant")

    let variant3 = service.getABTestVariant(.coordinateTransformation, for: "bridge_2")
    #expect(variant3 != nil, "Should get a variant for enabled A/B test")
  }

  @Test("A/B testing distribution")
  func aBTestingDistribution() throws {
    let service = DefaultFeatureFlagService()

    // Enable A/B testing
    try service.updateConfig(FeatureFlagConfig(flag: .coordinateTransformation,
                                               enabled: true,
                                               rolloutPercentage: .oneHundredPercent,
                                               abTestEnabled: true,
                                               abTestVariant: .treatment))

    var controlCount = 0
    var treatmentCount = 0
    let totalTests = 100

    for i in 0 ..< totalTests {
      let identifier = "bridge_\(i)"
      if let variant = service.getABTestVariant(.coordinateTransformation, for: identifier) {
        switch variant {
        case .control:
          controlCount += 1
        case .treatment:
          treatmentCount += 1
        }
      }
    }

    #expect(controlCount > 0, "Should have some control variants")
    #expect(treatmentCount > 0, "Should have some treatment variants")
    #expect(controlCount + treatmentCount == totalTests, "All tests should get a variant")
  }

  @Test("Feature flag persistence")
  func persistence() throws {
    let service1 = DefaultFeatureFlagService()

    // Update configuration
    try service1.updateConfig(FeatureFlagConfig(flag: .coordinateTransformation,
                                                enabled: true,
                                                rolloutPercentage: .fiftyPercent,
                                                metadata: ["test": "persistence"]))

    // Create new service instance (should load from persistence)
    let service2 = DefaultFeatureFlagService()
    let config = service2.getConfig(for: .coordinateTransformation)

    #expect(config.enabled == true, "Configuration should persist")
    #expect(config.rolloutPercentage == .fiftyPercent, "Rollout percentage should persist")
    #expect(config.metadata["test"] == "persistence", "Metadata should persist")
  }

  @Test("Feature flag rollback")
  func rollback() throws {
    let service = DefaultFeatureFlagService()

    // Enable feature
    try service.updateConfig(FeatureFlagConfig(flag: .coordinateTransformation,
                                               enabled: true,
                                               rolloutPercentage: .oneHundredPercent))

    #expect(service.isEnabled(.coordinateTransformation, for: "test") == true, "Feature should be enabled")

    // Rollback (disable)
    service.disableCoordinateTransformation()

    #expect(service.isEnabled(.coordinateTransformation, for: "test") == false, "Feature should be disabled after rollback")
  }

  @Test("Convenience methods")
  func convenienceMethods() throws {
    let service = DefaultFeatureFlagService()

    // Test enable with specific rollout
    service.enableCoordinateTransformation(rolloutPercentage: .twentyFivePercent)
    let config1 = service.getConfig(for: .coordinateTransformation)
    #expect(config1.enabled == true, "Should be enabled")
    #expect(config1.rolloutPercentage == .twentyFivePercent, "Should have 25% rollout")

    // Test A/B testing enable
    service.enableCoordinateTransformationABTest()
    let config2 = service.getConfig(for: .coordinateTransformation)
    #expect(config2.abTestEnabled == true, "A/B testing should be enabled")
    #expect(config2.rolloutPercentage == .fiftyPercent, "Should have 50% rollout for A/B testing")

    // Test disable
    service.disableCoordinateTransformation()
    let config3 = service.getConfig(for: .coordinateTransformation)
    #expect(config3.enabled == false, "Should be disabled")
    #expect(config3.abTestEnabled == false, "A/B testing should be disabled")
  }

  @Test("Date range filtering")
  func dateRangeFiltering() throws {
    let service = DefaultFeatureFlagService()

    let now = Date()
    let future = now.addingTimeInterval(3600) // 1 hour from now
    let past = now.addingTimeInterval(-3600)  // 1 hour ago

    // Test future start date
    try service.updateConfig(FeatureFlagConfig(flag: .coordinateTransformation,
                                               enabled: true,
                                               rolloutPercentage: .oneHundredPercent,
                                               startDate: future))

    #expect(service.isEnabled(.coordinateTransformation, for: "test") == false, "Feature should not be active before start date")

    // Test past end date
    try service.updateConfig(FeatureFlagConfig(flag: .coordinateTransformation,
                                               enabled: true,
                                               rolloutPercentage: .oneHundredPercent,
                                               endDate: past))

    #expect(service.isEnabled(.coordinateTransformation, for: "test") == false, "Feature should not be active after end date")
  }

  @Test("Reset to defaults")
  func testResetToDefaults() throws {
    let service = DefaultFeatureFlagService()

    // Modify configuration
    try service.updateConfig(FeatureFlagConfig(flag: .coordinateTransformation,
                                               enabled: true,
                                               rolloutPercentage: .oneHundredPercent))

    #expect(service.isEnabled(.coordinateTransformation, for: "test") == true, "Feature should be enabled")

    // Reset to defaults
    service.resetToDefaults()

    #expect(service.isEnabled(.coordinateTransformation, for: "test") == false, "Feature should be disabled after reset")
  }
}
