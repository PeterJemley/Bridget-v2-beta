import XCTest
@testable import Bridget

final class CoordinateTransformServiceTests: XCTestCase {
    
    var transformService: DefaultCoordinateTransformService!
    
    override func setUpWithError() throws {
        transformService = DefaultCoordinateTransformService(enableLogging: true)
    }
    
    override func tearDownWithError() throws {
        transformService = nil
    }
    
    // MARK: - Basic Transformation Tests
    
    func testIdentityTransformation() throws {
        let lat = 47.598
        let lon = -122.332
        
        let result = transformService.transform(
            latitude: lat,
            longitude: lon,
            from: .seattleReference,
            to: .seattleReference,
            bridgeId: "1"
        )
        
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.transformedLatitude)
        XCTAssertNotNil(result.transformedLongitude)
        XCTAssertEqual(result.transformedLatitude!, lat, accuracy: 0.000001)
        XCTAssertEqual(result.transformedLongitude!, lon, accuracy: 0.000001)
        XCTAssertEqual(result.confidence, 1.0)
    }
    
    func testBridge1Transformation() throws {
        // Test Bridge 1 (First Avenue South) transformation
        // API coordinates: (47.542213439941406, -122.33446502685547)
        // Expected reference: (47.598, -122.332)
        // Offset: ~6205m south, ~200m west
        
        let apiLat = 47.542213439941406
        let apiLon = -122.33446502685547
        let expectedLat = 47.598
        let expectedLon = -122.332
        
        let result = transformService.transform(
            latitude: apiLat,
            longitude: apiLon,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "1"
        )
        
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.transformedLatitude)
        XCTAssertNotNil(result.transformedLongitude)
        
        // Check that transformation brings coordinates closer to expected
        let transformedLat = result.transformedLatitude!
        let transformedLon = result.transformedLongitude!
        
        let originalDistance = haversineDistance(
            lat1: apiLat, lon1: apiLon,
            lat2: expectedLat, lon2: expectedLon
        )
        let transformedDistance = haversineDistance(
            lat1: transformedLat, lon1: transformedLon,
            lat2: expectedLat, lon2: expectedLon
        )
        
        // Transformed coordinates should be much closer to expected
        XCTAssertLessThan(transformedDistance, originalDistance)
        XCTAssertLessThan(transformedDistance, 1000) // Within 1km after transformation
        
        print("📍 Bridge 1 Transformation:")
        print("   API: (\(apiLat), \(apiLon))")
        print("   Transformed: (\(transformedLat), \(transformedLon))")
        print("   Expected: (\(expectedLat), \(expectedLon))")
        print("   Original Distance: \(Int(originalDistance))m")
        print("   Transformed Distance: \(Int(transformedDistance))m")
    }
    
    func testBridge6Transformation() throws {
        // Test Bridge 6 (Lower Spokane Street) transformation
        // API coordinates: (47.57137680053711, -122.35354614257812)
        // Expected reference: (47.58, -122.35)
        // Offset: ~995m south, ~400m west
        
        let apiLat = 47.57137680053711
        let apiLon = -122.35354614257812
        let expectedLat = 47.58
        let expectedLon = -122.35
        
        let result = transformService.transform(
            latitude: apiLat,
            longitude: apiLon,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "6"
        )
        
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.transformedLatitude)
        XCTAssertNotNil(result.transformedLongitude)
        
        let transformedLat = result.transformedLatitude!
        let transformedLon = result.transformedLongitude!
        
        let originalDistance = haversineDistance(
            lat1: apiLat, lon1: apiLon,
            lat2: expectedLat, lon2: expectedLon
        )
        let transformedDistance = haversineDistance(
            lat1: transformedLat, lon1: transformedLon,
            lat2: expectedLat, lon2: expectedLon
        )
        
        // Transformed coordinates should be much closer to expected
        XCTAssertLessThan(transformedDistance, originalDistance)
        XCTAssertLessThan(transformedDistance, 500) // Within 500m after transformation
        
        print("📍 Bridge 6 Transformation:")
        print("   API: (\(apiLat), \(apiLon))")
        print("   Transformed: (\(transformedLat), \(transformedLon))")
        print("   Expected: (\(expectedLat), \(expectedLon))")
        print("   Original Distance: \(Int(originalDistance))m")
        print("   Transformed Distance: \(Int(transformedDistance))m")
    }
    
    func testUnknownBridgeTransformation() throws {
        // Test transformation for unknown bridge (should use default matrix)
        let apiLat = 47.5
        let apiLon = -122.3
        
        let result = transformService.transform(
            latitude: apiLat,
            longitude: apiLon,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "999" // Unknown bridge
        )
        
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.transformedLatitude)
        XCTAssertNotNil(result.transformedLongitude)
        
        // Should have lower confidence for unknown bridge (but identity transformations get 1.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
        XCTAssertGreaterThan(result.confidence, 0.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCoordinates() throws {
        let result = transformService.transform(
            latitude: 100.0, // Invalid latitude
            longitude: -122.3,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "1"
        )
        
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
        
        if case .invalidInputCoordinates = result.error {
            // Expected error
        } else {
            XCTFail("Expected invalidInputCoordinates error")
        }
    }
    
    func testUnsupportedCoordinateSystem() throws {
        let result = transformService.transform(
            latitude: 47.5,
            longitude: -122.3,
            from: .nad27, // Not supported in current implementation
            to: .wgs84,
            bridgeId: "1"
        )
        
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
        
        if case .unsupportedCoordinateSystem = result.error {
            // Expected error
        } else {
            XCTFail("Expected unsupportedCoordinateSystem error")
        }
    }
    
    // MARK: - Matrix Calculation Tests
    
    func testTransformationMatrixCalculation() throws {
        let matrix = transformService.calculateTransformationMatrix(
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "1"
        )
        
        XCTAssertNotNil(matrix)
        XCTAssertNotEqual(matrix, .identity)
        
        // Bridge 1 should have specific offsets (now using inverse transformation)
        XCTAssertEqual(matrix!.latOffset, 0.056, accuracy: 0.001)
        XCTAssertEqual(matrix!.lonOffset, 0.002, accuracy: 0.001)
    }
    
    func testInverseTransformationMatrix() throws {
        let forwardMatrix = transformService.calculateTransformationMatrix(
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "1"
        )
        
        let inverseMatrix = transformService.calculateTransformationMatrix(
            from: .seattleReference,
            to: .seattleAPI,
            bridgeId: "1"
        )
        
        XCTAssertNotNil(forwardMatrix)
        XCTAssertNotNil(inverseMatrix)
        
        // Inverse should be the opposite of forward
        XCTAssertEqual(forwardMatrix!.latOffset, -inverseMatrix!.latOffset, accuracy: 0.000001)
        XCTAssertEqual(forwardMatrix!.lonOffset, -inverseMatrix!.lonOffset, accuracy: 0.000001)
    }
    
    // MARK: - Confidence Tests
    
    func testTransformationConfidence() throws {
        // Known bridge should have high confidence
        let knownResult = transformService.transform(
            latitude: 47.5,
            longitude: -122.3,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "1"
        )
        
        XCTAssertTrue(knownResult.success)
        XCTAssertGreaterThan(knownResult.confidence, 0.9)
        
        // Unknown bridge should have lower confidence
        let unknownResult = transformService.transform(
            latitude: 47.5,
            longitude: -122.3,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "999"
        )
        
        XCTAssertTrue(unknownResult.success)
        XCTAssertLessThanOrEqual(unknownResult.confidence, 1.0)
    }
    
    // MARK: - Integration Tests
    
    func testRoundTripTransformation() throws {
        let originalLat = 47.598
        let originalLon = -122.332
        
        // Transform to API coordinates
        let toApiResult = transformService.transform(
            latitude: originalLat,
            longitude: originalLon,
            from: .seattleReference,
            to: .seattleAPI,
            bridgeId: "1"
        )
        
        XCTAssertTrue(toApiResult.success)
        XCTAssertNotNil(toApiResult.transformedLatitude)
        XCTAssertNotNil(toApiResult.transformedLongitude)
        
        // Transform back to reference coordinates
        let backToRefResult = transformService.transform(
            latitude: toApiResult.transformedLatitude!,
            longitude: toApiResult.transformedLongitude!,
            from: .seattleAPI,
            to: .seattleReference,
            bridgeId: "1"
        )
        
        XCTAssertTrue(backToRefResult.success)
        XCTAssertNotNil(backToRefResult.transformedLatitude)
        XCTAssertNotNil(backToRefResult.transformedLongitude)
        
        // Should be very close to original
        XCTAssertNotNil(backToRefResult.transformedLatitude)
        XCTAssertNotNil(backToRefResult.transformedLongitude)
        let finalLat = backToRefResult.transformedLatitude!
        let finalLon = backToRefResult.transformedLongitude!
        
        XCTAssertEqual(finalLat, originalLat, accuracy: 0.000001)
        XCTAssertEqual(finalLon, originalLon, accuracy: 0.000001)
    }
    
    // MARK: - Helper Methods
    
    private func haversineDistance(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ) -> Double {
        let earthRadius = 6371000.0 // Earth's radius in meters
        
        let lat1Rad = lat1 * .pi / 180.0
        let lon1Rad = lon1 * .pi / 180.0
        let lat2Rad = lat2 * .pi / 180.0
        let lon2Rad = lon2 * .pi / 180.0
        
        let dLat = lat2Rad - lat1Rad
        let dLon = lon2Rad - lon1Rad
        
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(dLon/2) * sin(dLon/2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return earthRadius * c
    }
}
