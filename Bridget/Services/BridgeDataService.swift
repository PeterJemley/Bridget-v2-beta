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

// MARK: - Bridge Data Service

class BridgeDataService {
  static let shared = BridgeDataService()

  // MARK: - Service Dependencies

  private let networkClient = NetworkClient.shared
  private let cacheService = CacheService.shared
  private let dataProcessor = BridgeDataProcessor.shared
  private let sampleProvider = SampleDataProvider.shared

  private init() {}

  // MARK: - Historical Data Loading

  /// Loads historical bridge opening data with retry logic and caching
  ///
  /// This method orchestrates multiple specialized services to provide robust data loading:
  /// 1. **Cache-first approach**: Returns valid cached data if available
  /// 2. **Network fetching**: Uses NetworkClient for retry logic and validation
  /// 3. **Data processing**: Uses BridgeDataProcessor for JSON decoding and validation
  /// 4. **Graceful degradation**: Falls back to stale cache if all network attempts fail
  ///
  /// - Returns: Array of BridgeStatusModel instances with historical opening data
  /// - Throws: NetworkError or BridgeDataError if no data available
  func loadHistoricalData() async throws -> [BridgeStatusModel] {
    // Check cache first - return valid cached data if available
    if let cachedBridges: [BridgeStatusModel] = cacheService.loadFromCache([BridgeStatusModel].self,
                                                                           for: "historical_bridges"),
      cacheService.isCacheValid(for: "historical_bridges")
    {
      // Update cache metadata for all bridges
      cachedBridges.forEach { $0.updateCacheMetadata() }
      return cachedBridges
    }

    // Fetch from network using NetworkClient
    do {
      let data = try await fetchFromNetwork()
      let bridges = try dataProcessor.processHistoricalData(data)

      // Update cache metadata and save to cache
      bridges.forEach { $0.updateCacheMetadata() }
      cacheService.saveToCache(bridges, for: "historical_bridges")

      return bridges
    } catch {
      // Graceful degradation: return stale cache if network failed
      if let cachedBridges: [BridgeStatusModel] = cacheService.loadFromCache([BridgeStatusModel].self,
                                                                             for: "historical_bridges")
      {
        cachedBridges.forEach { $0.markAsStale() }
        return cachedBridges
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

  /// Loads sample data for testing and development
  ///
  /// - Returns: Array of BridgeStatusModel instances with sample data
  func loadSampleData() -> [BridgeStatusModel] {
    return sampleProvider.loadSampleData()
  }

  // MARK: - Route Generation

  func generateRoutes(from bridges: [BridgeStatusModel]) -> [RouteModel] {
    // Check cache first for generated routes
    if let cachedRoutes: [RouteModel] = cacheService.loadFromCache([RouteModel].self,
                                                                   for: "generated_routes"),
      cacheService.isCacheValid(for: "generated_routes")
    {
      // Update cache metadata for all routes
      cachedRoutes.forEach { $0.updateScoreMetadata() }
      return cachedRoutes
    }

    // Generate new routes using SampleDataProvider
    let routes = sampleProvider.generateSampleRoutes(from: bridges)

    // Update cache metadata and save to cache
    routes.forEach { $0.updateScoreMetadata() }
    cacheService.saveToCache(routes, for: "generated_routes")

    return routes
  }

  // MARK: - Cache Utilities

  func clearCache() {
    cacheService.clearCache()
  }

  func getCacheSize() -> Int64 {
    return cacheService.getCacheSize()
  }
}
