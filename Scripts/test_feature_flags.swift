#!/usr/bin/env swift

import Foundation

// Simple demonstration of feature flag functionality
print("🎯 Feature Flag System Demo")
print("=" * 50)

// Initialize feature flag service
let featureFlagService = DefaultFeatureFlagService()

// Test default state
print("\n📊 Default Configuration:")
let defaultConfig = featureFlagService.getConfig(for: .coordinateTransformation)
print("  Enabled: \(defaultConfig.enabled)")
print("  Rollout: \(defaultConfig.rolloutPercentage.description)")
print("  A/B Test: \(defaultConfig.abTestEnabled)")

// Test user bucketing
print("\n👥 User Bucketing Test (10 users, 50% rollout):")
featureFlagService.enableCoordinateTransformation(rolloutPercentage: .fiftyPercent)

var enabledCount = 0
for i in 1 ... 10 {
  let userId = "user-\(i)"
  let isEnabled = featureFlagService.isEnabled(.coordinateTransformation, for: userId)
  print("  \(userId): \(isEnabled ? "✅ Enabled" : "❌ Disabled")")
  if isEnabled { enabledCount += 1 }
}

print("  Total enabled: \(enabledCount)/10")

// Test A/B testing
print("\n🔬 A/B Testing Demo:")
featureFlagService.enableCoordinateTransformationABTest()

var controlCount = 0
var treatmentCount = 0
for i in 1 ... 10 {
  let userId = "abtest-user-\(i)"
  let variant = featureFlagService.getABTestVariant(.coordinateTransformation, for: userId)
  let variantName = variant?.description ?? "None"
  print("  \(userId): \(variantName)")
  if variant == .control { controlCount += 1 }
  if variant == .treatment { treatmentCount += 1 }
}

print("  Control: \(controlCount), Treatment: \(treatmentCount)")

// Test rollback
print("\n🔄 Rollback Test:")
featureFlagService.disableCoordinateTransformation()
let rollbackConfig = featureFlagService.getConfig(for: .coordinateTransformation)
print("  After rollback - Enabled: \(rollbackConfig.enabled)")
print("  After rollback - Rollout: \(rollbackConfig.rolloutPercentage.description)")

print("\n✅ Feature Flag Demo Complete!")
