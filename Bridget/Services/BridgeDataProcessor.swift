//
//  BridgeDataProcessor.swift
//  Bridget
//
//  Purpose: Processes raw bridge data and transforms it into BridgeStatusModel instances
//  Dependencies: Foundation (JSONDecoder, DateFormatter), BridgeStatusModel
//  Integration Points:
//    - Decodes JSON data from Seattle Open Data API
//    - Validates business rules and data integrity
//    - Groups records by bridge ID and maps to BridgeStatusModel
//    - Called by BridgeDataService for data processing
//

import Foundation

// MARK: - Data Models for JSON Decoding

struct BridgeOpeningRecord: Codable {
  let entitytype: String
  let entityname: String
  let entityid: String
  let opendatetime: String
  let closedatetime: String
  let minutesopen: String
  let latitude: String
  let longitude: String

  // Computed properties for parsed values
  var openDate: Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    return formatter.date(from: opendatetime)
  }

  var closeDate: Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    return formatter.date(from: closedatetime)
  }

  var minutesOpenValue: Int? { Int(minutesopen) }
  var latitudeValue: Double? { Double(latitude) }
  var longitudeValue: Double? { Double(longitude) }
}

// MARK: - Bridge Data Processor

class BridgeDataProcessor {
  static let shared = BridgeDataProcessor()

  // MARK: - Configuration

  /// Known bridge IDs for validation
  private let knownBridgeIDs = Set([
    "1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
  ])

  private init() {}

  // MARK: - Data Processing

  /// Processes raw JSON data and converts it to BridgeStatusModel instances
  ///
  /// This method handles the complete data processing pipeline:
  /// 1. **JSON Decoding**: Decodes raw JSON data into BridgeOpeningRecord instances
  /// 2. **Business Validation**: Filters out invalid records based on business rules
  /// 3. **Data Grouping**: Groups records by bridge ID for aggregation
  /// 4. **Model Creation**: Creates BridgeStatusModel instances from grouped data
  ///
  /// - Parameter data: Raw JSON data from the API
  /// - Returns: Array of BridgeStatusModel instances
  /// - Throws: BridgeDataError for processing failures
  func processHistoricalData(_ data: Data) throws -> [BridgeStatusModel] {
    // Centralized JSON decoder configuration
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601

    // Wrap and classify decoding errors for better diagnostics
    let bridgeRecords: [BridgeOpeningRecord]
    do {
      bridgeRecords = try decoder.decode([BridgeOpeningRecord].self,
                                         from: data)
    } catch let decodingError as DecodingError {
      #if DEBUG
        print("Decoding failed with error:", decodingError)
        if let jsonString = String(data: data, encoding: .utf8) {
          print("Payload was:", jsonString)
        }
      #endif
      throw BridgeDataError.decodingError(decodingError, rawData: data)
    }

    // Post-decode business validation with enhanced filtering
    let validRecords = validateAndFilterRecords(bridgeRecords)

    // Group records by bridge ID
    let groupedRecords = Dictionary(grouping: validRecords) { $0.entityid }

    // Convert to BridgeStatusModel instances
    return createBridgeModels(from: groupedRecords)
  }

  // MARK: - Record Validation and Filtering

  private func validateAndFilterRecords(_ records: [BridgeOpeningRecord]) -> [BridgeOpeningRecord] {
    var validRecords: [BridgeOpeningRecord] = []
    var skippedCount = 0

    for record in records {
      if !isValidRecord(record) {
        skippedCount += 1
        continue
      }
      validRecords.append(record)
    }

    #if DEBUG
      if skippedCount > 0 {
        print("Filtered out \(skippedCount) invalid records from \(records.count) total")
      }
    #endif

    return validRecords
  }

  private func isValidRecord(_ record: BridgeOpeningRecord) -> Bool {
    // Validate required fields
    guard !record.entityid.isEmpty, !record.entityname.isEmpty else {
      #if DEBUG
        print("Skipping record with empty fields: \(record)")
      #endif
      return false
    }

    // Validate bridge ID is known
    guard knownBridgeIDs.contains(record.entityid) else {
      #if DEBUG
        print("Skipping unknown bridge ID: \(record.entityid)")
      #endif
      return false
    }

    // Validate date parsing
    guard let openDate = record.openDate else {
      #if DEBUG
        print("Skipping record with invalid date: \(record.opendatetime)")
      #endif
      return false
    }

    // Validate date is reasonable (not too old or future)
    let calendar = Calendar.current
    let now = Date()
    let minDate = calendar.date(byAdding: .year, value: -10, to: now) ?? now
    let maxDate = calendar.date(byAdding: .year, value: 1, to: now) ?? now

    guard openDate >= minDate && openDate <= maxDate else {
      #if DEBUG
        print("Skipping record with out-of-range date: \(openDate)")
      #endif
      return false
    }

    return true
  }

  // MARK: - Bridge Model Creation

  private func createBridgeModels(from groupedRecords: [String: [BridgeOpeningRecord]]) -> [BridgeStatusModel] {
    var bridgeModels: [BridgeStatusModel] = []

    for (_, records) in groupedRecords {
      let openings = records.compactMap { record -> Date? in
        return record.openDate
      }

      // Use the first record's entityname as the bridge name
      let bridgeName = records.first?.entityname ?? "Unknown Bridge"

      let bridgeModel = BridgeStatusModel(bridgeID: bridgeName,
                                          historicalOpenings: openings.sorted())

      bridgeModels.append(bridgeModel)
    }

    return bridgeModels
  }
}

// MARK: - Bridge Data Error Types

enum BridgeDataError: Error, LocalizedError {
  case decodingError(DecodingError, rawData: Data)
  case processingError(String)

  var errorDescription: String? {
    switch self {
    case let .decodingError(error, _):
      return "JSON decoding failed: \(error.localizedDescription)"
    case let .processingError(message):
      return "Data processing error: \(message)"
    }
  }
}
