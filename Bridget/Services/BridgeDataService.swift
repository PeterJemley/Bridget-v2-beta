//
//  BridgeDataService.swift
//  Bridget
//
//  Purpose: Orchestrates bridge data operations using specialized services
//  Dependencies: NetworkClient, CacheService, BridgeDataProcessor, SampleDataProvider
//  Integration Points:
//    - Coordinates network, cache, and data processing operations
//    - Provides high-level API for bridge data management
//    - Called by AppStateModel to populate historical route data
//    - Future: Will integrate with real-time traffic data services (if available)
//  Key Features:
//    - Orchestrates multiple specialized services
//    - Implements cache-first strategy with graceful degradation
//    - Provides fallback to sample data for testing
//    - Maintains clean separation of concerns
//

import Foundation

// MARK: - BridgeDataService Class

// MARK: - Bridge Data Service

/// A service that orchestrates bridge data operations using network, cache, and data processors.
///
/// This service coordinates fetching, validating, and caching historical bridge opening data, and generates sample routes for UI and analysis.
///
/// - Integration Points: Used by AppStateModel to populate route data, called from top-level data loaders, coordinates error handling across subsystems.
/// - Key Features: Cache-first loading, retry logic, validation reporting, sample data fallback.
///
/// ## Usage
/// ```swift
/// let (bridges, failures) = try await BridgeDataService.shared.loadHistoricalData()
/// ```
///
/// ## Topics
/// - Data Loading: `loadHistoricalData()`
/// - Sample Data: `loadSampleData()`
/// - Route Generation: `generateRoutes(from:)`
/// - Cache Management: `clearCache()`, `getCacheSize()`
class BridgeDataService {
  static let shared = BridgeDataService()
  // MARK: - Service Dependencies

  private let networkClient = NetworkClient.shared
  private let cacheService = CacheService.shared
  private let dataProcessor = BridgeDataProcessor.shared
  private let sampleProvider = SampleDataProvider.shared

  // MARK: - Initialization

  private init() {}

  // MARK: - Historical Data Loading

  /// Loads historical bridge opening data with retry logic and caching.
  ///
  /// This method orchestrates multiple specialized services to provide robust data loading:
  /// 1. **Cache-first approach**: Returns valid cached data if available.
  /// 2. **Network fetching**: Uses NetworkClient for retry logic and validation.
  /// 3. **Data processing**: Uses BridgeDataProcessor for JSON decoding and validation.
  /// 4. **Data sanitization**: Filters out entries with missing IDs/names and duplicates.
  /// 5. **Graceful degradation**: Falls back to stale cache if all network attempts fail.
  ///
  /// - Returns: A tuple containing an array of `BridgeStatusModel` instances with historical opening data 
  ///            and an array of `BridgeDataProcessor.ValidationFailure` instances describing invalid records.
  /// - Throws: `NetworkError` or `BridgeDataError` if no data is available.
  ///
  /// ## Example
  /// ```swift
  /// do {
  ///   let (bridges, failures) = try await BridgeDataService.shared.loadHistoricalData()
  ///   // Use `bridges` for UI or analysis
  ///   // Optionally handle `failures` for logging or reporting
  /// } catch {
  ///   // Handle errors appropriately
  /// }
  /// ```
  func loadHistoricalData() async throws -> ([BridgeStatusModel], [BridgeDataProcessor.ValidationFailure]) {
    // Check cache first - return valid cached data if available
    if let cachedBridges: [BridgeStatusModel] = cacheService.loadFromCache([BridgeStatusModel].self,
                                                                           for: "historical_bridges"),
      cacheService.isCacheValid(for: "historical_bridges")
    {
      // Update cache metadata for all bridges
      cachedBridges.forEach { $0.updateCacheMetadata() }
      return (cachedBridges, [])
    }

    // Fetch from network using NetworkClient
    do {
      let data = try await fetchFromNetwork()
      let (bridges, validationFailures) = try dataProcessor.processHistoricalData(data)
      // Log and report validation failures for debugging/monitoring
      if !validationFailures.isEmpty {
        #if DEBUG
          for failure in validationFailures {
            print("[ValidationFailure] \(failure.reason) for record: \(failure.record)")
          }
          print("Filtered out \(validationFailures.count) invalid records from network response.")
        #else
          // Integrate with your monitoring/analytics solution here (e.g., Sentry, DataDog)
          // MonitoringService.recordValidationFailures(validationFailures)
        #endif
      }
      // `validationFailures` contains all invalid records, available for logging, monitoring, or reporting as needed.
      let cleanedBridges = Self.sanitizeBridgeModels(bridges)

      // Update cache metadata and save to cache
      cleanedBridges.forEach { $0.updateCacheMetadata() }
      cacheService.saveToCache(cleanedBridges, for: "historical_bridges")

      return (cleanedBridges, validationFailures)
    } catch {
      // Graceful degradation: return stale cache if network failed
      if let cachedBridges: [BridgeStatusModel] = cacheService.loadFromCache([BridgeStatusModel].self,
                                                                             for: "historical_bridges")
      {
        cachedBridges.forEach { $0.markAsStale() }
        return (cachedBridges, [])
      }

      // Last resort: throw the network error
      throw error
    }
  }

  // MARK: - Network Fetching

  private func fetchFromNetwork() async throws -> Data {
    var components = URLComponents(
      string: "https://data.seattle.gov/resource/gm8h-9449.json"
    )!
    components.queryItems = [
      URLQueryItem(name: "$limit", value: "1000"),
      URLQueryItem(name: "$order", value: "opendatetime DESC"),
    ]

    guard let url = components.url else {
      throw NetworkError.invalidResponse
    }

    return try await networkClient.fetchData(from: url)
  }

  // MARK: - Sample Data Loading

  /// Loads sample bridge data for testing and development.
  ///
  /// - Returns: An array of `BridgeStatusModel` instances containing sample data.
  ///
  /// ## Example
  /// ```swift
  /// let sampleBridges = BridgeDataService.shared.loadSampleData()
  /// ```
  func loadSampleData() -> [BridgeStatusModel] {
    return sampleProvider.loadSampleData()
  }

  // MARK: - Route Generation

  /// Generates route models from an array of bridge status models.
  ///
  /// This method checks cache first for generated routes. If no valid cached routes are available,
  /// it generates new routes using the `SampleDataProvider`.
  ///
  /// - Parameter bridges: An array of `BridgeStatusModel` to generate routes from.
  /// - Returns: An array of `RouteModel` instances representing generated routes.
  ///
  /// ## Example
  /// ```swift
  /// let routes = BridgeDataService.shared.generateRoutes(from: bridges)
  /// ```
  func generateRoutes(from bridges: [BridgeStatusModel]) -> [RouteModel] {
    // Check cache first for generated routes
    if let cachedRoutes: [RouteModel] = cacheService.loadFromCache([RouteModel].self,
                                                                   for: "generated_routes"),
      cacheService.isCacheValid(for: "generated_routes")
    {
      return cachedRoutes
    }

    // Generate new routes using SampleDataProvider
    let routes = sampleProvider.generateSampleRoutes(from: bridges)

    // Update cache metadata and save to cache
    cacheService.saveToCache(routes, for: "generated_routes")

    return routes
  }

  // MARK: - Cache Utilities

  /// Clears all cached bridge and route data managed by this service.
  ///
  /// ## Example
  /// ```swift
  /// BridgeDataService.shared.clearCache()
  /// ```
  func clearCache() {
    cacheService.clearCache()
  }

  /// Retrieves the current total size of the cache in bytes.
  ///
  /// - Returns: The cache size in bytes as an `Int64`.
  ///
  /// ## Example
  /// ```swift
  /// let cacheSize = BridgeDataService.shared.getCacheSize()
  /// print("Cache size: \(cacheSize) bytes")
  /// ```
  func getCacheSize() -> Int64 {
    return cacheService.getCacheSize()
  }

  // MARK: - Private Helpers

  /// Sanitizes the final bridge array by removing entries with missing IDs/names and eliminating
  /// duplicates (by `bridgeName`).
  ///
  /// - Parameter models: The array of `BridgeStatusModel` to sanitize.
  /// - Returns: A filtered array of `BridgeStatusModel` with valid, unique entries.
  private static func sanitizeBridgeModels(_ models: [BridgeStatusModel]) -> [BridgeStatusModel] {
    var seen = Set<String>()
    return models.filter { model in
      guard !model.bridgeName.isEmpty, model.apiBridgeID != nil else { return false }
      if seen.contains(model.bridgeName) { return false }
      seen.insert(model.bridgeName)
      return true
    }
  }
}

