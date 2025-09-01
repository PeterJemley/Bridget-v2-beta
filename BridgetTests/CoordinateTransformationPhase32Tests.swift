//
//  CoordinateTransformationPhase32Tests.swift
//  BridgetTests
//
//  Purpose: Phase 3.2 Testing Infrastructure for Coordinate Transformation System
//  Dependencies: Swift Testing framework, Bridget app module
//

import Foundation
import Testing

@testable import Bridget

@Suite("Coordinate Transformation Phase 3.2 Tests")
struct CoordinateTransformationPhase32Tests {

    @Test("Transformation accuracy on known point pairs")
    func testTransformationAccuracy() throws {
        let transformService = DefaultCoordinateTransformService(
            enableLogging: true
        )

        let testCases:
            [(
                bridgeId: String, apiCoords: (lat: Double, lon: Double),
                expectedCoords: (lat: Double, lon: Double)
            )] = [
                (
                    "1", (47.542213439941406, -122.33446502685547),
                    (47.598, -122.332)
                ),  // Bridge 1
                (
                    "6", (47.57137680053711, -122.35354614257812),
                    (47.58, -122.35)
                ),  // Bridge 6
            ]

        for testCase in testCases {
            let result = transformService.transformToReferenceSystem(
                latitude: testCase.apiCoords.lat,
                longitude: testCase.apiCoords.lon,
                from: .seattleAPI,
                bridgeId: testCase.bridgeId
            )

            #expect(
                result.success,
                "Transformation should succeed for bridge \(testCase.bridgeId)"
            )

            guard let transformedLat = result.transformedLatitude,
                let transformedLon = result.transformedLongitude
            else {
                #expect(
                    Bool(false),
                    "Transformed coordinates should not be nil"
                )
                continue
            }

            // Calculate distances
            let originalDistance = haversineDistanceMeters(
                lat1: testCase.apiCoords.lat,
                lon1: testCase.apiCoords.lon,
                lat2: testCase.expectedCoords.lat,
                lon2: testCase.expectedCoords.lon
            )

            let transformedDistance = haversineDistanceMeters(
                lat1: transformedLat,
                lon1: transformedLon,
                lat2: testCase.expectedCoords.lat,
                lon2: testCase.expectedCoords.lon
            )

            // Transformed coordinates should be significantly closer
            #expect(
                transformedDistance < originalDistance,
                "Transformation should improve accuracy for bridge \(testCase.bridgeId)"
            )

            // Transformed coordinates should be within reasonable distance
            #expect(
                transformedDistance < 1000,
                "Transformed coordinates should be within 1km for bridge \(testCase.bridgeId)"
            )

            print("📍 Bridge \(testCase.bridgeId) Accuracy:")
            print("   Original Distance: \(Int(originalDistance))m")
            print("   Transformed Distance: \(Int(transformedDistance))m")
            print(
                "   Improvement: \(Int(originalDistance - transformedDistance))m"
            )
        }
    }

    @Test("End-to-end validation pipeline")
    func testEndToEndValidationPipeline() throws {
        let testBridgeLocations: [String: (lat: Double, lon: Double)] = [
            "1": (47.598, -122.332)  // First Avenue South
        ]

        let knownBridgeIDs = Set(testBridgeLocations.keys)
        let validEntityTypes = Set(["bridge"])
        let minDate = Date(timeIntervalSince1970: 1_609_459_200)  // 2021-01-01
        let maxDate = Date(timeIntervalSince1970: 1_735_689_600)  // 2025-01-01

        let transformService = DefaultCoordinateTransformService(
            enableLogging: true
        )
        let bridgeRecordValidator = BridgeRecordValidator(
            knownBridgeIDs: knownBridgeIDs,
            bridgeLocations: testBridgeLocations,
            validEntityTypes: validEntityTypes,
            minDate: minDate,
            maxDate: maxDate,
            coordinateTransformService: transformService
        )

        let testRecord = BridgeOpeningRecord(
            entitytype: "bridge",
            entityname: "First Avenue South Bridge",
            entityid: "1",
            opendatetime: "2024-01-15T10:30:00.000",
            closedatetime: "2024-01-15T10:45:00.000",
            minutesopen: "15",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )

        let validationFailure = bridgeRecordValidator.validationFailure(
            for: testRecord
        )
        #expect(
            validationFailure == nil,
            "Bridge record should pass validation after transformation"
        )

        print("📍 End-to-end validation successful for bridge 1")
    }

    @Test("Performance impact measurement")
    func testPerformanceImpact() throws {
        let testBridgeLocations: [String: (lat: Double, lon: Double)] = [
            "1": (47.598, -122.332)  // First Avenue South
        ]

        let knownBridgeIDs = Set(testBridgeLocations.keys)
        let validEntityTypes = Set(["bridge"])
        let minDate = Date(timeIntervalSince1970: 1_609_459_200)  // 2021-01-01
        let maxDate = Date(timeIntervalSince1970: 1_735_689_600)  // 2025-01-01

        let transformService = DefaultCoordinateTransformService(
            enableLogging: true
        )
        let bridgeRecordValidator = BridgeRecordValidator(
            knownBridgeIDs: knownBridgeIDs,
            bridgeLocations: testBridgeLocations,
            validEntityTypes: validEntityTypes,
            minDate: minDate,
            maxDate: maxDate,
            coordinateTransformService: transformService
        )

        let testRecord = BridgeOpeningRecord(
            entitytype: "bridge",
            entityname: "First Avenue South Bridge",
            entityid: "1",
            opendatetime: "2024-01-15T10:30:00.000",
            closedatetime: "2024-01-15T10:45:00.000",
            minutesopen: "15",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )

        let iterations = 100
        let startTime = Date()

        for _ in 0..<iterations {
            _ = bridgeRecordValidator.validationFailure(for: testRecord)
        }

        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        let averageTime = totalTime / Double(iterations)

        #expect(
            averageTime < 0.01,
            "Average validation time should be less than 10ms"
        )

        print(
            "📍 Performance: \(String(format: "%.3f", averageTime * 1000))ms per validation"
        )
    }

    // MARK: - Helper Functions

    private func haversineDistanceMeters(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> Double {
        let R = 6_371_000.0  // Earth radius in meters
        let φ1 = lat1 * .pi / 180
        let φ2 = lat2 * .pi / 180
        let Δφ = (lat2 - lat1) * .pi / 180
        let Δλ = (lon2 - lon1) * .pi / 180

        let a =
            sin(Δφ / 2) * sin(Δφ / 2)
            + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}
