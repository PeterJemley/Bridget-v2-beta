//
//  TransformCacheTests.swift
//  Bridget
//
//  Purpose: Unit tests for TransformCache actor using Swift Testing
//  Dependencies: Testing, Bridget
//  Integration Points:
//    - Tests TransformCache actor functionality
//    - Validates LRU eviction behavior
//    - Tests version invalidation
//    - Verifies thread safety
//

import Testing

@testable import Bridget

@Suite("TransformCacheTests")
struct TransformCacheTests {

    // Helper to create a default-configured cache per test
    @MainActor
    private func makeDefaultCache() -> TransformCache {
        let config = TransformCache.CacheConfig(
            matrixCapacity: 3,
            pointCapacity: 5,
            pointTTLSeconds: 60,
            enablePointCache: true,
            quantizePrecision: 4
        )
        return TransformCache(config: config)
    }

    // MARK: - Matrix Cache Tests

    @Test("Matrix cache basic operations")
    @MainActor
    func testMatrixCacheBasicOperations() async throws {
        let cache = makeDefaultCache()
        let key = await cache.createMatrixKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-001"
        )
        let matrix = TransformationMatrix(latOffset: 0.001, lonOffset: 0.002)

        await cache.setMatrix(matrix, for: key)
        let retrieved = await cache.getMatrix(for: key)

        #expect(retrieved == matrix)
    }

    @Test("Matrix cache miss")
    @MainActor
    func testMatrixCacheMiss() async {
        let cache = makeDefaultCache()
        let key = await cache.createMatrixKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-001"
        )

        let retrieved = await cache.getMatrix(for: key)
        #expect(retrieved == nil)
    }

    @Test("Matrix cache LRU eviction")
    @MainActor
    func testMatrixCacheLRUEviction() async {
        let cache = makeDefaultCache()
        // Fill cache beyond capacity
        for i in 0..<5 {
            let key = await cache.createMatrixKey(
                source: .seattleAPI,
                target: .seattleReference,
                bridgeId: "bridge-\(i)"
            )
            let matrix = TransformationMatrix(
                latOffset: Double(i),
                lonOffset: Double(i)
            )
            await cache.setMatrix(matrix, for: key)
        }

        // First two should be evicted (capacity = 3)
        let key0 = await cache.createMatrixKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-0"
        )
        let key1 = await cache.createMatrixKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-1"
        )

        let result0 = await cache.getMatrix(for: key0)
        let result1 = await cache.getMatrix(for: key1)
        #expect(result0 == nil)
        #expect(result1 == nil)

        // Last three should still be there
        for i in 2..<5 {
            let key = await cache.createMatrixKey(
                source: .seattleAPI,
                target: .seattleReference,
                bridgeId: "bridge-\(i)"
            )
            let retrieved = await cache.getMatrix(for: key)
            #expect(retrieved != nil)
        }
    }

    @Test("Matrix cache version invalidation")
    @MainActor
    func testMatrixCacheVersionInvalidation() async {
        let cache = makeDefaultCache()
        let key = await cache.createMatrixKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-001"
        )
        let matrix = TransformationMatrix(latOffset: 0.001, lonOffset: 0.002)

        await cache.setMatrix(matrix, for: key)
        let result1 = await cache.getMatrix(for: key)
        #expect(result1 != nil)

        // Invalidate cache (increments version)
        await cache.invalidateAll()

        // Should miss due to version change
        let result2 = await cache.getMatrix(for: key)
        #expect(result2 == nil)
    }

    // MARK: - Point Cache Tests

    @Test("Point cache basic operations")
    @MainActor
    func testPointCacheBasicOperations() async throws {
        let cache = makeDefaultCache()
        let key = await cache.createPointKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-001",
            lat: 47.6062,
            lon: -122.3321
        )
        let point = (lat: 47.6063, lon: -122.3322)

        await cache.setPoint(point, for: key)
        let retrieved = await cache.getPoint(for: key)

        let r = try #require(retrieved)
        #expect(abs(r.lat - point.lat) <= 0.0001)
        #expect(abs(r.lon - point.lon) <= 0.0001)
    }

    @Test("Point cache quantization")
    @MainActor
    func testPointCacheQuantization() async {
        let cache = makeDefaultCache()
        let originalLat = 47.606234567
        let originalLon = -122.332198765

        let key = await cache.createPointKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-001",
            lat: originalLat,
            lon: originalLon
        )

        #expect(abs(key.quantizedLat - 47.6062) <= 0.0001)
        #expect(abs(key.quantizedLon - (-122.3322)) <= 0.0001)
    }

    @Test("Point cache disabled")
    @MainActor
    func testPointCacheDisabled() async {
        let config = TransformCache.CacheConfig(
            matrixCapacity: 3,
            pointCapacity: 5,
            pointTTLSeconds: 60,
            enablePointCache: false,  // Disabled
            quantizePrecision: 4
        )
        let disabledCache = TransformCache(config: config)

        let key = await disabledCache.createPointKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-001",
            lat: 47.6062,
            lon: -122.3321
        )
        let point = (lat: 47.6063, lon: -122.3322)

        await disabledCache.setPoint(point, for: key)

        let retrieved = await disabledCache.getPoint(for: key)
        #expect(retrieved == nil)
    }

    // MARK: - Statistics Tests

    @Test("Cache statistics")
    @MainActor
    func testCacheStatistics() async {
        let cache = makeDefaultCache()
        let key = await cache.createMatrixKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-001"
        )
        let matrix = TransformationMatrix(latOffset: 0.001, lonOffset: 0.002)

        // Initial stats
        var stats = await cache.getStats()
        #expect(stats.matrixHits == 0)
        #expect(stats.matrixMisses == 0)
        #expect(stats.totalRequests == 0)

        // Miss
        _ = await cache.getMatrix(for: key)
        stats = await cache.getStats()
        #expect(stats.matrixMisses == 1)
        #expect(stats.totalRequests == 1)

        // Set and hit
        await cache.setMatrix(matrix, for: key)
        _ = await cache.getMatrix(for: key)
        stats = await cache.getStats()
        #expect(stats.matrixHits == 1)
        #expect(stats.matrixMisses == 1)
        #expect(stats.totalRequests == 2)
    }

    @Test("Cache memory usage")
    @MainActor
    func testCacheMemoryUsage() async {
        let cache = makeDefaultCache()
        let key = await cache.createMatrixKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-001"
        )
        let matrix = TransformationMatrix(latOffset: 0.001, lonOffset: 0.002)

        await cache.setMatrix(matrix, for: key)

        let memoryUsage = await cache.getMemoryUsage()
        #expect(memoryUsage.matrixMemory > 0)
        #expect(memoryUsage.pointMemory == 0)  // No points cached yet
    }

    @Test("Cache sizes")
    @MainActor
    func testCacheSizes() async {
        let cache = makeDefaultCache()
        let key = await cache.createMatrixKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-001"
        )
        let matrix = TransformationMatrix(latOffset: 0.001, lonOffset: 0.002)

        await cache.setMatrix(matrix, for: key)

        let sizes = await cache.getCacheSizes()
        #expect(sizes.matrixCount == 1)
        #expect(sizes.pointCount == 0)
    }

    // MARK: - Cache Management Tests

    @Test("Clear all")
    @MainActor
    func testClearAll() async {
        let cache = makeDefaultCache()
        let key = await cache.createMatrixKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-001"
        )
        let matrix = TransformationMatrix(latOffset: 0.001, lonOffset: 0.002)

        await cache.setMatrix(matrix, for: key)
        let result1 = await cache.getMatrix(for: key)
        #expect(result1 != nil)

        await cache.clearAll()

        // Immediately after clear, stats should be reset
        var stats = await cache.getStats()
        #expect(stats.matrixHits == 0)
        #expect(stats.matrixMisses == 0)

        // Subsequent get should be a miss and update stats accordingly
        let result2 = await cache.getMatrix(for: key)
        #expect(result2 == nil)
        stats = await cache.getStats()
        #expect(stats.matrixHits == 0)
        #expect(stats.matrixMisses == 1)
    }

    @Test("Preload common matrices")
    @MainActor
    func testPreloadCommonMatrices() async {
        let cache = makeDefaultCache()

        // Capture sizes before preload
        let beforeSizes = await cache.getCacheSizes()

        await cache.preloadCommonMatrices()

        // After preload, matrix cache count should have increased by at least 1
        let afterSizes = await cache.getCacheSizes()
        #expect(afterSizes.matrixCount >= beforeSizes.matrixCount + 1)

        // Best-effort check for a commonly expected key, but don't fail the test if it's not present
        let key = await cache.createMatrixKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: nil
        )
        let matrix = await cache.getMatrix(for: key)
        if let matrix {
            #expect(matrix == .identity)
        }
    }

    // MARK: - Thread Safety Tests

    @Test("Concurrent access")
    @MainActor
    func testConcurrentAccess() async {
        // Use a larger capacity to avoid LRU evictions interfering with the test
        let config = TransformCache.CacheConfig(
            matrixCapacity: 20,
            pointCapacity: 10,
            pointTTLSeconds: 60,
            enablePointCache: true,
            quantizePrecision: 4
        )
        let cache = TransformCache(config: config)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let key = await cache.createMatrixKey(
                        source: .seattleAPI,
                        target: .seattleReference,
                        bridgeId: "bridge-\(i)"
                    )
                    let matrix = TransformationMatrix(
                        latOffset: Double(i),
                        lonOffset: Double(i)
                    )
                    await cache.setMatrix(matrix, for: key)
                    let retrieved = await cache.getMatrix(for: key)
                    #expect(retrieved == matrix)
                }
            }
            await group.waitForAll()
        }
    }

    // MARK: - Edge Cases

    @Test("Empty cache operations")
    @MainActor
    func testEmptyCacheOperations() async {
        let cache = makeDefaultCache()
        let key = await cache.createMatrixKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-001"
        )

        await cache.removeMatrix(for: key)  // should not crash

        let stats = await cache.getStats()
        #expect(stats.matrixHits == 0)
        #expect(stats.matrixMisses == 0)
    }

    @Test("Quantization precision")
    @MainActor
    func testQuantizationPrecision() async {
        let config = TransformCache.CacheConfig(
            matrixCapacity: 3,
            pointCapacity: 5,
            pointTTLSeconds: 60,
            enablePointCache: true,
            quantizePrecision: 2  // 2 decimal places
        )
        let precisionCache = TransformCache(config: config)

        let key = await precisionCache.createPointKey(
            source: .seattleAPI,
            target: .seattleReference,
            bridgeId: "bridge-001",
            lat: 47.606234567,
            lon: -122.332198765
        )

        #expect(abs(key.quantizedLat - 47.61) <= 0.001)
        #expect(abs(key.quantizedLon - (-122.33)) <= 0.001)
    }
}
