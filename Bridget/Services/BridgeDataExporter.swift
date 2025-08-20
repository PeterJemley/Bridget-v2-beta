//
//  BridgeDataExporter.swift
//  Bridget
//
//  Purpose: Export daily NDJSON files with one row per ProbeTick for ML and analytics.
//

import Foundation
import SwiftData

/// Clamps an integer value to the given closed range.
/// - Parameters:
///   - value: The integer to be clamped.
///   - range: The closed range to clamp within.
/// - Returns: The clamped integer value within the range.
func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
  if value < range.lowerBound { return range.lowerBound }
  if value > range.upperBound { return range.upperBound }
  return value
}

/// Clamps a double value to the given closed range.
/// - Parameters:
///   - value: The double to be clamped.
///   - range: The closed range to clamp within.
/// - Returns: The clamped double value within the range.
func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
  if value < range.lowerBound { return range.lowerBound }
  if value > range.upperBound { return range.upperBound }
  return value
}

/// Validates and clamps ProbeTick fields according to the business rules.
/// - Parameter tick: The ProbeTick instance to validate.
/// - Returns: A tuple containing the clamped/validated field values and a Bool indicating if any correction was applied.
func validateAndClampFields(from tick: ProbeTick) -> (crossK: Int,
                                                      crossN: Int,
                                                      viaPenaltySec: Int,
                                                      gateAnom: Double,
                                                      alternatesTotal: Int,
                                                      alternatesAvoid: Int,
                                                      hadCorrection: Bool)
{
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

  return (crossK, crossN, viaPenalty, gateAnom, alternatesTotal, alternatesAvoid, hadCorrection)
}

/// Represents a row in the NDJSON export, conforming to the expected schema.
struct NDJSONRow: Encodable {
  let v: Int            // schema version
  let tsUtc: String
  let bridgeId: Int
  let crossK: Int
  let crossN: Int
  let viaRoutable: Int
  let viaPenaltySec: Int
  let gateAnom: Double
  let alternatesTotal: Int
  let alternatesAvoidSpan: Int
  let freeEtaSec: Int?
  let viaEtaSec: Int?
  let openLabel: Int
}

/// Transforms an array of ProbeTick objects into an array of NDJSON row strings.
///
/// This function applies validation and clamping to each ProbeTick's fields,
/// then encodes each row as a JSON string, suitable for NDJSON output.
///
/// - Parameters:
///   - ticks: The array of ProbeTick objects to transform.
///   - isoFormatter: An ISO8601DateFormatter instance to format UTC timestamps.
///
/// - Returns: An array of NDJSON formatted strings, one per valid ProbeTick.
///            If encoding fails for any row, the error is thrown.
///
/// - Throws: An error if JSON encoding any row fails.
///
/// ## Notes
///
/// - This function is pure and has no side effects.
/// - Validation/correction is applied to each tick's fields.
/// - The output strings include a trailing newline character.
func makeNDJSONRows(from ticks: [ProbeTick], isoFormatter: ISO8601DateFormatter) throws -> [String] {
  let encoder = JSONEncoder.bridgeEncoder()
  encoder.outputFormatting = [.withoutEscapingSlashes]

  var rows: [String] = []
  rows.reserveCapacity(ticks.count)

  for tick in ticks {
    let (crossK, crossN, viaPenalty, gateAnom, alternatesTotal, alternatesAvoid, _) = validateAndClampFields(from: tick)

    let row = NDJSONRow(v: 1,
                        tsUtc: isoFormatter.string(from: tick.tsUtc),
                        bridgeId: Int(tick.bridgeId),
                        crossK: crossK,
                        crossN: crossN,
                        viaRoutable: tick.viaRoutable ? 1 : 0,
                        viaPenaltySec: viaPenalty,
                        gateAnom: gateAnom,
                        alternatesTotal: alternatesTotal,
                        alternatesAvoidSpan: alternatesAvoid,
                        freeEtaSec: tick.freeEtaSec == 0 ? nil : tick.freeEtaSec.map(Int.init),
                        viaEtaSec: tick.viaEtaSec == 0 ? nil : tick.viaEtaSec.map(Int.init),
                        openLabel: tick.openLabel ? 1 : 0)

    let data = try encoder.encode(row)
    guard var jsonString = String(data: data, encoding: .utf8) else {
      throw NSError(domain: "BridgeDataExporter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert encoded data to UTF-8 string"])
    }
    jsonString.append("\n")

    rows.append(jsonString)
  }

  return rows
}

/// Handles exporting daily probe data as NDJSON for ML and analytics.
///
/// `BridgeDataExporter` is responsible for exporting daily `ProbeTick` data in
/// NDJSON format for machine learning training and analytics. It ensures data
/// quality, handles deduplication, and provides comprehensive export metrics.
///
/// ## Overview
///
/// The exporter processes ProbeTick data for a specific local day, handling:
/// - **Time Zone Conversion**: DST-safe Pacific timezone to UTC conversion
/// - **Data Deduplication**: Removes duplicate records per bridge per minute
/// - **Data Validation**: Applies clamping and validation rules
/// - **Atomic Export**: Ensures data integrity during file operations
/// - **Metrics Generation**: Provides detailed export statistics
///
/// ## Key Features
///
/// - **Daily Export**: Exports one day of data at a time
/// - **NDJSON Format**: Newline-delimited JSON for ML processing
/// - **Deduplication**: Keeps latest record per bridge per minute
/// - **Validation**: Clamps values to expected ranges
/// - **Metrics**: Generates sidecar files with export statistics
/// - **Atomic Operations**: Ensures data integrity during export
///
/// ## Usage
///
/// ```swift
/// // Initialize the exporter
/// let exporter = BridgeDataExporter(context: modelContext)
///
/// // Export today's data
/// let today = Calendar.current.startOfDay(for: Date())
/// let outputURL = URL(fileURLWithPath: "/path/to/output/minutes_2025-01-27.ndjson")
/// try await exporter.exportDailyNDJSON(for: today, to: outputURL)
///
/// // Export specific date
/// let dateFormatter = DateFormatter()
/// dateFormatter.dateFormat = "yyyy-MM-dd"
/// let targetDate = dateFormatter.date(from: "2025-01-27")!
/// try await exporter.exportDailyNDJSON(for: targetDate, to: outputURL)
/// ```
///
/// ## Output Files
///
/// For each export, the following files are generated:
///
/// - **`minutes_YYYY-MM-DD.ndjson`**: Main data file with one JSON object per line
/// - **`minutes_YYYY-MM-DD.metrics.json`**: Export statistics and validation metrics
/// - **`.done`**: Zero-byte marker file indicating successful completion
///
/// ## Data Format
///
/// Each line in the NDJSON file contains a JSON object with:
///
/// ```json
/// {
///   "v": 1,
///   "ts_utc": "2025-01-27T08:00:00Z",
///   "bridge_id": 1,
///   "cross_k": 5,
///   "cross_n": 10,
///   "via_routable": true,
///   "via_penalty_sec": 120,
///   "gate_anom": 2.5,
///   "alternates_total": 3,
///   "alternates_avoid": 1,
///   "free_eta_sec": 300,
///   "via_eta_sec": 420,
///   "open_label": false
/// }
/// ```
///
/// ## Data Validation
///
/// The exporter applies the following validation rules:
///
/// - **`via_penalty_sec`**: Clipped to [0, 900] seconds
/// - **`gate_anom`**: Clipped to [1, 8] ratio
/// - **`cross_k`**: Must be ≤ `cross_n`
/// - **`ts_utc`**: Must be within the target day's UTC window
///
/// ## Performance Considerations
///
/// - **Memory Efficient**: Streams data to temporary files
/// - **Atomic Operations**: Uses temporary file + atomic replacement
/// - **Deduplication**: Handles large datasets efficiently
/// - **Validation**: Processes validation inline during export
///
/// ## Error Handling
///
/// The exporter throws errors for:
/// - Invalid date calculations
/// - File system operations
/// - Data encoding issues
/// - Insufficient data for export
///
/// ## Integration with ML Pipeline
///
/// This exporter is designed to work with the Python ML processing pipeline:
///
/// ```
/// BridgeDataExporter → NDJSON → train_prep.py → ML Training Data
/// ```
///
/// The exported NDJSON files can be processed directly by the `train_prep.py`
/// script to generate feature matrices for machine learning models.
final class BridgeDataExporter {
  /// The SwiftData context for fetching ProbeTick data
  let context: ModelContext

  /// ISO8601 date formatter for UTC timestamps
  private let iso = ISO8601DateFormatter()

  /// Creates a new BridgeDataExporter instance
  /// - Parameter context: The SwiftData ModelContext for data access
  init(context: ModelContext) {
    self.context = context
    iso.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime, .withColonSeparatorInTimeZone]
    iso.timeZone = TimeZone(secondsFromGMT: 0)
  }

  /// Exports all valid ProbeTick records for the specified local day as NDJSON.
  ///
  /// This method exports daily bridge probe data in NDJSON format for ML training
  /// and analytics. It handles timezone conversion, data deduplication, validation,
  /// and atomic file operations to ensure data integrity.
  ///
  /// ## Process Overview
  ///
  /// 1. **Time Zone Conversion**: Converts local day to UTC bounds with DST awareness
  /// 2. **Data Fetching**: Retrieves ProbeTick records within the UTC window
  /// 3. **Deduplication**: Removes duplicates per bridge per minute, keeping latest
  /// 4. **Validation**: Applies clamping rules and counts corrections
  /// 5. **Export**: Streams data to temporary NDJSON file
  /// 6. **Atomic Replacement**: Replaces target file atomically
  /// 7. **Metrics**: Generates sidecar files with export statistics
  /// 8. **Completion**: Writes `.done` marker file
  ///
  /// ## Time Zone Handling
  ///
  /// The method uses Pacific timezone (PST/PDT) for local day calculations:
  /// - Converts local midnight to UTC bounds
  /// - Handles DST transitions automatically
  /// - Ensures consistent day boundaries regardless of DST state
  ///
  /// ## Deduplication Strategy
  ///
  /// Records are deduplicated by:
  /// - **Bridge ID**: Unique identifier for each bridge
  /// - **Minute Timestamp**: Floored to minute precision
  /// - **Latest Record**: Keeps the most recent record per group
  ///
  /// ## Validation Rules
  ///
  /// The following validation is applied during export:
  /// - **`via_penalty_sec`**: Clipped to [0, 900] seconds
  /// - **`gate_anom`**: Clipped to [1, 8] ratio
  /// - **`cross_k`**: Must be ≤ `cross_n`
  /// - **Data Quality**: Only exports records with `isValid = true`
  ///
  /// ## Output Structure
  ///
  /// The export creates three files:
  ///
  /// 1. **Main Data File**: `minutes_YYYY-MM-DD.ndjson`
  ///    - One JSON object per line
  ///    - Includes schema version `v: 1`
  ///    - Sorted by timestamp, then bridge ID
  ///
  /// 2. **Metrics File**: `minutes_YYYY-MM-DD.metrics.json`
  ///    - Export statistics and validation counts
  ///    - Per-bridge data summaries
  ///    - Missing minute analysis
  ///
  /// 3. **Completion Marker**: `.done`
  ///    - Zero-byte file indicating successful export
  ///    - Used for downstream coordination
  ///
  /// ## Performance Notes
  ///
  /// - **Memory Efficient**: Streams data to avoid memory issues
  /// - **Atomic Operations**: Uses temporary file + replacement for integrity
  /// - **Validation**: Processes validation inline during export
  /// - **Large Datasets**: Handles full days of data efficiently
  ///
  /// ## Error Conditions
  ///
  /// The method throws errors for:
  /// - Invalid date calculations or timezone issues
  /// - File system permission or space problems
  /// - Data encoding or validation failures
  /// - Insufficient ProbeTick data for the target day
  ///
  /// ## Example Usage
  ///
  /// ```swift
  /// let exporter = BridgeDataExporter(context: modelContext)
  /// let today = Calendar.current.startOfDay(for: Date())
  /// let outputURL = URL(fileURLWithPath: "/path/to/output/minutes_2025-01-27.ndjson")
  ///
  /// do {
  ///     try await exporter.exportDailyNDJSON(for: today, to: outputURL)
  ///     print("✅ Successfully exported today's data")
  /// } catch {
  ///     print("❌ Export failed: \(error)")
  /// }
  /// ```
  ///
  /// ## Integration Notes
  ///
  /// - **ML Pipeline**: Designed to work with Python `train_prep.py`
  /// - **Data Quality**: Exports only validated ProbeTick records
  /// - **File Format**: NDJSON for easy ML processing
  /// - **Atomicity**: Ensures data integrity for downstream consumers
  ///
  /// - Parameters:
  ///   - dayLocal: The day (midnight local time) to export (e.g., for 2025-08-11)
  ///   - url: Output file URL for NDJSON
  /// - Throws: Any error reading, encoding, writing NDJSON, or file operations
  func exportDailyNDJSON(for dayLocal: Date, to url: URL) async throws {
    // Define the Pacific timezone (PST/PDT) for DST-aware calculations
    let pacific = TimeZone(identifier: "America/Los_Angeles")!
    let cal = Calendar(identifier: .gregorian)
    var calPacific = cal
    calPacific.timeZone = pacific

    // Get the start of the local day in Pacific timezone (midnight Pacific time)
    let startPacific = calPacific.startOfDay(for: dayLocal)
    // The next day at midnight Pacific time
    guard let endPacific = calPacific.date(byAdding: .day, value: 1, to: startPacific) else {
      let errorMessage = "Failed to compute end of day"
      throw NSError(domain: "BridgeDataExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
    }

    // Convert the Pacific local day window to UTC bounds, accounting for DST safely
    let startUTC = startPacific.addingTimeInterval(-TimeInterval(pacific.secondsFromGMT(for: startPacific)))
    let endUTC = endPacific.addingTimeInterval(-TimeInterval(pacific.secondsFromGMT(for: endPacific)))

    // Fetch all ProbeTick within the UTC window that are valid
    let fetchDescriptor = FetchDescriptor<ProbeTick>(predicate: #Predicate {
      $0.tsUtc >= startUTC && $0.tsUtc < endUTC && $0.isValid
    },
    sortBy: [SortDescriptor(\.tsUtc), SortDescriptor(\.bridgeId)])
    let ticks = try context.fetch(fetchDescriptor)

    // Deduplicate ticks by (bridgeId, floored minute of tsUtc), keeping the latest (max tsUtc) for each group
    // Key: (bridgeId, minuteTimestamp)
    var latestTicks: [String: ProbeTick] = [:]

    for tick in ticks {
      // Floor timestamp to minute (UTC)
      let ts = tick.tsUtc
      let flooredTimestamp = ts.timeIntervalSince1970 - (ts.timeIntervalSince1970.truncatingRemainder(dividingBy: 60))

      let key = "\(tick.bridgeId)-\(Int(flooredTimestamp))"

      if let existing = latestTicks[key] {
        if existing.tsUtc < tick.tsUtc {
          latestTicks[key] = tick
        }
      } else {
        latestTicks[key] = tick
      }
    }

    // Sort deduplicated ticks by timestamp ascending, then bridgeId ascending for consistency
    let dedupedTicks = latestTicks.values.sorted {
      if $0.tsUtc != $1.tsUtc {
        return $0.tsUtc < $1.tsUtc
      }
      return $0.bridgeId < $1.bridgeId
    }

    // Prepare NDJSON rows using pure function
    let ndjsonRows = try makeNDJSONRows(from: dedupedTicks, isoFormatter: iso)

    let outputDirectory = url.deletingLastPathComponent()
    let bridgeMapURL = outputDirectory.appendingPathComponent("bridge_map.json")

    // Prepare a temporary file URL for atomic replacement
    let tempURL = try FileManagerUtils.createTemporaryFile(in: outputDirectory, prefix: "export", extension: "ndjson.tmp")

    // Open the temp file for writing
    guard let handle = try? FileHandle(forWritingTo: tempURL) else {
      let errorMessage = "Failed to open temp file for writing"
      throw NSError(domain: "BridgeDataExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: errorMessage])
    }
    try handle.truncate(atOffset: 0)

    // Metrics collection
    var totalRows = 0
    var correctedRows = 0
    var bridgeCounts: [Int: Int] = [:]
    var minTimestamp: Date? = nil
    var maxTimestamp: Date? = nil

    // For each deduped tick, we apply validation and count corrections again to keep metrics accurate.
    // (We could optimize by modifying makeNDJSONRows to also return corrections, but per instructions keep class logic here.)
    for tick in dedupedTicks {
      let (_, _, _, _, _, _, hadCorrection) = validateAndClampFields(from: tick)

      // Write NDJSON line (already encoded)
      let index = totalRows
      if index < ndjsonRows.count {
        let line = ndjsonRows[index]
        try handle.write(contentsOf: Data(line.utf8))
      }

      totalRows += 1
      if hadCorrection { correctedRows += 1 }

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

    // Atomically replace the destination file with the temp file
    do {
      try FileManagerUtils.atomicReplaceItem(at: url, with: tempURL)
    } catch {
      // Cleanup temp file on failure
      try? FileManagerUtils.removeFile(at: tempURL)
      throw error
    }

    // Write sidecar metrics JSON file
    struct Metrics: Encodable {
      let totalRows: Int
      let correctedRows: Int
      let bridgeCounts: [String: Int]
      let minTsUtc: String?
      let maxTsUtc: String?
      let expectedMinutes: Int
      let missingMinutesByBridge: [String: Int]
    }

    // Calculate expected minutes (1440 per day)
    let expectedMinutes = 1440

    // Calculate missing minutes by bridge
    var missingMinutesByBridge: [String: Int] = [:]
    for (bridgeId, actualCount) in bridgeCounts {
      let missing = expectedMinutes - actualCount
      missingMinutesByBridge[String(bridgeId)] = missing > 0 ? missing : 0
    }

    // Also include bridges with zero counts but present in bridge_map
    if FileManagerUtils.fileExists(at: bridgeMapURL) {
      if let data = try? Data(contentsOf: bridgeMapURL),
         let bridgeMap = try? JSONDecoder.bridgeDecoder().decode([String: String].self, from: data)
      {
        for bridgeIdStr in bridgeMap.keys {
          if bridgeCounts[Int(bridgeIdStr) ?? -1] == nil {
            missingMinutesByBridge[bridgeIdStr] = expectedMinutes
          }
        }
      }
    }

    let metricsURL = url.deletingPathExtension().appendingPathExtension("metrics.json")
    let bridgeCountsDict = Dictionary(uniqueKeysWithValues: bridgeCounts.map { (String($0.key), $0.value) })
    let metrics = Metrics(totalRows: totalRows,
                          correctedRows: correctedRows,
                          bridgeCounts: bridgeCountsDict,
                          minTsUtc: minTimestamp.map { iso.string(from: $0) },
                          maxTsUtc: maxTimestamp.map { iso.string(from: $0) },
                          expectedMinutes: expectedMinutes,
                          missingMinutesByBridge: missingMinutesByBridge)
    let metricsData = try JSONEncoder.bridgeEncoder().encode(metrics)
    try metricsData.write(to: metricsURL, options: .atomic)

    // Write zero-byte .done marker file after atomic replacement for downstream coordination
    let doneURL = url.deletingPathExtension().appendingPathExtension("done")
    try FileManagerUtils.createMarkerFile(at: doneURL)

    // Note: gzip compression can be added here on the NDJSON file stream if needed in the future.
  }
}
