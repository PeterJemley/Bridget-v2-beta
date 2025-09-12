//
//  CoordinateTransformService+Caching.swift
//  Bridget
//
//  Purpose: Caching extension for CoordinateTransformService
//  Dependencies: Foundation, Bridget
//  Integration Points:
//    - Extends DefaultCoordinateTransformService with TransformCache
//    - Provides cached matrix lookups and point transformations
//    - Maintains backward compatibility with existing API
//  Key Features:
//    - Matrix caching with LRU eviction
//    - Optional point result caching
//    - Version-based cache invalidation
//    - Performance metrics collection
//

import Foundation

// MARK: - Caching Configuration

/// Configuration for coordinate transformation caching
public struct TransformCachingConfig: Sendable {
    public let enableMatrixCache: Bool
    public let enablePointCache: Bool
    public let matrixCacheCapacity: Int
    public let pointCacheCapacity: Int
    public let pointTTLSeconds: Int
    public let quantizePrecision: Int

    public init(
        enableMatrixCache: Bool = true,
        enablePointCache: Bool = false,
        matrixCacheCapacity: Int = 512,
        pointCacheCapacity: Int = 2048,
        pointTTLSeconds: Int = 0,
        quantizePrecision: Int = 4
    ) {
        self.enableMatrixCache = enableMatrixCache
        self.enablePointCache = enablePointCache
        self.matrixCacheCapacity = matrixCacheCapacity
        self.pointCacheCapacity = pointCacheCapacity
        self.pointTTLSeconds = pointTTLSeconds
        self.quantizePrecision = quantizePrecision
    }
}

// MARK: - Cached Coordinate Transform Service

/// Cached version of the coordinate transformation service
@MainActor
public final class CachedCoordinateTransformService: CoordinateTransformService
{

    // MARK: - Properties

    private let baseService: DefaultCoordinateTransformService
    private let cache: TransformCache
    private let config: TransformCachingConfig

    // MARK: - Initialization

    public init(
        baseService: DefaultCoordinateTransformService,
        config: TransformCachingConfig = TransformCachingConfig()
    ) {
        self.baseService = baseService
        self.config = config

        // Create cache with configuration
        let cacheConfig = TransformCache.CacheConfig(
            matrixCapacity: config.matrixCacheCapacity,
            pointCapacity: config.pointCacheCapacity,
            pointTTLSeconds: config.pointTTLSeconds,
            enablePointCache: config.enablePointCache,
            quantizePrecision: config.quantizePrecision
        )
        self.cache = TransformCache(config: cacheConfig)
    }

    // Note: The base service now performs synchronous matrix caching internally.
    // This wrapper remains a pass-through for single-point calls; async batch caching will be added later.

    // MARK: - CoordinateTransformService Implementation

    public func transform(
        latitude: Double,
        longitude: Double,
        from sourceSystem: CoordinateSystem,
        to targetSystem: CoordinateSystem,
        bridgeId: String?
    ) -> TransformationResult {
        
        // Matrix caching is handled inside baseService
        return baseService.transform(
            latitude: latitude,
            longitude: longitude,
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )
    }

    public func transformToReferenceSystem(
        latitude: Double,
        longitude: Double,
        from sourceSystem: CoordinateSystem,
        bridgeId: String?
    ) -> TransformationResult {
        return transform(
            latitude: latitude,
            longitude: longitude,
            from: sourceSystem,
            to: .seattleReference,
            bridgeId: bridgeId
        )
    }

    public func calculateTransformationMatrix(
        from sourceSystem: CoordinateSystem,
        to targetSystem: CoordinateSystem,
        bridgeId: String?
    ) -> TransformationMatrix? {
        
        // Matrix caching is handled inside baseService
        return baseService.calculateTransformationMatrix(
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )
    }

    public func canTransform(
        from sourceSystem: CoordinateSystem,
        to targetSystem: CoordinateSystem,
        bridgeId: String?
    ) -> Bool {
        return baseService.canTransform(
            from: sourceSystem,
            to: targetSystem,
            bridgeId: bridgeId
        )
    }

    // MARK: - Cache Management

    /// Invalidate all caches
    public func invalidateCache() async {
        await cache.invalidateAll()
    }

    /// Clear all caches
    public func clearCache() async {
        await cache.clearAll()
    }

    /// Get cache statistics
    public func getCacheStats() async -> TransformCache.CacheStats {
        return await cache.getStats()
    }

    /// Preload common transformation matrices
    public func preloadCommonMatrices() async {
        await cache.preloadCommonMatrices()
    }

    // MARK: - Private Methods

    /// Apply transformation using the given matrix
    private func applyTransformationWithMatrix(
        latitude: Double,
        longitude: Double,
        matrix: TransformationMatrix,
        sourceSystem: CoordinateSystem,
        targetSystem: CoordinateSystem,
        bridgeId: String?
    ) -> TransformationResult {

        // Use the same transformation logic as the base service
        do {
            let (transformedLat, transformedLon) = try applyTransformation(
                latitude: latitude,
                longitude: longitude,
                matrix: matrix
            )

            // Determine confidence based on transformation type
            let confidence: Double
            if matrix == .identity {
                confidence = 1.0
            } else {
                confidence = getTransformationConfidence(bridgeId: bridgeId)
            }

            return .success(
                latitude: transformedLat,
                longitude: transformedLon,
                confidence: confidence,
                matrix: matrix
            )

        } catch {
            return .failure(.transformationCalculationFailed)
        }
    }

    /// Apply transformation using the given matrix (copied from base service)
    private func applyTransformation(
        latitude: Double,
        longitude: Double,
        matrix: TransformationMatrix
    ) throws -> (latitude: Double, longitude: Double) {
        // Apply translation
        var transformedLat = latitude + matrix.latOffset
        var transformedLon = longitude + matrix.lonOffset

        // Apply scaling
        transformedLat *= matrix.latScale
        transformedLon *= matrix.lonScale

        // Apply rotation (simplified - assumes small angles)
        if matrix.rotation != 0.0 {
            let rotationRad = matrix.rotation * .pi / 180.0
            let cosRot = cos(rotationRad)
            let sinRot = sin(rotationRad)

            let latRad = transformedLat * .pi / 180.0
            let lonRad = transformedLon * .pi / 180.0

            let newLatRad = latRad * cosRot - lonRad * sinRot
            let newLonRad = latRad * sinRot + lonRad * cosRot

            transformedLat = newLatRad * 180.0 / .pi
            transformedLon = newLonRad * 180.0 / .pi
        }

        // Validate transformed coordinates
        guard
            isValidCoordinate(
                latitude: transformedLat,
                longitude: transformedLon
            )
        else {
            throw TransformationError.transformationCalculationFailed
        }

        return (transformedLat, transformedLon)
    }

    /// Validate coordinate bounds (copied from base service)
    private func isValidCoordinate(latitude: Double, longitude: Double) -> Bool
    {
        return latitude >= -90.0 && latitude <= 90.0 && longitude >= -180.0
            && longitude <= 180.0 && !latitude.isNaN && !longitude.isNaN
            && !latitude.isInfinite && !longitude.isInfinite
    }

    /// Get transformation confidence for a bridge
    private func getTransformationConfidence(bridgeId: String?) -> Double {
        // This would typically come from the base service or bridge data
        // For now, return a default confidence
        return 0.9
    }
}

// MARK: - Convenience Extensions

extension DefaultCoordinateTransformService {

    /// Create a cached version of this service
    public func withCaching(
        config: TransformCachingConfig = TransformCachingConfig()
    ) -> CachedCoordinateTransformService {
        return CachedCoordinateTransformService(
            baseService: self,
            config: config
        )
    }
}
