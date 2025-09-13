//
//  CoordinateTransformServiceCachingTests.swift
//  Bridget
//
//  Purpose: End-to-end integration tests for coordinate transformation caching
//  Dependencies: Testing, Bridget
//  Integration Points:
//    - Verifies Gate C: identical outputs with and without cache
//    - Tests parity between DefaultCoordinateTransformService and CachedCoordinateTransformService
//    - Validates cache behavior doesn't affect transformation results
//

import Foundation
import Testing

@testable import Bridget

@Suite("CoordinateTransformServiceCachingTests")
struct CoordinateTransformServiceCachingTests {

    // MARK: - Test Setup

    @MainActor
    private func makeBaseService() -> DefaultCoordinateTransformService {
        return DefaultCoordinateTransformService(
            bridgeTransformations: [:],
            defaultTransformationMatrix: .identity,
            enableLogging: false
        )
    }

    @MainActor
    private func makeCachedService(
        config: TransformCachingConfig = TransformCachingConfig()
    ) -> CachedCoordinateTransformService {
        let baseService = makeBaseService()
        return CachedCoordinateTransformService(
            baseService: baseService,
            config: config
        )
    }

    // MARK: - Gate C: End-to-End Parity Tests

    @Test("End-to-end parity: cached vs base across random samples")
    @MainActor
    func testEndToEndParityAcrossSamples() async throws {
        let base = makeBaseService()
        let cached = makeCachedService(
            config: TransformCachingConfig(
                enableMatrixCache: true,
                enablePointCache: true,
                matrixCacheCapacity: 128,
                pointCacheCapacity: 256,
                pointTTLSeconds: 60,
                quantizePrecision: 4
            )
        )

        // Generate representative samples
        let systems: [(CoordinateSystem, CoordinateSystem)] = [
            (.seattleAPI, .seattleReference),
            (.seattleReference, .seattleAPI),
            (.wgs84, .seattleReference),
        ]

        for (fromSys, toSys) in systems {
            for i in 0..<50 {
                let lat = 47.5 + Double(i) * 0.001
                let lon = -122.4 + Double(i) * 0.001
                let bridgeId = i % 2 == 0 ? "1" : "6"

                let baseResult = base.transform(
                    latitude: lat,
                    longitude: lon,
                    from: fromSys,
                    to: toSys,
                    bridgeId: bridgeId
                )
                let cachedResult = cached.transform(
                    latitude: lat,
                    longitude: lon,
                    from: fromSys,
                    to: toSys,
                    bridgeId: bridgeId
                )

                #expect(baseResult.success == cachedResult.success)
                if baseResult.success && cachedResult.success {
                    #expect(
                        baseResult.transformedLatitude
                            == cachedResult.transformedLatitude
                    )
                    #expect(
                        baseResult.transformedLongitude
                            == cachedResult.transformedLongitude
                    )
                }
            }
        }
    }

    @Test("End-to-end parity: transformToReferenceSystem")
    @MainActor
    func testEndToEndParityTransformToReferenceSystem() async throws {
        let base = makeBaseService()
        let cached = makeCachedService()

        let testCases = [
            (47.6062, -122.3321, CoordinateSystem.seattleAPI),
            (47.6205, -122.3493, CoordinateSystem.wgs84),
            (47.6097, -122.3331, CoordinateSystem.seattleReference),
        ]

        for (lat, lon, sourceSystem) in testCases {
            let baseResult = base.transformToReferenceSystem(
                latitude: lat,
                longitude: lon,
                from: sourceSystem,
                bridgeId: "test-bridge"
            )

            let cachedResult = cached.transformToReferenceSystem(
                latitude: lat,
                longitude: lon,
                from: sourceSystem,
                bridgeId: "test-bridge"
            )

            // Results should be identical
            #expect(baseResult.success == cachedResult.success)
            if baseResult.success && cachedResult.success {
                #expect(
                    baseResult.transformedLatitude
                        == cachedResult.transformedLatitude
                )
                #expect(
                    baseResult.transformedLongitude
                        == cachedResult.transformedLongitude
                )
            }
        }
    }

    @Test("End-to-end parity: cache invalidation doesn't affect results")
    @MainActor
    func testEndToEndParityWithCacheInvalidation() async throws {
        let base = makeBaseService()
        let cached = makeCachedService()

        let testPoint = (lat: 47.6062, lon: -122.3321)
        let sourceSystem = CoordinateSystem.seattleAPI
        let targetSystem = CoordinateSystem.seattleReference
        let bridgeId = "test-bridge"

        // Test before invalidation
        let baseResult1 = base.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )
        let cachedResult1 = cached.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        #expect(baseResult1.success == cachedResult1.success)
        if baseResult1.success && cachedResult1.success {
            #expect(
                baseResult1.transformedLatitude
                    == cachedResult1.transformedLatitude
            )
            #expect(
                baseResult1.transformedLongitude
                    == cachedResult1.transformedLongitude
            )
        }

        // Invalidate cache
        await cached.invalidateCache()

        // Test after invalidation - results should still be identical
        let baseResult2 = base.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )
        let cachedResult2 = cached.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        #expect(baseResult2.success == cachedResult2.success)
        if baseResult2.success && cachedResult2.success {
            #expect(
                baseResult2.transformedLatitude
                    == cachedResult2.transformedLatitude
            )
            #expect(
                baseResult2.transformedLongitude
                    == cachedResult2.transformedLongitude
            )
        }
    }

    @Test("End-to-end parity: cache clear doesn't affect results")
    @MainActor
    func testEndToEndParityWithCacheClear() async throws {
        let base = makeBaseService()
        let cached = makeCachedService()

        let testPoint = (lat: 47.6062, lon: -122.3321)
        let sourceSystem = CoordinateSystem.seattleAPI
        let targetSystem = CoordinateSystem.seattleReference
        let bridgeId = "test-bridge"

        // Test before clear
        let baseResult1 = base.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )
        let cachedResult1 = cached.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        #expect(baseResult1.success == cachedResult1.success)
        if baseResult1.success && cachedResult1.success {
            #expect(
                baseResult1.transformedLatitude
                    == cachedResult1.transformedLatitude
            )
            #expect(
                baseResult1.transformedLongitude
                    == cachedResult1.transformedLongitude
            )
        }

        // Clear cache
        await cached.clearCache()

        // Test after clear - results should still be identical
        let baseResult2 = base.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )
        let cachedResult2 = cached.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        #expect(baseResult2.success == cachedResult2.success)
        if baseResult2.success && cachedResult2.success {
            #expect(
                baseResult2.transformedLatitude
                    == cachedResult2.transformedLatitude
            )
            #expect(
                baseResult2.transformedLongitude
                    == cachedResult2.transformedLongitude
            )
        }
    }

    @Test("End-to-end parity: matrix cache disabled vs enabled")
    @MainActor
    func testEndToEndParityMatrixCacheDisabledVsEnabled() async throws {
        let base = makeBaseService()
        let cachedDisabled = makeCachedService(
            config: TransformCachingConfig(enableMatrixCache: false)
        )
        let cachedEnabled = makeCachedService(
            config: TransformCachingConfig(enableMatrixCache: true)
        )

        let testPoint = (lat: 47.6062, lon: -122.3321)
        let sourceSystem = CoordinateSystem.seattleAPI
        let targetSystem = CoordinateSystem.seattleReference
        let bridgeId = "test-bridge"

        let baseResult = base.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        let cachedDisabledResult = cachedDisabled.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        let cachedEnabledResult = cachedEnabled.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        // All results should be identical regardless of cache configuration
        #expect(baseResult.success == cachedDisabledResult.success)
        #expect(baseResult.success == cachedEnabledResult.success)
        #expect(cachedDisabledResult.success == cachedEnabledResult.success)

        if baseResult.success && cachedDisabledResult.success
            && cachedEnabledResult.success
        {
            #expect(
                baseResult.transformedLatitude
                    == cachedDisabledResult.transformedLatitude
            )
            #expect(
                baseResult.transformedLatitude
                    == cachedEnabledResult.transformedLatitude
            )
            #expect(
                cachedDisabledResult.transformedLatitude
                    == cachedEnabledResult.transformedLatitude
            )

            #expect(
                baseResult.transformedLongitude
                    == cachedDisabledResult.transformedLongitude
            )
            #expect(
                baseResult.transformedLongitude
                    == cachedEnabledResult.transformedLongitude
            )
            #expect(
                cachedDisabledResult.transformedLongitude
                    == cachedEnabledResult.transformedLongitude
            )
        }
    }

    @Test("End-to-end parity: point cache disabled vs enabled")
    @MainActor
    func testEndToEndParityPointCacheDisabledVsEnabled() async throws {
        let base = makeBaseService()
        let cachedDisabled = makeCachedService(
            config: TransformCachingConfig(enablePointCache: false)
        )
        let cachedEnabled = makeCachedService(
            config: TransformCachingConfig(enablePointCache: true)
        )

        let testPoint = (lat: 47.6062, lon: -122.3321)
        let sourceSystem = CoordinateSystem.seattleAPI
        let targetSystem = CoordinateSystem.seattleReference
        let bridgeId = "test-bridge"

        let baseResult = base.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        let cachedDisabledResult = cachedDisabled.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        let cachedEnabledResult = cachedEnabled.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        // All results should be identical regardless of cache configuration
        #expect(baseResult.success == cachedDisabledResult.success)
        #expect(baseResult.success == cachedEnabledResult.success)
        #expect(cachedDisabledResult.success == cachedEnabledResult.success)

        if baseResult.success && cachedDisabledResult.success
            && cachedEnabledResult.success
        {
            #expect(
                baseResult.transformedLatitude
                    == cachedDisabledResult.transformedLatitude
            )
            #expect(
                baseResult.transformedLatitude
                    == cachedEnabledResult.transformedLatitude
            )
            #expect(
                cachedDisabledResult.transformedLatitude
                    == cachedEnabledResult.transformedLatitude
            )

            #expect(
                baseResult.transformedLongitude
                    == cachedDisabledResult.transformedLongitude
            )
            #expect(
                baseResult.transformedLongitude
                    == cachedEnabledResult.transformedLongitude
            )
            #expect(
                cachedDisabledResult.transformedLongitude
                    == cachedEnabledResult.transformedLongitude
            )
        }
    }

    @Test("End-to-end parity: error handling consistency")
    @MainActor
    func testEndToEndParityErrorHandlingConsistency() async throws {
        let base = makeBaseService()
        let cached = makeCachedService()

        let errorTestCases = [
            // Invalid coordinates
            (
                999.0, -122.3321, CoordinateSystem.seattleAPI,
                CoordinateSystem.seattleReference, "test-bridge"
            ),
            (
                47.6062, 999.0, CoordinateSystem.seattleAPI,
                CoordinateSystem.seattleReference, "test-bridge"
            ),
            // Unsupported coordinate system
            (
                47.6062, -122.3321, CoordinateSystem.seattleAPI,
                CoordinateSystem.nad27, "test-bridge"
            ),
        ]

        for (lat, lon, sourceSystem, targetSystem, bridgeId) in errorTestCases {
            let baseResult = base.transform(
                latitude: lat,
                longitude: lon,
                from: sourceSystem,
                to: targetSystem,
                bridgeId: bridgeId
            )

            let cachedResult = cached.transform(
                latitude: lat,
                longitude: lon,
                from: sourceSystem,
                to: targetSystem,
                bridgeId: bridgeId
            )

            // Error handling should be identical
            #expect(baseResult.success == cachedResult.success)
            #expect(
                baseResult.error?.localizedDescription
                    == cachedResult.error?.localizedDescription
            )
        }
    }
}
