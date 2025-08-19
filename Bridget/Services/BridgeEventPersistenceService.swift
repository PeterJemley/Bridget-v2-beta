//  BridgeEventPersistenceService.swift
//  Bridget
//
//  Persists and retrieves BridgeEvent data for analytics, ML, and offline functionality
//
//  Designed for modularity: can be used by AppStateModel, analytics, and future ML/CoreML/ANE routing

import Foundation
import SwiftData

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
  
  // MARK: - BridgeEventPersistenceServiceProtocol Implementation
  
  /// Save event data with the specified ID
  func saveEvent(_ event: Data, withID id: String) throws {
    // For now, this is a placeholder implementation
    // In a real implementation, you would save the Data to persistent storage
    // associated with the given ID
    print("Saving event with ID: \(id), data size: \(event.count) bytes")
  }
  
  /// Load event data with the specified ID
  func loadEvent(withID id: String) throws -> Data? {
    // For now, this is a placeholder implementation
    // In a real implementation, you would load the Data from persistent storage
    // associated with the given ID
    print("Loading event with ID: \(id)")
    return nil
  }
  
  /// Delete event data with the specified ID
  func deleteEvent(withID id: String) throws {
    // For now, this is a placeholder implementation
    // In a real implementation, you would delete the Data from persistent storage
    // associated with the given ID
    print("Deleting event with ID: \(id)")
  }
  
    /// Fetch all event IDs
  func fetchAllEventIDs() throws -> [String] {
    // For now, this is a placeholder implementation
    // In a real implementation, you would return all stored event IDs
    let allEvents = try modelContext.fetch(FetchDescriptor<BridgeEvent>())
    return allEvents.map { String(describing: $0.id) }
  }
}
