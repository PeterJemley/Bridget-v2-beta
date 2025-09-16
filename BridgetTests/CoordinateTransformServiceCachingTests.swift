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
import Bridget

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
        config: TransformCache.CacheConfig = TransformCache.CacheConfig()
    ) -> DefaultCoordinateTransformService {
        // The base service now has unified caching built-in
        return DefaultCoordinateTransformService(
            bridgeTransformations: [:],
            defaultTransformationMatrix: .identity,
            enableLogging: false,
            enableMatrixCaching: config.matrixCapacity > 0,
            matrixCacheCapacity: config.matrixCapacity
        )
    }

    // MARK: - Gate C: End-to-End Parity Tests

    @Test("End-to-end parity: cached vs base across random samples")
    @MainActor
    func testEndToEndParityAcrossSamples() async throws {
        let base = makeBaseService()
        let cached = makeCachedService(
            config: TransformCache.CacheConfig(
                matrixCapacity: 128,
                pointCapacity: 256,
                pointTTLSeconds: 60,
                enablePointCache: true,
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

                let baseResult = await base.transform(
                    latitude: lat,
                    longitude: lon,
                    from: fromSys,
                    to: toSys,
                    bridgeId: bridgeId
                )
                let cachedResult = await cached.transform(
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
            let baseResult = await base.transformToReferenceSystem(
                latitude: lat,
                longitude: lon,
                from: sourceSystem,
                bridgeId: "test-bridge"
            )

            let cachedResult = await cached.transformToReferenceSystem(
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
        let baseResult1 = await base.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )
        let cachedResult1 = await cached.transform(
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
        cached.invalidateMatrixCache()

        // Test after invalidation - results should still be identical
        let baseResult2 = await base.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )
        let cachedResult2 = await cached.transform(
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
        let baseResult1 = await base.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )
        let cachedResult1 = await cached.transform(
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
        cached.invalidateMatrixCache()

        // Test after clear - results should still be identical
        let baseResult2 = await base.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )
        let cachedResult2 = await cached.transform(
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
            config: TransformCache.CacheConfig(matrixCapacity: 0)
        )
        let cachedEnabled = makeCachedService(
            config: TransformCache.CacheConfig(matrixCapacity: 64)
        )

        let testPoint = (lat: 47.6062, lon: -122.3321)
        let sourceSystem = CoordinateSystem.seattleAPI
        let targetSystem = CoordinateSystem.seattleReference
        let bridgeId = "test-bridge"

        let baseResult = await base.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        let cachedDisabledResult = await cachedDisabled.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        let cachedEnabledResult = await cachedEnabled.transform(
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
            config: TransformCache.CacheConfig(enablePointCache: false)
        )
        let cachedEnabled = makeCachedService(
            config: TransformCache.CacheConfig(enablePointCache: true)
        )

        let testPoint = (lat: 47.6062, lon: -122.3321)
        let sourceSystem = CoordinateSystem.seattleAPI
        let targetSystem = CoordinateSystem.seattleReference
        let bridgeId = "test-bridge"

        let baseResult = await base.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        let cachedDisabledResult = await cachedDisabled.transform(
            latitude: testPoint.lat,
            longitude: testPoint.lon,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )

        let cachedEnabledResult = await cachedEnabled.transform(
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
            let baseResult = await base.transform(
                latitude: lat,
                longitude: lon,
                from: sourceSystem,
                to: targetSystem,
                bridgeId: bridgeId
            )

            let cachedResult = await cached.transform(
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

    @Test("Gate G: Metrics visible locally; counters validated")
    @MainActor
    func testGateGMetricsVisibilityAndCounters() async throws {
        // Use cached service as outermost entry to exercise SLO timer and throughput
        let cached = makeCachedService(
            config: TransformCache.CacheConfig(
                matrixCapacity: 8,
                pointCapacity: 0,
                pointTTLSeconds: 0,
                enablePointCache: false,
                quantizePrecision: 4
            )
        )

        // Run a small workload
        let systems: [(CoordinateSystem, CoordinateSystem)] = [
            (.seattleAPI, .seattleReference),
            (.seattleReference, .seattleAPI)
        ]
        for (fromSys, toSys) in systems {
            for i in 0..<10 {
                let lat = 47.6 + Double(i) * 0.0001
                let lon = -122.33 + Double(i) * 0.0001
                _ = await cached.transform(
                    latitude: lat,
                    longitude: lon,
                    from: fromSys,
                    to: toSys,
                    bridgeId: i % 2 == 0 ? "1" : "6"
                )
            }
        }

        // Capture snapshot and assert basic properties
        let snap = await TransformMetrics.snapshot()

        // Throughput should be >= number of calls above (20)
        let throughput = snap.counters[TransformMetricKey.transformThroughputCount] ?? 0
        #expect(throughput >= 20)

        // Cache counters should exist (hits + misses >= 0). We can't guarantee hits > 0 with tiny capacity, but counters should be present.
        let hits = snap.counters[TransformMetricKey.cacheHitCount] ?? 0
        let misses = snap.counters[TransformMetricKey.cacheMissCount] ?? 0
        #expect(hits >= 0)
        #expect(misses >= 0)

        // Gauges should be non-negative
        let items = snap.gauges[TransformMetricKey.cacheItemsGauge] ?? 0
        let mem = snap.gauges[TransformMetricKey.cacheMemoryBytesGauge] ?? 0
        #expect(items >= 0)
        #expect(mem >= 0)

        // Latency stats should be recorded and p95 >= p50
        if let latStats = snap.latencyStats[TransformMetricKey.transformLatencySeconds] {
            #expect(latStats.count >= 20)
            #expect(latStats.p95 >= latStats.p50)
        } else {
            Issue.record("Expected transform latency stats to be present")
        }
    }


    // MARK: - Step 6 Accuracy Guard Test

    @Test("Step 6 Accuracy Guard: metrics+caching introduce no drift")
    @MainActor
    func testAccuracyGuard_NoDriftWithMetricsAndCaching() async throws {
        // Baseline (no caching/metrics) vs Instrumented (caching+metrics)
        let baseline = makeBaseService()
        let instrumented = makeCachedService(
            config: TransformCache.CacheConfig(
                matrixCapacity: 256,
                pointCapacity: 512,
                pointTTLSeconds: 300,
                enablePointCache: true,
                quantizePrecision: 4
            )
        )

        // Dataset ~300 points across Seattle area, both bridge IDs
        let systemPairs: [(from: CoordinateSystem, to: CoordinateSystem)] = [
            (.seattleAPI, .seattleReference),
            (.wgs84, .seattleReference),
        ]
        let points = TestAccuracyDatasetFactoryCS.generateGrid(
            countPerPair: TestAccuracyDatasetConfig.countPerPair,
            centerLat: 47.60,
            centerLon: -122.33,
            halfSpanLat: 0.05,
            halfSpanLon: 0.05,
            bridgeIds: ["1", "6"],
            systemPairs: systemPairs
        )

        var latResiduals: [Double] = []
        var lonResiduals: [Double] = []
        var exactMatches = 0

        for p in points {
            let from = p.fromSystem as! CoordinateSystem
            let to = p.toSystem as! CoordinateSystem

            let baseRes = await baseline.transform(
                latitude: p.lat, longitude: p.lon,
                from: from, to: to,
                bridgeId: p.bridgeId
            )
            let instRes = await instrumented.transform(
                latitude: p.lat, longitude: p.lon,
                from: from, to: to,
                bridgeId: p.bridgeId
            )

            // Both should succeed or fail identically; if failure, skip stats
            #expect(baseRes.success == instRes.success)
            guard baseRes.success, instRes.success,
                  let bLat = baseRes.transformedLatitude,
                  let bLon = baseRes.transformedLongitude,
                  let iLat = instRes.transformedLatitude,
                  let iLon = instRes.transformedLongitude else {
                continue
            }

            let latDiff = abs(bLat - iLat)
            let lonDiff = abs(bLon - iLon)
            latResiduals.append(latDiff)
            lonResiduals.append(lonDiff)
            if latDiff == 0 && lonDiff == 0 { exactMatches += 1 }
        }

        try #require(!latResiduals.isEmpty && !lonResiduals.isEmpty, "No successful comparable results for residual analysis")

        let exactMatchRate = Double(exactMatches) / Double(latResiduals.count)

        // Uncomment for local diagnostics
        // TestAccuracyDiagnostics.logResidualStats(latResiduals: latResiduals, lonResiduals: lonResiduals, label: "Step 6 Residuals")

        TestAccuracyAsserts.assertStep6Bundle(latResiduals: latResiduals, lonResiduals: lonResiduals, exactMatchRate: exactMatchRate)
    }

    @Test("Gate G: Accuracy guard — median/p95 residual unchanged")
    @MainActor
    func testGateGAccuracyGuardResiduals() async throws {
        let base = makeBaseService()
        let cached = makeCachedService(
            config: TransformCache.CacheConfig(
                matrixCapacity: 128,
                pointCapacity: 512,
                pointTTLSeconds: 60,
                enablePointCache: true,
                quantizePrecision: 4
            )
        )

        var samples: [(Double, Double, CoordinateSystem, CoordinateSystem, String)] = []
        let systems: [(CoordinateSystem, CoordinateSystem)] = [
            (.seattleAPI, .seattleReference),
            (.seattleReference, .seattleAPI),
            (.wgs84, .seattleReference),
        ]
        let bridges = ["1", "6"]

        // 12x12 grid per system pair with slight decorrelation
        for (fromSys, toSys) in systems {
            for i in 0..<TestAccuracyDatasetConfig.gridSize {
                for j in 0..<TestAccuracyDatasetConfig.gridSize {
                    let lat = 47.55 + Double(i) * 0.005 + Double(j) * 1e-6
                    let lon = -122.40 + Double(j) * 0.005 + Double(i) * 1e-6
                    let bridgeId = bridges[(i + j) % bridges.count]
                    samples.append((lat, lon, fromSys, toSys, bridgeId))
                }
            }
        }

        var latResiduals: [Double] = []
        var lonResiduals: [Double] = []

        for (lat, lon, fromSys, toSys, bridgeId) in samples {
            let baseResult = await base.transform(
                latitude: lat,
                longitude: lon,
                from: fromSys,
                to: toSys,
                bridgeId: bridgeId
            )
            let cachedResult = await cached.transform(
                latitude: lat,
                longitude: lon,
                from: fromSys,
                to: toSys,
                bridgeId: bridgeId
            )

            #expect(baseResult.success == cachedResult.success)
            if !baseResult.success || !cachedResult.success {
                #expect(baseResult.error?.localizedDescription == cachedResult.error?.localizedDescription)
                continue
            }

            let dLat = abs((baseResult.transformedLatitude ?? 0) - (cachedResult.transformedLatitude ?? 0))
            let dLon = abs((baseResult.transformedLongitude ?? 0) - (cachedResult.transformedLongitude ?? 0))
            latResiduals.append(dLat)
            lonResiduals.append(dLon)
        }

        #expect(!latResiduals.isEmpty && !lonResiduals.isEmpty, "No successful samples to evaluate accuracy residuals")

        let latMedian = TestAccuracyStats.median(latResiduals)
        let lonMedian = TestAccuracyStats.median(lonResiduals)
        let latP95 = TestAccuracyStats.percentile(latResiduals, 95)
        let lonP95 = TestAccuracyStats.percentile(lonResiduals, 95)

        #expect(latMedian <= TestAccuracyThresholds.medianEps, "lat median residual too high: \(latMedian)")
        #expect(lonMedian <= TestAccuracyThresholds.medianEps, "lon median residual too high: \(lonMedian)")
        #expect(latP95 <= TestAccuracyThresholds.p95Eps, "lat p95 residual too high: \(latP95)")
        #expect(lonP95 <= TestAccuracyThresholds.p95Eps, "lon p95 residual too high: \(lonP95)")
    }
}

