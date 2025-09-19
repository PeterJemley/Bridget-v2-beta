// BridgeRecordValidatorIntegrationTests.swift
import Foundation
import Testing

@testable import Bridget

@Suite("BridgeRecordValidator Integration Tests (2)")
@MainActor
struct BridgeRecordValidatorIntegrationTests2 {
    // MARK: - Common Setup

    private let knownBridgeIDs: Set<String> = ["1", "6"]
    private let bridgeLocations: [String: (lat: Double, lon: Double)] = [
        "1": (47.598, -122.332),  // First Avenue South
        "6": (47.58, -122.35),  // Lower Spokane Street
    ]
    private let validEntityTypes: Set<String> = ["bridge"]
    private let minDate = Date(timeIntervalSince1970: 1_609_459_200)  // 2021-01-01
    private let maxDate = Date(timeIntervalSince1970: 1_735_689_600)  // 2025-01-01

    private var transformService = DefaultCoordinateTransformService(
        enableLogging: true
    )

    private func makeValidator() -> BridgeRecordValidator {
        BridgeRecordValidator(
            knownBridgeIDs: knownBridgeIDs,
            bridgeLocations: bridgeLocations,
            validEntityTypes: validEntityTypes,
            minDate: minDate,
            maxDate: maxDate,
            coordinateTransformService: transformService
        )
    }

    // MARK: - 1) End-to-end validator acceptance (Phase 3.2 parity)

    @Test("E2E: Validator accepts transformed record for bridge 1")
    func endToEndValidatorAcceptance_bridge1() async throws {
        let validator = makeValidator()

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

        let failure = await validator.validationFailure(for: testRecord)
        #expect(
            failure == nil,
            "Bridge record should pass validation after transformation"
        )
    }

    // MARK: - 2) Transformation improves proximity at validator layer

    @Test("Integration: Transformation improves proximity (bridges 1 and 6)")
    func transformationImprovesProximityViaValidator() async throws {
        let validator = makeValidator()

        struct Case {
            let bridgeId: String
            let api: (lat: Double, lon: Double)
            let expected: (lat: Double, lon: Double)
            let maxDistanceAfterTransformMeters: Double
        }

        let cases: [Case] = [
            Case(
                bridgeId: "1",
                api: (47.542213439941406, -122.33446502685547),
                expected: (47.598, -122.332),
                maxDistanceAfterTransformMeters: 1000
            ),
            Case(
                bridgeId: "6",
                api: (47.57137680053711, -122.35354614257812),
                expected: (47.58, -122.35),
                maxDistanceAfterTransformMeters: 500
            ),
        ]

        for c in cases {
            // Record that should be accepted post-transformation
            let rec = BridgeOpeningRecord(
                entitytype: "bridge",
                entityname: "Bridge \(c.bridgeId)",
                entityid: c.bridgeId,
                opendatetime: "2024-01-15T10:30:00.000",
                closedatetime: "2024-01-15T10:45:00.000",
                minutesopen: "15",
                latitude: "\(c.api.lat)",
                longitude: "\(c.api.lon)"
            )

            let failure = await validator.validationFailure(for: rec)
            #expect(
                failure == nil,
                "Record for bridge \(c.bridgeId) should pass after transformation"
            )

            // Independently measure improvement using the transform service
            let originalDistance = haversineDistanceMeters(
                lat1: c.api.lat,
                lon1: c.api.lon,
                lat2: c.expected.lat,
                lon2: c.expected.lon
            )

            let t = await transformService.transformToReferenceSystem(
                latitude: c.api.lat,
                longitude: c.api.lon,
                from: .seattleAPI,
                bridgeId: c.bridgeId
            )
            #expect(
                t.success,
                "Transform should succeed for bridge \(c.bridgeId)"
            )

            let tLat = try #require(t.transformedLatitude)
            let tLon = try #require(t.transformedLongitude)
            let transformedDistance = haversineDistanceMeters(
                lat1: tLat,
                lon1: tLon,
                lat2: c.expected.lat,
                lon2: c.expected.lon
            )

            #expect(
                transformedDistance < originalDistance,
                "Transformation should improve proximity for bridge \(c.bridgeId)"
            )
            #expect(
                transformedDistance < c.maxDistanceAfterTransformMeters,
                "Transformed distance should be within \(Int(c.maxDistanceAfterTransformMeters))m for bridge \(c.bridgeId)"
            )

            print("📍 Bridge \(c.bridgeId) Integration:")
            print("   Original Distance: \(Int(originalDistance))m")
            print("   Transformed Distance: \(Int(transformedDistance))m")
            print(
                "   Improvement: \(Int(originalDistance - transformedDistance))m"
            )
        }
    }

    // MARK: - 3) Validator performance budget (Phase 3.2 parity)

    @Test("Performance: validation average < 10ms over 100 iterations")
    func validatorPerformanceBudget() async throws {
        let validator = makeValidator()

        let rec = BridgeOpeningRecord(
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
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = await validator.validationFailure(for: rec)
        }
        let total = CFAbsoluteTimeGetCurrent() - start
        let avg = total / Double(iterations)

        #expect(
            avg < 0.01,
            "Average validation time should be < 10ms, got \(avg * 1000)ms"
        )
        print(
            "📍 Validator performance: \(String(format: "%.3f", avg * 1000))ms per validation"
        )
    }

    // MARK: - Helper

    private func haversineDistanceMeters(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> Double {
        let R = 6_371_000.0
        let φ1 = lat1 * .pi / 180
        let φ2 = lat2 * .pi / 180
        let Δφ = (lat2 - lat1) * .pi / 180
        let Δλ = (lon2 - lon1) * .pi / 180

        let a =
            sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2)
            * sin(Δλ / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}

