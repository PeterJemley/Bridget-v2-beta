// Extensions 2.swift
// Canonical shared extensions for core Swift types: Date, Array, String, etc.

import Foundation

// MARK: - Date Extensions

/// Extensions related to `Date` for common date calculations and formatting.
public extension Date {
  /// Returns the Date floored to the nearest minute.
  ///
  /// This property calculates the date by removing the seconds and smaller
  /// components, effectively rounding down the time to the start of the current minute.
  ///
  /// - Returns: A new `Date` instance representing the time at the start of the current minute.
  ///
  /// - Note: The returned date will have zero seconds and fractional seconds.
  var flooredToMinute: Date {
    let time = timeIntervalSince1970
    let floored = time - (time.truncatingRemainder(dividingBy: 60))
    return Date(timeIntervalSince1970: floored)
  }

  /// Returns the number of whole minutes elapsed since another date.
  ///
  /// This method calculates the difference between the receiver and the provided date,
  /// returning the integer number of minutes. Partial minutes are truncated towards zero.
  ///
  /// - Parameter other: The date to compare against.
  /// - Returns: An `Int` representing the number of minutes from `other` to the current date.
  ///
  /// - Note: If `self` is earlier than `other`, the result will be negative.
  func minutes(since other: Date) -> Int {
    return Int(timeIntervalSince(other) / 60)
  }
}

// MARK: - Array Extensions

/// Extensions related to `Array` for safe access and chunking functionality.
public extension Array {
  /// Safely returns the element at the specified index if it exists.
  ///
  /// This subscript returns `nil` instead of crashing if the index is out of bounds.
  ///
  /// - Parameter index: The index of the element to access.
  /// - Returns: The element at the given index if it exists, otherwise `nil`.
  ///
  /// - Note: This is useful for avoiding runtime errors from invalid indices.
  subscript(safe index: Int) -> Element? {
    return (indices.contains(index)) ? self[index] : nil
  }

  /// Splits the array into chunks of the specified size.
  ///
  /// This method partitions the array into subarrays each containing `size` elements,
  /// except possibly the last chunk which may contain fewer if there are not enough elements.
  ///
  /// - Parameter size: The maximum size of each chunk. Must be greater than zero.
  /// - Returns: An array of arrays, where each subarray has up to `size` elements.
  ///
  /// - Note: If `size` is less than or equal to zero, the method returns an empty array.
  func chunked(into size: Int) -> [[Element]] {
    if size <= 0 { return [] }
    return stride(from: 0, to: count, by: size).map { i in
      Array(self[i ..< Swift.min(i + size, count)])
    }
  }
}

// MARK: - String Extensions

/// Extensions related to `String` for trimming and date validation.
extension String {
  /// Returns a copy of the string with whitespace and newline characters trimmed from both ends.
  ///
  /// Leading and trailing whitespace and newline characters are removed.
  ///
  /// - Returns: A new string without leading or trailing whitespace and newlines.
  public var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Returns `true` if the string is a valid ISO8601 date format.
  ///
  /// This property attempts to parse the string using `ISO8601DateFormatter`,
  /// accepting both standard internet date-time and fractional seconds variants.
  ///
  /// - Returns: `true` if the string can be converted to a `Date` using ISO8601 format, otherwise `false`.
  ///
  /// - Note: This does not guarantee the string is a complete ISO8601 date, but that it can be parsed by the formatter.
  public var isISO8601Date: Bool {
    if String.iso8601WithFractionalSeconds.date(from: self) != nil {
      return true
    }
    if String.iso8601InternetDateTime.date(from: self) != nil {
      return true
    }
    return false
  }

  // Cached formatters for performance and to cover both formats
  private static let iso8601InternetDateTime: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [
      .withInternetDateTime, .withColonSeparatorInTimeZone,
    ]
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
  }()

  private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [
      .withInternetDateTime, .withFractionalSeconds,
      .withColonSeparatorInTimeZone,
    ]
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
  }()
}
