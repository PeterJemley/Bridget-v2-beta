"""
# Validation Failures in Bridge Data Processing

This DocC article documents the data validation failure model used throughout the Bridget app during the processing of bridge opening records. It is not source code and is not meant to be compiled.

**Purpose:**
- To explain the types, reasons, and propagation of validation failures encountered when processing bridge data
- To serve as reference documentation for developers and maintainers

The Swift code and types below are illustrative and document the API surface for validation failures. They help clarify which cases are handled, what error messages are surfaced, and what data structures are used in validation-related APIs.
"""

import Foundation
import CoreLocation

/// Represents a validation failure during processing of bridge opening data.
public struct ValidationFailure {
    /// The raw record that failed validation.
    public let record: BridgeOpeningRawRecord
    /// The specific reason for the validation failure.
    public let reason: ValidationFailureReason
}

/// Enum describing specific reasons a bridge opening record failed validation.
public enum ValidationFailureReason: Error, CustomStringConvertible {
    case missingEntityId
    case missingName
    case missingType
    case unknownBridgeId(String)
    case invalidDate(String)
    case invalidTime(String)
    case invalidLatitude(Double)
    case invalidLongitude(Double)
    case inconsistentCoordinates(latitude: Double, longitude: Double)
    case invalidMinutesOpen(Int)
    case minutesOpenMismatch(expected: Int, actual: Int)
    case jsonDecodingError(Error)
    case unknownError(String)
    
    public var description: String {
        switch self {
        case .missingEntityId:
            return "Missing entity ID"
        case .missingName:
            return "Missing name"
        case .missingType:
            return "Missing type"
        case .unknownBridgeId(let id):
            return "Unknown bridge ID: \(id)"
        case .invalidDate(let dateString):
            return "Invalid date: \(dateString)"
        case .invalidTime(let timeString):
            return "Invalid time: \(timeString)"
        case .invalidLatitude(let lat):
            return "Invalid latitude: \(lat)"
        case .invalidLongitude(let lon):
            return "Invalid longitude: \(lon)"
        case .inconsistentCoordinates(let lat, let lon):
            return "Inconsistent coordinates: latitude \(lat), longitude \(lon)"
        case .invalidMinutesOpen(let mins):
            return "Invalid minutes open: \(mins)"
        case .minutesOpenMismatch(let expected, let actual):
            return "Minutes open mismatch: expected \(expected), got \(actual)"
        case .jsonDecodingError(let error):
            return "JSON decoding error: \(error.localizedDescription)"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

/// Represents a raw bridge opening record received from external sources.
public struct BridgeOpeningRawRecord: Decodable {
    public let entityId: String?
    public let name: String?
    public let type: String?
    public let bridgeId: String?
    public let date: String?
    public let time: String?
    public let latitude: Double?
    public let longitude: Double?
    public let minutesOpen: Int?
    // Other raw fields as needed
    
    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case name
        case type
        case bridgeId = "bridge_id"
        case date
        case time
        case latitude
        case longitude
        case minutesOpen = "minutes_open"
    }
}

/// Represents a fully validated and parsed bridge status model.
public struct BridgeStatusModel {
    public let entityId: String
    public let name: String
    public let type: String
    public let bridgeId: String
    public let dateTime: Date
    public let coordinate: CLLocationCoordinate2D
    public let minutesOpen: Int
}

public enum BridgeDataError: Error {
    case jsonDecodingFailed(Error)
    case unknownError(String)
}

/// Responsible for processing bridge opening data.
public class BridgeDataProcessor {
    
    public static let shared = BridgeDataProcessor()
    
    private let knownBridgeIds: Set<String> = [
        // Preset known bridge identifiers
        "BR123", "BR456", "BR789"
    ]
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private let calendar = Calendar(identifier: .gregorian)
    
    private init() { }
    
    /// Processes historical bridge opening data.
    /// - Parameter data: JSON data containing an array of raw bridge opening records.
    /// - Returns: A tuple containing an array of validated bridge status models and an array of validation failures encountered.
    /// - Throws: `BridgeDataError` if there is a systemic failure such as JSON decoding error.
    public func processHistoricalData(_ data: Data) throws -> (models: [BridgeStatusModel], failures: [ValidationFailure]) {
        var failures: [ValidationFailure] = []
        var validModels: [BridgeStatusModel] = []
        
        let decoder = JSONDecoder()
        let rawRecords: [BridgeOpeningRawRecord]
        do {
            rawRecords = try decoder.decode([BridgeOpeningRawRecord].self, from: data)
        } catch {
            throw BridgeDataError.jsonDecodingFailed(error)
        }
        
        for record in rawRecords {
            if let failure = validateRecord(record) {
                failures.append(failure)
            } else if let model = parseRecord(record) {
                validModels.append(model)
            } else {
                // Defensive fallback if parseRecord returns nil without failure reason
                failures.append(
                    ValidationFailure(record: record, reason: .unknownError("Failed to parse record but no validation failure reason found"))
                )
            }
        }
        
        return (validModels, failures)
    }
    
    private func validateRecord(_ record: BridgeOpeningRawRecord) -> ValidationFailure? {
        // Check for required fields
        guard let entityId = record.entityId, !entityId.isEmpty else {
            return ValidationFailure(record: record, reason: .missingEntityId)
        }
        guard let name = record.name, !name.isEmpty else {
            return ValidationFailure(record: record, reason: .missingName)
        }
        guard let type = record.type, !type.isEmpty else {
            return ValidationFailure(record: record, reason: .missingType)
        }
        // Validate known bridge id if present
        if let bridgeId = record.bridgeId {
            if !knownBridgeIds.contains(bridgeId) {
                return ValidationFailure(record: record, reason: .unknownBridgeId(bridgeId))
            }
        }
        // Validate date
        if let dateString = record.date {
            if dateFormatter.date(from: dateString) == nil {
                return ValidationFailure(record: record, reason: .invalidDate(dateString))
            }
        } else {
            return ValidationFailure(record: record, reason: .invalidDate("nil"))
        }
        // Validate time
        if let timeString = record.time {
            if timeFormatter.date(from: timeString) == nil {
                return ValidationFailure(record: record, reason: .invalidTime(timeString))
            }
        } else {
            return ValidationFailure(record: record, reason: .invalidTime("nil"))
        }
        // Validate latitude and longitude
        if let lat = record.latitude {
            if lat < -90.0 || lat > 90.0 {
                return ValidationFailure(record: record, reason: .invalidLatitude(lat))
            }
        } else {
            return ValidationFailure(record: record, reason: .invalidLatitude(Double.nan))
        }
        if let lon = record.longitude {
            if lon < -180.0 || lon > 180.0 {
                return ValidationFailure(record: record, reason: .invalidLongitude(lon))
            }
        } else {
            return ValidationFailure(record: record, reason: .invalidLongitude(Double.nan))
        }
        // Additional geospatial consistency checks (example: latitude and longitude must not both be zero)
        if let lat = record.latitude, let lon = record.longitude {
            if lat == 0 && lon == 0 {
                return ValidationFailure(record: record, reason: .inconsistentCoordinates(latitude: lat, longitude: lon))
            }
        }
        // Validate minutes open
        if let minutesOpen = record.minutesOpen {
            if minutesOpen < 0 {
                return ValidationFailure(record: record, reason: .invalidMinutesOpen(minutesOpen))
            }
            // Could add logic to compare minutesOpen against date/time difference if applicable
        } else {
            return ValidationFailure(record: record, reason: .invalidMinutesOpen(-1))
        }
        
        return nil
    }
    
    private func parseRecord(_ record: BridgeOpeningRawRecord) -> BridgeStatusModel? {
        guard let entityId = record.entityId,
              let name = record.name,
              let type = record.type,
              let bridgeId = record.bridgeId,
              let dateString = record.date,
              let timeString = record.time,
              let latitude = record.latitude,
              let longitude = record.longitude,
              let minutesOpen = record.minutesOpen else {
            return nil
        }
        
        guard let datePart = dateFormatter.date(from: dateString),
              let timePart = timeFormatter.date(from: timeString) else {
            return nil
        }
        
        // Combine date and time into one Date object
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: datePart)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timePart)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        guard let dateTime = calendar.date(from: combinedComponents) else {
            return nil
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        return BridgeStatusModel(entityId: entityId,
                                 name: name,
                                 type: type,
                                 bridgeId: bridgeId,
                                 dateTime: dateTime,
                                 coordinate: coordinate,
                                 minutesOpen: minutesOpen)
    }
}

# Validation Failures

This document describes how validation failures are handled in the Bridget application.

## Overview

Validation failures occur when bridge opening records don't meet the required business rules. The application uses a centralized validation system to ensure consistency and maintainability.

## Validation Architecture

### Centralized Validation Utilities

The application now uses a centralized validation system to eliminate code duplication and ensure consistent validation patterns:

- **`ValidationUtils`**: Reusable utility functions for common validation patterns
- **`BridgeRecordValidator`**: Business-specific validation logic for bridge records
- **`ValidationTypes`**: Shared data structures for validation results

### Key Components

#### ValidationUtils
Provides reusable functions for common validation patterns:
- String validation (empty checks, trimming)
- Collection validation (emptiness checks)
- Range validation (bounds checking)
- Optional validation (nil checks)
- Date validation (format and range checks)

#### BridgeRecordValidator
Encapsulates all business-specific validation rules for `BridgeOpeningRecord` instances:
- Entity ID validation
- Entity name validation
- Date format validation
- **Coordinate validation with transformation** - Uses coordinate system transformation for accurate validation (500m threshold) with 8km fallback
- Business rule enforcement

## Coordinate Transformation Validation

The application now uses coordinate system transformation to provide accurate geospatial validation instead of tolerance-based acceptance:

### Transformation-Based Validation
- **Primary**: 500m tight threshold using coordinate transformation
- **Fallback**: 8km threshold if transformation fails
- **Accuracy**: Dramatic improvement in validation accuracy (e.g., Bridge 1: 6205m → 42m)

### Implementation Details
- **`CoordinateTransformService`**: Handles coordinate system transformations
- **`BridgeRecordValidator`**: Integrates transformation into validation pipeline
- **Testing**: Comprehensive test suite validates transformation accuracy and performance

For complete implementation details, see <doc:CoordinateTransformationPlan>.

## Validation Failure Types

