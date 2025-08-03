//
//  AppStateModel.swift
//  Bridget
//
//  Module: Models
//  Purpose: Global application state management with error handling and async data loading
//  Dependencies:
//    - Foundation (for Date, Error types)
//    - Observation framework
//    - BridgeDataService (for data loading)
//    - RouteModel (for route data)
//  Integration Points:
//    - Single source of truth for all route data and UI state
//    - Passed to RouteListView via @Bindable for UI updates
//    - Updated by BridgeDataService with loaded routes
//    - Manages loading states and error handling
//    - Future: Will be updated by real-time traffic and ML scoring services
//  Key Features:
//    - Async data loading within Observation Framework
//    - Comprehensive error state management
//    - Route selection and management
//    - Sample data fallback on API failure
//    - MainActor compliance for UI updates
//

import Foundation
import Observation

/// A global application state container responsible for managing routing data, loading states,
/// error handling, and user selections within the Bridget app.
///
/// This model is marked `@Observable` and is the single source of truth for all route data.
/// It interacts with services like `BridgeDataService` to fetch and cache route data.
///
/// - Note: This class is intended to be used in SwiftUI views via `@Bindable`.
@Observable
class AppStateModel {
  /// The current list of available routes, fetched from a data source.
  var routes: [RouteModel]

  /// A Boolean value indicating whether data is currently being loaded.
  var isLoading: Bool

  /// The identifier of the currently selected route, if any.
  var selectedRouteID: String?

  /// The most recent error encountered during data fetching or processing.
  var error: Error?

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

  /// Initializes the application state model with default values and starts loading data.
  init() {
    self.routes = []
    self.isLoading = false
    self.selectedRouteID = nil
    self.error = nil
    self.lastDataRefresh = nil
    self.isOfflineMode = false
    self.lastSuccessfulFetch = nil

    // Start loading data immediately
    Task {
      await loadData()
    }
  }

  // MARK: - Data Loading

  /// Loads historical bridge data asynchronously and updates the application state.
  ///
  /// This method fetches data from the BridgeDataService and handles loading states,
  /// error handling, and cache management.
  @MainActor
  private func loadData() async {
    isLoading = true
    error = nil

    do {
      let bridges = try await BridgeDataService.shared.loadHistoricalData()
      let routes = BridgeDataService.shared.generateRoutes(from: bridges)

      self.routes = routes
      self.isLoading = false
      self.recordSuccessfulFetch()
    } catch {
      self.error = error
      self.isLoading = false
      self.markAsOffline()

      // For now, let's see the real error instead of falling back to sample data
      print("API Error:", error)
    }
  }

  // MARK: - Refresh Data

  /// Refreshes all route data by clearing cache metadata and reloading from the network.
  ///
  /// This method marks all existing routes and bridges as stale before reloading,
  /// ensuring fresh data is fetched from the API.
  @MainActor
  func refreshData() async {
    // Force refresh by clearing cache metadata
    for route in routes {
      route.markScoreAsStale()
      route.bridges.forEach { $0.markAsStale() }
    }

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
}
