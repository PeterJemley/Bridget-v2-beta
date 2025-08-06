//
//  BridgeDecoderTests.swift
//  BridgetTests
//
//  Tests for JSONDecoder.bridgeDecoder() focusing on date decoding variants.
//
@testable import Bridget
import XCTest

final class BridgeDecoderTests: XCTestCase {
  let decoder = JSONDecoder.bridgeDecoder()

  struct DateTestModel: Codable {
    let date: Date
  }

  func testValidPrimaryFormat() async throws {
    let json = #"{"date": "2025-01-03T10:12:00.000"}"#.data(using: .utf8)!
    let obj = try decoder.decode(DateTestModel.self, from: json)
    XCTAssertEqual(Calendar.current.component(.year, from: obj.date), 2025)
    XCTAssertEqual(Calendar.current.component(.month, from: obj.date), 1)
    XCTAssertEqual(Calendar.current.component(.day, from: obj.date), 3)
  }

  func testValidISO8601Format() async throws {
    let json = #"{"date": "2025-01-03T10:12:00Z"}"#.data(using: .utf8)!
    let obj = try decoder.decode(DateTestModel.self, from: json)
    XCTAssertEqual(Calendar.current.component(.year, from: obj.date), 2025)
    XCTAssertEqual(Calendar.current.component(.month, from: obj.date), 1)
    XCTAssertEqual(Calendar.current.component(.day, from: obj.date), 3)
  }

  func testMalformedDate() async throws {
    let json = #"{"date": "not-a-date"}"#.data(using: .utf8)!
    do {
      _ = try decoder.decode(DateTestModel.self, from: json)
      XCTFail("Malformed date should throw decoding error")
    } catch let DecodingError.dataCorrupted(context) {
      XCTAssertTrue(context.debugDescription.contains("Invalid date format"))
    }
  }

  func testNullDate() async throws {
    let json = #"{"date": null}"#.data(using: .utf8)!
    do {
      _ = try decoder.decode(DateTestModel.self, from: json)
      XCTFail("Null date should throw decoding error")
    } catch let DecodingError.typeMismatch(type, _) {
      XCTAssertEqual(String(describing: type), "Date") // Just ensure it's a typeMismatch
    }
  }

  func testExtraUnknownFields() async throws {
    let json = #"{"date": "2025-01-03T10:12:00.000", "unknown": 42}"#.data(using: .utf8)!
    let obj = try decoder.decode(DateTestModel.self, from: json)
    XCTAssertEqual(Calendar.current.component(.year, from: obj.date), 2025)
  }
}
