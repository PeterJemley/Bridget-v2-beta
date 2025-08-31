//
//  AppStateModel.swift
//  Bridget
//
//  ## Module
//  Models
//
//  ## Purpose
//  Global application state management with error handling and async data loading
//
//  ## Dependencies
//  - Foundation (for Date, Error types)
//  - Observation framework
//  - SwiftData (for local persistence)
//  - BridgeDataService (for data loading)
//  - RouteModel (for route data)
//
//  ## Integration Points
//  - Single source of truth for all route data and UI state
//  - Passed to RouteListView via @Bindable for UI updates
//  - Persisted and loaded via SwiftData ModelContext
//  - Updated by BridgeDataService with loaded routes
//  - Manages loading states and error handling
//  - Future: Will be updated by real-time traffic and ML scoring services
//
//  ## Key Features
//  - Async data loading within Observation Framework
//  - SwiftData persistence integration (offline-first)
//  - Comprehensive error state management
//  - Route selection and management
//  - Sample data fallback on API failure
//  - MainActor compliance for UI updates
//

import Foundation
import MapKit
import Observation
import SwiftData

/// A global application state container responsible for managing persistence,
/// loading states, error handling, and internal cache metadata within the Bridget app.
///
/// This model is marked `@Observable` and primarily manages persistence and internal state for analytics
/// and background processing. It no longer exposes any bridge or route data for UI display.
///
/// - Note: UI-related properties and methods have been removed to restrict exposure of bridge and route data.
@Observable
class AppStateModel {
  /// SwiftData context for managing persistence of bridge events and other entities.
  let modelContext: ModelContext

  /// Service responsible for persistence operations on BridgeEvent entities.
  private let bridgeEventPersistence: BridgeEventPersistenceServiceProtocol

  /// A Boolean value indicating whether data is currently being loaded.
  var isLoading: Bool

  /// The most recent error encountered during data fetching or processing.
  var error: Error?

  // MARK: - Validation Failures

  /// Validation failures encountered during the loading and processing of bridge data.
  /// These are not fatal errors but indicate issues that may affect data integrity.
  @ObservationIgnored
  var validationFailures: [ValidationFailure] = []

  // MARK: - Cache Metadata (Internal Only)

  /// The timestamp of the most recent data refresh.
  @ObservationIgnored
  var lastDataRefresh: Date?

  /// The duration (in seconds) that cached data remains valid.
  /// Default is 5 minutes.
  @ObservationIgnored
  var cacheExpirationTime: TimeInterval = 300  // 5 minutes

  /// A flag indicating whether the app is currently in offline mode.
  @ObservationIgnored
  var isOfflineMode: Bool = false

  /// The timestamp of the last successful data fetch.
  @ObservationIgnored
  var lastSuccessfulFetch: Date?

  /// Real-time traffic status for each bridge, keyed by bridge ID.
  @ObservationIgnored
  var bridgeTrafficStatus: [String: TrafficStatus] = [:]

  /// Initializes the application state model with default values and starts loading data with persistence.
  ///
  /// - Parameters:
  ///   - modelContext: The SwiftData ModelContext used for local data persistence.
  ///   - bridgeEventPersistence: The persistence service for BridgeEvent entities.
  ///     Optional. If not provided, a `BridgeEventPersistenceService` will be created with the given `modelContext`.
  init(modelContext: ModelContext,
       bridgeEventPersistence: BridgeEventPersistenceServiceProtocol? = nil)
  {
    self.modelContext = modelContext
    self.bridgeEventPersistence =
      bridgeEventPersistence
        ?? BridgeEventPersistenceService(modelContext: modelContext)
    self.isLoading = false
    self.error = nil
    self.validationFailures = []
    self.lastDataRefresh = nil
    self.isOfflineMode = false
    self.lastSuccessfulFetch = nil

    // Start loading data immediately, leveraging the provided persistence service.
    Task {
      await loadData()
    }
  }

  /// Convenience initializer for testing purposes, using an in-memory ModelContext.
  ///
  /// This is intended for unit tests and should not be used in production.
  @MainActor convenience init() {
    #if DEBUG
      // Create a lightweight in-memory ModelContainer for SwiftData
      let schema = Schema([BridgeEvent.self])
      let modelConfiguration = ModelConfiguration(
        isStoredInMemoryOnly: true
      )
      do {
        let container = try ModelContainer(for: schema,
                                           configurations: [modelConfiguration])
        self.init(modelContext: container.mainContext)
      } catch {
        fatalError(
          "Failed to create test ModelContainer: \(error.localizedDescription)"
        )
      }
    #else
      fatalError(
        "AppStateModel.init() is for test use only. Use the designated initializer."
      )
    #endif
  }

  // MARK: - Data Loading

  /// Loads historical bridge data asynchronously and updates internal application state.
  ///
  /// This method attempts to load persisted bridge events via the persistence service.
  /// If persisted data is incomplete or missing, it fetches from the BridgeDataService API and persists the results.
  /// Validation failures are stored internally.
  ///
  /// - Note: This method no longer exposes or updates any UI-related route or bridge collections.
  @MainActor
  private func loadData() async {
    isLoading = true
    error = nil
    validationFailures = []

    #if DEBUG
      // Verify bridge coordinates during development
      // Note: Use SeattleDrawbridges for coordinate verification
      // await SeattleDrawbridges.verifyCoordinates() // TODO: Implement if needed
    #endif

    // Load persisted BridgeEvent entities via persistence service
    var persistedBridgeEvents: [BridgeEvent] = []
    do {
      persistedBridgeEvents = try bridgeEventPersistence.fetchAllEvents()  // fetchAllEvents is sync so no await
    } catch {
      print("Failed to fetch persisted BridgeEvents:", error)
    }

    do {
      // Fetch all bridges from API to get the canonical list for validation
      let (apiBridges, apiValidationFailures) =
        try await BridgeDataService.shared.loadHistoricalData()
      validationFailures = apiValidationFailures

      let persistedBridgeIDs = Set(
        persistedBridgeEvents.map { $0.bridgeID }
      )
      let apiBridgeIDs = Set(
        apiBridges.compactMap { $0.apiBridgeID?.rawValue }
      )

      if apiBridgeIDs.isSubset(of: persistedBridgeIDs),
         !persistedBridgeEvents.isEmpty
      {
        // Persisted data is complete or newer, no UI update needed here
        isLoading = false
        recordSuccessfulFetch()
      } else {
        // Persisted data incomplete or missing, fallback to API fetch and persist

        // Clear existing persisted bridge events before inserting new ones via persistence service
        do {
          try bridgeEventPersistence.deleteAllEvents()
        } catch {
          print("Failed to clear persisted BridgeEvents before inserting new ones:",
                error)
        }

        // Persist bridge events fetched from API via persistence service
        do {
          let bridgeEvents: [BridgeEvent] = apiBridges.flatMap {
            model in
            // TODO: Populate minutesOpen, latitude, longitude with real values if available
            model.historicalOpenings.map {
              BridgeEvent(bridgeID: model.apiBridgeID?.rawValue ?? "",
                          bridgeName: model.bridgeName,
                          openDateTime: $0,
                          minutesOpen: 0,  // TODO: Provide correct duration
                          latitude: 0.0,  // TODO: Provide correct latitude
                          longitude: 0.0  // TODO: Provide correct longitude
              )
            }
          }
          try bridgeEventPersistence.save(events: bridgeEvents)
        } catch {
          print("Failed to save BridgeEvents to persistence:", error)
        }

        // No UI update, just finish loading and update cache metadata
        isLoading = false
        recordSuccessfulFetch()
      }
    } catch {
      // On API error, fallback to persisted data if available
      if !persistedBridgeEvents.isEmpty {
        isLoading = false
        markAsOffline()
        print("Using persisted data due to API error:", error)
      } else {
        // No persisted data, show error and fallback to API data directly
        self.error = error
        self.isLoading = false
        self.markAsOffline()
        print("API Error:", error)

        // Attempt to fetch API data only (without persistence)
        do {
          _ = try await BridgeDataService.shared.loadHistoricalData()
          // No UI update
        } catch {
          print("Failed to load API bridge data fallback:", error)
        }
      }
    }
  }

  // MARK: - Refresh Data

  /// Refreshes all data by clearing cache metadata and reloading from network and persistence.
  ///
  /// This method clears persisted bridge events to avoid stale data usage,
  /// then reloads fresh data asynchronously.
  ///
  /// - Note: No UI-related data updates are performed.
  @MainActor
  func refreshData() async {
    // Clear persisted bridge events via persistence service to avoid stale data
    do {
      try bridgeEventPersistence.deleteAllEvents()
    } catch {
      print("Failed to clear persisted BridgeEvents during refresh:",
            error)
    }

    // Load fresh data (will fetch from API and persist)
    await loadData()
  }

  // MARK: - Error and Loading State Management

  /// Clears the current error state.
  func clearError() {
    error = nil
  }

  // MARK: - Cache Management

  /// Updates the cache metadata with the current timestamp and marks the app as online.
  ///
  /// This method is intended for internal use only to track fetch success.
  func updateCacheMetadata() {
    lastDataRefresh = Date()
    isOfflineMode = false
  }

  /// Marks the app as being in offline mode.
  ///
  /// Internal use only.
  func markAsOffline() {
    isOfflineMode = true
  }

  /// Records a successful data fetch by updating the last successful fetch timestamp
  /// and cache metadata.
  ///
  /// Internal use only.
  func recordSuccessfulFetch() {
    lastSuccessfulFetch = Date()
    updateCacheMetadata()
  }

  /// Determines whether the cached data is stale based on the cache expiration time.
  ///
  /// - Returns: `true` if the data is stale; otherwise, `false`.
  ///
  /// Internal use only.
  var isDataStale: Bool {
    guard let lastRefresh = lastDataRefresh else { return true }
    let dataAge = Date().timeIntervalSince(lastRefresh)
    return dataAge > cacheExpirationTime
  }

  /// Determines whether data should be refreshed based on staleness or offline mode.
  ///
  /// - Returns: `true` if data should be refreshed; otherwise, `false`.
  ///
  /// Internal use only.
  var shouldRefreshData: Bool {
    return isDataStale || isOfflineMode
  }

  /// The age of the cached data in seconds, if available.
  ///
  /// - Returns: The age in seconds or `nil` if no cache timestamp exists.
  ///
  /// Internal use only.
  var dataAge: TimeInterval? {
    guard let lastRefresh = lastDataRefresh else { return nil }
    return Date().timeIntervalSince(lastRefresh)
  }

  // MARK: - Traffic Data Integration

  /// Fetches real-time traffic data for all bridges and updates traffic status.
  /// This uses MapKit's traffic layer and region queries for each bridge location.
  @MainActor
  func updateTrafficStatusForBridges() async {
    // TODO: Query MapKit traffic in the vicinity of each bridge using latitude/longitude.
    // For each bridge, update bridgeTrafficStatus[bridgeID] with current congestion/passability.
    // For now, this is a stub.
  }

  /// Infers whether the bridge is currently passable based on traffic data.
  /// - Parameter bridgeID: The ID of the bridge.
  /// - Returns: Boolean indicating if the bridge is likely passable.
  func isBridgePassable(bridgeID: String) -> Bool {
    return bridgeTrafficStatus[bridgeID]?.isPassable ?? true
  }
}
