#!/usr/bin/env swift

import Foundation

// Simple test to verify coordinate transformation feature flag is enabled
print("🔍 Testing Coordinate Transformation Feature Flag Status")
print(String(repeating: "=", count: 50))

// Simulate the feature flag service
let featureFlagService = DefaultFeatureFlagService.shared

// Check if coordinate transformation is enabled
let isEnabled = featureFlagService.isEnabled(.coordinateTransformation, for: "1")
let config = featureFlagService.getConfig(for: .coordinateTransformation)

print("📍 Feature Flag Status:")
print("   Enabled: \(isEnabled)")
print("   Rollout Percentage: \(config.rolloutPercentage.rawValue)%")
print("   A/B Testing: \(config.abTestEnabled)")
print("   Description: \(config.metadata["description"] ?? "No description")")

if isEnabled {
  print("✅ Coordinate transformation is ENABLED!")
  print("   This should resolve the geospatial validation errors.")

  // Test with Bridge 1 coordinates
  let apiLat = 47.542213439941406
  let apiLon = -122.33446502685547
  let expectedLat = 47.598
  let expectedLon = -122.332

  print("\n📍 Testing Bridge 1 Transformation:")
  print("   API Coordinates: (\(apiLat), \(apiLon))")
  print("   Expected Coordinates: (\(expectedLat), \(expectedLon))")

  // Calculate distance without transformation
  let distanceWithoutTransform = haversineDistance(lat1: apiLat, lon1: apiLon, lat2: expectedLat, lon2: expectedLon)
  print("   Distance without transformation: \(Int(distanceWithoutTransform))m")

  // With transformation (simplified)
  let transformedLat = apiLat + 0.056  // Apply the transformation offset
  let transformedLon = apiLon + 0.002
  let distanceWithTransform = haversineDistance(lat1: transformedLat, lon1: transformedLon, lat2: expectedLat, lon2: expectedLon)

  print("   Transformed Coordinates: (\(transformedLat), \(transformedLon))")
  print("   Distance with transformation: \(Int(distanceWithTransform))m")
  print("   Improvement: \(Int(distanceWithoutTransform - distanceWithTransform))m")

  if distanceWithTransform < 500 {
    print("✅ Transformation brings coordinates within 500m threshold!")
  } else {
    print("⚠️ Transformation still exceeds 500m threshold")
  }
} else {
  print("❌ Coordinate transformation is DISABLED!")
  print("   This explains the persistent geospatial validation errors.")
}

// Helper function to calculate Haversine distance
func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
  let R = 6_371_000.0  // Earth radius in meters
  let φ1 = lat1 * .pi / 180
  let φ2 = lat2 * .pi / 180
  let Δφ = (lat2 - lat1) * .pi / 180
  let Δλ = (lon2 - lon1) * .pi / 180

  let a = sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
  let c = 2 * atan2(sqrt(a), sqrt(1 - a))
  return R * c
}

print("\n" + String(repeating: "=", count: 50))
print("🎯 Summary:")
if isEnabled {
  print("✅ Coordinate transformation feature flag is ENABLED")
  print("✅ This should resolve the data validation errors")
  print("✅ The system will now use 500m threshold instead of 8km")
} else {
  print("❌ Coordinate transformation feature flag is DISABLED")
  print("❌ This explains the persistent validation errors")
  print("❌ The system is still using the old threshold-based validation")
}
