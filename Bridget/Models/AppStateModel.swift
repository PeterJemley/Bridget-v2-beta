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

@Observable
class AppStateModel {
  var routes: [RouteModel]
  var isLoading: Bool
  var selectedRouteID: String?
  var error: Error?

  // MARK: - Cache Metadata (Internal Only)

  @ObservationIgnored
  var lastDataRefresh: Date?

  @ObservationIgnored
  var cacheExpirationTime: TimeInterval = 300 // 5 minutes

  @ObservationIgnored
  var isOfflineMode: Bool = false

  @ObservationIgnored
  var lastSuccessfulFetch: Date?

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

  var selectedRoute: RouteModel? {
    guard let selectedRouteID = selectedRouteID else { return nil }
    return routes.first { $0.routeID == selectedRouteID }
  }

  var totalRoutes: Int {
    return routes.count
  }

  var hasError: Bool {
    return error != nil
  }

  var errorMessage: String? {
    return error?.localizedDescription
  }

  // MARK: - Route Selection

  func selectRoute(withID routeID: String) {
    selectedRouteID = routeID
  }

  func clearSelection() {
    selectedRouteID = nil
  }

  func clearError() {
    error = nil
  }

  // MARK: - Cache Management

  func updateCacheMetadata() {
    lastDataRefresh = Date()
    isOfflineMode = false
  }

  func markAsOffline() {
    isOfflineMode = true
  }

  func recordSuccessfulFetch() {
    lastSuccessfulFetch = Date()
    updateCacheMetadata()
  }

  var isDataStale: Bool {
    guard let lastRefresh = lastDataRefresh else { return true }
    let dataAge = Date().timeIntervalSince(lastRefresh)
    return dataAge > cacheExpirationTime
  }

  var shouldRefreshData: Bool {
    return isDataStale || isOfflineMode
  }

  var dataAge: TimeInterval? {
    guard let lastRefresh = lastDataRefresh else { return nil }
    return Date().timeIntervalSince(lastRefresh)
  }
}
