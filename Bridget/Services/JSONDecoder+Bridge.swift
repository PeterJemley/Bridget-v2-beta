//
//  JSONDecoder+Bridge.swift
//  Bridget
//
//  Centralized JSONDecoder factory for consistent decoding configuration across the app.
//
//  Usage: JSONDecoder.bridgeDecoder()
//

import Foundation

extension JSONDecoder {
  /// Formatter for Seattle Open Data API dates: "yyyy-MM-dd'T'HH:mm:ss.SSS" (UTC, US_POSIX)
  private static let bridgeDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()

  /// Returns a JSONDecoder configured for the Bridget data pipeline.
  /// - Ensures consistent key decoding and robust date decoding with fallback.
  static func bridgeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let dateString = try container.decode(String.self)

      // Primary format: "yyyy-MM-dd'T'HH:mm:ss.SSS"
      if let date = bridgeDateFormatter.date(from: dateString) {
        return date
      }
      // ISO8601 fallback
      if let date = ISO8601DateFormatter().date(from: dateString) {
        return date
      }
      throw DecodingError.dataCorruptedError(in: container,
                                             debugDescription: "Invalid date format: \(dateString)")
    }
    return decoder
  }
}
