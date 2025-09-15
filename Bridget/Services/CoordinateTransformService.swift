//
//  CoordinateTransformService.swift
//  Bridget
//
//  Purpose: Handles coordinate system transformations between API data and reference system
//  Dependencies: Foundation, CoreLocation (for coordinate calculations)
//  Integration Points:
//    - Used by BridgeRecordValidator for geospatial validation
//    - Used by MultiPath services for accurate route calculations
//    - Configurable transformation matrices for different coordinate systems
//  Key Features:
//    - Systematic offset correction based on Phase 1 analysis
//    - Bridge-specific transformation matrices
//    - Fallback to current threshold-based approach
//    - Comprehensive error handling and logging
//

import CoreLocation
import Foundation

// MARK: - Coordinate System Types

/// Represents different coordinate systems used in the application
public enum CoordinateSystem: String, CaseIterable, Sendable {
    case wgs84 = "WGS84"
    case nad83 = "NAD83"
    case nad27 = "NAD27"
    case seattleAPI = "SeattleAPI"  // Seattle Open Data API coordinate system
    case seattleReference = "SeattleReference"  // Our canonical reference system

    public var description: String {
        switch self {
        case .wgs84:
            return "World Geodetic System 1984"
        case .nad83:
            return "North American Datum 1983"
        case .nad27:
            return "North American Datum 1927"
        case .seattleAPI:
            return "Seattle Open Data API Coordinate System"
        case .seattleReference:
            return "Seattle Reference System (WGS84-based)"
        }
    }
}

// MARK: - Transformation Matrix

/// Represents a coordinate transformation matrix
public struct TransformationMatrix: Codable, Equatable, Sendable {
    /// Translation offset in degrees (latitude)
    public let latOffset: Double
    /// Translation offset in degrees (longitude)
    public let lonOffset: Double
    /// Scale factor for latitude (1.0 = no scaling)
    public let latScale: Double
    /// Scale factor for longitude (1.0 = no scaling)
    public let lonScale: Double
    /// Rotation angle in degrees (positive = clockwise)
    public let rotation: Double

    public init(
        latOffset: Double = 0.0,
        lonOffset: Double = 0.0,
        latScale: Double = 1.0,
        lonScale: Double = 1.0,
        rotation: Double = 0.0
    ) {
        self.latOffset = latOffset
        self.lonOffset = lonOffset
        self.latScale = latScale
        self.lonScale = lonScale
        self.rotation = rotation
    }

    /// Identity transformation (no change)
    public static let identity = TransformationMatrix()

    /// Creates a translation-only transformation
    public static func translation(latOffset: Double, lonOffset: Double)
        -> TransformationMatrix
    {
        TransformationMatrix(latOffset: latOffset, lonOffset: lonOffset)
    }

    /// Creates a scale-only transformation
    public static func scale(latScale: Double, lonScale: Double)
        -> TransformationMatrix
    {
        TransformationMatrix(latScale: latScale, lonScale: lonScale)
    }

    /// Creates a rotation-only transformation
    public static func rotation(_ angle: Double) -> TransformationMatrix {
        TransformationMatrix(rotation: angle)
    }
}

// MARK: - Bridge-Specific Transformations

/// Bridge-specific transformation data based on Phase 1 analysis
public struct BridgeTransformation: Codable, Equatable, Sendable {
    public let bridgeId: String
    public let bridgeName: String
    public let transformationMatrix: TransformationMatrix
    public let confidence: Double  // 0.0 to 1.0
    public let sampleCount: Int

    public init(
        bridgeId: String,
        bridgeName: String,
        transformationMatrix: TransformationMatrix,
        confidence: Double = 1.0,
        sampleCount: Int = 0
    ) {
        self.bridgeId = bridgeId
        self.bridgeName = bridgeName
        self.transformationMatrix = transformationMatrix
        self.confidence = max(0.0, min(1.0, confidence))
        self.sampleCount = sampleCount
    }
}

// MARK: - Transformation Result

/// Result of a coordinate transformation operation
public struct TransformationResult: Sendable {
    public let success: Bool
    public let transformedLatitude: Double?
    public let transformedLongitude: Double?
    public let error: TransformationError?
    public let confidence: Double
    public let transformationMatrix: TransformationMatrix?

    public init(
        success: Bool,
        transformedLatitude: Double? = nil,
        transformedLongitude: Double? = nil,
        error: TransformationError? = nil,
        confidence: Double = 1.0,
        transformationMatrix: TransformationMatrix? = nil
    ) {
        self.success = success
        self.transformedLatitude = transformedLatitude
        self.transformedLongitude = transformedLongitude
        self.error = error
        self.confidence = max(0.0, min(1.0, confidence))
        self.transformationMatrix = transformationMatrix
    }

    /// Successful transformation
    public static func success(
        latitude: Double,
        longitude: Double,
        confidence: Double = 1.0,
        matrix: TransformationMatrix? = nil
    ) -> TransformationResult {
        TransformationResult(
            success: true,
            transformedLatitude: latitude,
            transformedLongitude: longitude,
            confidence: confidence,
            transformationMatrix: matrix
        )
    }

    /// Failed transformation
    public static func failure(_ error: TransformationError)
        -> TransformationResult
    {
        TransformationResult(success: false, error: error)
    }
}

// MARK: - Transformation Errors

/// Errors that can occur during coordinate transformation
public enum TransformationError: LocalizedError, Sendable {
    case unsupportedCoordinateSystem(CoordinateSystem)
    case invalidTransformationMatrix(TransformationMatrix)
    case bridgeNotFound(String)
    case transformationCalculationFailed
    case invalidInputCoordinates(latitude: Double, longitude: Double)

    public var errorDescription: String? {
        switch self {
        case .unsupportedCoordinateSystem(let system):
            return "Unsupported coordinate system: \(system.rawValue)"
        case .invalidTransformationMatrix(let matrix):
            return "Invalid transformation matrix: \(matrix)"
        case .bridgeNotFound(let bridgeId):
            return "Bridge not found: \(bridgeId)"
        case .transformationCalculationFailed:
            return "Transformation calculation failed"
        case .invalidInputCoordinates(let lat, let lon):
            return "Invalid input coordinates: (\(lat), \(lon))"
        }
    }
}

// MARK: - Internal Matrix Cache (Synchronous)

/// Key for matrix cache entries
internal struct MatrixKey: Hashable {
    let source: CoordinateSystem
    let target: CoordinateSystem
    let bridgeId: String?
    let version: Int
}

// SimpleLRU removed - now using TransformCache actor for unified caching

// MARK: - Coordinate Transform Service

/// Service for transforming coordinates between different coordinate systems
@preconcurrency
public protocol CoordinateTransformService {
    /// Transforms coordinates from source system to target system
    @MainActor func transform(
        latitude: Double,
        longitude: Double,
        from sourceSystem: CoordinateSystem,
        to targetSystem: CoordinateSystem,
        bridgeId: String?
    ) async -> TransformationResult

    /// Transforms coordinates to our reference system (SeattleReference)
    @MainActor func transformToReferenceSystem(
        latitude: Double,
        longitude: Double,
        from sourceSystem: CoordinateSystem,
        bridgeId: String?
    ) async -> TransformationResult

    /// Calculates transformation matrix between two coordinate systems
    @MainActor func calculateTransformationMatrix(
        from sourceSystem: CoordinateSystem,
        to targetSystem: CoordinateSystem,
        bridgeId: String?
    ) async -> TransformationMatrix?

    /// Validates if a transformation is available for the given parameters
    @MainActor func canTransform(
        from sourceSystem: CoordinateSystem,
        to targetSystem: CoordinateSystem,
        bridgeId: String?
    ) -> Bool
}

// MARK: - Default Implementation

/// Default implementation of the coordinate transformation service
@MainActor
public final class DefaultCoordinateTransformService: CoordinateTransformService
{
    // MARK: - Properties

    /// Enable/disable matrix caching via feature flag
    private let enableMatrixCaching: Bool

    /// Capacity for the internal matrix cache
    private let matrixCacheCapacity: Int

    /// Version for cache invalidation (bumped on config/registry changes)
    private var matrixVersion: Int = 1

    /// Unified cache for transformation matrices and point results
    private let cache: TransformCache

    /// Lightweight internal metrics counters
    private var matrixHitCount: Int = 0
    private var matrixMissCount: Int = 0

    /// Bridge-specific transformations based on Phase 1 analysis
    private let bridgeTransformations: [String: BridgeTransformation]

    /// Default transformation matrix for unknown bridges
    private let defaultTransformationMatrix: TransformationMatrix

    /// Whether to enable detailed logging
    private let enableLogging: Bool

    /// Feature flag service for gradual rollout and A/B testing
    private let featureFlagService: FeatureFlagService
    
    /// SQLite store for matrix persistence (optional)
    private let matrixStore: MatrixStoreSQLite?

    // MARK: - Initialization

    public init(
        bridgeTransformations: [String: BridgeTransformation] = [:],
        defaultTransformationMatrix: TransformationMatrix = .identity,
        enableLogging: Bool = false,
        featureFlagService: FeatureFlagService? = nil,
        enableMatrixCaching: Bool = true,
        matrixCacheCapacity: Int = 512,
        enableDiskPersistence: Bool = false,
        matrixStorePath: String? = nil
    ) {
        // Initialize with Phase 1 findings if no transformations provided
        let finalTransformations =
            bridgeTransformations.isEmpty
            ? Self.createDefaultTransformations() : bridgeTransformations

        self.bridgeTransformations = finalTransformations
        self.defaultTransformationMatrix = defaultTransformationMatrix
        self.enableLogging = enableLogging
        self.featureFlagService =
            featureFlagService ?? DefaultFeatureFlagService.shared

        // Resolve caching enablement from feature flag metadata override if present
        let cachingOverride = Self.resolveCachingEnabled(
            from: self.featureFlagService
        )
        let effectiveEnableMatrixCaching =
            cachingOverride ?? enableMatrixCaching
        self.enableMatrixCaching = effectiveEnableMatrixCaching

        self.matrixCacheCapacity = matrixCacheCapacity
        
        // Create unified TransformCache with configuration
        let cacheConfig = TransformCache.CacheConfig(
            matrixCapacity: matrixCacheCapacity,
            pointCapacity: 2048, // Default point cache capacity
            pointTTLSeconds: 0,   // No TTL for now
            enablePointCache: false, // Disable point cache for now
            quantizePrecision: 4
        )
        self.cache = TransformCache(config: cacheConfig)
        
        // Initialize matrix store if disk persistence is enabled
        if enableDiskPersistence, let path = matrixStorePath {
            do {
                self.matrixStore = try MatrixStoreSQLite(path: path)
            } catch {
                if enableLogging {
                    print("⚠️ Failed to initialize matrix store: \(error)")
                }
                self.matrixStore = nil
            }
        } else {
            self.matrixStore = nil
        }
    }

    /// Resolve a metadata override for matrix caching from the coordinate transformation feature flag
    private static func resolveCachingEnabled(from service: FeatureFlagService)
        -> Bool?
    {
        let cfg = service.getConfig(for: .coordinateTransformation)
        if let raw = cfg.metadata["transform.caching.enabled"]?.lowercased() {
            switch raw {
            case "1", "true", "yes", "on": return true
            case "0", "false", "no", "off": return false
            default: break
            }
        }
        return nil
    }

    // MARK: - Public Methods

    public func transform(
        latitude: Double,
        longitude: Double,
        from sourceSystem: CoordinateSystem,
        to targetSystem: CoordinateSystem,
        bridgeId: String?
    ) async -> TransformationResult {
        // Check feature flag for gradual rollout
        let identifier = bridgeId ?? "default"
        let isFeatureEnabled = featureFlagService.isEnabled(
            .coordinateTransformation,
            for: identifier
        )

        if !isFeatureEnabled {
            // Feature flag disabled - return identity transformation (no change)
            if enableLogging {
                print(
                    "📍 CoordinateTransformService: Feature flag disabled, returning identity transformation"
                )
            }
            return .success(
                latitude: latitude,
                longitude: longitude,
                confidence: 1.0,
                matrix: .identity
            )
        }

        // Check A/B test variant if enabled
        if let abTestVariant = featureFlagService.getABTestVariant(
            .coordinateTransformation,
            for: identifier
        ) {
            if abTestVariant == .control {
                // Control group - use old threshold-based approach
                if enableLogging {
                    print(
                        "📍 CoordinateTransformService: A/B test control group, using threshold-based validation"
                    )
                }
                return .success(
                    latitude: latitude,
                    longitude: longitude,
                    confidence: 0.8,  // Lower confidence for old approach
                    matrix: .identity
                )
            }
            // Treatment group - use new transformation system
            if enableLogging {
                print(
                    "📍 CoordinateTransformService: A/B test treatment group, using coordinate transformation"
                )
            }
        }

        // Validate input coordinates
        guard isValidCoordinate(latitude: latitude, longitude: longitude) else {
            return .failure(
                .invalidInputCoordinates(
                    latitude: latitude,
                    longitude: longitude
                )
            )
        }

        // Check if transformation is supported
        guard
            canTransform(
                from: sourceSystem,
                to: targetSystem,
                bridgeId: bridgeId
            )
        else {
            return .failure(.unsupportedCoordinateSystem(sourceSystem))
        }

        // Get transformation matrix
        guard
            let matrix = await calculateTransformationMatrix(
                from: sourceSystem,
                to: targetSystem,
                bridgeId: bridgeId
            )
        else {
            return .failure(.transformationCalculationFailed)
        }

        // Apply transformation with timing
        return await TransformMetrics.timeInner {
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
                    // Note: This is a synchronous call since we can't await inside timeInner
                    // We'll use the cached confidence from the matrix lookup
                    confidence = bridgeTransformations[bridgeId ?? ""]?.confidence ?? 0.5
                }

                if enableLogging {
                    print(
                        "📍 CoordinateTransformService: Transformed (\(latitude), \(longitude)) to (\(transformedLat), \(transformedLon))"
                    )
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
    }

    public func transformToReferenceSystem(
        latitude: Double,
        longitude: Double,
        from sourceSystem: CoordinateSystem,
        bridgeId: String?
    ) async -> TransformationResult {
        return await transform(
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
    ) async -> TransformationMatrix? {
        // If source and target are the same, return identity
        if sourceSystem == targetSystem {
            return .identity
        }

        // Attempt cache lookup if enabled
        if enableMatrixCaching {
            let key = makeMatrixKey(
                from: sourceSystem,
                to: targetSystem,
                bridgeId: bridgeId
            )
            // Convert MatrixKey to MatrixCacheKey for TransformCache
            let cacheKey = MatrixCacheKey(
                source: key.source,
                target: key.target,
                bridgeId: key.bridgeId,
                version: key.version
            )
            
            if let cached = await cache.getMatrix(for: cacheKey) {
                await TransformMetrics.hit()
                matrixHitCount &+= 1
                
                // Persist to disk if store is available
                if let store = matrixStore {
                    do {
                        try store.upsert(key: key, matrix: cached)
                    } catch {
                        if enableLogging {
                            print("⚠️ Failed to persist matrix to disk: \(error)")
                        }
                    }
                }
                
                return cached
            }
        }

        // Compute matrix per existing rules
        let computed: TransformationMatrix?
        if sourceSystem == .seattleAPI, targetSystem == .seattleReference {
            computed = getBridgeSpecificMatrix(bridgeId: bridgeId)?.inverse()
        } else if sourceSystem == .seattleReference, targetSystem == .seattleAPI
        {
            computed = getBridgeSpecificMatrix(bridgeId: bridgeId)
        } else {
            computed = defaultTransformationMatrix
        }

        // Populate cache on miss
        if let m = computed, enableMatrixCaching {
            let key = makeMatrixKey(
                from: sourceSystem,
                to: targetSystem,
                bridgeId: bridgeId
            )
            // Convert MatrixKey to MatrixCacheKey for TransformCache
            let cacheKey = MatrixCacheKey(
                source: key.source,
                target: key.target,
                bridgeId: key.bridgeId,
                version: key.version
            )
            
            await TransformMetrics.miss()
            matrixMissCount &+= 1
            await cache.setMatrix(m, for: cacheKey)
            
            // Persist to disk if store is available
            if let store = matrixStore {
                do {
                    try store.upsert(key: key, matrix: m)
                } catch {
                    if enableLogging {
                        print("⚠️ Failed to persist computed matrix to disk: \(error)")
                    }
                }
            }
        }

        return computed
    }

    /// Prewarm a matrix into the cache (for startup optimization)
    nonisolated internal func prewarmMatrix(key: MatrixKey, matrix: TransformationMatrix) {
        guard enableMatrixCaching else { return }
        // Convert MatrixKey to MatrixCacheKey for TransformCache
        let cacheKey = MatrixCacheKey(
            source: key.source,
            target: key.target,
            bridgeId: key.bridgeId,
            version: key.version
        )
        // Note: This is nonisolated, so we can't await here
        // The prewarming will be handled by the CoordinateTransformServiceManager
        Task {
            await cache.setMatrix(matrix, for: cacheKey)
        }
    }

    public func canTransform(
        from sourceSystem: CoordinateSystem,
        to targetSystem: CoordinateSystem,
        bridgeId _: String?
    ) -> Bool {
        // Always support same-system transformations
        if sourceSystem == targetSystem {
            return true
        }

        // Support Seattle API ↔ Reference transformations
        if (sourceSystem == .seattleAPI && targetSystem == .seattleReference)
            || (sourceSystem == .seattleReference
                && targetSystem == .seattleAPI)
        {
            return true
        }

        // For other transformations, check if we have a default matrix
        return defaultTransformationMatrix != .identity
    }

    // MARK: - Cache Control

    /// Invalidate matrix cache by bumping version and clearing entries
    public func invalidateMatrixCache() {
        matrixVersion &+= 1
        Task {
            await cache.invalidateAll()
        }
        matrixHitCount = 0
        matrixMissCount = 0
    }

    // MARK: - Metrics & Introspection

    /// Read-only view of matrix cache counters for tuning
    public func matrixCacheCounters() -> (
        hits: Int, misses: Int, hitRate: Double, version: Int, capacity: Int
    ) {
        let total = matrixHitCount + matrixMissCount
        let rate = total > 0 ? Double(matrixHitCount) / Double(total) : 0.0
        return (
            matrixHitCount, matrixMissCount, rate, matrixVersion,
            matrixCacheCapacity
        )
    }

    // MARK: - Private Methods

    private func makeMatrixKey(
        from sourceSystem: CoordinateSystem,
        to targetSystem: CoordinateSystem,
        bridgeId: String?
    ) -> MatrixKey {
        MatrixKey(
            source: sourceSystem,
            target: targetSystem,
            bridgeId: bridgeId,
            version: matrixVersion
        )
    }

    private func getBridgeSpecificMatrix(bridgeId: String?)
        -> TransformationMatrix?
    {
        guard let bridgeId = bridgeId else {
            return defaultTransformationMatrix
        }

        return bridgeTransformations[bridgeId]?.transformationMatrix
            ?? defaultTransformationMatrix
    }

    private func getTransformationConfidence(bridgeId: String?) async -> Double {
        guard let bridgeId = bridgeId else {
            return 0.5  // Lower confidence for unknown bridges
        }

        // For identity transformations, return 1.0 confidence
        if let matrix = bridgeTransformations[bridgeId]?.transformationMatrix,
            matrix == .identity
        {
            return 1.0
        }

        // For same-system transformations (identity), return 1.0 confidence
        if let matrix = await calculateTransformationMatrix(
            from: .seattleReference,
            to: .seattleReference,
            bridgeId: bridgeId
        ), matrix == .identity {
            return 1.0
        }

        return bridgeTransformations[bridgeId]?.confidence ?? 0.5
    }

    private func applyTransformation(
        latitude: Double,
        longitude: Double,
        matrix: TransformationMatrix
    ) throws -> (latitude: Double, longitude: Double) {
        // Use SIMD-optimized transformation for better performance
        let (transformedLat, transformedLon) = applyTransformationSIMD(
            latitude: latitude,
            longitude: longitude,
            matrix: matrix
        )

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

    private func isValidCoordinate(latitude: Double, longitude: Double) -> Bool
    {
        return latitude >= -90.0 && latitude <= 90.0 && longitude >= -180.0
            && longitude <= 180.0 && !latitude.isNaN && !longitude.isNaN
            && !latitude.isInfinite && !longitude.isInfinite
    }

    // MARK: - Default Transformations

    /// Creates default bridge transformations based on Phase 1 analysis
    private static func createDefaultTransformations() -> [String:
        BridgeTransformation]
    {
        var transformations: [String: BridgeTransformation] = [:]

        // Bridge 1 (First Avenue South) - ~6205m offset
        // Based on Phase 1 analysis: API coordinates are consistently offset
        // This is a simplified translation-only transformation
        let bridge1Matrix = TransformationMatrix.translation(
            latOffset: -0.056,  // ~6205m south
            lonOffset: -0.002  // ~200m west
        )
        transformations["1"] = BridgeTransformation(
            bridgeId: "1",
            bridgeName: "First Avenue South Bridge",
            transformationMatrix: bridge1Matrix,
            confidence: 0.95,
            sampleCount: 1000  // Estimated from logs
        )

        // Bridge 6 (Lower Spokane Street) - ~995m offset
        let bridge6Matrix = TransformationMatrix.translation(
            latOffset: -0.009,  // ~995m south
            lonOffset: -0.004  // ~400m west
        )
        transformations["6"] = BridgeTransformation(
            bridgeId: "6",
            bridgeName: "Lower Spokane Street Bridge",
            transformationMatrix: bridge6Matrix,
            confidence: 0.95,
            sampleCount: 1000  // Estimated from logs
        )

        return transformations
    }
}

// MARK: - TransformationMatrix Extensions

extension TransformationMatrix {
    /// Returns the inverse of this transformation matrix
    public func inverse() -> TransformationMatrix {
        // For translation-only transformations, inverse is just negative offsets
        return TransformationMatrix(
            latOffset: -latOffset,
            lonOffset: -lonOffset,
            latScale: 1.0 / latScale,
            lonScale: 1.0 / lonScale,
            rotation: -rotation
        )
    }
}

// MARK: - Singleton Instance

extension DefaultCoordinateTransformService {
    /// Shared instance for use throughout the application
    public static let shared = DefaultCoordinateTransformService(
        enableLogging: true
    )
}

extension DefaultCoordinateTransformService: @unchecked Sendable {}


