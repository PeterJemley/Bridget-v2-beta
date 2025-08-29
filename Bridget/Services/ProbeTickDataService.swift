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

// MARK: - Pure Feature Computation and ProbeTick Creation Functions

/// Calculates the crossing rate (k/n) for a specific timestamp.
///
/// This function analyzes historical traffic patterns to estimate the
/// vehicle crossing rate at the given timestamp. It uses a rolling
/// window approach to provide realistic estimates.
///
/// - Parameters:
///   - timestamp: The timestamp for crossing rate calculation
///   - events: Historical bridge events for context
/// - Returns: Tuple of (crossK, crossN) representing crossing rate
func calculateCrossRate(at timestamp: Date, from events: [BridgeEvent]) -> (Int, Int) {
  let calendar = Calendar.current
  let oneMinuteAgo = calendar.date(byAdding: .minute, value: -1, to: timestamp) ?? timestamp

  // Count vehicles that crossed in the last minute
  let crossingEvents = events.filter { event in
    event.openDateTime >= oneMinuteAgo && event.openDateTime <= timestamp
  }

  // For now, use a simplified calculation based on bridge openings
  // In a real implementation, this would come from traffic sensors or GPS data
  let crossK = crossingEvents.count
  let crossN = max(crossK, 1)  // Ensure we don't divide by zero

  return (crossK, crossN)
}

/// Calculates via routing metrics for a specific timestamp.
///
/// This function determines whether the bridge can be used as an alternative
/// route and calculates any associated penalties based on historical
/// routing patterns and bridge conditions.
///
/// - Parameters:
///   - timestamp: The timestamp for via routing calculation
///   - events: Historical bridge events for context
/// - Returns: Tuple of (viaRoutable, viaPenaltySec)
func calculateViaMetrics(at timestamp: Date, from events: [BridgeEvent]) -> (Bool, Int) {
  // Check if there's an active bridge opening that would require via routing
  let activeEvent = events.first { event in
    event.openDateTime <= timestamp
      && (event.closeDateTime == nil || event.closeDateTime! > timestamp)
  }

  let viaRoutable = activeEvent == nil  // Can route directly if bridge is closed
  let viaPenaltySec = activeEvent != nil ? Int(activeEvent!.minutesOpen * 60) : 0

  return (viaRoutable, viaPenaltySec)
}

/// Calculates gate ETA anomaly for a specific timestamp.
///
/// This function compares current gate ETA to historical baseline to
/// identify anomalies that might indicate bridge issues or unusual
/// traffic conditions.
///
/// - Parameters:
///   - timestamp: The timestamp for anomaly calculation
///   - events: Historical bridge events for baseline
/// - Returns: Anomaly ratio (clipped to [1, 8])
func calculateGateAnomaly(at timestamp: Date, from events: [BridgeEvent]) -> Double {
  // Calculate the ratio of current wait time to historical average
  let calendar = Calendar.current
  let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: timestamp) ?? timestamp

  let recentEvents = events.filter { $0.openDateTime >= oneWeekAgo }
  let averageMinutesOpen =
    recentEvents.isEmpty
      ? 5.0 : Double(recentEvents.map { $0.minutesOpen }.reduce(0, +)) / Double(recentEvents.count)

  let currentEvent = events.first { event in
    event.openDateTime <= timestamp
      && (event.closeDateTime == nil || event.closeDateTime! > timestamp)
  }

  if let currentEvent = currentEvent {
    let currentMinutesOpen =
      currentEvent.closeDateTime != nil
        ? Double(
          calendar.dateComponents([.minute], from: currentEvent.openDateTime, to: currentEvent.closeDateTime!).minute ?? 0)
        : Double(
          calendar.dateComponents([.minute], from: currentEvent.openDateTime, to: timestamp).minute
            ?? 0)

    let ratio = currentMinutesOpen / max(averageMinutesOpen, 1.0)
    return min(max(ratio, 1.0), 8.0)  // Clamp to [1, 8]
  }

  return 1.0  // No anomaly if bridge is closed
}

/// Calculates alternate route metrics for a specific timestamp.
///
/// This function analyzes the availability of alternative routes and
/// determines what fraction of routes avoid the bridge span,
/// which is useful for understanding traffic diversion patterns.
///
/// - Parameters:
///   - timestamp: The timestamp for alternate route calculation
///   - events: Historical bridge events for context
/// - Returns: Tuple of (alternatesTotal, alternatesAvoid)
func calculateAlternateMetrics(at _: Date, from _: [BridgeEvent]) -> (Int, Int) {
  // For now, use simplified metrics
  // In a real implementation, this would come from routing engine analysis
  let alternatesTotal = 3  // Assume 3 alternate routes available
  let alternatesAvoid = 0  // Assume no alternates avoid the bridge span

  return (alternatesTotal, alternatesAvoid)
}

/// Creates a ProbeTick record for a specific bridge at a specific timestamp,
/// based purely on input parameters without side-effects.
///
/// This function analyzes historical BridgeEvent data to compute ML features
/// and determine bridge status at the given timestamp.
///
/// - Parameters:
///   - bridgeID: The bridge identifier string
///   - timestamp: The timestamp for this tick
///   - events: Historical bridge events for this bridge
/// - Returns: A ProbeTick instance if valid data exists, nil otherwise
func makeProbeTick(for bridgeID: String,
                   at timestamp: Date,
                   from events: [BridgeEvent]) -> ProbeTick?
{
  // Find if there's an active bridge opening at this timestamp
  let activeEvent = events.first { event in
    event.openDateTime <= timestamp
      && (event.closeDateTime == nil || event.closeDateTime! > timestamp)
  }

  // Calculate features based on historical data
  let (crossK, crossN) = calculateCrossRate(at: timestamp, from: events)
  let (viaRoutable, viaPenaltySec) = calculateViaMetrics(at: timestamp, from: events)
  let gateAnom = calculateGateAnomaly(at: timestamp, from: events)
  let (alternatesTotal, alternatesAvoid) = calculateAlternateMetrics(at: timestamp, from: events)
  let openLabel = activeEvent != nil

  // Validate bridgeID conversion
  guard let bridgeIdInt = Int16(bridgeID), bridgeIdInt > 0 else {
    return nil
  }

  // Validate and clamp values to prevent crashes
  let clampedViaPenaltySec = min(max(viaPenaltySec, 0), 900)  // Clamp to [0, 900]
  let clampedGateAnom = min(max(gateAnom, 1.0), 8.0)  // Clamp to [1, 8]
  let clampedCrossK = max(crossK, 0)
  let clampedCrossN = max(crossN, 1)  // Ensure we don't have zero

  // Create the ProbeTick record
  let tick = ProbeTick(tsUtc: timestamp,
                       bridgeId: bridgeIdInt,
                       crossK: Int16(clampedCrossK),
                       crossN: Int16(clampedCrossN),
                       viaRoutable: viaRoutable,
                       viaPenaltySec: Int32(clampedViaPenaltySec),
                       gateAnom: clampedGateAnom,
                       alternatesTotal: Int16(alternatesTotal),
                       alternatesAvoid: Int16(alternatesAvoid),
                       freeEtaSec: nil,  // TODO: Implement real-time ETA calculation
                       viaEtaSec: nil,  // TODO: Implement via route ETA calculation
                       openLabel: openLabel,
                       isValid: true)

  return tick
}

/// Creates an array of ProbeTick records for given bridge IDs and date range from BridgeEvent data,
/// without any side effects or database mutations.
///
/// This function produces one ProbeTick per minute per bridge for the entire date range,
/// computing ML features based on historical patterns and filtering invalid bridge IDs.
///
/// - Parameters:
///   - events: Array of BridgeEvent records covering entire date range
///   - bridgeIDs: List of bridge ID strings to generate ticks for
///   - startDate: Start of the date range (inclusive)
///   - endDate: End of the date range (exclusive)
/// - Returns: Array of ProbeTick instances created
func makeProbeTicks(from events: [BridgeEvent],
                    for bridgeIDs: [String],
                    from startDate: Date,
                    to endDate: Date) -> [ProbeTick]
{
  let calendar = Calendar.current

  // Group events by bridge ID for efficient lookup
  var eventsByBridge: [String: [BridgeEvent]] = [:]
  for event in events {
    eventsByBridge[event.bridgeID, default: []].append(event)
  }

  var probeTicks: [ProbeTick] = []

  var currentDate = startDate
  while currentDate < endDate {
    for bridgeID in bridgeIDs {
      let bridgeEvents = eventsByBridge[bridgeID] ?? []
      if let tick = makeProbeTick(for: bridgeID, at: currentDate, from: bridgeEvents) {
        probeTicks.append(tick)
      }
    }
    currentDate = calendar.date(byAdding: .minute, value: 1, to: currentDate) ?? currentDate
  }

  return probeTicks
}

// MARK: - ProbeTickDataService Class

/// Service for populating and managing ProbeTick data for ML training and analytics.
///
/// `ProbeTickDataService` is responsible for converting existing `BridgeEvent` data
/// into `ProbeTick` records and managing the ongoing data collection pipeline
/// needed for machine learning model training.
///
/// Internally, it uses pure functions for the heavy computations and data creation,
/// and manages SwiftData context mutation and persistence.
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
  /// opening records. It processes data in batches, uses pure functions for feature
  /// computation, and persists ProbeTick records into the database.
  ///
  /// - Parameters:
  ///   - startDate: Start of the date range (inclusive)
  ///   - endDate: End of the date range (exclusive)
  /// - Throws: Any error during data processing or storage
  ///
  /// ## Performance Notes
  ///
  /// - Processes one minute at a time for all bridges
  /// - Computes features based on historical event patterns
  /// - Saves to database after processing each batch
  /// - May take several minutes for large date ranges
  func populateHistoricalProbeTicks(from startDate: Date, to endDate: Date) async throws {
    // Fetch all bridge events in the date range
    let fetchDescriptor = FetchDescriptor<BridgeEvent>(predicate: #Predicate {
      $0.openDateTime >= startDate && $0.openDateTime < endDate && $0.isValidated
    },
    sortBy: [SortDescriptor(\.openDateTime), SortDescriptor(\.bridgeID)])

    let events = try context.fetch(fetchDescriptor)

    // Extract unique bridge IDs from the events
    let bridgeIDs = Set(events.map { $0.bridgeID })

    let calendar = Calendar.current
    let totalMinutes = calendar.dateComponents([.minute], from: startDate, to: endDate).minute ?? 0
    var processedMinutes = 0
    var batchCount = 0
    let batchSize = 50  // Batch size for saving

    print("🔄 [INFO] Starting data population: \(totalMinutes) minutes to process")

    var currentDate = startDate
    while currentDate < endDate {
      for bridgeID in bridgeIDs {
        let bridgeEvents = events.filter { $0.bridgeID == bridgeID }

        if let tick = makeProbeTick(for: bridgeID, at: currentDate, from: bridgeEvents) {
          context.insert(tick)
          batchCount += 1

          if batchCount >= batchSize {
            try context.save()
            batchCount = 0
          }
        }
      }

      currentDate = calendar.date(byAdding: .minute, value: 1, to: currentDate) ?? currentDate
      processedMinutes += 1

      if processedMinutes % 100 == 0 {
        let progress = Double(processedMinutes) / Double(totalMinutes) * 100
        print(
          "🔄 [INFO] Data population progress: \(Int(progress))% (\(processedMinutes)/\(totalMinutes) minutes)"
        )
      }
    }

    if batchCount > 0 {
      try context.save()
    }

    print("✅ [INFO] Data population completed: \(processedMinutes) minutes processed")
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
}
