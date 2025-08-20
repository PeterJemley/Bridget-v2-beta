//
//  BridgeDataProcessor.swift
//  Bridget
//
//  Purpose: Processes raw bridge data and transforms it into BridgeStatusModel instances
//  Dependencies: Foundation (JSONDecoder, DateFormatter), BridgeStatusModel, ValidationUtils, BridgeRecordValidator
//  Integration Points:
//    - Decodes JSON data from Seattle Open Data API using centralized decoder factory
//    - Validates business rules and data integrity via BridgeRecordValidator
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

// ValidationFailureReason enum moved to ValidationTypes.swift

// MARK: - BridgeDataProcessor Class

/// A singleton service responsible for validating and transforming raw bridge data into app-ready models.
///
/// Handles JSON decoding, business rule validation (via `BridgeRecordValidator`), aggregation, and comprehensive error reporting for raw bridge opening records.
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
/// - Validation Delegation: Utilizes `BridgeRecordValidator` and `ValidationUtils`
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

  private let validator: BridgeRecordValidator

  // MARK: - Initializer

  private init() {
    let now = Date()
    let calendar = Calendar.current
    let minDate = calendar.date(byAdding: .year, value: -10, to: now) ?? now
    let maxDate = calendar.date(byAdding: .year, value: 1, to: now) ?? now
    validator = BridgeRecordValidator(knownBridgeIDs: knownBridgeIDs,
                                      bridgeLocations: bridgeLocations,
                                      validEntityTypes: validEntityTypes,
                                      minDate: minDate,
                                      maxDate: maxDate)
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
    let decoder = JSONDecoder.bridgeDecoder()
    do {
      let records = try decoder.decode([BridgeOpeningRecord].self, from: data)
      for record in records {
        if let reason = validator.validationFailure(for: record) {
          failures.append(ValidationFailure(record: record, reason: reason))
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
      if isNotEmpty(record.entityid), isNotEmpty(record.entityname), record.openDate != nil {
        modelMap[record.entityid, default: (record.entityname, [])].openings.append(record.openDate!)
      }
    }
    let models: [BridgeStatusModel] = modelMap.compactMap { id, val in
      if let bridgeID = BridgeID(rawValue: id), isNotEmpty(val.name) {
        let sortedOpenings = val.openings.sorted()
        return BridgeStatusModel(bridgeName: val.name, apiBridgeID: bridgeID, historicalOpenings: sortedOpenings)
      }
      return nil
    }
    return (models, failures)
  }
}
