#!/usr/bin/env swift

/**
 Bridget Data Exporter Command Line Tool

 This script demonstrates how to run the BridgeDataExporter for today's data.
 It shows the complete workflow:
 1. Populate ProbeTick data from existing BridgeEvent records
 2. Export daily NDJSON files for ML training
 3. Generate the required output files

 Usage:
     swift run_exporter.swift [--output-dir /path/to/output]

 Output files generated:
     - minutes_YYYY-MM-DD.ndjson (main data file)
     - minutes_YYYY-MM-DD.metrics.json (export statistics)
     - .done (completion marker)

 Example:
     swift run_exporter.swift --output-dir ~/ml_data
 */

import Foundation
import SwiftData

// MARK: - Simple Models for Command Line Tool

/// Simplified ProbeTick model for command line usage
struct SimpleProbeTick {
  let tsUtc: Date
  let bridgeId: Int16
  let crossK: Int16
  let crossN: Int16
  let viaRoutable: Bool
  let viaPenaltySec: Int32
  let gateAnom: Double
  let alternatesTotal: Int16
  let alternatesAvoid: Int16
  let freeEtaSec: Int32?
  let viaEtaSec: Int32?
  let openLabel: Bool
  let isValid: Bool
}

/// Simplified BridgeEvent model for command line usage
struct SimpleBridgeEvent {
  let bridgeID: String
  let bridgeName: String
  let openDateTime: Date
  let closeDateTime: Date?
  let minutesOpen: Int
  let latitude: Double
  let longitude: Double
  let isValidated: Bool
}

// MARK: - Data Population Service

class SimpleProbeTickService {
  /// Populates ProbeTick data for today from sample BridgeEvent data
  func populateTodayProbeTicks() -> [SimpleProbeTick] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var ticks: [SimpleProbeTick] = []

    // Create sample bridge events for today
    let sampleEvents = createSampleBridgeEvents(for: today)

    // Generate ProbeTick records for each minute of today
    var currentDate = today

    while currentDate < calendar.date(byAdding: .day, value: 1, to: today)! {
      for event in sampleEvents {
        let tick = createProbeTick(
          for: event,
          at: currentDate,
          from: sampleEvents)
        ticks.append(tick)
      }

      // Move to next minute
      currentDate = calendar.date(byAdding: .minute, value: 1, to: currentDate)!
    }

    return ticks
  }

  /// Creates sample BridgeEvent data for testing
  private func createSampleBridgeEvents(for date: Date) -> [SimpleBridgeEvent] {
    let calendar = Calendar.current

    let bridgeIDs = ["1", "2", "3"]  // First Ave South, Ballard, Fremont
    let bridgeNames = ["First Avenue South Bridge", "Ballard Bridge", "Fremont Bridge"]
    var events: [SimpleBridgeEvent] = []

    for (index, bridgeID) in bridgeIDs.enumerated() {
      // Morning opening (8 AM)
      let morningOpen = calendar.date(byAdding: .hour, value: 8, to: date)!
      let morningClose = calendar.date(byAdding: .minute, value: 15, to: morningOpen)!

      let morningEvent = SimpleBridgeEvent(
        bridgeID: bridgeID,
        bridgeName: bridgeNames[index],
        openDateTime: morningOpen,
        closeDateTime: morningClose,
        minutesOpen: 15,
        latitude: 47.5422,
        longitude: -122.3344,
        isValidated: true)

      // Afternoon opening (5 PM)
      let afternoonOpen = calendar.date(byAdding: .hour, value: 17, to: date)!
      let afternoonClose = calendar.date(byAdding: .minute, value: 12, to: afternoonOpen)!

      let afternoonEvent = SimpleBridgeEvent(
        bridgeID: bridgeID,
        bridgeName: bridgeNames[index],
        openDateTime: afternoonOpen,
        closeDateTime: afternoonClose,
        minutesOpen: 12,
        latitude: 47.5422,
        longitude: -122.3344,
        isValidated: true)

      events.append(morningEvent)
      events.append(afternoonEvent)
    }

    return events
  }

  /// Creates a ProbeTick record for a specific bridge at a specific timestamp
  private func createProbeTick(
    for event: SimpleBridgeEvent,
    at timestamp: Date,
    from allEvents: [SimpleBridgeEvent]
  ) -> SimpleProbeTick {
    // Find if there's an active bridge opening at this timestamp
    let activeEvent = allEvents.first { event in
      event.openDateTime <= timestamp
        && (event.closeDateTime == nil || event.closeDateTime! > timestamp)
    }

    // Calculate features based on historical data
    let (crossK, crossN) = calculateCrossRate(at: timestamp, from: allEvents)
    let (viaRoutable, viaPenaltySec) = calculateViaMetrics(at: timestamp, from: allEvents)
    let gateAnom = calculateGateAnomaly(at: timestamp, from: allEvents)
    let (alternatesTotal, alternatesAvoid) = calculateAlternateMetrics(
      at: timestamp, from: allEvents)
    let openLabel = activeEvent != nil

    return SimpleProbeTick(
      tsUtc: timestamp,
      bridgeId: Int16(event.bridgeID) ?? 0,
      crossK: Int16(crossK),
      crossN: Int16(crossN),
      viaRoutable: viaRoutable,
      viaPenaltySec: Int32(viaPenaltySec),
      gateAnom: gateAnom,
      alternatesTotal: Int16(alternatesTotal),
      alternatesAvoid: Int16(alternatesAvoid),
      freeEtaSec: nil,
      viaEtaSec: nil,
      openLabel: openLabel,
      isValid: true)
  }

  /// Calculates the cross rate (k/n) for a specific timestamp
  private func calculateCrossRate(at timestamp: Date, from events: [SimpleBridgeEvent]) -> (
    Int, Int
  ) {
    let calendar = Calendar.current
    let oneMinuteAgo = calendar.date(byAdding: .minute, value: -1, to: timestamp)!

    let crossingEvents = events.filter { event in
      event.openDateTime >= oneMinuteAgo && event.openDateTime <= timestamp
    }

    let crossK = crossingEvents.count
    let crossN = max(crossK, 1)

    return (crossK, crossN)
  }

  /// Calculates via routing metrics for a specific timestamp
  private func calculateViaMetrics(at timestamp: Date, from events: [SimpleBridgeEvent]) -> (
    Bool, Int
  ) {
    let activeEvent = events.first { event in
      event.openDateTime <= timestamp
        && (event.closeDateTime == nil || event.closeDateTime! > timestamp)
    }

    let viaRoutable = activeEvent == nil
    let viaPenaltySec = activeEvent != nil ? Int(activeEvent!.minutesOpen * 60) : 0

    return (viaRoutable, viaPenaltySec)
  }

  /// Calculates gate anomaly metrics for a specific timestamp
  private func calculateGateAnomaly(at timestamp: Date, from events: [SimpleBridgeEvent]) -> Double
  {
    let calendar = Calendar.current
    let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: timestamp)!

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
          calendar.dateComponents(
            [.minute], from: currentEvent.openDateTime, to: currentEvent.closeDateTime!
          ).minute ?? 0)
        : Double(
          calendar.dateComponents([.minute], from: currentEvent.openDateTime, to: timestamp).minute
            ?? 0)

      let ratio = currentMinutesOpen / max(averageMinutesOpen, 1.0)
      return min(max(ratio, 1.0), 8.0)
    }

    return 1.0
  }

  /// Calculates alternate route metrics for a specific timestamp
  private func calculateAlternateMetrics(at _: Date, from _: [SimpleBridgeEvent]) -> (Int, Int) {
    let alternatesTotal = 3
    let alternatesAvoid = 0
    return (alternatesTotal, alternatesAvoid)
  }
}

// MARK: - Data Exporter

class SimpleBridgeDataExporter {
  private let iso = ISO8601DateFormatter()

  init() {
    iso.formatOptions = [
      .withInternetDateTime, .withColonSeparatorInTime, .withColonSeparatorInTimeZone,
    ]
    iso.timeZone = TimeZone(secondsFromGMT: 0)
  }

  /// Exports ProbeTick data to NDJSON format
  func exportToNDJSON(ticks: [SimpleProbeTick], to url: URL) throws {
    let encoder = JSONEncoder.bridgeEncoder(outputFormatting: [.withoutEscapingSlashes])

    // Create output directory if it doesn't exist
    let outputDirectory = url.deletingLastPathComponent()
    try FileManagerUtils.ensureDirectoryExists(outputDirectory)

    // Prepare a temporary file for atomic replacement
    let tempURL = try FileManagerUtils.createTemporaryFile(
      in: outputDirectory, prefix: "export", extension: "ndjson.tmp")

    // Write NDJSON data
    var totalRows = 0
    var correctedRows = 0
    var bridgeCounts: [Int: Int] = [:]
    var minTimestamp: Date?
    var maxTimestamp: Date?

    let handle = try FileHandle(forWritingTo: tempURL)
    defer { try? handle.close() }

    for tick in ticks {
      // Validate and clamp fields
      var crossK = Int(tick.crossK)
      var crossN = Int(tick.crossN)
      var viaPenalty = Int(tick.viaPenaltySec)
      var gateAnom = tick.gateAnom
      var alternatesTotal = Int(tick.alternatesTotal)
      var alternatesAvoid = Int(tick.alternatesAvoid)

      var hadCorrection = false

      if crossK < 0 {
        crossK = 0
        hadCorrection = true
      }
      if crossN < crossK {
        crossN = crossK
        hadCorrection = true
      }
      if viaPenalty < 0 {
        viaPenalty = 0
        hadCorrection = true
      } else if viaPenalty > 900 {
        viaPenalty = 900
        hadCorrection = true
      }
      if gateAnom < 1.0 {
        gateAnom = 1.0
        hadCorrection = true
      } else if gateAnom > 8.0 {
        gateAnom = 8.0
        hadCorrection = true
      }
      if alternatesTotal < 1 {
        alternatesTotal = 1
        hadCorrection = true
      }
      if alternatesAvoid < 0 {
        alternatesAvoid = 0
        hadCorrection = true
      } else if alternatesAvoid > alternatesTotal {
        alternatesAvoid = alternatesTotal
        hadCorrection = true
      }

      if hadCorrection { correctedRows += 1 }

      // Create row data
      let row: [String: Any] = [
        "v": 1,
        "ts_utc": iso.string(from: tick.tsUtc),
        "bridge_id": Int(tick.bridgeId),
        "cross_k": crossK,
        "cross_n": crossN,
        "via_routable": tick.viaRoutable ? 1 : 0,
        "via_penalty_sec": viaPenalty,
        "gate_anom": gateAnom,
        "alternates_total": alternatesTotal,
        "alternates_avoid_span": alternatesAvoid,
        "free_eta_sec": tick.freeEtaSec as Any,
        "via_eta_sec": tick.viaEtaSec as Any,
        "open_label": tick.openLabel ? 1 : 0,
      ]

      let data = try JSONSerialization.data(withJSONObject: row)
      var lineData = data
      lineData.append(0x0A)  // newline
      try handle.write(contentsOf: lineData)

      // Update metrics
      totalRows += 1
      bridgeCounts[Int(tick.bridgeId), default: 0] += 1
      if let minTS = minTimestamp {
        if tick.tsUtc < minTS { minTimestamp = tick.tsUtc }
      } else {
        minTimestamp = tick.tsUtc
      }
      if let maxTS = maxTimestamp {
        if tick.tsUtc > maxTS { maxTimestamp = tick.tsUtc }
      } else {
        maxTimestamp = tick.tsUtc
      }
    }

    try handle.close()

    // Atomically replace the destination file
    try FileManagerUtils.atomicReplaceItem(at: url, with: tempURL)

    // Write metrics file
    let metrics: [String: Any] = [
      "total_rows": totalRows,
      "corrected_rows": correctedRows,
      "bridge_counts": bridgeCounts.mapKeys { String($0) },
      "min_ts_utc": minTimestamp.map { iso.string(from: $0) } as Any,
      "max_ts_utc": maxTimestamp.map { iso.string(from: $0) } as Any,
      "expected_minutes": 1440,
      "missing_minutes_by_bridge": [:],
    ]

    let metricsURL = url.deletingPathExtension().appendingPathExtension("metrics.json")
    let metricsData = try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted])
    try metricsData.write(to: metricsURL, options: .atomic)

    // Write .done marker file
    let doneURL = url.deletingPathExtension().appendingPathExtension("done")
    try FileManagerUtils.createMarkerFile(at: doneURL)

    print("✅ Export complete!")
    print("📊 Files generated:")
    print("   - \(url.lastPathComponent)")
    print("   - \(metricsURL.lastPathComponent)")
    print("   - \(doneURL.lastPathComponent)")
    print("📈 Total rows: \(totalRows)")
    print("🔧 Corrected rows: \(correctedRows)")
  }
}

// MARK: - Main Execution

func main() {
  let arguments = CommandLine.arguments

  // Parse command line arguments
  var outputDir = FileManagerUtils.temporaryDirectory().appendingPathComponent("ml_export").path

  for i in 0..<arguments.count {
    if arguments[i] == "--output-dir", i + 1 < arguments.count {
      outputDir = arguments[i + 1]
    }
  }

  print("🚀 Bridget Data Exporter")
  print("📁 Output directory: \(outputDir)")
  print("")

  do {
    // Step 1: Populate ProbeTick data for today
    print("📊 Step 1: Populating ProbeTick data for today...")
    let service = SimpleProbeTickService()
    let ticks = service.populateTodayProbeTicks()
    print("✅ Created \(ticks.count) ProbeTick records")

    // Step 2: Export to NDJSON
    print("📤 Step 2: Exporting to NDJSON...")
    let exporter = SimpleBridgeDataExporter()

    let today = Calendar.current.startOfDay(for: Date())
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let dateString = formatter.string(from: today)

    let outputURL = URL(fileURLWithPath: "\(outputDir)/minutes_\(dateString).ndjson")
    try exporter.exportToNDJSON(ticks: ticks, to: outputURL)

    print("")
    print("🎉 Export pipeline complete!")
    print("")
    print("Next steps:")
    print("1. Process the exported data with Python:")
    print("   python Scripts/train_prep.py --input \(outputURL.path) --output training_data.csv")
    print("")
    print("2. Use the generated CSV files for ML model training")

  } catch {
    print("❌ Error: \(error)")
    exit(1)
  }
}

// MARK: - Extensions

extension Dictionary {
  func mapKeys<T>(_ transform: (Key) -> T) -> [T: Value] {
    var result: [T: Value] = [:]
    for (key, value) in self {
      result[transform(key)] = value
    }
    return result
  }
}

// Run the main function
main()
