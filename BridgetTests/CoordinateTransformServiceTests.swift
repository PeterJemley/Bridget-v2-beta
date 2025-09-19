import Foundation
import Testing

@testable import Bridget

@MainActor
@Suite("Coordinate Transform Service Tests")
struct CoordinateTransformServiceTests {
    var transformService: DefaultCoordinateTransformService

    init() {
        self.transformService = DefaultCoordinateTransformService(
            enableLogging: true
        )
    }

    // MARK: - Basic Transformation Tests

    @Test(
        "Identity transformation returns same coordinates with full confidence"
    )
    func identityTransformation() async throws {
        let lat = 47.598
        let lon = -122.332

        let result = await transformService.transform(
            latitude: lat,
            longitude: lon,
            from: .seattleReference,
            to: .seattleReference,
            bridgeId: "1"
        )

        #expect(result.success)
        let tLat = try #require(result.transformedLatitude)
        let tLon = try #require(result.transformedLongitude)
        #expect(abs(tLat - lat) <= 0.000001)
        #expect(abs(tLon - lon) <= 0.000001)
        #expect(result.confidence == 1.0)
    }

    @Test("Bridge 1 transformation improves proximity to expected location")
    func bridge1Transformation() async throws {
        // API coordinates: (47.542213439941406, -122.33446502685547)
        // Expected reference: (47.598, -122.332)
        let apiLat = 47.542213439941406
        let apiLon = -122.33446502685547
        let expectedLat = 47.598
        let expectedLon = -122.332

        let result = await transformService.transform(
            latitude: apiLat,
            longitude: apiLon,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "1"
        )

        #expect(result.success)
        let transformedLat = try #require(result.transformedLatitude)
        let transformedLon = try #require(result.transformedLongitude)

        let originalDistance = haversineDistance(
            lat1: apiLat,
            lon1: apiLon,
            lat2: expectedLat,
            lon2: expectedLon
        )
        let transformedDistance = haversineDistance(
            lat1: transformedLat,
            lon1: transformedLon,
            lat2: expectedLat,
            lon2: expectedLon
        )

        #expect(transformedDistance < originalDistance)
        #expect(transformedDistance < 1000)  // Within 1km after transformation

        print("📍 Bridge 1 Transformation:")
        print("   API: (\(apiLat), \(apiLon))")
        print("   Transformed: (\(transformedLat), \(transformedLon))")
        print("   Expected: (\(expectedLat), \(expectedLon))")
        print("   Original Distance: \(Int(originalDistance))m")
        print("   Transformed Distance: \(Int(transformedDistance))m")
    }

    @Test("Bridge 6 transformation improves proximity to expected location")
    func bridge6Transformation() async throws {
        // API coordinates: (47.57137680053711, -122.35354614257812)
        // Expected reference: (47.58, -122.35)
        let apiLat = 47.57137680053711
        let apiLon = -122.35354614257812
        let expectedLat = 47.58
        let expectedLon = -122.35

        let result = await transformService.transform(
            latitude: apiLat,
            longitude: apiLon,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "6"
        )

        #expect(result.success)
        let transformedLat = try #require(result.transformedLatitude)
        let transformedLon = try #require(result.transformedLongitude)

        let originalDistance = haversineDistance(
            lat1: apiLat,
            lon1: apiLon,
            lat2: expectedLat,
            lon2: expectedLon
        )
        let transformedDistance = haversineDistance(
            lat1: transformedLat,
            lon1: transformedLon,
            lat2: expectedLat,
            lon2: expectedLon
        )

        #expect(transformedDistance < originalDistance)
        #expect(transformedDistance < 500)  // Within 500m after transformation

        print("📍 Bridge 6 Transformation:")
        print("   API: (\(apiLat), \(apiLon))")
        print("   Transformed: (\(transformedLat), \(transformedLon))")
        print("   Expected: (\(expectedLat), \(expectedLon))")
        print("   Original Distance: \(Int(originalDistance))m")
        print("   Transformed Distance: \(Int(transformedDistance))m")
    }

    @Test(
        "Unknown bridge uses default matrix and returns reasonable confidence"
    )
    func unknownBridgeTransformation() async throws {
        let apiLat = 47.5
        let apiLon = -122.3

        let result = await transformService.transform(
            latitude: apiLat,
            longitude: apiLon,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "999"
        )

        #expect(result.success)
        _ = try #require(result.transformedLatitude)
        _ = try #require(result.transformedLongitude)

        #expect(result.confidence <= 1.0)
        #expect(result.confidence > 0.0)
    }

    // MARK: - Error Handling Tests

    @Test("Invalid coordinates produce invalidInputCoordinates error")
    func invalidCoordinates() async throws {
        let result = await transformService.transform(
            latitude: 100.0,  // Invalid latitude
            longitude: -122.3,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "1"
        )

        #expect(!result.success)
        let error = try #require(result.error, "Expected an error result")
        switch error {
        case .invalidInputCoordinates:
            #expect(true)
        default:
            Issue.record("Expected invalidInputCoordinates error, got \(error)")
            #expect(Bool(false))
        }
    }

    @Test("Unsupported coordinate system produces appropriate error")
    func testUnsupportedCoordinateSystem() async throws {
        let result = await transformService.transform(
            latitude: 47.5,
            longitude: -122.3,
            from: .nad27,  // Not supported in current implementation
            to: .wgs84,
            bridgeId: "1"
        )

        #expect(!result.success)
        let error = try #require(result.error, "Expected an error result")
        switch error {
        case .unsupportedCoordinateSystem:
            #expect(true)
        default:
            Issue.record(
                "Expected unsupportedCoordinateSystem error, got \(error)"
            )
            #expect(Bool(false))
        }
    }

    // MARK: - Matrix Calculation Tests

    @Test(
        "Matrix calculation returns non-identity for SeattleAPI -> Reference (Bridge 1)"
    )
    func transformationMatrixCalculation() async throws {
        let matrix = await transformService.calculateTransformationMatrix(
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "1"
        )

        let m = try #require(matrix)
        #expect(!(m == .identity))
        // Bridge 1 should have specific offsets (now using inverse transformation)
        #expect(abs(m.latOffset - 0.056) <= 0.001)
        #expect(abs(m.lonOffset - 0.002) <= 0.001)
    }

    @Test("Inverse matrix is the opposite of forward matrix")
    func inverseTransformationMatrix() async throws {
        let forwardMatrix = await transformService.calculateTransformationMatrix(
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "1"
        )
        let inverseMatrix = await transformService.calculateTransformationMatrix(
            from: .seattleReference,
            to: .seattleAPI,
            bridgeId: "1"
        )

        let fwd = try #require(forwardMatrix)
        let inv = try #require(inverseMatrix)

        #expect(abs(fwd.latOffset + inv.latOffset) <= 0.000001)
        #expect(abs(fwd.lonOffset + inv.lonOffset) <= 0.000001)
    }

    // MARK: - Confidence Tests

    @Test("Known bridge has high confidence; unknown bridge has lower (<= 1.0)")
    func transformationConfidence() async throws {
        // Known bridge should have high confidence
        let knownResult = await transformService.transform(
            latitude: 47.5,
            longitude: -122.3,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "1"
        )

        #expect(knownResult.success)
        #expect(knownResult.confidence > 0.9)

        // Unknown bridge should have lower confidence (but <= 1.0)
        let unknownResult = await transformService.transform(
            latitude: 47.5,
            longitude: -122.3,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "999"
        )

        #expect(unknownResult.success)
        #expect(unknownResult.confidence <= 1.0)
    }

    // MARK: - Integration Tests

    @Test("Round-trip transformation returns to original coordinates")
    func roundTripTransformation() async throws {
        let originalLat = 47.598
        let originalLon = -122.332

        // Transform to API coordinates
        let toApiResult = await transformService.transform(
            latitude: originalLat,
            longitude: originalLon,
            from: .seattleReference,
            to: .seattleAPI,
            bridgeId: "1"
        )

        #expect(toApiResult.success)
        let toApiLat = try #require(toApiResult.transformedLatitude)
        let toApiLon = try #require(toApiResult.transformedLongitude)

        // Transform back to reference coordinates
        let backToRefResult = await transformService.transform(
            latitude: toApiLat,
            longitude: toApiLon,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "1"
        )

        #expect(backToRefResult.success)
        let finalLat = try #require(backToRefResult.transformedLatitude)
        let finalLon = try #require(backToRefResult.transformedLongitude)

        #expect(abs(finalLat - originalLat) <= 0.000001)
        #expect(abs(finalLon - originalLon) <= 0.000001)
    }

    // MARK: - Helper Methods

    private func haversineDistance(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> Double {
        let earthRadius = 6_371_000.0  // Earth's radius in meters

        let lat1Rad = lat1 * .pi / 180.0
        let lon1Rad = lon1 * .pi / 180.0
        let lat2Rad = lat2 * .pi / 180.0
        let lon2Rad = lon2 * .pi / 180.0

        let dLat = lat2Rad - lat1Rad
        let dLon = lon2Rad - lon1Rad

        let a =
            sin(dLat / 2) * sin(dLat / 2) + cos(lat1Rad) * cos(lat2Rad)
            * sin(dLon / 2) * sin(dLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }
}
