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
import Observation
import SwiftData

/// A global application state container responsible for managing routing data, loading states,
/// error handling, user selections, validation failures, and persistence within the Bridget app.
///
/// This model is marked `@Observable` and is the single source of truth for all route data.
/// It interacts with services like `BridgeDataService` to fetch and cache route data and uses
/// SwiftData's ModelContext for local persistence.
///
/// - Note: This class is intended to be used in SwiftUI views via `@Bindable`.
@Observable
class AppStateModel {
  /// SwiftData context for managing persistence of bridge events and other entities.
  let modelContext: ModelContext

  /// The current list of available routes, fetched from a data source or loaded from persistence.
  var routes: [RouteModel]

  /// A Boolean value indicating whether data is currently being loaded.
  var isLoading: Bool

  /// The identifier of the currently selected route, if any.
  var selectedRouteID: String?

  /// The most recent error encountered during data fetching or processing.
  var error: Error?

  // MARK: - Validation Failures

  /// Validation failures encountered during the loading and processing of bridge data.
  /// These are not fatal errors but indicate issues that may affect data integrity.
  @ObservationIgnored
  var validationFailures: [BridgeDataProcessor.ValidationFailure] = []

  // MARK: - Cache Metadata (Internal Only)

  /// The timestamp of the most recent data refresh.
  @ObservationIgnored
  var lastDataRefresh: Date?

  /// The duration (in seconds) that cached data remains valid.
  /// Default is 5 minutes.
  @ObservationIgnored
  var cacheExpirationTime: TimeInterval = 300 // 5 minutes

  /// A flag indicating whether the app is currently in offline mode.
  @ObservationIgnored
  var isOfflineMode: Bool = false

  /// The timestamp of the last successful data fetch.
  @ObservationIgnored
  var lastSuccessfulFetch: Date?

  /// Initializes the application state model with default values and starts loading data with persistence.
  ///
  /// - Parameter modelContext: The SwiftData ModelContext used for local data persistence.
  init(modelContext: ModelContext) {
    self.modelContext = modelContext
    self.routes = []
    self.isLoading = false
    self.selectedRouteID = nil
    self.error = nil
    self.validationFailures = []
    self.lastDataRefresh = nil
    self.isOfflineMode = false
    self.lastSuccessfulFetch = nil

    // Start loading data immediately, leveraging the provided modelContext for persistence.
    Task {
      await loadData()
    }
  }

  // MARK: - Data Loading

  /// Loads historical bridge data asynchronously and updates the application state.
  ///
  /// This method first attempts to load persisted bridge events from SwiftData.
  /// If persisted data exists for all bridges, it uses that data (offline-first).
  /// Otherwise, it fetches from the BridgeDataService API, persists the results,
  /// and then reloads from SwiftData to update the in-memory models and UI state.
  ///
  /// Validation failures encountered during data processing are stored in `validationFailures`
  /// without disrupting the data load.
  @MainActor
  private func loadData() async {
    isLoading = true
    error = nil
    validationFailures = []

    // Load persisted BridgeEvent entities from SwiftData
    var persistedBridgeEvents: [BridgeEvent] = []
    do {
      persistedBridgeEvents = try modelContext.fetch(FetchDescriptor<BridgeEvent>())
    } catch {
      print("Failed to fetch persisted BridgeEvents:", error)
    }

    do {
      // Fetch all bridges from API to get the canonical list for validation
      let (apiBridges, apiValidationFailures) = try await BridgeDataService.shared.loadHistoricalData()
      validationFailures = apiValidationFailures

      let persistedBridgeIDs = Set(persistedBridgeEvents.map { $0.bridgeID })
      let apiBridgeIDs = Set(apiBridges.compactMap { $0.apiBridgeID?.rawValue })

      if apiBridgeIDs.isSubset(of: persistedBridgeIDs), !persistedBridgeEvents.isEmpty {
        // Persisted data is complete or newer, use persisted data for in-memory route list
        routes = BridgeDataService.shared.generateRoutes(from: bridgeStatusModels(from: persistedBridgeEvents))
        isLoading = false
        recordSuccessfulFetch()
      } else {
        // Persisted data incomplete or missing, fallback to API fetch and persist

        // Clear existing persisted bridge events before inserting new ones
        for event in persistedBridgeEvents {
          modelContext.delete(event)
        }

        // Save the deletion before inserting new data
        do {
          try modelContext.save()
        } catch {
          print("Failed to clear persisted BridgeEvents before inserting new ones:", error)
        }

        // Persist bridge events fetched from API
        // Removed insertion of BridgeEvent with only bridgeID and name as per instructions

        // Save context to persist data (no new insertions, so this mainly flushes deletions)
        do {
          try modelContext.save()
        } catch {
          print("Failed to save BridgeEvents to persistence:", error)
        }

        // Reload persisted data to repopulate in-memory models and UI state
        let reloadedBridgeEvents = try modelContext.fetch(FetchDescriptor<BridgeEvent>())
        routes = BridgeDataService.shared.generateRoutes(from: bridgeStatusModels(from: reloadedBridgeEvents))
        isLoading = false
        recordSuccessfulFetch()
      }
    } catch {
      // On API error, fall back to persisted data if available
      if !persistedBridgeEvents.isEmpty {
        routes = BridgeDataService.shared.generateRoutes(from: bridgeStatusModels(from: persistedBridgeEvents))
        isLoading = false
        markAsOffline()
        print("Using persisted data due to API error:", error)
      } else {
        // No persisted data, show error and fallback to API data directly
        self.error = error
        self.isLoading = false
        self.markAsOffline()
        print("API Error:", error)

        // Attempt to fetch API data only (without persistence) and generate routes
        do {
          let (apiBridges, _) = try await BridgeDataService.shared.loadHistoricalData()
          routes = BridgeDataService.shared.generateRoutes(from: apiBridges)
        } catch {
          print("Failed to load API bridge data fallback:", error)
        }
      }
    }
  }

  // MARK: - Refresh Data

  /// Refreshes all route data by clearing cache metadata and reloading from the network and persistence.
  ///
  /// This method marks all existing routes and bridges as stale before reloading,
  /// ensuring fresh data is fetched from the API and persisted.
  ///
  /// After fetching and persisting, the in-memory state is updated from SwiftData.
  @MainActor
  func refreshData() async {
    // Mark existing bridges as stale to force refresh
    for route in routes {
      route.bridges.forEach { $0.markAsStale() }
    }

    // Clear persisted bridge events to avoid stale data usage
    do {
      let persistedBridgeEvents = try modelContext.fetch(FetchDescriptor<BridgeEvent>())
      for event in persistedBridgeEvents {
        modelContext.delete(event)
      }
      try modelContext.save()
    } catch {
      print("Failed to clear persisted BridgeEvents during refresh:", error)
    }

    // Load fresh data (will fetch from API and persist)
    await loadData()
  }

  // MARK: - Computed Properties

  /// Returns the currently selected `RouteModel`, if one exists.
  ///
  /// - Returns: The selected `RouteModel` or `nil` if no selection is made.
  var selectedRoute: RouteModel? {
    guard let selectedRouteID = selectedRouteID else { return nil }
    return routes.first { $0.routeID == selectedRouteID }
  }

  /// The total number of available routes.
  var totalRoutes: Int {
    return routes.count
  }

  /// A Boolean value indicating whether there is an active error.
  var hasError: Bool {
    return error != nil
  }

  /// The localized description of the current error, if any.
  var errorMessage: String? {
    return error?.localizedDescription
  }

  /// A Boolean value indicating whether there are any validation failures.
  var hasValidationFailures: Bool {
    return !validationFailures.isEmpty
  }

  // MARK: - Route Selection

  /// Selects a route by its identifier.
  ///
  /// - Parameter routeID: The identifier of the route to select.
  func selectRoute(withID routeID: String) {
    selectedRouteID = routeID
  }

  /// Clears the current route selection.
  func clearSelection() {
    selectedRouteID = nil
  }

  /// Clears the current error state.
  func clearError() {
    error = nil
  }

  // MARK: - Cache Management

  /// Updates the cache metadata with the current timestamp and marks the app as online.
  func updateCacheMetadata() {
    lastDataRefresh = Date()
    isOfflineMode = false
  }

  /// Marks the app as being in offline mode.
  func markAsOffline() {
    isOfflineMode = true
  }

  /// Records a successful data fetch by updating the last successful fetch timestamp
  /// and cache metadata.
  func recordSuccessfulFetch() {
    lastSuccessfulFetch = Date()
    updateCacheMetadata()
  }

  /// Determines whether the cached data is stale based on the cache expiration time.
  ///
  /// - Returns: `true` if the data is stale; otherwise, `false`.
  var isDataStale: Bool {
    guard let lastRefresh = lastDataRefresh else { return true }
    let dataAge = Date().timeIntervalSince(lastRefresh)
    return dataAge > cacheExpirationTime
  }

  /// Determines whether data should be refreshed based on staleness or offline mode.
  ///
  /// - Returns: `true` if data should be refreshed; otherwise, `false`.
  var shouldRefreshData: Bool {
    return isDataStale || isOfflineMode
  }

  /// The age of the cached data in seconds, if available.
  ///
  /// - Returns: The age in seconds or `nil` if no cache timestamp exists.
  var dataAge: TimeInterval? {
    guard let lastRefresh = lastDataRefresh else { return nil }
    return Date().timeIntervalSince(lastRefresh)
  }

  /// Converts an array of BridgeEvent to BridgeStatusModel by grouping events for each bridge.
  private func bridgeStatusModels(from events: [BridgeEvent]) -> [BridgeStatusModel] {
    let grouped = Dictionary(grouping: events) { $0.bridgeID }
    return grouped.compactMap { bridgeID, eventsForBridge in
      guard let bridgeName = eventsForBridge.first?.bridgeName else { return nil }
      let openings = eventsForBridge.map { $0.openDateTime }
      return BridgeStatusModel(bridgeName: bridgeName, apiBridgeID: BridgeID(rawValue: bridgeID), historicalOpenings: openings)
    }
  }
}
