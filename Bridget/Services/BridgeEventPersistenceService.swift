//  BridgeEventPersistenceService.swift
//  Bridget
//
//  Persists and retrieves BridgeEvent data for analytics, ML, and offline functionality
//
//  Designed for modularity: can be used by AppStateModel, analytics, and future ML/CoreML/ANE routing

import Foundation
import SwiftData

/// Protocol for bridge event persistence. Abstracts saving, fetching, and deleting bridge opening events.
protocol BridgeEventPersistenceServiceProtocol {
  func save(events: [BridgeEvent]) throws
  func fetchAllEvents() throws -> [BridgeEvent]
  func deleteAllEvents() throws
}

/// Concrete implementation of BridgeEventPersistenceServiceProtocol using SwiftData.
class BridgeEventPersistenceService: BridgeEventPersistenceServiceProtocol {
  private let modelContext: ModelContext

  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  /// Save new bridge events, deleting existing ones for a full refresh.
  func save(events: [BridgeEvent]) throws {
    try deleteAllEvents()
    for event in events {
      modelContext.insert(event)
    }
    try modelContext.save()
  }

  /// Fetch all BridgeEvent entities.
  func fetchAllEvents() throws -> [BridgeEvent] {
    return try modelContext.fetch(FetchDescriptor<BridgeEvent>())
  }

  /// Delete all BridgeEvent entities.
  func deleteAllEvents() throws {
    let allEvents = try modelContext.fetch(FetchDescriptor<BridgeEvent>())
    for event in allEvents {
      modelContext.delete(event)
    }
    try modelContext.save()
  }
}
