//
//  TransformCache.swift
//  Bridget
//
//  Purpose: High-performance in-memory cache for coordinate transformation matrices and results
//  Dependencies: Foundation, Accelerate, simd
//  Integration Points:
//    - Used by CoordinateTransformService for matrix caching
//    - Used by batch processing for point result caching
//    - Thread-safe actor for concurrent access
//  Key Features:
//    - LRU cache for matrices and point transformations
//    - Version-based invalidation
//    - Memory-efficient storage
//    - Metrics collection for monitoring
//

import Accelerate
import Foundation
import simd

// MARK: - Cache Keys

/// Cache key for transformation matrices
public struct MatrixCacheKey: Hashable, Sendable {
    public let source: CoordinateSystem
    public let target: CoordinateSystem
    public let bridgeId: String?
    public let version: Int

    public init(
        source: CoordinateSystem,
        target: CoordinateSystem,
        bridgeId: String? = nil,
        version: Int = 1
    ) {
        self.source = source
        self.target = target
        self.bridgeId = bridgeId
        self.version = version
    }
}

/// Cache key for point transformations (quantized coordinates)
public struct PointCacheKey: Hashable, Sendable {
    public let source: CoordinateSystem
    public let target: CoordinateSystem
    public let bridgeId: String?
    public let quantizedLat: Double
    public let quantizedLon: Double
    public let version: Int

    public init(
        source: CoordinateSystem,
        target: CoordinateSystem,
        bridgeId: String? = nil,
        quantizedLat: Double,
        quantizedLon: Double,
        version: Int = 1
    ) {
        self.source = source
        self.target = target
        self.bridgeId = bridgeId
        self.quantizedLat = quantizedLat
        self.quantizedLon = quantizedLon
        self.version = version
    }
}

// MARK: - Cache Metadata

/// Metadata for cached items
public struct CacheMetadata: Sendable {
    public let timestamp: Date
    public let accessCount: Int
    public let lastAccessed: Date
    public let memorySize: Int

    public init(
        timestamp: Date = Date(),
        accessCount: Int = 0,
        lastAccessed: Date = Date(),
        memorySize: Int = 0
    ) {
        self.timestamp = timestamp
        self.accessCount = accessCount
        self.lastAccessed = lastAccessed
        self.memorySize = memorySize
    }
}

// MARK: - LRU Cache Implementation

/// Thread-safe LRU cache implementation
private final class LRUCache<Key: Hashable, Value>: @unchecked Sendable {
    private let capacity: Int
    private var cache: [Key: (value: Value, metadata: CacheMetadata)] = [:]
    private var accessOrder: [Key] = []
    private let queue = DispatchQueue(
        label: "com.bridget.lru.cache",
        attributes: .concurrent
    )

    init(capacity: Int) {
        self.capacity = capacity
    }

    func get(_ key: Key) -> Value? {
        return queue.sync(flags: .barrier) {
            guard let (value, metadata) = cache[key] else { return nil }

            // Update access order
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)

            // Update metadata
            let newMetadata = CacheMetadata(
                timestamp: metadata.timestamp,
                accessCount: metadata.accessCount + 1,
                lastAccessed: Date(),
                memorySize: metadata.memorySize
            )
            cache[key] = (value: value, metadata: newMetadata)

            return value
        }
    }

    func set(_ key: Key, value: Value, metadata: CacheMetadata) {
        queue.sync(flags: .barrier) {
            // Remove if exists
            if cache[key] != nil {
                accessOrder.removeAll { $0 == key }
            }

            // Add new item
            cache[key] = (value: value, metadata: metadata)
            accessOrder.append(key)

            // Evict if over capacity
            while cache.count > capacity {
                let oldestKey = accessOrder.removeFirst()
                cache.removeValue(forKey: oldestKey)
            }
        }
    }

    func remove(_ key: Key) {
        queue.sync(flags: .barrier) {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
    }

    func clear() {
        queue.sync(flags: .barrier) {
            cache.removeAll()
            accessOrder.removeAll()
        }
    }

    var count: Int {
        return queue.sync { cache.count }
    }

    var memoryUsage: Int {
        return queue.sync {
            cache.values.reduce(0) { $0 + $1.metadata.memorySize }
        }
    }
}

// MARK: - Transform Cache Actor

@available(iOS 26.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public actor TransformCache {

    // MARK: - Properties

    /// Matrix cache (LRU for hot matrices)
    private let matrixCache: LRUCache<MatrixCacheKey, TransformationMatrix>

    /// Point cache (LRU for recent transformations)
    private let pointCache: LRUCache<PointCacheKey, (lat: Double, lon: Double)>

    /// Current version for invalidation
    private var currentVersion: Int = 1

    /// Cache statistics
    private var stats = CacheStats()

    /// Configuration
    private let config: CacheConfig

    // MARK: - Configuration

    public struct CacheConfig: Sendable {
        public let matrixCapacity: Int
        public let pointCapacity: Int
        public let pointTTLSeconds: Int
        public let enablePointCache: Bool
        public let quantizePrecision: Int

        public init(
            matrixCapacity: Int = 512,
            pointCapacity: Int = 2048,
            pointTTLSeconds: Int = 300,  // 5 minutes
            enablePointCache: Bool = false,
            quantizePrecision: Int = 6
        ) {
            self.matrixCapacity = matrixCapacity
            self.pointCapacity = pointCapacity
            self.pointTTLSeconds = pointTTLSeconds
            self.enablePointCache = enablePointCache
            self.quantizePrecision = quantizePrecision
        }
    }

    // MARK: - Statistics

    public struct CacheStats: Sendable {
        public var matrixHits: Int = 0
        public var matrixMisses: Int = 0
        public var pointHits: Int = 0
        public var pointMisses: Int = 0
        public var matrixEvictions: Int = 0
        public var pointEvictions: Int = 0
        public var totalRequests: Int = 0

        public var matrixHitRate: Double {
            let total = matrixHits + matrixMisses
            return total > 0 ? Double(matrixHits) / Double(total) : 0.0
        }

        public var pointHitRate: Double {
            let total = pointHits + pointMisses
            return total > 0 ? Double(pointHits) / Double(total) : 0.0
        }
    }

    // MARK: - Initialization

    public init(config: CacheConfig = CacheConfig()) {
        self.config = config
        self.matrixCache = LRUCache<MatrixCacheKey, TransformationMatrix>(
            capacity: config.matrixCapacity
        )
        self.pointCache = LRUCache<PointCacheKey, (lat: Double, lon: Double)>(
            capacity: config.pointCapacity
        )
    }

    // MARK: - Matrix Cache Operations

    /// Get transformation matrix from cache
    public func getMatrix(for key: MatrixCacheKey) -> TransformationMatrix? {
        stats.totalRequests += 1

        guard let matrix = matrixCache.get(key) else {
            stats.matrixMisses += 1
            return nil
        }

        stats.matrixHits += 1
        return matrix
    }

    /// Store transformation matrix in cache
    public func setMatrix(
        _ matrix: TransformationMatrix,
        for key: MatrixCacheKey
    ) {
        let metadata = CacheMetadata(
            timestamp: Date(),
            memorySize: MemoryLayout<TransformationMatrix>.size
        )
        matrixCache.set(key, value: matrix, metadata: metadata)
    }

    /// Remove matrix from cache
    public func removeMatrix(for key: MatrixCacheKey) {
        matrixCache.remove(key)
    }

    // MARK: - Point Cache Operations

    /// Get transformed point from cache
    public func getPoint(for key: PointCacheKey) -> (lat: Double, lon: Double)?
    {
        guard config.enablePointCache else { return nil }

        stats.totalRequests += 1

        guard let point = pointCache.get(key) else {
            stats.pointMisses += 1
            return nil
        }

        stats.pointHits += 1
        return point
    }

    /// Store transformed point in cache
    public func setPoint(
        _ point: (lat: Double, lon: Double),
        for key: PointCacheKey
    ) {
        guard config.enablePointCache else { return }

        let metadata = CacheMetadata(
            timestamp: Date(),
            memorySize: MemoryLayout<Double>.size * 2
        )
        pointCache.set(key, value: point, metadata: metadata)
    }

    /// Remove point from cache
    public func removePoint(for key: PointCacheKey) {
        pointCache.remove(key)
    }

    // MARK: - Utility Methods

    /// Quantize coordinates for cache key
    public func quantizeCoordinate(_ value: Double) -> Double {
        let multiplier = pow(10.0, Double(config.quantizePrecision))
        return round(value * multiplier) / multiplier
    }

    /// Create point cache key with quantized coordinates
    public func createPointKey(
        source: CoordinateSystem,
        target: CoordinateSystem,
        bridgeId: String?,
        lat: Double,
        lon: Double
    ) -> PointCacheKey {
        return PointCacheKey(
            source: source,
            target: target,
            bridgeId: bridgeId,
            quantizedLat: quantizeCoordinate(lat),
            quantizedLon: quantizeCoordinate(lon),
            version: currentVersion
        )
    }

    /// Create matrix cache key
    public func createMatrixKey(
        source: CoordinateSystem,
        target: CoordinateSystem,
        bridgeId: String?
    ) -> MatrixCacheKey {
        return MatrixCacheKey(
            source: source,
            target: target,
            bridgeId: bridgeId,
            version: currentVersion
        )
    }

    // MARK: - Cache Management

    /// Invalidate all caches (increment version)
    public func invalidateAll() {
        currentVersion += 1
        clearAll()
    }

    /// Clear all caches
    public func clearAll() {
        matrixCache.clear()
        pointCache.clear()
        stats = CacheStats()
    }

    /// Clear expired point cache entries
    public func clearExpiredPoints() {
        // This would require tracking timestamps, simplified for now
        // In a full implementation, we'd iterate through and remove expired entries
    }

    // MARK: - Statistics and Monitoring

    /// Get current cache statistics
    public func getStats() -> CacheStats {
        return stats
    }

    /// Get cache memory usage
    public func getMemoryUsage() -> (
        matrixMemory: Int, pointMemory: Int, totalMemory: Int
    ) {
        let matrixMemory = matrixCache.memoryUsage
        let pointMemory = pointCache.memoryUsage
        return (matrixMemory, pointMemory, matrixMemory + pointMemory)
    }

    /// Get cache sizes
    public func getCacheSizes() -> (matrixCount: Int, pointCount: Int) {
        return (matrixCache.count, pointCache.count)
    }

    /// Reset statistics
    public func resetStats() {
        stats = CacheStats()
    }
}

// MARK: - Cache Extensions

@available(iOS 26.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension TransformCache {

    /// Preload matrices for common transformations
    public func preloadCommonMatrices() async {
        let commonTransforms = [
            (CoordinateSystem.seattleAPI, CoordinateSystem.seattleReference),
            (CoordinateSystem.seattleReference, CoordinateSystem.seattleAPI),
            (CoordinateSystem.wgs84, CoordinateSystem.seattleReference),
            (CoordinateSystem.seattleReference, CoordinateSystem.wgs84),
        ]

        for (source, target) in commonTransforms {
            let key = createMatrixKey(
                source: source,
                target: target,
                bridgeId: nil
            )
            // Preload with identity matrix as placeholder
            setMatrix(.identity, for: key)
        }
    }

    /// Warm up cache with frequently used matrices
    public func warmup(matrices: [(MatrixCacheKey, TransformationMatrix)]) async
    {
        for (key, matrix) in matrices {
            setMatrix(matrix, for: key)
        }
    }
}

