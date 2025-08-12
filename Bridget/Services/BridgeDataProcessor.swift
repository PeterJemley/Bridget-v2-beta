//
//  BridgeDataProcessor.swift
//  Bridget
//
//  Purpose: Processes raw bridge data and transforms it into BridgeStatusModel instances
//  Dependencies: Foundation (JSONDecoder, DateFormatter), BridgeStatusModel
//  Integration Points:
//    - Decodes JSON data from Seattle Open Data API using centralized decoder factory
//    - Validates business rules and data integrity
//    - Groups records by bridge ID and maps to BridgeStatusModel
//    - Called by BridgeDataService for data processing
//

import Foundation

// MARK: - BridgeID Enum

/// Represents the stable set of known Seattle drawbridge IDs as provided by the city's open data API.
///
/// This enum contains all valid bridge IDs recognized by the Bridget app. The set is considered stable—update only
/// when actual bridges are added or removed from the API dataset. Using this enum throughout the codebase ensures
/// safe ID referencing and robust validation.
///
/// - Note: All bridge ID validation, mapping, and reference logic should use this enum for safety and consistency.
///
/// ## Topics
/// - ID validation and mapping
/// - Business logic referencing
/// - UI display of bridge names
///
/// ### Discussion
/// Referencing bridge IDs using this enum improves data quality, reduces typos, and simplifies future migrations or
/// maintenance. If a new bridge is added, update this enum and related logic accordingly.
enum BridgeID: String, CaseIterable, Equatable {
  case firstAveSouth = "1"
  case ballard = "2"
  case fremont = "3"
  case montlake = "4"
  case lowerSpokane = "6"
  case university = "21"
  case southPark = "29"

  /// All known IDs as a Set (for efficient lookup)
  static var allIDs: Set<String> {
    Set(allCases.map { $0.rawValue })
  }
}

// MARK: - ValidationFailureReason Enum

/// Comprehensive business validation failure reasons for bridge records.
///
/// Used to classify reasons why a given bridge opening record fails validation checks.
///
/// - Note: Use `description` to obtain a user-friendly explanation of the failure.
enum ValidationFailureReason: CustomStringConvertible, Equatable {
  case emptyEntityID
  case emptyEntityName
  case emptyEntityType
  case invalidEntityType(String)
  case unknownBridgeID(String)
  case malformedOpenDate(String)
  case malformedCloseDate(String)
  case outOfRangeOpenDate(Date)
  case closeDateNotAfterOpenDate(open: Date, close: Date)
  case invalidLatitude(Double?)
  case invalidLongitude(Double?)
  case negativeMinutesOpen(Int?)
  case minutesOpenMismatch(reported: Int, actual: Int)

  case malformedLatitude(String)
  case malformedLongitude(String)
  case malformedMinutesOpen(String)

  case geospatialMismatch(expectedLat: Double, expectedLon: Double, actualLat: Double, actualLon: Double)

  /// A descriptive string explaining the validation failure reason.
  var description: String {
    switch self {
    case .emptyEntityID:
      return "Empty entityid"
    case .emptyEntityName:
      return "Empty entityname"
    case .emptyEntityType:
      return "Empty entitytype"
    case let .invalidEntityType(value):
      return "Invalid entitytype: \(value)"
    case let .unknownBridgeID(id):
      return "Unknown bridge ID: \(id)"
    case let .malformedOpenDate(value):
      return "Malformed open date: \(value)"
    case let .malformedCloseDate(value):
      return "Malformed close date: \(value)"
    case let .outOfRangeOpenDate(date):
      return "Open date out of allowed range: \(date)"
    case let .closeDateNotAfterOpenDate(open, close):
      return "Close date (\(close)) is not after open date (\(open))"
    case let .invalidLatitude(value):
      return "Invalid latitude: \(String(describing: value)) (must be between -90 and 90)"
    case let .invalidLongitude(value):
      return "Invalid longitude: \(String(describing: value)) (must be between -180 and 180)"
    case let .negativeMinutesOpen(value):
      return "Negative minutes open: \(String(describing: value))"
    case let .minutesOpenMismatch(reported, actual):
      return "minutesopen mismatch: reported \(reported), actual \(actual) " +
        "(should match the difference between open/close times)"
    case let .malformedLatitude(raw):
      return "Malformed latitude: \(raw) (not a valid number)"
    case let .malformedLongitude(raw):
      return "Malformed longitude: \(raw) (not a valid number)"
    case let .malformedMinutesOpen(raw):
      return "Malformed minutesopen: \(raw) (not a valid number)"
    case let .geospatialMismatch(expectedLat, expectedLon, actualLat, actualLon):
      return "Geospatial mismatch: expected (\(expectedLat), \(expectedLon)), " +
        "got (\(actualLat), \(actualLon)) (too far from known location)"
    }
  }
}

// MARK: - BridgeOpeningRecord Struct

/// A single bridge opening record decoded from JSON data.
///
/// Contains raw string values and computed properties for convenient typed access.
/// Used internally during validation and transformation.
struct BridgeOpeningRecord: Codable {
  let entitytype: String
  let entityname: String
  let entityid: String
  let opendatetime: String
  let closedatetime: String
  let minutesopen: String
  let latitude: String
  let longitude: String

  /// Date formatter for parsing opendatetime and closedatetime strings.
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  /// Parsed open date, or `nil` if the string is malformed.
  var openDate: Date? {
    Self.dateFormatter.date(from: opendatetime)
  }

  /// Parsed close date, or `nil` if the string is malformed.
  var closeDate: Date? {
    Self.dateFormatter.date(from: closedatetime)
  }

  /// Parsed minutes open as integer, or `nil` if the string is malformed.
  var minutesOpenValue: Int? { Int(minutesopen) }

  /// Parsed latitude as double, or `nil` if the string is malformed.
  var latitudeValue: Double? { Double(latitude) }

  /// Parsed longitude as double, or `nil` if the string is malformed.
  var longitudeValue: Double? { Double(longitude) }
}

// MARK: - BridgeDataProcessor Class

/// A singleton service responsible for validating and transforming raw bridge data into app-ready models.
///
/// Handles JSON decoding, business rule validation, aggregation, and comprehensive error reporting for raw bridge opening records.
/// Used by `BridgeDataService` to power historical data loading and validation analytics.
///
/// ## Usage
/// ```swift
/// let (models, failures) = try BridgeDataProcessor.shared.processHistoricalData(data)
/// ```
///
/// ## Topics
/// - Data Processing: `processHistoricalData(_:)`
/// - Validation Rules: `ValidationFailureReason`
/// - Error Reporting: `BridgeDataError`
class BridgeDataProcessor {
  static let shared = BridgeDataProcessor()

  // MARK: - Properties

  /// Known bridge IDs for validation.
  private let knownBridgeIDs = BridgeID.allIDs

  private let bridgeLocations: [String: (lat: Double, lon: Double)] = [
    "1": (47.542213439941406, -122.33446502685547), // 1st Ave South
    "2": (47.65981674194336, -122.37619018554688),  // Ballard
    "3": (47.64760208129883, -122.3497314453125),   // Fremont
    "4": (47.64728546142578, -122.3045883178711),   // Montlake
    "6": (47.57137680053711, -122.35354614257812),  // Lower Spokane St
    "21": (47.652652740478516, -122.32042694091797), // University
    "29": (47.52923583984375, -122.31411743164062),  // South Park
  ]

  private let validEntityTypes = Set(["Bridge"]) // Expand as needed

  // MARK: - Nested Types

  /// Encapsulates a validation failure for a specific bridge opening record.
  struct ValidationFailure {
    /// The original record that failed validation.
    let record: BridgeOpeningRecord
    /// The reason for validation failure.
    let reason: ValidationFailureReason
  }

  // MARK: - Initializer

  private init() {}

  // MARK: - Validation

  /// Validates a single `BridgeOpeningRecord` and returns the first encountered validation failure reason, or nil if the record is valid.
  ///
  /// - Parameter record: The record to validate.
  /// - Returns: An optional `ValidationFailureReason` indicating why the record is invalid, or nil if it is valid.
  func validationFailureReason(for record: BridgeOpeningRecord) -> ValidationFailureReason? {
    guard !record.entityid.isEmpty else {
      return .emptyEntityID
    }
    guard !record.entityname.isEmpty else {
      return .emptyEntityName
    }
    guard let _ = BridgeID(rawValue: record.entityid) else {
      return .unknownBridgeID(record.entityid)
    }
    guard let openDate = record.openDate else {
      return .malformedOpenDate(record.opendatetime)
    }
    let now = Date()
    let calendar = Calendar.current
    let minDate = calendar.date(byAdding: .year, value: -10, to: now) ?? now
    let maxDate = calendar.date(byAdding: .year, value: 1, to: now) ?? now
    if openDate < minDate || openDate > maxDate {
      return .outOfRangeOpenDate(openDate)
    }
    guard let closeDate = record.closeDate else {
      return .malformedCloseDate(record.closedatetime)
    }
    if closeDate <= openDate {
      return .closeDateNotAfterOpenDate(open: openDate, close: closeDate)
    }
    guard let lat = record.latitudeValue, lat >= -90, lat <= 90 else {
      return .invalidLatitude(record.latitudeValue)
    }
    guard let lon = record.longitudeValue, lon >= -180, lon <= 180 else {
      return .invalidLongitude(record.longitudeValue)
    }
    guard let minutesOpen = record.minutesOpenValue, minutesOpen >= 0 else {
      return .negativeMinutesOpen(record.minutesOpenValue)
    }
    let actualMinutes = Int(closeDate.timeIntervalSince(openDate) / 60)
    if abs(minutesOpen - actualMinutes) > 1 {
      return .minutesOpenMismatch(reported: minutesOpen, actual: actualMinutes)
    }
    // Geospatial mismatch check (if bridgeLocations applies)
    if let expected = bridgeLocations[record.entityid], abs(expected.lat - lat) > 0.001 || abs(expected.lon - lon) > 0.001 {
      return .geospatialMismatch(expectedLat: expected.lat, expectedLon: expected.lon, actualLat: lat, actualLon: lon)
    }
    return nil
  }

  // MARK: - Data Processing

  /// Processes raw JSON data into bridge status models and collects all failed validations.
  ///
  /// - Parameter data: Raw JSON data from the Seattle Open Data API.
  /// - Returns: A tuple containing two elements: an array of validated `BridgeStatusModel` instances and an array of `ValidationFailure` detailing the reasons why specific records were rejected.
  /// - Throws: `BridgeDataError` in case of JSON decoding failures or fatal processing errors.
  func processHistoricalData(_ data: Data) throws -> ([BridgeStatusModel], [ValidationFailure]) {
    var failures: [ValidationFailure] = []
    var validRecords: [BridgeOpeningRecord] = []
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .useDefaultKeys
    do {
      let records = try decoder.decode([BridgeOpeningRecord].self, from: data)
      for record in records {
        guard !record.entityid.isEmpty else {
          failures.append(ValidationFailure(record: record, reason: .emptyEntityID))
          continue
        }
        guard !record.entityname.isEmpty else {
          failures.append(ValidationFailure(record: record, reason: .emptyEntityName))
          continue
        }
        guard let _ = BridgeID(rawValue: record.entityid) else {
          failures.append(ValidationFailure(record: record, reason: .unknownBridgeID(record.entityid)))
          continue
        }
        guard let openDate = record.openDate else {
          failures.append(ValidationFailure(record: record, reason: .malformedOpenDate(record.opendatetime)))
          continue
        }
        let now = Date()
        let calendar = Calendar.current
        let minDate = calendar.date(byAdding: .year, value: -10, to: now) ?? now
        let maxDate = calendar.date(byAdding: .year, value: 1, to: now) ?? now
        if openDate < minDate || openDate > maxDate {
          failures.append(ValidationFailure(record: record, reason: .outOfRangeOpenDate(openDate)))
          continue
        }
        guard let closeDate = record.closeDate else {
          failures.append(ValidationFailure(record: record, reason: .malformedCloseDate(record.closedatetime)))
          continue
        }
        if closeDate <= openDate {
          failures.append(ValidationFailure(record: record, reason: .closeDateNotAfterOpenDate(open: openDate, close: closeDate)))
          continue
        }
        guard let lat = record.latitudeValue, lat >= -90, lat <= 90 else {
          failures.append(ValidationFailure(record: record, reason: .invalidLatitude(record.latitudeValue)))
          continue
        }
        guard let lon = record.longitudeValue, lon >= -180, lon <= 180 else {
          failures.append(ValidationFailure(record: record, reason: .invalidLongitude(record.longitudeValue)))
          continue
        }
        guard let minutesOpen = record.minutesOpenValue, minutesOpen >= 0 else {
          failures.append(ValidationFailure(record: record, reason: .negativeMinutesOpen(record.minutesOpenValue)))
          continue
        }
        let actualMinutes = Int(closeDate.timeIntervalSince(openDate) / 60)
        if abs(minutesOpen - actualMinutes) > 1 {
          failures.append(ValidationFailure(record: record, reason: .minutesOpenMismatch(reported: minutesOpen, actual: actualMinutes)))
          continue
        }
        validRecords.append(record)
      }
    } catch let err as DecodingError {
      throw BridgeDataError.decodingError(err, rawData: data)
    } catch {
      throw BridgeDataError.processingError("Unknown error: \(error)")
    }
    var modelMap = [String: (name: String, openings: [Date])]()
    for record in validRecords {
      guard !record.entityid.isEmpty, !record.entityname.isEmpty, let openDate = record.openDate else { continue }
      modelMap[record.entityid, default: (record.entityname, [])].openings.append(openDate)
    }
    let models: [BridgeStatusModel] = modelMap.compactMap { id, val in
      guard let bridgeID = BridgeID(rawValue: id), !val.name.isEmpty else { return nil }
      let sortedOpenings = val.openings.sorted()
      return BridgeStatusModel(bridgeName: val.name, apiBridgeID: bridgeID, historicalOpenings: sortedOpenings)
    }
    return (models, failures)
  }
}
