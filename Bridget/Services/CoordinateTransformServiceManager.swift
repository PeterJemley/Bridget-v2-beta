//
//  CoordinateTransformServiceManager.swift
//  Bridget
//
//  Service manager for coordinate transformation with prewarming and persistence
//

import Foundation
import OSLog

@MainActor
public final class CoordinateTransformServiceManager: ObservableObject {
    private let logger = Logger(subsystem: "Bridget", category: "CoordinateTransform")
    
    /// Shared instance
    public static let shared = CoordinateTransformServiceManager()
    
    /// The coordinate transformation service
    public private(set) var transformService: DefaultCoordinateTransformService
    
    /// Feature flags for transformation behavior
    private let transformFlags: TransformFlags
    
    /// Matrix store for persistence (optional)
    private let matrixStore: MatrixStoreSQLite?
    
    private init() {
        // Initialize feature flags from environment or defaults
        self.transformFlags = TransformFlags(
            caching: true,
            pointCache: false,
            batch: true,
            multiSource: false,
            strictGuardrails: true,
            diskPersistence: Self.isDiskPersistenceEnabled()
        )
        
        // Initialize matrix store if persistence is enabled
        let storePath = transformFlags.diskPersistence ? PrewarmPaths.defaultDBPath() : nil
        var matrixStore: MatrixStoreSQLite? = nil
        
        if let path = storePath {
            do {
                matrixStore = try MatrixStoreSQLite(path: path)
                logger.info("Matrix store initialized at: \(path)")
            } catch {
                logger.error("Failed to initialize matrix store: \(error)")
            }
        }
        
        self.matrixStore = matrixStore
        
        // Initialize the coordinate transformation service
        self.transformService = DefaultCoordinateTransformService(
            enableLogging: true,
            enableMatrixCaching: self.transformFlags.caching,
            enableDiskPersistence: self.transformFlags.diskPersistence,
            matrixStorePath: storePath
        )
        
        logger.info("CoordinateTransformServiceManager initialized with disk persistence: \(self.transformFlags.diskPersistence)")
    }
    
    /// Perform prewarming at startup
    public func prewarm() async {
        guard self.transformFlags.caching && self.transformFlags.diskPersistence else {
            logger.info("Prewarming skipped - caching or disk persistence disabled")
            return
        }
        
        let storePath = PrewarmPaths.defaultDBPath()
        
        logger.info("Starting matrix prewarming...")
        
        let result = Prewarmer.prewarm(
            atStartup: self.transformFlags,
            dbPath: storePath,
            topN: 32,
             loadMatrix: nil as ((MatrixKey) throws -> TransformationMatrix)?, // No backfill needed - we compute on demand
            cacheSet: { [weak self] key, matrix in
                // Insert into the service's in-memory cache
                self?.transformService.prewarmMatrix(key: key, matrix: matrix)
            }
        )
        
        logger.info("Prewarming completed: \(result.attempted) attempted, \(result.loaded) loaded in \(String(format: "%.3f", result.durationSeconds))s")
        
        // Emit prewarming metrics
        emitPrewarmingMetrics(result)
    }
    
    /// Check if disk persistence is enabled via feature flags
    private static func isDiskPersistenceEnabled() -> Bool {
        // Check environment variable first
        if let envValue = ProcessInfo.processInfo.environment["TRANSFORM_DISK_PERSISTENCE"] {
            switch envValue.lowercased() {
            case "1", "true", "yes", "on": return true
            case "0", "false", "no", "off": return false
            default: break
            }
        }
        
        // Default to enabled in production
        #if DEBUG
        return false // Disabled in debug builds by default
        #else
        return true
        #endif
    }
    
    /// Emit prewarming metrics for monitoring
    private func emitPrewarmingMetrics(_ result: Prewarmer.Result) {
        // Log metrics that can be picked up by monitoring systems
        logger.info("prewarm_attempted: \(result.attempted)")
        logger.info("prewarm_loaded: \(result.loaded)")
        logger.info("prewarm_duration_s: \(String(format: "%.6f", result.durationSeconds))")
        
        // If you have a metrics service, you could also emit counters here:
        // metricsService.increment("prewarm_attempted", by: result.attempted)
        // metricsService.increment("prewarm_loaded", by: result.loaded)
        // metricsService.record("prewarm_duration_s", value: result.durationSeconds)
    }
}
