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

/// A service responsible for managing disk-based caching operations for bridge data.
///
/// This service provides a robust caching layer that handles JSON serialization,
/// cache expiration, and disk I/O operations. It implements a cache-first strategy
/// with automatic expiration and size management capabilities.
///
/// ## Overview
///
/// The `CacheService` manages persistent caching of bridge data to support offline
/// functionality and improve app performance. It uses JSON encoding/decoding for
/// data serialization and implements automatic cache expiration.
///
/// ## Key Features
///
/// - **Disk-based Storage**: Uses FileManager for persistent cache storage
/// - **JSON Serialization**: Automatic encoding/decoding of Codable types
/// - **Cache Expiration**: Automatic validation based on file modification time
/// - **Size Management**: Cache size calculation and cleanup utilities
/// - **Error Handling**: Graceful degradation when cache operations fail
/// - **Thread Safety**: Singleton pattern ensures consistent cache state
///
/// ## Usage
///
/// ```swift
/// let cacheService = CacheService.shared
///
/// // Save data to cache
/// cacheService.saveToCache(bridges, for: "historical_bridges")
///
/// // Load data from cache
/// if let cachedBridges: [BridgeStatusModel] = cacheService.loadFromCache(
///     [BridgeStatusModel].self, for: "historical_bridges") {
///     // Use cached data
/// }
///
/// // Check cache validity
/// if cacheService.isCacheValid(for: "historical_bridges") {
///     // Cache is fresh
/// }
/// ```
///
/// ## Topics
///
/// ### Cache Operations
/// - ``saveToCache(_:for:)``
/// - ``loadFromCache(_:for:)``
/// - ``isCacheValid(for:)``
///
/// ### Cache Management
/// - ``clearCache()``
/// - ``getCacheSize()``
///
/// ## Cache Configuration
///
/// - **Cache Directory**: `BridgeCache` in app's documents directory
/// - **Expiration Time**: 5 minutes (300 seconds)
/// - **File Format**: JSON with ISO8601 date encoding
/// - **Error Handling**: Silent failure with console logging
class CacheService {
  static let shared = CacheService()

  // MARK: - Configuration

  private let cacheDirectory = "BridgeCache"
  private let cacheExpirationTime: TimeInterval = 300 // 5 minutes

  private init() {}

  // MARK: - Cache Directory Management

  private func getCacheDirectory() -> URL? {
    guard let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                       in: .userDomainMask).first
    else {
      return nil
    }
    return documentsPath.appendingPathComponent(cacheDirectory)
  }

  private func getCacheFileURL(for key: String) -> URL? {
    return getCacheDirectory()?.appendingPathComponent("\(key).json")
  }

  // MARK: - Cache Operations

  /// Saves data to cache with JSON encoding and ISO8601 date formatting.
  ///
  /// This method serializes the provided data to JSON and writes it to disk
  /// in the cache directory. The file is named using the provided key and
  /// uses ISO8601 date encoding for consistent date handling.
  ///
  /// - Parameters:
  ///   - data: The data to cache. Must conform to `Codable` protocol.
  ///   - key: The cache key used for file naming and retrieval.
  ///     Should be descriptive and unique (e.g., "historical_bridges").
  ///
  /// - Note: This method fails silently and logs errors to console.
  ///   No exceptions are thrown to maintain app stability.
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

  /// Loads data from cache with JSON decoding and ISO8601 date parsing.
  ///
  /// This method reads the cached JSON file from disk and deserializes it
  /// to the specified type. It uses ISO8601 date decoding for consistent
  /// date handling across the app.
  ///
  /// - Parameters:
  ///   - type: The type to decode from cache. Must conform to `Codable` protocol.
  ///   - key: The cache key used for file naming and retrieval.
  ///     Should match the key used when saving the data.
  ///
  /// - Returns: The decoded data if the cache file exists and can be
  ///   successfully deserialized, or `nil` if the file doesn't exist,
  ///   is corrupted, or decoding fails.
  ///
  /// - Note: This method fails silently and logs errors to console.
  ///   No exceptions are thrown to maintain app stability.
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

  /// Checks if cached data is still valid based on file modification time and expiration settings.
  ///
  /// This method validates cache freshness by comparing the file's modification
  /// timestamp against the configured expiration time (5 minutes). It ensures
  /// that cached data is not used beyond its intended lifespan.
  ///
  /// - Parameter key: The cache key to validate. Should match the key used
  ///   when saving the data.
  ///
  /// - Returns: `true` if the cache file exists and is within the expiration
  ///   time (5 minutes), `false` if the file doesn't exist, is expired,
  ///   or cannot be accessed.
  ///
  /// - Note: This method uses the file system's modification timestamp for
  ///   accurate cache age calculation.
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

  /// Removes all cached data files from the cache directory.
  ///
  /// This method deletes all JSON files in the cache directory, effectively
  /// clearing all cached data. It's useful for freeing up disk space or
  /// forcing a fresh data load on the next app launch.
  ///
  /// - Note: This method fails silently and logs errors to console.
  ///   No exceptions are thrown to maintain app stability.
  func clearCache() {
    guard let cacheDir = getCacheDirectory() else { return }

    do {
      let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheDir,
                                                                 includingPropertiesForKeys: nil)
      for fileURL in fileURLs {
        try FileManager.default.removeItem(at: fileURL)
      }
    } catch {
      print("Failed to clear cache: \(error)")
    }
  }

  /// Calculates the total size of all cached data files in bytes.
  ///
  /// This method iterates through all files in the cache directory and
  /// sums their individual file sizes. It's useful for monitoring cache
  /// usage and implementing cache size limits.
  ///
  /// - Returns: The total size of all cache files in bytes, or 0 if the
  ///   cache directory doesn't exist or cannot be accessed.
  ///
  /// - Note: This method fails silently and returns 0 if any errors occur
  ///   during size calculation.
  func getCacheSize() -> Int64 {
    guard let cacheDir = getCacheDirectory() else { return 0 }

    do {
      let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheDir,
                                                                 includingPropertiesForKeys: [.fileSizeKey])
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
