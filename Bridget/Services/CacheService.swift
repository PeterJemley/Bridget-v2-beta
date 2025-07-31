//
//  CacheService.swift
//  Bridget
//
//  Purpose: Handles all caching operations including disk I/O and cache validation
//  Dependencies: Foundation (FileManager, JSONEncoder, JSONDecoder)
//  Integration Points:
//    - Manages disk-based caching for bridge data
//    - Handles cache expiration and validation
//    - Provides cache utilities for size management
//    - Called by BridgeDataService for data persistence
//

import Foundation

// MARK: - Cache Service
class CacheService {
    static let shared = CacheService()
    
    // MARK: - Configuration
    private let cacheDirectory = "BridgeCache"
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    // MARK: - Cache Directory Management
    private func getCacheDirectory() -> URL? {
        guard let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return documentsPath.appendingPathComponent(cacheDirectory)
    }
    
    private func getCacheFileURL(for key: String) -> URL? {
        return getCacheDirectory()?.appendingPathComponent("\(key).json")
    }
    
    // MARK: - Cache Operations
    /// Saves data to cache with JSON encoding
    ///
    /// - Parameters:
    ///   - data: The data to cache (must conform to Codable)
    ///   - key: The cache key for retrieval
    func saveToCache<T: Codable>(_ data: T, for key: String) {
        guard let cacheURL = getCacheFileURL(for: key) else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(data)
            try data.write(to: cacheURL)
        } catch {
            print("Failed to save cache for key \(key): \(error)")
        }
    }
    
    /// Loads data from cache with JSON decoding
    ///
    /// - Parameters:
    ///   - type: The type to decode from cache
    ///   - key: The cache key for retrieval
    /// - Returns: The decoded data if available and valid
    func loadFromCache<T: Codable>(_ type: T.Type, for key: String) -> T? {
        guard let cacheURL = getCacheFileURL(for: key) else { return nil }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            print("Failed to load cache for key \(key): \(error)")
            return nil
        }
    }
    
    /// Checks if cached data is still valid based on expiration time
    ///
    /// - Parameter key: The cache key to validate
    /// - Returns: True if cache is valid and not expired
    func isCacheValid(for key: String) -> Bool {
        guard let cacheURL = getCacheFileURL(for: key) else { return false }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(
                atPath: cacheURL.path
            )
            guard let modificationDate = attributes[.modificationDate] as? Date
            else { return false }
            
            let cacheAge = Date().timeIntervalSince(modificationDate)
            return cacheAge < cacheExpirationTime
        } catch {
            return false
        }
    }
    
    // MARK: - Cache Utilities
    /// Clears all cached data
    func clearCache() {
        guard let cacheDir = getCacheDirectory() else { return }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: cacheDir,
                includingPropertiesForKeys: nil
            )
            for fileURL in fileURLs {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }
    
    /// Gets the total size of cached data in bytes
    ///
    /// - Returns: Total cache size in bytes, or 0 if cache directory doesn't exist
    func getCacheSize() -> Int64 {
        guard let cacheDir = getCacheDirectory() else { return 0 }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: cacheDir,
                includingPropertiesForKeys: [.fileSizeKey]
            )
            return fileURLs.reduce(0) { total, fileURL in
                do {
                    let attributes = try FileManager.default.attributesOfItem(
                        atPath: fileURL.path
                    )
                    return total + (attributes[.size] as? Int64 ?? 0)
                } catch {
                    return total
                }
            }
        } catch {
            return 0
        }
    }
} 