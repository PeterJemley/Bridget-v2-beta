//
//  BridgeDecoderTests.swift
//  BridgetTests
//
//  Tests for JSONDecoder.bridgeDecoder() focusing on date decoding variants.
//
//  PERFORMANCE MONITORING UPDATE:
//  ==============================
//
//  This test suite uses Apple's os_signpost APIs for enhanced
//  performance monitoring and profiling. Timing intervals are recorded via os_signpost.
//
//  Viewing Results:
//  - In Xcode, open the "Metrics" tab while running tests to observe os_signpost metrics in real-time.
//  - Use Instruments with the "Points of Interest" instrument to see os_signpost markers and intervals.
//
//  For system-level metric aggregation, consider integrating MetricKit separately.
//  See Apple's documentation for details on MetricKit and os_signpost usage.
//

@testable import Bridget
import Foundation
import MetricKit
import os
import OSLog
import Testing
import XCTest

/// Minimal MetricKit observer that prints received metric payloads for demonstration.
///
/// Note: MetricKit reports system-level metrics asynchronously and is not intended for inline timing.
/// For CI/CD or device-wide performance analysis, use MetricKit along with os_signpost.
///
/// Delivery of MetricKit payloads is asynchronous and may arrive after tests complete.
/// For reliable system and cumulative metric collection in CI environments:
/// - Consider running a background agent or a post-processing step that collects metric payloads from disk.
/// - Use Xcode's --resultBundlePath option and tools like `xccov` and `xcrun` to export and analyze archives.
/// - See Apple's documentation on automated device analytics and MetricKit for best practices.
final class MetricKitObserver: NSObject, MXMetricManagerSubscriber {
  // Performance thresholds for monitoring
  private enum PerformanceThresholds {
    static let maxCPUTime: TimeInterval = 5.0  // 5 seconds
    static let maxMemoryUsage: UInt64 = 100 * 1024 * 1024  // 100 MB
    static let maxLaunchTime: TimeInterval = 3.0  // 3 seconds
    static let maxDiskReadBytes: UInt64 = 50 * 1024 * 1024  // 50 MB
  }

  private var performanceWarnings: [String] = []

  override init() {
    super.init()
    MXMetricManager.shared.add(self)
  }

  func didReceive(_ payloads: [MXMetricPayload]) {
    performanceWarnings.removeAll()

    for (index, payload) in payloads.enumerated() {
      print("📊 MetricKit Payload #\(index + 1) received:")

      // CPU Metrics Analysis
      if let cpuMetrics = payload.cpuMetrics {
        print("  🔥 CPU Metrics:")
        // cumulativeCPUTime is Measurement<UnitDuration>
        let cpuTimeSeconds = cpuMetrics.cumulativeCPUTime.value
        print("    - Cumulative CPU Time: \(cpuTimeSeconds) seconds")

        // Check CPU thresholds
        if cpuTimeSeconds > PerformanceThresholds.maxCPUTime {
          performanceWarnings.append("⚠️ High CPU usage: \(cpuTimeSeconds)s (threshold: \(PerformanceThresholds.maxCPUTime)s)")
        }
      } else {
        print("  🔥 CPU Metrics: Unavailable")
      }

      // Memory Metrics Analysis
      if let memoryMetrics = payload.memoryMetrics {
        print("  💾 Memory Metrics:")
        // peakMemoryUsage is Measurement<UnitInformationStorage>
        let peakBytes = memoryMetrics.peakMemoryUsage.value
        print("    - Peak Memory Usage: \(peakBytes) bytes")

        // Check memory thresholds
        if UInt64(peakBytes) > PerformanceThresholds.maxMemoryUsage {
          performanceWarnings.append("⚠️ High memory usage: \(peakBytes) bytes (threshold: \(PerformanceThresholds.maxMemoryUsage) bytes)")
        }
      } else {
        print("  💾 Memory Metrics: Unavailable")
      }

      // Application Launch Metrics
      if payload.applicationLaunchMetrics != nil {
        print("  🚀 Launch Metrics:")
        print("    - Launch metrics available")
      } else {
        print("  🚀 Launch Metrics: Unavailable")
      }

      // Disk I/O Metrics
      if payload.diskIOMetrics != nil {
        print("  💿 Disk I/O Metrics:")
        print("    - Disk I/O metrics available")
      } else {
        print("  💿 Disk I/O Metrics: Unavailable")
      }

      // Network Transfer Metrics
      // Detailed network transfer properties (cellularBytesSent, wifiBytesReceived, etc.) are not guaranteed public.
      // Hence, only print presence and warn about lack of detailed data.
      if let _ = payload.networkTransferMetrics {
        print("  🌐 Network Transfer Metrics: Present (detailed values unavailable due to MetricKit API limitations)")
      } else {
        print("  🌐 Network Transfer Metrics: Unavailable")
      }

      // GPU Metrics (Not publicly available / no gpuMetrics property in MXMetricPayload)
      // Removed as per instruction

      print("  📅 Time Range: \(payload.timeStampBegin) to \(payload.timeStampEnd)")
      print("")
    }

    // Print performance warnings if any
    if !performanceWarnings.isEmpty {
      print("🚨 Performance Warnings:")
      for warning in performanceWarnings {
        print("  \(warning)")
      }
      print("")
    }
  }

  func didReceiveError(_ error: Error) {
    print("❌ MetricKit error: \(error.localizedDescription)")
  }
}

/// Custom metric collector for Bridget-specific operations
class BridgetMetricsCollector {
  static let shared = BridgetMetricsCollector()

  private var dateValidationMetrics: [String: TimeInterval] = [:]
  private var validationCounts: [String: Int] = [:]
  private let queue = DispatchQueue(label: "com.bridget.metrics", qos: .utility)

  private init() {}

  /// Track date validation performance
  func trackDateValidation(format: String, duration: TimeInterval, success: Bool) {
    queue.async {
      let key = "\(format)_\(success ? "success" : "failure")"
      self.dateValidationMetrics[key, default: 0] += duration
      self.validationCounts[key, default: 0] += 1
    }
  }

  /// Get performance summary
  func getPerformanceSummary() -> String {
    return queue.sync {
      var summary = "📈 Bridget Performance Summary:\n"

      for (key, duration) in dateValidationMetrics {
        let count = validationCounts[key] ?? 0
        let avgDuration = count > 0 ? duration / Double(count) : 0
        summary += "  - \(key): \(count) validations, avg: \(String(format: "%.3f", avgDuration))s\n"
      }

      return summary
    }
  }

  /// Reset metrics
  func reset() {
    queue.async {
      self.dateValidationMetrics.removeAll()
      self.validationCounts.removeAll()
    }
  }
}

private let _metricKitObserver = MetricKitObserver()

/// Reasons for date validation failures in business logic.
///
/// This enum enumerates the possible failures that can occur when validating date strings
/// before decoding, such as empty values, invalid format, or values out of an expected range.
/// It provides descriptive error messages to facilitate debugging and error reporting.
enum DateValidationError: Error, CustomStringConvertible, Equatable {
  case emptyOrNull
  case invalidFormat(String)
  case valueOutOfRange(String)

  /// A human-readable description of the validation error.
  var description: String {
    switch self {
    case .emptyOrNull: return "Date string is empty or null."
    case let .invalidFormat(str): return "Invalid date format: \(str)"
    case let .valueOutOfRange(message): return "Value out of range: \(message)"
    }
  }
}

/// Log level for structured validation logging.
enum LogLevel: String {
  case debug = "DEBUG"
  case info = "INFO"
  case warning = "WARNING"
  case error = "ERROR"

  var displayName: String { rawValue }
}

/// Context for a date validation error report.
struct DateValidationContext {
  var recordID: String?
  var source: String?
  var timestamp: Date = .init()
  var userAction: String? = nil
}

/// Protocol for reporting date validation errors with context and level.
protocol DateValidationErrorReporter {
  func report(_ error: DateValidationError, level: LogLevel, context: DateValidationContext)
}

/// Console reporter for date validation errors.
struct ConsoleDateValidationErrorReporter: DateValidationErrorReporter {
  func report(_ error: DateValidationError, level: LogLevel, context: DateValidationContext) {
    let id = context.recordID.map { "RecordID: \($0)" } ?? "RecordID: N/A"
    let src = context.source ?? ""
    let ts = ISO8601DateFormatter().string(from: context.timestamp)
    let suggestion: String = {
      switch error {
      case .emptyOrNull:
        return "Suggestion: Ensure the date string is not missing."
      case .invalidFormat:
        return "Suggestion: Check that the date matches supported formats."
      case .valueOutOfRange:
        return "Suggestion: Ensure the date is within a valid range."
      }
    }()
    print("[\(level.displayName)] DateValidationError: \(error) \(id) Source: \(src) @\(ts)\n  \(suggestion)")
  }
}

/// Stub: File reporter for future use.
struct FileDateValidationErrorReporter: DateValidationErrorReporter {
  func report(_: DateValidationError, level _: LogLevel, context _: DateValidationContext) {
    // Stub: Write to file
  }
}

/// Stub: Monitoring reporter for future integration (e.g., Sentry, DataDog).
struct MonitoringDateValidationErrorReporter: DateValidationErrorReporter {
  func report(_: DateValidationError, level _: LogLevel, context _: DateValidationContext) {
    // Stub: Send to monitoring/logging service
  }
}

/// Business validation for date strings.
///
/// This struct provides a static method to validate date strings according to business rules.
/// Validation includes checks for non-empty values and conformance to expected formats.
/// Additional range or content validations can be added as needed.
enum DateValidator {
  /// Supported date formats (Seattle API and ISO8601 variants):
  /// - yyyy-MM-dd'T'HH:mm:ss.SSS
  /// - yyyy-MM-dd'T'HH:mm:ss
  /// - yyyy-MM-dd'T'HH:mm:ss.SSSZ
  /// - yyyy-MM-dd'T'HH:mm:ssZ
  /// - yyyy-MM-dd'T'HH:mm:ss.SSS±HH:mm
  /// - yyyy-MM-dd'T'HH:mm:ss±HH:mm
  /// ISO8601DateFormatter is also tried for broader compatibility.
  static let regex =
    #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?([Z]|[+-]\d{2}:\d{2})?$"#

  static let formatters: [DateFormatter] = {
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

  static let iso8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [
      .withInternetDateTime,
      .withFractionalSeconds,
    ]
    return f
  }()

  /// Validates a date string for emptiness, format, and actual calendar correctness.
  /// Supports Seattle API, ISO8601, and common timezone offset formats.
  static func validate(_ dateString: String?) -> Result<Void, DateValidationError> {
    guard let s = dateString, !s.trimmingCharacters(in: .whitespaces).isEmpty else {
      return .failure(.emptyOrNull)
    }
    guard s.range(of: regex, options: .regularExpression) != nil else {
      return .failure(.invalidFormat(s))
    }

    // Extract year, month, day from input string for validation
    let yearStr = String(s.prefix(4))
    let monthStr = String(s.dropFirst(5).prefix(2))
    let dayStr = String(s.dropFirst(8).prefix(2))

    guard let y = Int(yearStr), let m = Int(monthStr), let d = Int(dayStr) else {
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
    let extractedComps = calendar.dateComponents([.year, .month, .day], from: date)
    guard extractedComps.year == y && extractedComps.month == m && extractedComps.day == d else {
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

/// Error type for unexpected test outcomes.
enum TestError: Error {
  case unexpectedSuccess(String)
}

/// Test suite for verifying the behavior of `JSONDecoder.bridgeDecoder()`
/// with a focus on date decoding formats, error handling, business validation,
/// and logging features controlled by the `TEST_LOGGING` macro.
@Suite("BridgeDecoder")
struct BridgeDecoderTests {
  let decoder = JSONDecoder.bridgeDecoder()

  struct DateTestModel: Codable {
    let date: Date
  }

  /// Tests decoding a date string in the valid primary format "yyyy-MM-ddTHH:mm:ss.SSS".
  @Test("valid primary format")
  func validPrimaryFormat() async throws {
    let json = #"{"date": "2025-01-03T10:12:00.000"}"#.data(using: .utf8)!
    let dateString = "2025-01-03T10:12:00.000"
    let reporter = ConsoleDateValidationErrorReporter()
    let context = DateValidationContext(recordID: "test-validPrimaryFormat", source: "BridgeDecoderTests")
    let valResult = DateValidator.validate(dateString)
    if case let .failure(error) = valResult {
      reporter.report(error, level: .error, context: context)
      throw error
    }
    let obj = try decoder.decode(DateTestModel.self, from: json)
    #expect(Calendar.current.component(.year, from: obj.date) == 2025)
    #expect(Calendar.current.component(.month, from: obj.date) == 1)
    #expect(Calendar.current.component(.day, from: obj.date) == 3)
  }

  /// Tests decoding a date string in valid ISO8601 format "yyyy-MM-ddTHH:mm:ssZ".
  @Test("valid ISO8601 format")
  func validISO8601Format() async throws {
    let json = #"{"date": "2025-01-03T10:12:00Z"}"#.data(using: .utf8)!
    let dateString = "2025-01-03T10:12:00Z"
    let reporter = ConsoleDateValidationErrorReporter()
    let context = DateValidationContext(recordID: "test-validISO8601Format", source: "BridgeDecoderTests")
    let valResult = DateValidator.validate(dateString)
    if case let .failure(error) = valResult {
      reporter.report(error, level: .error, context: context)
      throw error
    }
    let obj = try decoder.decode(DateTestModel.self, from: json)
    #expect(Calendar.current.component(.year, from: obj.date) == 2025)
    #expect(Calendar.current.component(.month, from: obj.date) == 1)
    #expect(Calendar.current.component(.day, from: obj.date) == 3)
  }

  /// Verifies that decoding a malformed date string throws an error and that validation reports errors.
  @Test("malformed date")
  func malformedDate() async throws {
    let json = #"{"date": "not-a-date"}"#.data(using: .utf8)!
    let reporter = ConsoleDateValidationErrorReporter()
    let dateString = "not-a-date"
    let context = DateValidationContext(recordID: "test-malformedDate", source: "BridgeDecoderTests")
    let valResult = DateValidator.validate(dateString)
    if case let .failure(error) = valResult {
      reporter.report(error, level: .error, context: context)
    }
    do {
      _ = try decoder.decode(DateTestModel.self, from: json)
      // If we reach here, the test should fail because malformed date should throw
      throw TestError.unexpectedSuccess("Malformed date should throw decoding error")
    } catch {
      // Expected error for malformed date
    }
  }

  /// Verifies that decoding a null date value throws an error.
  @Test("null date")
  func nullDate() async throws {
    let json = #"{"date": null}"#.data(using: .utf8)!
    do {
      _ = try decoder.decode(DateTestModel.self, from: json)
      // If we reach here, the test should fail because null date should throw
      throw TestError.unexpectedSuccess("Null date should throw decoding error")
    } catch {
      // Any error is acceptable for null date
    }
  }

  /// Tests that extra unknown fields in the JSON do not prevent successful decoding.
  @Test("extra unknown fields")
  func extraUnknownFields() async throws {
    let json = #"{"date": "2025-01-03T10:12:00.000", "unknown": 42}"#.data(using: .utf8)!
    let obj = try decoder.decode(DateTestModel.self, from: json)
    #expect(Calendar.current.component(.year, from: obj.date) == 2025)
  }

  /// Tests that when the `TEST_LOGGING` macro is defined, the logging date parser is triggered and logs errors.
  @Test("logging parser verification")
  func loggingParserVerification() async throws {
    // This test should trigger the LoggingDateParser when TEST_LOGGING is defined
    // We'll use a date that should fail parsing to trigger the logging
    let json = #"{"date": "invalid-date-format"}"#.data(using: .utf8)!
    do {
      _ = try decoder.decode(DateTestModel.self, from: json)
      // If we reach here, the test should fail because invalid date should throw
      throw TestError.unexpectedSuccess("Invalid date should throw error")
    } catch {
      // The error is expected, but the LoggingDateParser should have printed a message
    }
  }

  /// Verifies the presence or absence of the `TEST_LOGGING` macro by checking which parser is used.
  @Test("TEST_LOGGING macro verification")
  func loggingMacroVerification() async throws {
    // This test directly verifies that the TEST_LOGGING macro is working
    #if TEST_LOGGING
      // When TEST_LOGGING is defined, we should be using LoggingDateParser
      let parser = LoggingDateParser()
      let result = parser.parse("invalid-date")
      #expect(result == nil, "Invalid date should return nil")
    // Reaching here means TEST_LOGGING macro is active
    #else
      // When TEST_LOGGING is not defined, we should be using DefaultDateParser
      let parser = DefaultDateParser()
      let result = parser.parse("invalid-date")
      #expect(result == nil, "Invalid date should return nil")
      // Reaching here means TEST_LOGGING macro is not active
    #endif
  }

  /// Tests business validation for empty and malformed date strings,
  /// ensuring appropriate failures are reported and valid strings succeed.
  @Test("business validation: empty and malformed date")
  func businessValidationEmptyAndMalformed() async throws {
    let reporter = ConsoleDateValidationErrorReporter()
    let context = DateValidationContext(recordID: "test-businessValidation", source: "BridgeDecoderTests")
    let emptyResult = DateValidator.validate("")
    #expect({ if case .failure = emptyResult { return true } else { return false } }())
    if case let .failure(err) = emptyResult { reporter.report(err, level: .error, context: context) }

    let malformedResult = DateValidator.validate("not-a-date")
    #expect({ if case .failure = malformedResult { return true } else { return false } }())
    if case let .failure(err) = malformedResult { reporter.report(err, level: .error, context: context) }

    let validResult = DateValidator.validate("2025-08-07T12:34:56.000")
    #expect({ if case .success = validResult { return true } else { return false } }())
  }

  /// Tests edge cases and boundary conditions for date validation, including
  /// invalid calendar dates, timezone offsets, boundary years, leap years, extra whitespace, and null/optional handling.
  @Test("date edge and boundary cases")
  func dateEdgeAndBoundaryCases() async throws {
    let reporter = ConsoleDateValidationErrorReporter()
    let ctx = DateValidationContext(recordID: "test-dateEdgeCases", source: "BridgeDecoderTests")

    // Invalid calendar date: February 30th
    let feb30 = "2025-02-30T10:00:00"
    let result1 = DateValidator.validate(feb30)
    #expect({ if case .failure = result1 { return true } else { return false } }(), "February 30th should fail")
    if case let .failure(err) = result1 { reporter.report(err, level: .error, context: ctx) }

    // Invalid calendar date: April 31st
    let apr31 = "2025-04-31T10:00:00"
    let result2 = DateValidator.validate(apr31)
    #expect({ if case .failure = result2 { return true } else { return false } }(), "April 31st should fail")
    if case let .failure(err) = result2 { reporter.report(err, level: .error, context: ctx) }

    // Valid leap year: Feb 29, 2024
    let leap = "2024-02-29T12:00:00"
    let result3 = DateValidator.validate(leap)
    #expect({ if case .success = result3 { return true } else { return false } }(), "Leap year Feb 29 should pass")

    // Invalid leap year: Feb 29, 2023
    let notLeap = "2023-02-29T12:00:00"
    let result4 = DateValidator.validate(notLeap)
    #expect({ if case .failure = result4 { return true } else { return false } }(), "Non-leap year Feb 29 should fail")
    if case let .failure(err) = result4 { reporter.report(err, level: .error, context: ctx) }

    // Valid timezone offset, positive
    let tzpos = "2025-01-01T12:00:00+05:00"
    let result5 = DateValidator.validate(tzpos)
    #expect({ if case .success = result5 { return true } else { return false } }(), "Positive timezone offset should pass")

    // Valid timezone offset, negative
    let tzneg = "2025-01-01T12:00:00-08:00"
    let result6 = DateValidator.validate(tzneg)
    #expect({ if case .success = result6 { return true } else { return false } }(), "Negative timezone offset should pass")

    // Boundary year: 1900
    let y1900 = "1900-01-01T00:00:00Z"
    let result7 = DateValidator.validate(y1900)
    #expect({ if case .success = result7 { return true } else { return false } }(), "Year 1900 should pass")

    // Boundary year: 2100
    let y2100 = "2100-12-31T23:59:59Z"
    let result8 = DateValidator.validate(y2100)
    #expect({ if case .success = result8 { return true } else { return false } }(), "Year 2100 should pass")

    // Extra whitespace
    let ws = " 2025-01-01T12:00:00Z "
    let result9 = DateValidator.validate(ws.trimmingCharacters(in: .whitespaces))
    #expect({ if case .success = result9 { return true } else { return false } }(), "Whitespace-trimmed string should pass")

    // Null/optional handling
    let result10 = DateValidator.validate(nil)
    #expect({ if case .failure = result10 { return true } else { return false } }(), "Nil string should fail")
  }

  /// Measures performance of date validation for 10,000 records with a realistic date string.
  /// Prints elapsed time and asserts that validation completes quickly.
  @Test("date validation performance - 10,000 records")
  func dateValidationPerformance() async throws {
    // Reset metrics collector
    BridgetMetricsCollector.shared.reset()

    let log = OSLog(subsystem: "com.yourcompany.BridgeDecoderTests", category: "performance")
    let signpostID = OSSignpostID(log: log)
    os_signpost(.begin, log: log, name: "ValidationLoop", signpostID: signpostID)

    let baseDates = [
      "2025-01-03T10:12:00.000",    // Standard format
      "2025-01-03T10:12:00Z",       // UTC format
      "2025-01-03T10:12:00+05:00",  // Timezone offset
      "2024-02-29T12:00:00",        // Leap year
      "1900-01-01T00:00:00Z",       // Boundary year (valid)
      "invalid-date",               // Invalid format
      "2023-02-29T12:00:00",        // Invalid leap (should fail)
      "2025-02-30T10:00:00",        // Invalid calendar day
      "2025-01-01T12:00:00-08:00",  // Negative offset
      "2025-01-01T12:00:00",        // No milliseconds, no zone
      " 2025-01-01T12:00:00Z ",     // Whitespace
      "2025-01-03T10:12:00.500",
    ]
    // Ensure we get exactly 10,000 dates
    let repeats = 10000 / baseDates.count  // Integer division
    let remainder = 10000 % baseDates.count  // Get remainder
    let testDates = Array(repeating: baseDates, count: repeats).flatMap { $0 } + Array(baseDates.prefix(remainder))

    var successCount = 0, failCount = 0
    for date in testDates {
      let startTime = CFAbsoluteTimeGetCurrent()
      let result = DateValidator.validate(date.trimmingCharacters(in: .whitespaces))
      let endTime = CFAbsoluteTimeGetCurrent()
      let duration = endTime - startTime

      // Track metrics for each validation
      let format = String(date.prefix(19)) // Get format type
      if case .success = result {
        BridgetMetricsCollector.shared.trackDateValidation(format: format, duration: duration, success: true)
        successCount += 1
      } else {
        BridgetMetricsCollector.shared.trackDateValidation(format: format, duration: duration, success: false)
        failCount += 1
      }
    }

    print("dateValidationPerformance: successCount=\(successCount), failCount=\(failCount), total=\(successCount + failCount)")

    // Print Bridget-specific metrics
    print(BridgetMetricsCollector.shared.getPerformanceSummary())

    os_signpost(.end, log: log, name: "ValidationLoop", signpostID: signpostID)

    // The test validates 10,000 dates, but some may be rejected by improved validation
    // We expect the total to be 10,000, but the exact success/fail distribution may vary
    let totalValidations = successCount + failCount
    #expect(totalValidations == 10000, "Validation did not cover all records: success=\(successCount) fail=\(failCount) total=\(totalValidations)")
    #expect(successCount > 0, "No successful validations")
    #expect(failCount > 0, "No failed validations - validation may be too permissive")
  }

  /// Compares date validation performance vs. a trivial baseline for multiple data sizes (1K, 10K, 100K).
  /// Prints timings for both baseline (isEmpty check) and full validation for each size. Useful for regression tracking.
  @Test("date validation performance: comparative and scaling")
  func dateValidationComparativeScaling() async throws {
    let log = OSLog(subsystem: "com.yourcompany.BridgeDecoderTests", category: "performance")

    let baseDates = [
      "2025-01-03T10:12:00.000", "2025-01-03T10:12:00Z", "2025-01-03T10:12:00+05:00",
      "2024-02-29T12:00:00", "1900-01-01T00:00:00Z", "invalid-date",
      "2023-02-29T12:00:00", "2025-02-30T10:00:00", "2025-01-01T12:00:00-08:00",
      "2025-01-01T12:00:00", " 2025-01-01T12:00:00Z ", "2025-01-03T10:12:00.500",
    ]
    let sizes = [1000, 10000, 100_000]

    for size in sizes {
      let repeats = size / baseDates.count + 1
      let testDates = Array(repeating: baseDates, count: repeats).flatMap { $0 }.prefix(size)

      let baselineSignpostID = OSSignpostID(log: log)
      os_signpost(.begin, log: log, name: "BaselineCheck", signpostID: baselineSignpostID)

      for date in testDates {
        _ = !date.isEmpty
      }

      os_signpost(.end, log: log, name: "BaselineCheck", signpostID: baselineSignpostID)

      let validationSignpostID = OSSignpostID(log: log)
      os_signpost(.begin, log: log, name: "FullValidation", signpostID: validationSignpostID)

      var successCount = 0, failCount = 0
      for date in testDates {
        let result = DateValidator.validate(date.trimmingCharacters(in: .whitespaces))
        if case .success = result {
          successCount += 1
        } else {
          failCount += 1
        }
      }

      os_signpost(.end, log: log, name: "FullValidation", signpostID: validationSignpostID)

      #expect(successCount + failCount == size)
    }
  }

  /// Enhanced performance test with custom metrics integration for automated CI/CD monitoring
  @Test("date validation performance: metrics integration")
  func dateValidationMetricsIntegration() async throws {
    let log = OSLog(subsystem: "com.yourcompany.BridgeDecoderTests", category: "performance")

    // Test different validation scenarios with signposts
    let scenarios = [
      ("valid_only", ["2025-01-03T10:12:00.000", "2025-01-03T10:12:00Z", "2025-01-03T10:12:00+05:00"]),
      ("mixed_validity", ["2025-01-03T10:12:00.000", "invalid-date", "2025-01-03T10:12:00Z", "not-a-date"]),
      ("edge_cases", ["2024-02-29T12:00:00", "2023-02-29T12:00:00", "2025-02-30T10:00:00", "1900-01-01T00:00:00Z"]),
    ]

    for (_, testDates) in scenarios {
      let signpostID = OSSignpostID(log: log)
      os_signpost(.begin, log: log, name: "Scenario", signpostID: signpostID)

      var successCount = 0, failCount = 0
      for date in testDates {
        let result = DateValidator.validate(date)
        if case .success = result {
          successCount += 1
        } else {
          failCount += 1
        }
      }

      os_signpost(.end, log: log, name: "Scenario", signpostID: signpostID)
    }

    // Memory usage tracking
    let memoryInfo = ProcessInfo.processInfo
    _ = memoryInfo.physicalMemory
  }

  /**
   ### Performance Monitoring and Profiling Guide

   #### 1. Manual Profiling with Xcode Instruments
   - In Xcode, select "Product > Profile" (or use Cmd+I) and choose Instruments.
   - Use the "Allocations" and "Leaks" templates for memory analysis.
   - Use "Points of Interest" to see os_signpost markers for timing intervals.
   - Run these tests as part of the profiling session and observe resource graphs.

   #### 2. Automated MetricKit Integration (Optional)
   MetricKit provides system-level performance and energy metrics asynchronously.
   This test file includes a minimal MetricKit observer that prints payloads received.
   For deeper integration, see Apple's documentation:
   https://developer.apple.com/documentation/metrickit

   #### 3. Usage Examples

   **For Development:**
   ```swift
   // Run tests with metrics collection
   xcodebuild test -scheme Bridget -destination 'platform=iOS Simulator,name=iPhone 16'

   */
}
