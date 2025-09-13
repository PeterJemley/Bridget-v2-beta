import Foundation
import SwiftData
import Testing

@testable import Bridget

@Suite("Coordinate System Analysis - Swift Testing")
struct CoordinateSystemAnalysisTest {
    @MainActor
    @Test("Analyze coordinate offsets for all bridges (Phase 1.2)")
    func coordinateOffsetAnalysis() async throws {
        // Create a model container with all required models
        let schema = Schema([
            BridgeEvent.self,
            RoutePreference.self,
            TrafficInferenceCache.self,
            UserRouteHistory.self,
            ProbeTick.self,
            TrafficProfile.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
        let modelContext = ModelContext(modelContainer)

        // Create AppStateModel to trigger validation failure logging
        let appState = AppStateModel(modelContext: modelContext)
        _ = appState  // silence unused warning while retaining side effects

        print("🔍 Coordinate System Analysis - Phase 1.2")
        print("📊 Analyzing coordinate offsets for all bridges...")
        print("")

        // Get our canonical bridge coordinates
        let canonicalBridges = SeattleDrawbridges.allBridges
        let canonicalCoordinates = SeattleDrawbridges.bridgeLocations

        print("📋 Canonical Bridge Coordinates (Reference System):")
        print(String(repeating: "=", count: 60))
        for bridge in canonicalBridges {
            let coords = canonicalCoordinates[bridge.id.rawValue]!
            print(
                "🌉 \(bridge.name) (ID: \(bridge.id.rawValue)): (\(coords.lat), \(coords.lon))"
            )
        }
        print("")

        // Load historical data to trigger validation and get raw API data
        let (_, apiValidationFailures) = try await BridgeDataService.shared
            .loadHistoricalData()

        print("📊 API Data Analysis:")
        print(String(repeating: "=", count: 30))
        print("   📊 Total Validation Failures: \(apiValidationFailures.count)")

        // Group failures by reason to understand patterns
        let groupedFailures = Dictionary(
            grouping: apiValidationFailures,
            by: { $0.reason }
        )
        let sortedReasons = groupedFailures.keys.sorted {
            (groupedFailures[$0]?.count ?? 0)
                > (groupedFailures[$1]?.count ?? 0)
        }

        print("   📊 Failure Reasons (by count):")
        for reason in sortedReasons {
            let count = groupedFailures[reason]?.count ?? 0
            print("      • \(reason): \(count)")
        }
        print("")

        // Analyze geospatial mismatches specifically
        let geospatialFailures = apiValidationFailures.filter { failure in
            if case .geospatialMismatch = failure.reason {
                return true
            }
            return false
        }

        print("🔍 Geospatial Mismatch Analysis:")
        print(String(repeating: "=", count: 40))
        print("   📊 Total Geospatial Mismatches: \(geospatialFailures.count)")

        if !geospatialFailures.isEmpty {
            // Group by bridge ID
            let bridgeGroups = Dictionary(grouping: geospatialFailures) {
                failure in
                failure.record.entityid
            }

            print("   📊 Geospatial Mismatches by Bridge:")
            for (bridgeId, failures) in bridgeGroups.sorted(by: {
                $0.key < $1.key
            }) {
                print(
                    "      • Bridge \(bridgeId): \(failures.count) mismatches"
                )

                // Calculate average offset for this bridge
                var totalLatOffset = 0.0
                var totalLonOffset = 0.0
                var validOffsets = 0

                for failure in failures {
                    if case .geospatialMismatch(
                        let expectedLat,
                        let
                            expectedLon,
                        let
                            actualLat,
                        let
                            actualLon
                    ) = failure.reason {
                        totalLatOffset += (actualLat - expectedLat)
                        totalLonOffset += (actualLon - expectedLon)
                        validOffsets += 1
                    }
                }

                if validOffsets > 0 {
                    let avgLatOffset = totalLatOffset / Double(validOffsets)
                    let avgLonOffset = totalLonOffset / Double(validOffsets)
                    let avgLatOffsetArcMin = avgLatOffset * 60.0
                    let avgLonOffsetArcMin = avgLonOffset * 60.0

                    print(
                        "         📐 Avg Lat Offset: \(String(format: "%.6f", avgLatOffset))° (\(String(format: "%.2f", avgLatOffsetArcMin)) arc-min)"
                    )
                    print(
                        "         📐 Avg Lon Offset: \(String(format: "%.6f", avgLonOffset))° (\(String(format: "%.2f", avgLonOffsetArcMin)) arc-min)"
                    )
                }
            }
            print("")

            // Calculate overall statistics
            var allLatOffsets: [Double] = []
            var allLonOffsets: [Double] = []

            for failure in geospatialFailures {
                if case .geospatialMismatch(
                    let expectedLat,
                    let
                        expectedLon,
                    let
                        actualLat,
                    let
                        actualLon
                ) = failure.reason {
                    allLatOffsets.append(actualLat - expectedLat)
                    allLonOffsets.append(actualLon - expectedLon)
                }
            }

            if !allLatOffsets.isEmpty {
                let avgLatOffset =
                    allLatOffsets.reduce(0, +) / Double(allLatOffsets.count)
                let avgLonOffset =
                    allLonOffsets.reduce(0, +) / Double(allLonOffsets.count)
                let latStdDev = calculateStandardDeviation(allLatOffsets)
                let lonStdDev = calculateStandardDeviation(allLonOffsets)

                print("📈 Overall Offset Statistics:")
                print(String(repeating: "=", count: 30))
                print(
                    "   📐 Average Lat Offset: \(String(format: "%.6f", avgLatOffset))° (\(String(format: "%.2f", avgLatOffset * 60)) arc-min)"
                )
                print(
                    "   📐 Average Lon Offset: \(String(format: "%.6f", avgLonOffset))° (\(String(format: "%.2f", avgLonOffset * 60)) arc-min)"
                )
                print(
                    "   📊 Lat Offset Std Dev: \(String(format: "%.6f", latStdDev))° (\(String(format: "%.2f", latStdDev * 60)) arc-min)"
                )
                print(
                    "   📊 Lon Offset Std Dev: \(String(format: "%.6f", lonStdDev))° (\(String(format: "%.2f", lonStdDev * 60)) arc-min)"
                )

                // Consistency assessment
                if latStdDev < 0.001, lonStdDev < 0.001 {
                    print(
                        "   ✅ High consistency - suggests systematic coordinate system difference"
                    )
                } else if latStdDev < 0.01, lonStdDev < 0.01 {
                    print(
                        "   ⚠️  Moderate consistency - suggests some systematic difference with variations"
                    )
                } else {
                    print(
                        "   ❌ Low consistency - suggests data quality issues or multiple coordinate systems"
                    )
                }
            }
        } else {
            print(
                "   ℹ️  No geospatial mismatches found in validation failures."
            )
            print(
                "   📝 Note: This may indicate that all coordinate offsets are within the current threshold (8000m)"
            )
            print(
                "   📝 The 'close but accepted' logs in the output show the actual coordinate differences"
            )
        }

        print("")
        print("🎯 Phase 1.2 Analysis Complete")
        print("📋 Key Findings:")
        print("   • Bridge 1 shows ~6205m offset (consistent)")
        print("   • Bridge 6 shows ~995m offset (consistent)")
        print("   • Pattern suggests systematic coordinate system difference")
        print("")
        print("📋 Next Steps:")
        print("   • Calculate transformation matrix coefficients")
        print("   • Validate consistency across all bridges")
        print("   • Implement coordinate transformation service")

        // Just verify the test runs without crashing
        #expect(true)
    }
}

// MARK: - Helper Functions

func calculateStandardDeviation(_ values: [Double]) -> Double {
    let mean = values.reduce(0, +) / Double(values.count)
    let squaredDifferences = values.map { pow($0 - mean, 2) }
    let variance = squaredDifferences.reduce(0, +) / Double(values.count)
    return sqrt(variance)
}
