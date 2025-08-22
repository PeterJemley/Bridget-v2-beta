//
//  BridgeCoordinateVerifier.swift
//  Bridget
//
//  Purpose: DEBUG-only utility for verifying bridge coordinates against API data
//  Dependencies: Foundation, CoreLocation, BridgeDataService
//  Integration Points:
//    - Uses BridgeDataService to fetch API coordinates
//    - Compares with BridgesCanonicalData constants
//    - Provides simple console output for verification
//  Key Features:
//    - DEBUG-only compilation
//    - Simple coordinate comparison
//    - Console-based reporting
//

import CoreLocation
import Foundation
import OSLog

#if DEBUG

  /// DEBUG-only utility for verifying bridge coordinates against API data.
  /// This code is excluded from production builds to reduce app size and complexity.
  public enum BridgeCoordinateVerifier {
    /// Verifies that our hardcoded bridge coordinates match the API data.
    /// Outputs results to console for manual review.
    public static func verifyCoordinates() async {
      os_log("🔍 Verifying bridge coordinates against API data...", log: .default, type: .info)

      do {
        // Fetch coordinates from Seattle API using DEBUG-only access
        let data = try await BridgeDataService.shared.debug_fetchFromNetwork()
        let records = try JSONDecoder.bridgeDecoder().decode([BridgeOpeningRecord].self, from: data)

        // Group by bridge ID and get unique coordinates
        let apiCoordinates = Dictionary(grouping: records) { $0.entityid }
          .compactMapValues { records -> (Double, Double)? in
            // Get the first valid coordinate set for each bridge
            guard let record = records.first,
                  let lat = record.latitudeValue,
                  let lon = record.longitudeValue else { return nil }
            return (lat, lon)
          }

        // Compare with our constants
        for bridge in BridgesCanonicalData.all {
          if let (apiLat, apiLon) = apiCoordinates[bridge.id] {
            let latDiff = abs(bridge.coordinate.latitude - apiLat)
            let lonDiff = abs(bridge.coordinate.longitude - apiLon)

            // Tolerance of ~100 meters (0.001 degrees ≈ 100m)
            if latDiff > 0.001 || lonDiff > 0.001 {
              os_log("⚠️  %{public}@ (ID: %d): API differs significantly", log: .default, type: .info, bridge.name, bridge.id)
              os_log("    Constants: %f, %f", log: .default, type: .info, bridge.coordinate.latitude, bridge.coordinate.longitude)
              os_log("    API: %f, %f", log: .default, type: .info, apiLat, apiLon)
              os_log("    Diff: lat=%f, lon=%f", log: .default, type: .info, latDiff, lonDiff)
            } else {
              os_log("✅ %{public}@ (ID: %d): coordinates match", log: .default, type: .info, bridge.name, bridge.id)
            }
          } else {
            os_log("❌ %{public}@ (ID: %d): no API data found", log: .default, type: .info, bridge.name, bridge.id)
          }
        }

        os_log("🔍 Coordinate verification complete.", log: .default, type: .info)

      } catch {
        os_log("❌ Failed to verify coordinates: %{public}@", log: .default, type: .error, error.localizedDescription)
      }
    }
  }

#endif
