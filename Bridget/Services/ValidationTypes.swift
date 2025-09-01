// ValidationTypes.swift
// Shared validation types, error enums, and helpers for Bridget ML pipeline and tests.

import Foundation

/// A single bridge opening record decoded from JSON data.
///
/// Contains raw string values and computed properties for convenient typed access.
/// Used internally during validation and transformation.
public struct BridgeOpeningRecord: Codable, Equatable {
    public let entitytype: String
    public let entityname: String
    public let entityid: String
    public let opendatetime: String
    public let closedatetime: String
    public let minutesopen: String
    public let latitude: String
    public let longitude: String

    /// Date formatter for parsing opendatetime and closedatetime strings.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Parsed open date, or `nil` if the string is malformed.
    public var openDate: Date? {
        Self.dateFormatter.date(from: opendatetime)
    }

    /// Parsed close date, or `nil` if the string is malformed.
    public var closeDate: Date? {
        Self.dateFormatter.date(from: closedatetime)
    }

    /// Parsed minutes open as integer, or `nil` if the string is malformed.
    public var minutesOpenValue: Int? { Int(minutesopen) }

    /// Parsed latitude as double, or `nil` if the string is malformed.
    public var latitudeValue: Double? { Double(latitude) }

    /// Parsed longitude as double, or `nil` if the string is malformed.
    public var longitudeValue: Double? { Double(longitude) }
}

/// A validation failure containing the record that failed validation and the reason.
public struct ValidationFailure: Equatable {
    /// The record that failed validation.
    public let record: BridgeOpeningRecord
    /// The reason for validation failure.
    public let reason: ValidationFailureReason

    public init(record: BridgeOpeningRecord, reason: ValidationFailureReason) {
        self.record = record
        self.reason = reason
    }
}

/// Comprehensive business validation failure reasons for bridge records.
public enum ValidationFailureReason: CustomStringConvertible, Equatable,
    Hashable
{
    case emptyEntityID
    case emptyEntityName
    case emptyEntityType
    case invalidEntityType(String)
    case unknownBridgeID(String)
    case malformedOpenDate(String)
    case outOfRangeOpenDate(Date)
    case malformedCloseDate(String)
    case outOfRangeCloseDate(Date)
    case closeDateNotAfterOpenDate(open: Date, close: Date)
    case invalidLatitude(Double?)
    case invalidLongitude(Double?)
    case negativeMinutesOpen(Int?)
    case minutesOpenMismatch(reported: Int, actual: Int)
    case malformedLatitude(String)
    case malformedLongitude(String)
    case malformedMinutesOpen(String)
    case geospatialMismatch(
        expectedLat: Double,
        expectedLon: Double,
        actualLat: Double,
        actualLon: Double
    )
    case missingRequiredField(String)
    case duplicateRecord
    case other(String)

    public var description: String {
        switch self {
        case .emptyEntityID:
            return "Empty entityid"
        case .emptyEntityName:
            return "Empty entityname"
        case .emptyEntityType:
            return "Empty entitytype"
        case .invalidEntityType(let value):
            return "Invalid entitytype: \(value)"
        case .unknownBridgeID(let id):
            return "Unknown bridge ID: \(id)"
        case .malformedOpenDate(let value):
            return "Malformed open date: \(value)"
        case .outOfRangeOpenDate(let date):
            return "Open date out of allowed range: \(date)"
        case .malformedCloseDate(let value):
            return "Malformed close date: \(value)"
        case .outOfRangeCloseDate(let date):
            return "Close date out of allowed range: \(date)"
        case .closeDateNotAfterOpenDate(let open, let close):
            return "Close date (\(close)) is not after open date (\(open))"
        case .invalidLatitude(let value):
            return
                "Invalid latitude: \(String(describing: value)) (must be between -90 and 90)"
        case .invalidLongitude(let value):
            return
                "Invalid longitude: \(String(describing: value)) (must be between -180 and 180)"
        case .negativeMinutesOpen(let value):
            return "Negative minutes open: \(String(describing: value))"
        case .minutesOpenMismatch(let reported, let actual):
            return
                "minutesopen mismatch: reported \(reported), actual \(actual) "
                + "(should match the difference between open/close times)"
        case .malformedLatitude(let raw):
            return "Malformed latitude: \(raw) (not a valid number)"
        case .malformedLongitude(let raw):
            return "Malformed longitude: \(raw) (not a valid number)"
        case .malformedMinutesOpen(let raw):
            return "Malformed minutesopen: \(raw) (not a valid number)"
        case .geospatialMismatch(
            let expectedLat,
            let
                expectedLon,
            let
                actualLat,
            let
                actualLon
        ):
            return
                "Geospatial mismatch: expected (\(expectedLat), \(expectedLon)), "
                + "got (\(actualLat), \(actualLon)) (too far from known location)"
        case .missingRequiredField(let name):
            return "Missing required field: \(name)"
        case .duplicateRecord:
            return "Duplicate record detected"
        case .other(let message):
            return message
        }
    }
}

/// Reasons for date validation failures in business logic.
public enum DateValidationError: Error, CustomStringConvertible, Equatable {
    case emptyOrNull
    case invalidFormat(String)
    case valueOutOfRange(String)

    public var description: String {
        switch self {
        case .emptyOrNull: return "Date string is empty or null."
        case .invalidFormat(let str): return "Invalid date format: \(str)"
        case .valueOutOfRange(let message):
            return "Value out of range: \(message)"
        }
    }
}

/// Log level for structured validation logging.
public enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    public var displayName: String { rawValue }
}

/// Context for a date validation error report.
public struct DateValidationContext {
    public var recordID: String?
    public var source: String?
    public var timestamp: Date = .init()
    public var userAction: String? = nil
}

/// Protocol for reporting date validation errors with context and level.
public protocol DateValidationErrorReporter {
    func report(
        _ error: DateValidationError,
        level: LogLevel,
        context: DateValidationContext
    )
}

/// Console reporter for date validation errors.
public struct ConsoleDateValidationErrorReporter: DateValidationErrorReporter {
    public func report(
        _ error: DateValidationError,
        level: LogLevel,
        context: DateValidationContext
    ) {
        let id = context.recordID.map { "RecordID: \($0)" } ?? "RecordID: N/A"
        let src = context.source ?? ""
        let ts = ISO8601DateFormatter().string(from: context.timestamp)
        let suggestion: String = {
            switch error {
            case .emptyOrNull:
                return "Suggestion: Ensure the date string is not missing."
            case .invalidFormat:
                return
                    "Suggestion: Check that the date matches supported formats."
            case .valueOutOfRange:
                return "Suggestion: Ensure the date is within a valid range."
            }
        }()
        print(
            "[\(level.displayName)] DateValidationError: \(error) \(id) Source: \(src) @\(ts)\n  \(suggestion)"
        )
    }
}

/// Stub: File reporter for future use.
public struct FileDateValidationErrorReporter: DateValidationErrorReporter {
    public func report(
        _: DateValidationError,
        level _: LogLevel,
        context _: DateValidationContext
    ) {
        // Stub: Write to file
    }
}

/// Stub: Monitoring reporter for future integration (e.g., Sentry, DataDog).
public struct MonitoringDateValidationErrorReporter: DateValidationErrorReporter
{
    public func report(
        _: DateValidationError,
        level _: LogLevel,
        context _: DateValidationContext
    ) {
        // Stub: Send to monitoring/logging service
    }
}

/// Business validation for date strings.
public enum DateValidator {
    /// Supported date formats (Seattle API and ISO8601 variants):
    /// - yyyy-MM-dd'T'HH:mm:ss.SSS
    /// - yyyy-MM-dd'T'HH:mm:ss
    /// - yyyy-MM-dd'T'HH:mm:ss.SSSZ
    /// - yyyy-MM-dd'T'HH:mm:ssZ
    /// - yyyy-MM-dd'T'HH:mm:ss.SSS±HH:mm
    /// - yyyy-MM-dd'T'HH:mm:ss±HH:mm
    /// ISO8601DateFormatter is also tried for broader compatibility.
    public static let regex =
        #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?([Z]|[+-]\d{2}:\d{2})?$"#

    public static let formatters: [DateFormatter] = {
        let base = Locale(identifier: "en_US_POSIX")
        var result: [DateFormatter] = []
        let fmts = [
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        ]
        for fmt in fmts {
            let f = DateFormatter()
            f.locale = base
            f.dateFormat = fmt
            f.isLenient = false
            f.timeZone = TimeZone(abbreviation: "UTC")
            result.append(f)
        }
        return result
    }()

    public static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        return f
    }()

    /// Validates a date string for emptiness, format, and actual calendar correctness.
    /// Supports Seattle API, ISO8601, and common timezone offset formats.
    public static func validate(_ dateString: String?) -> Result<
        Void, DateValidationError
    > {
        guard let s = dateString,
            !s.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            return .failure(.emptyOrNull)
        }
        guard s.range(of: regex, options: .regularExpression) != nil else {
            return .failure(.invalidFormat(s))
        }

        // Extract year, month, day from input string for validation
        let yearStr = String(s.prefix(4))
        let monthStr = String(s.dropFirst(5).prefix(2))
        let dayStr = String(s.dropFirst(8).prefix(2))

        guard let y = Int(yearStr), let m = Int(monthStr), let d = Int(dayStr)
        else {
            return .failure(.invalidFormat(s))
        }

        // Validate calendar date exists
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d

        guard let date = calendar.date(from: components) else {
            return .failure(.invalidFormat(s))
        }

        // Verify the date components match what we extracted (double-check)
        let extractedComps = calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
        guard
            extractedComps.year == y && extractedComps.month == m
                && extractedComps.day == d
        else {
            return .failure(.invalidFormat(s))
        }

        // Now try to parse the full date string with formatters
        for fmt in formatters {
            if fmt.date(from: s) != nil {
                return .success(())
            }
        }

        // Try ISO8601 fallback
        if iso8601Formatter.date(from: s) != nil {
            return .success(())
        }

        return .failure(.invalidFormat(s))
    }
}
