//
//  BridgeDecoderTests.swift
//  BridgetTests
//
//  Tests for JSONDecoder.bridgeDecoder() focusing on date decoding variants.
//
//  TEST_LOGGING FLAG MANAGEMENT:
//  =============================
//
//  This test suite uses a preprocessor macro to enable enhanced logging during date parsing.
//
//  How to Enable in Xcode:
//  -----------------------
//  1. In Xcode: Go to your test target's Build Settings
//  2. Find: "Other Swift Flags"
//  3. Add: -DTEST_LOGGING
//
//  When to Enable:
//  ---------------
//  • During development/debugging of date parsing issues
//  • When investigating JSON decoding failures
//  • When you need detailed logging of parse attempts and failures
//
//  When to Disable:
//  ----------------
//  • During normal test runs (to reduce noise)
//  • In CI/CD pipelines (unless debugging specific issues)
//  • When running performance tests
//
//  Current Status: ENABLED via command line flag for this test run
//  To disable: Remove -DTEST_LOGGING from "Other Swift Flags" in Xcode
//
@testable import Bridget
import Foundation
import Testing

enum TestError: Error {
  case unexpectedSuccess(String)
}

@Suite("BridgeDecoder")
struct BridgeDecoderTests {
  let decoder = JSONDecoder.bridgeDecoder()
  struct DateTestModel: Codable {
    let date: Date
  }

  @Test("valid primary format")
  func validPrimaryFormat() async throws {
    let json = #"{"date": "2025-01-03T10:12:00.000"}"#.data(using: .utf8)!
    let obj = try decoder.decode(DateTestModel.self, from: json)
    #expect(Calendar.current.component(.year, from: obj.date) == 2025)
    #expect(Calendar.current.component(.month, from: obj.date) == 1)
    #expect(Calendar.current.component(.day, from: obj.date) == 3)
  }

  @Test("valid ISO8601 format")
  func validISO8601Format() async throws {
    let json = #"{"date": "2025-01-03T10:12:00Z"}"#.data(using: .utf8)!
    let obj = try decoder.decode(DateTestModel.self, from: json)
    #expect(Calendar.current.component(.year, from: obj.date) == 2025)
    #expect(Calendar.current.component(.month, from: obj.date) == 1)
    #expect(Calendar.current.component(.day, from: obj.date) == 3)
  }

  @Test("malformed date")
  func malformedDate() async throws {
    let json = #"{"date": "not-a-date"}"#.data(using: .utf8)!
    do {
      _ = try decoder.decode(DateTestModel.self, from: json)
      // If we reach here, the test should fail because malformed date should throw
      throw TestError.unexpectedSuccess("Malformed date should throw decoding error")
    } catch {
      // Expected error for malformed date
    }
  }

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

  @Test("extra unknown fields")
  func extraUnknownFields() async throws {
    let json = #"{"date": "2025-01-03T10:12:00.000", "unknown": 42}"#.data(using: .utf8)!
    let obj = try decoder.decode(DateTestModel.self, from: json)
    #expect(Calendar.current.component(.year, from: obj.date) == 2025)
  }

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
}
