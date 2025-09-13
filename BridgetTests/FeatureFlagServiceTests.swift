//
//  FeatureFlagServiceTests.swift
//  BridgetTests
//
//  Purpose: Unit tests for FeatureFlagService functionality
//  Dependencies: Foundation, Testing
//  Test Coverage:
//    - Feature flag configuration management
//    - Gradual rollout functionality
//    - A/B testing logic
//    - User bucketing consistency
//    - Configuration persistence
//

import Foundation
import Testing

@testable import Bridget

@Suite("Feature Flag Service Tests", .serialized)
@MainActor
struct FeatureFlagServiceTests {
    private var featureFlagService: DefaultFeatureFlagService!
    private let suiteName: String
    private let testDefaults: UserDefaults

    init() throws {
        // Use an isolated UserDefaults suite so tests are deterministic and do not
        // read/write the app’s standard defaults.
        self.suiteName = "FeatureFlagServiceTests-\(UUID().uuidString)"
        self.testDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        // Ensure a clean slate for this suite
        self.testDefaults.removePersistentDomain(forName: suiteName)

        featureFlagService = DefaultFeatureFlagService(
            userDefaults: testDefaults
        )
        // Start from known defaults every time
        featureFlagService.resetToDefaults()
    }

    @Test("Feature flag service should initialize with default configurations")
    func defaultInitialization() throws {
        let config = featureFlagService.getConfig(
            for: .coordinateTransformation
        )
        #expect(config.enabled == true)
        #expect(config.rolloutPercentage == .oneHundredPercent)
        #expect(config.abTestEnabled == false)
    }

    @Test("Feature flag should be enabled by default")
    func defaultEnabled() throws {
        let isEnabled = featureFlagService.isEnabled(
            .coordinateTransformation,
            for: "test-user"
        )
        #expect(isEnabled == true)
    }

    @Test("Feature flag should be enabled for users within rollout percentage")
    func testRolloutPercentage() throws {
        // Enable with 50% rollout
        try featureFlagService.updateConfig(
            FeatureFlagConfig(
                flag: .coordinateTransformation,
                enabled: true,
                rolloutPercentage: .fiftyPercent
            )
        )

        // Test multiple users to verify bucketing
        var enabledCount = 0
        let testUsers = [
            "user1", "user2", "user3", "user4", "user5", "user6", "user7",
            "user8", "user9", "user10",
        ]

        for user in testUsers {
            if featureFlagService.isEnabled(
                .coordinateTransformation,
                for: user
            ) {
                enabledCount += 1
            }
        }

        // Should be approximately 50% (allowing for some variance due to hashing)
        #expect(enabledCount >= 3 && enabledCount <= 7)
    }

    @Test("A/B testing should assign consistent variants to users")
    func aBTestingConsistency() throws {
        // Enable A/B testing (ensure abTestVariant non-nil so AB test is considered active)
        try featureFlagService.updateConfig(
            FeatureFlagConfig(
                flag: .coordinateTransformation,
                enabled: true,
                rolloutPercentage: .fiftyPercent,
                abTestEnabled: true,
                abTestVariant: .control
            )
        )

        let testUser = "consistent-user"

        // Get variant multiple times - should be consistent
        let variant1 = featureFlagService.getABTestVariant(
            .coordinateTransformation,
            for: testUser
        )
        let variant2 = featureFlagService.getABTestVariant(
            .coordinateTransformation,
            for: testUser
        )
        let variant3 = featureFlagService.getABTestVariant(
            .coordinateTransformation,
            for: testUser
        )

        #expect(variant1 == variant2)
        #expect(variant2 == variant3)
        #expect(variant1 != nil)
    }

    @Test("A/B testing should assign different variants to different users")
    func aBTestingDifferentUsers() throws {
        // Enable A/B testing (ensure abTestVariant non-nil so AB test is considered active)
        try featureFlagService.updateConfig(
            FeatureFlagConfig(
                flag: .coordinateTransformation,
                enabled: true,
                rolloutPercentage: .fiftyPercent,
                abTestEnabled: true,
                abTestVariant: .control
            )
        )

        let user1 = "user-a"
        let user2 = "user-b"

        let variant1 = featureFlagService.getABTestVariant(
            .coordinateTransformation,
            for: user1
        )
        let variant2 = featureFlagService.getABTestVariant(
            .coordinateTransformation,
            for: user2
        )

        // Variants should be assigned (though they might be the same due to hashing)
        #expect(variant1 != nil)
        #expect(variant2 != nil)
    }

    @Test("Feature flag should respect date range constraints")
    func dateRangeConstraints() throws {
        let futureDate = Date().addingTimeInterval(24 * 60 * 60)  // Tomorrow
        let pastDate = Date().addingTimeInterval(-24 * 60 * 60)  // Yesterday

        // Feature flag with future start date
        try featureFlagService.updateConfig(
            FeatureFlagConfig(
                flag: .coordinateTransformation,
                enabled: true,
                rolloutPercentage: .oneHundredPercent,
                startDate: futureDate
            )
        )

        let isEnabledFuture = featureFlagService.isEnabled(
            .coordinateTransformation,
            for: "test-user"
        )
        #expect(isEnabledFuture == false)

        // Feature flag with past end date
        try featureFlagService.updateConfig(
            FeatureFlagConfig(
                flag: .coordinateTransformation,
                enabled: true,
                rolloutPercentage: .oneHundredPercent,
                endDate: pastDate
            )
        )

        let isEnabledPast = featureFlagService.isEnabled(
            .coordinateTransformation,
            for: "test-user"
        )
        #expect(isEnabledPast == false)
    }

    @Test("Feature flag should be active within valid date range")
    func validDateRange() throws {
        let startDate = Date().addingTimeInterval(-60 * 60)  // 1 hour ago
        let endDate = Date().addingTimeInterval(60 * 60)  // 1 hour from now

        try featureFlagService.updateConfig(
            FeatureFlagConfig(
                flag: .coordinateTransformation,
                enabled: true,
                rolloutPercentage: .oneHundredPercent,
                startDate: startDate,
                endDate: endDate
            )
        )

        let isEnabled = featureFlagService.isEnabled(
            .coordinateTransformation,
            for: "test-user"
        )
        #expect(isEnabled == true)
    }

    @Test("Reset to defaults should restore initial configuration")
    func testResetToDefaults() throws {
        // Modify configuration
        try featureFlagService.updateConfig(
            FeatureFlagConfig(
                flag: .coordinateTransformation,
                enabled: false,
                rolloutPercentage: .disabled
            )
        )

        let modifiedConfig = featureFlagService.getConfig(
            for: .coordinateTransformation
        )
        #expect(modifiedConfig.enabled == false)
        #expect(modifiedConfig.rolloutPercentage == .disabled)

        // Reset to defaults
        featureFlagService.resetToDefaults()

        let defaultConfig = featureFlagService.getConfig(
            for: .coordinateTransformation
        )
        #expect(defaultConfig.enabled == true)
        #expect(defaultConfig.rolloutPercentage == .oneHundredPercent)
    }

    @Test("Get all configs should return all feature flags")
    func testGetAllConfigs() throws {
        let allConfigs = featureFlagService.getAllConfigs()

        // Should have configurations for all feature flags
        for flag in FeatureFlag.allCases {
            #expect(allConfigs[flag] != nil)
        }
    }

    @Test("Convenience methods should work correctly")
    func convenienceMethods() throws {
        // Test enable coordinate transformation
        featureFlagService.enableCoordinateTransformation(
            rolloutPercentage: .twentyFivePercent
        )

        let config = featureFlagService.getConfig(
            for: .coordinateTransformation
        )
        #expect(config.enabled == true)
        #expect(config.rolloutPercentage == .twentyFivePercent)

        // Test enable A/B testing
        featureFlagService.enableCoordinateTransformationABTest()

        let abConfig = featureFlagService.getConfig(
            for: .coordinateTransformation
        )
        #expect(abConfig.abTestEnabled == true)
        #expect(abConfig.rolloutPercentage == .fiftyPercent)

        // Test disable
        featureFlagService.disableCoordinateTransformation()

        let disabledConfig = featureFlagService.getConfig(
            for: .coordinateTransformation
        )
        #expect(disabledConfig.enabled == false)
        #expect(disabledConfig.rolloutPercentage == .disabled)
        #expect(disabledConfig.abTestEnabled == false)
    }

    @Test("Rollout percentage enum should have correct descriptions")
    func rolloutPercentageDescriptions() throws {
        #expect(RolloutPercentage.disabled.description == "Disabled (0%)")
        #expect(RolloutPercentage.tenPercent.description == "10% Rollout")
        #expect(RolloutPercentage.fiftyPercent.description == "50% Rollout")
        #expect(
            RolloutPercentage.oneHundredPercent.description
                == "100% Rollout (Full)"
        )
    }

    @Test("AB test variant enum should have correct descriptions")
    func aBTestVariantDescriptions() throws {
        #expect(ABTestVariant.control.description == "Control (Current)")
        #expect(ABTestVariant.treatment.description == "Treatment (New)")
    }

    @Test("Feature flag enum should have correct descriptions")
    func featureFlagDescriptions() throws {
        #expect(
            FeatureFlag.coordinateTransformation.description
                == "Coordinate Transformation System"
        )
        #expect(
            FeatureFlag.enhancedValidation.description
                == "Enhanced Bridge Record Validation"
        )
        #expect(
            FeatureFlag.statisticalUncertainty.description
                == "Statistical Uncertainty Quantification"
        )
        #expect(
            FeatureFlag.trafficProfileIntegration.description
                == "Traffic Profile Integration"
        )
    }
}
