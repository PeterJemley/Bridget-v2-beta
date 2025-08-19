//
//  JSONDecoder+Bridge.swift
//  Bridget
//
//  Centralized JSONDecoder factory for consistent decoding configuration across the app.
//
//  # Project Serialization Policy
//  All JSON encoding/decoding throughout the project MUST use the centralized
//  `bridgeEncoder`/`bridgeDecoder` factories unless a documented exception applies.
//
//  - Ensures all serialization is consistent (dates, keys, formatting).
//  - Callers may optionally override default strategies as needed for special cases.
//  - To extend or change defaults, update this file and audit usages project-wide.
//
//  ## Example Usage
//  ```swift
//  let encoder = JSONEncoder.bridgeEncoder()
//  let decoder = JSONDecoder.bridgeDecoder()
//  ```
//
//  ## Special Cases
//  If a special configuration is required (e.g., key/field remapping, custom date parser), use the relevant parameters. Do not instantiate JSONDecoder directly.
//
//  ## Supported Date Formats
//  - Primary: "yyyy-MM-dd'T'HH:mm:ss.SSS"
//  - Fallback: ISO8601 (e.g., "2025-01-03T10:12:00Z")
//
//  ## See Also
//  - JSONEncoder+Bridge.swift (companion factory)
//  - project-level serialization tests
//

import Foundation

#if TEST_LOGGING
  let defaultParser: DateParser = LoggingDateParser()
#else
  let defaultParser: DateParser = DefaultDateParser()
#endif

// MARK: - Date Parsing Protocols

protocol DateParser {
  func parse(_ string: String) -> Date?
}

// MARK: - Date Parser Implementations

struct DefaultDateParser: DateParser {
  func parse(_ string: String) -> Date? {
    // Primary format: "yyyy-MM-dd'T'HH:mm:ss.SSS"
    if let date = JSONDecoder.bridgeDateFormatter.date(from: string) {
      return date
    }
    // ISO8601 fallback
    return ISO8601DateFormatter().date(from: string)
  }
}

struct LoggingDateParser: DateParser {
  func parse(_ string: String) -> Date? {
    let date = DefaultDateParser().parse(string)
    if date == nil {
      print("Date parse failed for string: \(string)")
    }
    return date
  }
}

// MARK: - JSONDecoder Extensions

extension JSONDecoder {
  /// Formatter for Seattle Open Data API dates: "yyyy-MM-dd'T'HH:mm:ss.SSS" (UTC, US_POSIX)
  static let bridgeDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()

  /// Returns a JSONDecoder configured for the Bridget data pipeline.
  ///
  /// - Parameter dateParser: The date parser implementation. Defaults to the production parser unless TEST_LOGGING is enabled.
  ///
  /// - Ensures consistent key decoding and robust date decoding with fallback to ISO8601.
  /// - Handles both the city’s primary API format and ISO8601 edge cases.
  /// - Use this everywhere in the project unless you must support an exception; document any such cases.
  ///
  /// ## Supported Formats
  /// - "yyyy-MM-dd'T'HH:mm:ss.SSS" (primary)
  /// - ISO8601 fallback (e.g., "2025-01-03T10:12:00Z")
  ///
  /// ## Example
  /// ```swift
  /// let decoder = JSONDecoder.bridgeDecoder()
  /// let model = try decoder.decode(MyModel.self, from: jsonData)
  /// ```
  ///
  /// ## Extending Defaults
  /// To change default decoding strategies or parsing logic, update this factory and audit usage project-wide. See the `Bridge` project policy for guidance.
  static func bridgeDecoder(dateParser: DateParser = defaultParser) -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      if container.decodeNil() {
        throw DecodingError.typeMismatch(Date.self,
                                         DecodingError.Context(codingPath: container.codingPath,
                                                               debugDescription: "Date value was null"))
      }
      let dateString = try container.decode(String.self)
      if let date = dateParser.parse(dateString) {
        return date
      }
      throw DecodingError.dataCorruptedError(in: container,
                                             debugDescription: "Invalid date format: \(dateString)")
    }
    return decoder
  }
}
