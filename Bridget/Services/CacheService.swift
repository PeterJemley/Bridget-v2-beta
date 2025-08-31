//
//  CacheService.swift
//  Bridget
//
//  ## Purpose
//  Handles all caching operations including disk I/O and cache validation
//
//  ## Dependencies
//  Foundation (FileManager, JSONEncoder, JSONDecoder)
//
//  ## Integration Points
//    - Manages disk-based caching for bridge data
//    - Handles cache expiration and validation
//    - Provides cache utilities for size management
//    - Called by BridgeDataService for data persistence
//

// MARK: - Imports

import Foundation

// MARK: - CacheService Class

/// A singleton service for disk-based JSON caching of bridge data.
///
/// Handles serialization, expiration, and cleanup of cached data for offline support and performance.
/// Used by `BridgeDataService` to persist and validate bridge and route models.
///
/// ## Purpose
/// Provides a robust caching layer that handles JSON serialization, cache expiration,
/// and disk I/O operations with a cache-first strategy and automatic expiration.
///
/// ## Integration Points
/// - Manages disk-based caching for bridge data
/// - Handles cache expiration and validation
/// - Provides cache utilities for size management
/// - Called by BridgeDataService for data persistence
///
/// ## Features
/// - Disk-based Storage: Uses FileManager for persistent cache storage
/// - JSON Serialization: Automatic encoding/decoding of Codable types
/// - Cache Expiration: Automatic validation based on file modification time
/// - Size Management: Cache size calculation and cleanup utilities
/// - Error Handling: Silent failure with console logging
/// - Thread Safety: Singleton pattern ensures consistent cache state
///
/// ## Usage
/// ```swift
/// CacheService.shared.saveToCache(data, for: "historical_bridges")
/// let cached: [BridgeStatusModel]? = CacheService.shared.loadFromCache([BridgeStatusModel].self, for: "historical_bridges")
/// if CacheService.shared.isCacheValid(for: "historical_bridges") {
///     // Use valid cache
/// }
/// CacheService.shared.clearCache()
/// let size = CacheService.shared.getCacheSize()
/// ```
///
/// ## Topics
/// - Caching: `saveToCache(_:for:)`, `loadFromCache(_:for:)`, `isCacheValid(for:)`
/// - Utilities: `clearCache()`, `getCacheSize()`
class CacheService {
  /// Shared singleton instance of `CacheService`.
  ///
  /// Use this instance to access caching functionality throughout the app.
  static let shared = CacheService()

  // MARK: - Properties

  private let cacheDirectory = "BridgeCache"
  private let cacheExpirationTime: TimeInterval = 300  // 5 minutes

  // MARK: - Initialization

  private init() {
    // Diagnostic probe to test directory creation capabilities
    runDirectoryCreationProbe()
  }

  // MARK: - Diagnostic Methods

  /// One-off probe to test directory creation capabilities at app launch
  private func runDirectoryCreationProbe() {
    print("🔍 Running directory creation probe...")

    // Test Documents directory
    do {
      let base = try FileManagerUtils.documentsDirectory()
      let dir = base.appendingPathComponent("Probe", isDirectory: true)
      print("📍 Testing Documents: \(dir.path)")
      try FileManagerUtils.ensureDirectoryExists(dir)
      print("✅ Documents directory creation successful")
    } catch {
      print("❌ Documents directory creation failed: \(error)")
      if let nsError = error as NSError? {
        print("   Domain: \(nsError.domain), Code: \(nsError.code)")
        print("   UserInfo: \(nsError.userInfo)")
      }
    }

    // Test Temporary directory
    do {
      let tmp = FileManagerUtils.temporaryDirectory()
        .appendingPathComponent("Probe", isDirectory: true)
      print("📍 Testing Temp: \(tmp.path)")
      try FileManagerUtils.ensureDirectoryExists(tmp)
      print("✅ Temporary directory creation successful")
    } catch {
      print("❌ Temporary directory creation failed: \(error)")
      if let nsError = error as NSError? {
        print("   Domain: \(nsError.domain), Code: \(nsError.code)")
        print("   UserInfo: \(nsError.userInfo)")
      }
    }

    // Log container information (portable across Apple platforms)
    let homePath = NSHomeDirectory()
    print("🏠 Home directory: \(homePath)")
    let bundleURL = Bundle.main.bundleURL
    let containerPath = bundleURL.deletingLastPathComponent().path
    print("📱 App container path: \(containerPath)")
  }

  // MARK: - Private Methods

  private func getCacheDirectory() -> URL? {
    do {
      let documentsPath = try FileManagerUtils.documentsDirectory()
      let cacheURL = documentsPath.appendingPathComponent(cacheDirectory,
                                                          isDirectory: true)

      // Create cache directory if it doesn't exist
      try FileManagerUtils.ensureDirectoryExists(cacheURL)

      return cacheURL
    } catch {
      print("Failed to create cache directory: \(error)")
      return nil
    }
  }

  private func getCacheFileURL(for key: String) -> URL? {
    return getCacheDirectory()?.appendingPathComponent("\(key).json",
                                                       isDirectory: false)
  }

  // MARK: - Cache Operations

  /// Saves the provided data to disk cache using JSON encoding.
  ///
  /// Encodes the data with an ISO8601 date encoding strategy and writes it
  /// to a JSON file named by the given key in the cache directory.
  ///
  /// - Parameters:
  ///   - data: The data to cache. Must conform to `Codable`.
  ///   - key: A unique key identifying the cache file (e.g., `"historical_bridges"`).
  ///
  /// - Note: This method fails silently and logs errors to the console.
  ///
  /// ## Example
  /// ```swift
  /// CacheService.shared.saveToCache(bridges, for: "historical_bridges")
  /// ```
  func saveToCache<T: Codable>(_ data: T, for key: String) {
    print("💾 Attempting to save cache for key: \(key)")

    guard let cacheURL = getCacheFileURL(for: key) else {
      print("❌ Failed to get cache file URL for key: \(key)")
      return
    }

    print("📍 Cache file URL: \(cacheURL.path)")

    do {
      // Ensure cache directory exists
      _ = getCacheDirectory()

      let encoder = JSONEncoder.bridgeEncoder(
        dateEncodingStrategy: .iso8601
      )
      let data = try encoder.encode(data)
      print("✅ Data encoded successfully, size: \(data.count) bytes")

      try data.write(to: cacheURL)
      print("✅ Cache file written successfully to: \(cacheURL.path)")
    } catch {
      print("❌ Failed to save cache for key \(key): \(error)")
      if let nsError = error as NSError? {
        print("   Domain: \(nsError.domain), Code: \(nsError.code)")
        print("   UserInfo: \(nsError.userInfo)")
      }
    }
  }

  /// Loads and decodes cached data from disk.
  ///
  /// Reads the JSON file associated with the given key from the cache directory,
  /// then decodes it to the specified type using the centralized JSON decoder.
  ///
  /// - Parameters:
  ///   - type: The expected data type conforming to `Codable`.
  ///   - key: The cache key identifying the file to load.
  ///
  /// - Returns: An instance of the decoded data if successful, or `nil` if
  ///   the file does not exist, decoding fails, or an error occurs.
  ///
  /// - Note: This method fails silently and logs errors to the console.
  ///
  /// ## Example
  /// ```swift
  /// if let cachedBridges: [BridgeStatusModel] = CacheService.shared.loadFromCache([BridgeStatusModel].self, for: "historical_bridges") {
  ///     // Use cached data
  /// }
  /// ```
  func loadFromCache<T: Codable>(_ type: T.Type, for key: String) -> T? {
    print("📖 Attempting to load cache for key: \(key)")

    guard let cacheURL = getCacheFileURL(for: key) else {
      print("❌ Failed to get cache file URL for key: \(key)")
      return nil
    }

    print("📍 Cache file URL: \(cacheURL.path)")

    do {
      let data = try Data(contentsOf: cacheURL)
      print("✅ Cache file read successfully, size: \(data.count) bytes")

      let decoder = JSONDecoder.bridgeDecoder()
      let result = try decoder.decode(type, from: data)
      print("✅ Cache data decoded successfully")
      return result
    } catch {
      print("❌ Failed to load cache for key \(key): \(error)")
      if let nsError = error as NSError? {
        print("   Domain: \(nsError.domain), Code: \(nsError.code)")
        print("   UserInfo: \(nsError.userInfo)")
      }
      return nil
    }
  }

  /// Determines whether the cached data for the given key is still valid.
  ///
  /// Validity is based on the file's last modification date compared against
  /// the cache expiration time (default 5 minutes).
  ///
  /// - Parameter key: The cache key identifying the file to validate.
  ///
  /// - Returns: `true` if the cached file exists and is not expired,
  ///   otherwise `false`.
  ///
  /// ## Example
  /// ```swift
  /// if CacheService.shared.isCacheValid(for: "historical_bridges") {
  ///     // Cache is fresh and usable
  /// }
  /// ```
  func isCacheValid(for key: String) -> Bool {
    guard let cacheURL = getCacheFileURL(for: key) else { return false }

    do {
      let attributes = try FileManagerUtils.attributesOfItem(at: cacheURL)
      guard let modificationDate = attributes[.modificationDate] as? Date
      else { return false }

      let cacheAge = Date().timeIntervalSince(modificationDate)
      return cacheAge < cacheExpirationTime
    } catch {
      return false
    }
  }

  // MARK: - Cache Utilities

  /// Clears all cached files from the cache directory.
  ///
  /// Deletes all files in the cache directory, freeing disk space and forcing
  /// future data loads to be fresh.
  ///
  /// - Note: This method fails silently and logs errors to the console.
  ///
  /// ## Example
  /// ```swift
  /// CacheService.shared.clearCache()
  /// ```
  func clearCache() {
    guard let cacheDir = getCacheDirectory() else { return }

    do {
      let fileURLs = try FileManagerUtils.enumerateFiles(in: cacheDir)
      for fileURL in fileURLs {
        try FileManagerUtils.removeFile(at: fileURL)
      }
    } catch {
      print("Failed to clear cache: \(error)")
    }
  }

  /// Calculates the total size of all cached files in bytes.
  ///
  /// Iterates over all files in the cache directory summing their sizes.
  ///
  /// - Returns: The total size of cached data in bytes, or 0 if the cache
  ///   directory is inaccessible or empty.
  ///
  /// ## Example
  /// ```swift
  /// let cacheSize = CacheService.shared.getCacheSize()
  /// print("Cache size: \(cacheSize) bytes")
  /// ```
  func getCacheSize() -> Int64 {
    guard let cacheDir = getCacheDirectory() else { return 0 }

    do {
      return try FileManagerUtils.calculateDirectorySize(in: cacheDir)
    } catch {
      return 0
    }
  }
}
