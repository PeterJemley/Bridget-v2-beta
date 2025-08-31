// BridgeRecordValidator.swift
// Encapsulates all bridge record validation logic, using ValidationUtils
//
// Created for Bridget app to reduce duplication and centralize business logic

import Foundation

struct BridgeRecordValidator {
  let knownBridgeIDs: Set<String>
  let bridgeLocations: [String: (lat: Double, lon: Double)]

  let minDate: Date
  let maxDate: Date
  let validEntityTypes: Set<String>

  init(knownBridgeIDs: Set<String>,
       bridgeLocations: [String: (lat: Double, lon: Double)],
       validEntityTypes: Set<String>,
       minDate: Date,
       maxDate: Date)
  {
    self.knownBridgeIDs = knownBridgeIDs
    self.bridgeLocations = bridgeLocations
    self.validEntityTypes = validEntityTypes
    self.minDate = minDate
    self.maxDate = maxDate
  }

  /// Returns first validation failure reason, or nil if valid, using ValidationUtils
  func validationFailure(for record: BridgeOpeningRecord)
    -> ValidationFailureReason?
  {
    if !isNotEmpty(record.entityid) {
      return .emptyEntityID
    }
    if !isNotEmpty(record.entityname) {
      return .emptyEntityName
    }
    if !knownBridgeIDs.contains(record.entityid) {
      return .unknownBridgeID(record.entityid)
    }
    guard let openDate = record.openDate else {
      return .malformedOpenDate(record.opendatetime)
    }
    if openDate < minDate || openDate > maxDate {
      return .outOfRangeOpenDate(openDate)
    }
    guard let closeDate = record.closeDate else {
      return .malformedCloseDate(record.closedatetime)
    }
    if closeDate <= openDate {
      return .closeDateNotAfterOpenDate(open: openDate, close: closeDate)
    }
    guard let lat = record.latitudeValue, isInRange(lat, -90.0 ... 90.0)
    else {
      return .invalidLatitude(record.latitudeValue)
    }
    guard let lon = record.longitudeValue, isInRange(lon, -180.0 ... 180.0)
    else {
      return .invalidLongitude(record.longitudeValue)
    }
    guard let minutesOpen = record.minutesOpenValue, minutesOpen >= 0 else {
      return .negativeMinutesOpen(record.minutesOpenValue)
    }
    let actualMinutes = Int(closeDate.timeIntervalSince(openDate) / 60)
    if abs(minutesOpen - actualMinutes) > 1 {
      return .minutesOpenMismatch(reported: minutesOpen,
                                  actual: actualMinutes)
    }
    if let expected = bridgeLocations[record.entityid] {
      let latDiff = abs(expected.lat - lat)
      let lonDiff = abs(expected.lon - lon)

      if latDiff > 0.01 || lonDiff > 0.01 {
        return .geospatialMismatch(expectedLat: expected.lat,
                                   expectedLon: expected.lon,
                                   actualLat: lat,
                                   actualLon: lon)
      } else if latDiff > 0.001 || lonDiff > 0.001 {
        // Log when coordinates are close but within tolerance (for debugging)
        print(
          "📍 Bridge \(record.entityid) coordinates close but accepted: expected (\(expected.lat), \(expected.lon)), got (\(lat), \(lon)) - diff: lat \(latDiff), lon \(lonDiff)"
        )
      }
    }
    return nil
  }
}
