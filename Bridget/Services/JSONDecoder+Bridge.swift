//
//  JSONDecoder+Bridge.swift
//  Bridget
//
//  Centralized JSONDecoder factory for consistent decoding configuration across the app.
//
//  Usage: JSONDecoder.bridgeDecoder()
//

import Foundation

#if TEST_LOGGING
  let defaultParser: DateParser = LoggingDateParser()
#else
  let defaultParser: DateParser = DefaultDateParser()
#endif

protocol DateParser {
  func parse(_ string: String) -> Date?
}

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
  /// - Ensures consistent key decoding and robust date decoding with fallback.
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
