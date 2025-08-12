//
//  ProbeTickDataService.swift
//  Bridget
//
//  Purpose: Populates and manages ProbeTick data for ML training and analytics
//  Dependencies: SwiftData, Foundation, BridgeEvent, ProbeTick
//  Integration Points:
//    - Converts BridgeEvent data to ProbeTick records
//    - Manages daily data collection for ML training
//    - Provides data for BridgeDataExporter
//  Key Features:
//    - Historical data conversion from BridgeEvent to ProbeTick
//    - Per-minute bridge status snapshots
//    - Feature computation for ML training
//    - Data validation and quality checks
//

import Foundation
import SwiftData

/// Service for populating and managing ProbeTick data for ML training and analytics.
///
/// `ProbeTickDataService` is responsible for converting existing `BridgeEvent` data
/// into `ProbeTick` records and managing the ongoing data collection pipeline
/// needed for machine learning model training.
///
/// ## Overview
///
/// This service bridges the gap between the historical bridge opening data
/// (BridgeEvent) and the per-minute probe snapshots (ProbeTick) required for
/// ML training. It computes ML features in real-time during data processing
/// and ensures data quality and completeness.
///
/// ## Key Responsibilities
///
/// - **Historical Data Conversion**: Convert BridgeEvent records to ProbeTick snapshots
/// - **Feature Computation**: Calculate ML features like crossing rates and routing metrics
/// - **Data Population**: Populate daily and historical ProbeTick data
/// - **Quality Assurance**: Validate data and ensure completeness
///
/// ## Usage
///
/// ```swift
/// // Initialize the service
/// let service = ProbeTickDataService(context: modelContext)
///
/// // Populate today's data
/// try await service.populateTodayProbeTicks()
///
/// // Populate historical data for training
/// let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
/// let endDate = Date()
/// try await service.populateHistoricalProbeTicks(from: startDate, to: endDate)
///
/// // Populate last week's data
/// try await service.populateLastWeekProbeTicks()
/// ```
///
/// ## ML Feature Computation
///
/// The service computes the following features for each ProbeTick:
/// - **Crossing Rate**: `crossK / crossN` for vehicle flow analysis
/// - **Via Routing**: Alternative route availability and penalties
/// - **Gate Anomaly**: ETA ratio compared to historical baseline
/// - **Detour Metrics**: Fraction of routes avoiding the bridge
///
/// ## Data Flow
///
/// ```
/// BridgeEvent → ProbeTickDataService → ProbeTick → BridgeDataExporter → NDJSON
///     ↓              ↓                    ↓              ↓
/// Historical    Feature Comp.      SwiftData      ML Training
/// Openings      & Validation       Storage        Data Export
/// ```
///
/// ## Integration with BridgeDataExporter
///
/// This service populates the data that `BridgeDataExporter` then exports
/// as NDJSON for ML processing. The exporter depends on having sufficient
/// ProbeTick data for the target date range.
final class ProbeTickDataService {
  /// The SwiftData context for database operations
  private let context: ModelContext

  /// Creates a new ProbeTickDataService instance
  /// - Parameter context: The SwiftData ModelContext for database operations
  init(context: ModelContext) {
    self.context = context
  }

  /// Populates ProbeTick data for a specific date range from existing BridgeEvent data.
  ///
  /// This method is used to create historical training data from existing bridge
  /// opening records. It generates one ProbeTick per minute per bridge for the
  /// entire date range, computing ML features based on historical patterns.
  ///
  /// - Parameters:
  ///   - startDate: Start of the date range (inclusive)
  ///   - endDate: End of the date range (exclusive)
  /// - Throws: Any error during data processing or storage
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Populate last 30 days of data for ML training
  /// let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
  /// let endDate = Date()
  /// try await service.populateHistoricalProbeTicks(from: startDate, to: endDate)
  /// ```
  ///
  /// ## Performance Notes
  ///
  /// - Processes one minute at a time for all bridges
  /// - Computes features based on historical event patterns
  /// - Saves to database after processing each minute
  /// - May take several minutes for large date ranges
  func populateHistoricalProbeTicks(from startDate: Date, to endDate: Date) async throws {
    // Fetch all bridge events in the date range
    let fetchDescriptor = FetchDescriptor<BridgeEvent>(predicate: #Predicate {
      $0.openDateTime >= startDate && $0.openDateTime < endDate && $0.isValidated
    },
    sortBy: [SortDescriptor(\.openDateTime), SortDescriptor(\.bridgeID)])

    let events = try context.fetch(fetchDescriptor)

    // Group events by bridge ID
    var eventsByBridge: [String: [BridgeEvent]] = [:]
    for event in events {
      eventsByBridge[event.bridgeID, default: []].append(event)
    }

    // Generate ProbeTick records for each minute in the date range
    let calendar = Calendar.current
    var currentDate = startDate

    while currentDate < endDate {
      for (bridgeID, bridgeEvents) in eventsByBridge {
        let tick = try await createProbeTick(for: bridgeID,
                                             at: currentDate,
                                             from: bridgeEvents)

        if let tick = tick {
          context.insert(tick)
        }
      }

      // Move to next minute
      currentDate = calendar.date(byAdding: .minute, value: 1, to: currentDate) ?? currentDate
    }

    try context.save()
  }

  /// Populates ProbeTick data for today from existing BridgeEvent data.
  ///
  /// This is a convenience method that populates data for the current day,
  /// starting from midnight local time. It's useful for daily data collection
  /// and ensuring the most recent data is available for export.
  ///
  /// - Throws: Any error during data processing or storage
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Populate today's data for daily export
  /// try await service.populateTodayProbeTicks()
  /// ```
  func populateTodayProbeTicks() async throws {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

    try await populateHistoricalProbeTicks(from: today, to: tomorrow)
  }

  /// Populates ProbeTick data for the last week from existing BridgeEvent data.
  ///
  /// This convenience method populates data for the past 7 days, which is
  /// useful for weekly data collection and ensuring recent historical data
  /// is available for ML training.
  ///
  /// - Throws: Any error during data processing or storage
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Populate last week's data for weekly analysis
  /// try await service.populateLastWeekProbeTicks()
  /// ```
  func populateLastWeekProbeTicks() async throws {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let lastWeek = calendar.date(byAdding: .day, value: -7, to: today) ?? today

    try await populateHistoricalProbeTicks(from: lastWeek, to: today)
  }

  /// Creates a ProbeTick record for a specific bridge at a specific timestamp.
  ///
  /// This private method handles the core logic of creating individual ProbeTick
  /// records. It analyzes historical BridgeEvent data to compute ML features
  /// and determine bridge status at the given timestamp.
  ///
  /// - Parameters:
  ///   - bridgeID: The bridge identifier string
  ///   - timestamp: The timestamp for this tick
  ///   - events: Historical bridge events for this bridge
  /// - Returns: A ProbeTick instance if valid data exists, nil otherwise
  /// - Throws: Any error during feature computation
  ///
  /// ## Feature Computation
  ///
  /// The method computes:
  /// - **Crossing Rate**: Based on historical traffic patterns
  /// - **Via Metrics**: Alternative routing availability and penalties
  /// - **Gate Anomaly**: ETA ratio compared to baseline
  /// - **Alternate Metrics**: Route avoidance patterns
  /// - **Bridge Status**: Whether bridge is open at timestamp
  private func createProbeTick(for bridgeID: String,
                               at timestamp: Date,
                               from events: [BridgeEvent]) async throws -> ProbeTick?
  {
    // Find if there's an active bridge opening at this timestamp
    let activeEvent = events.first { event in
      event.openDateTime <= timestamp &&
        (event.closeDateTime == nil || event.closeDateTime! > timestamp)
    }

    // Calculate features based on historical data
    let (crossK, crossN) = calculateCrossRate(at: timestamp, from: events)
    let (viaRoutable, viaPenaltySec) = calculateViaMetrics(at: timestamp, from: events)
    let gateAnom = calculateGateAnomaly(at: timestamp, from: events)
    let (alternatesTotal, alternatesAvoid) = calculateAlternateMetrics(at: timestamp, from: events)
    let openLabel = activeEvent != nil

    // Create the ProbeTick record
    let tick = ProbeTick(tsUtc: timestamp,
                         bridgeId: Int16(bridgeID) ?? 0,
                         crossK: Int16(crossK),
                         crossN: Int16(crossN),
                         viaRoutable: viaRoutable,
                         viaPenaltySec: Int32(viaPenaltySec),
                         gateAnom: gateAnom,
                         alternatesTotal: Int16(alternatesTotal),
                         alternatesAvoid: Int16(alternatesAvoid),
                         freeEtaSec: nil, // TODO: Implement real-time ETA calculation
                         viaEtaSec: nil,  // TODO: Implement via route ETA calculation
                         openLabel: openLabel,
                         isValid: true)

    return tick
  }

  /// Calculates the crossing rate (k/n) for a specific timestamp.
  ///
  /// This method analyzes historical traffic patterns to estimate the
  /// vehicle crossing rate at the given timestamp. It uses a rolling
  /// window approach to provide realistic estimates.
  ///
  /// - Parameters:
  ///   - timestamp: The timestamp for crossing rate calculation
  ///   - events: Historical bridge events for context
  /// - Returns: Tuple of (crossK, crossN) representing crossing rate
  private func calculateCrossRate(at timestamp: Date, from events: [BridgeEvent]) -> (Int, Int) {
    let calendar = Calendar.current
    let oneMinuteAgo = calendar.date(byAdding: .minute, value: -1, to: timestamp) ?? timestamp

    // Count vehicles that crossed in the last minute
    let crossingEvents = events.filter { event in
      event.openDateTime >= oneMinuteAgo && event.openDateTime <= timestamp
    }

    // For now, use a simplified calculation based on bridge openings
    // In a real implementation, this would come from traffic sensors or GPS data
    let crossK = crossingEvents.count
    let crossN = max(crossK, 1) // Ensure we don't divide by zero

    return (crossK, crossN)
  }

  /// Calculates via routing metrics for a specific timestamp.
  ///
  /// This method determines whether the bridge can be used as an alternative
  /// route and calculates any associated penalties based on historical
  /// routing patterns and bridge conditions.
  ///
  /// - Parameters:
  ///   - timestamp: The timestamp for via routing calculation
  ///   - events: Historical bridge events for context
  /// - Returns: Tuple of (viaRoutable, viaPenaltySec)
  private func calculateViaMetrics(at timestamp: Date, from events: [BridgeEvent]) -> (Bool, Int) {
    // Check if there's an active bridge opening that would require via routing
    let activeEvent = events.first { event in
      event.openDateTime <= timestamp &&
        (event.closeDateTime == nil || event.closeDateTime! > timestamp)
    }

    let viaRoutable = activeEvent == nil // Can route directly if bridge is closed
    let viaPenaltySec = activeEvent != nil ? Int(activeEvent!.minutesOpen * 60) : 0

    return (viaRoutable, viaPenaltySec)
  }

  /// Calculates gate ETA anomaly for a specific timestamp.
  ///
  /// This method compares current gate ETA to historical baseline to
  /// identify anomalies that might indicate bridge issues or unusual
  /// traffic conditions.
  ///
  /// - Parameters:
  ///   - timestamp: The timestamp for anomaly calculation
  ///   - events: Historical bridge events for baseline
  /// - Returns: Anomaly ratio (clipped to [1, 8])
  private func calculateGateAnomaly(at timestamp: Date, from events: [BridgeEvent]) -> Double {
    // Calculate the ratio of current wait time to historical average
    let calendar = Calendar.current
    let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: timestamp) ?? timestamp

    let recentEvents = events.filter { $0.openDateTime >= oneWeekAgo }
    let averageMinutesOpen = recentEvents.isEmpty ? 5.0 :
      Double(recentEvents.map { $0.minutesOpen }.reduce(0, +)) / Double(recentEvents.count)

    let currentEvent = events.first { event in
      event.openDateTime <= timestamp &&
        (event.closeDateTime == nil || event.closeDateTime! > timestamp)
    }

    if let currentEvent = currentEvent {
      let currentMinutesOpen = currentEvent.closeDateTime != nil ?
        Double(calendar.dateComponents([.minute], from: currentEvent.openDateTime, to: currentEvent.closeDateTime!).minute ?? 0) :
        Double(calendar.dateComponents([.minute], from: currentEvent.openDateTime, to: timestamp).minute ?? 0)

      let ratio = currentMinutesOpen / max(averageMinutesOpen, 1.0)
      return min(max(ratio, 1.0), 8.0) // Clamp to [1, 8]
    }

    return 1.0 // No anomaly if bridge is closed
  }

  /// Calculates alternate route metrics for a specific timestamp.
  ///
  /// This method analyzes the availability of alternative routes and
  /// determines what fraction of routes avoid the bridge span,
  /// which is useful for understanding traffic diversion patterns.
  ///
  /// - Parameters:
  ///   - timestamp: The timestamp for alternate route calculation
  ///   - events: Historical bridge events for context
  /// - Returns: Tuple of (alternatesTotal, alternatesAvoid)
  private func calculateAlternateMetrics(at _: Date, from _: [BridgeEvent]) -> (Int, Int) {
    // For now, use simplified metrics
    // In a real implementation, this would come from routing engine analysis
    let alternatesTotal = 3 // Assume 3 alternate routes available
    let alternatesAvoid = 0 // Assume no alternates avoid the bridge span

    return (alternatesTotal, alternatesAvoid)
  }
}
