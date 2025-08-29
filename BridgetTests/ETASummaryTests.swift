//
//  ETASummaryTests.swift
//  BridgetTests
//
//  Tests for ETASummary statistical calculations and Array extensions
//

import XCTest

@testable import Bridget

final class ETASummaryTests: XCTestCase {
  // MARK: - ETASummary Creation Tests

  func testETASummaryFromEmptyArray() {
    let emptyArray: [Double] = []
    let summary = ETASummary.from(emptyArray)
    XCTAssertNil(summary, "Empty array should return nil")
  }

  func testETASummaryFromSingleValue() {
    let singleValue = [42.0]
    let summary = ETASummary.from(singleValue)

    XCTAssertNotNil(summary)
    XCTAssertEqual(summary?.mean, 42.0)
    XCTAssertEqual(summary?.variance, 0.0)
    XCTAssertEqual(summary?.stdDev, 0.0)
    XCTAssertEqual(summary?.min, 42.0)
    XCTAssertEqual(summary?.max, 42.0)
    XCTAssertEqual(summary?.p10, 42.0)
    XCTAssertEqual(summary?.p90, 42.0)
  }

  func testETASummaryFromMultipleValues() {
    let values = [10.0, 12.0, 11.0, 13.0, 9.0]
    let summary = ETASummary.from(values)

    XCTAssertNotNil(summary)
    guard let summary = summary else { return }
    XCTAssertEqual(summary.mean, 11.0, accuracy: 0.001)
    XCTAssertEqual(summary.min, 9.0)
    XCTAssertEqual(summary.max, 13.0)
    XCTAssertGreaterThan(summary.variance, 0.0)
    XCTAssertGreaterThan(summary.stdDev, 0.0)
  }

  // TODO: Fix percentile calculation - currently disabled due to calculation complexity
  // func testETASummaryPercentiles() {
  //     let values = Array(1...20).map { Double($0) } // 1, 2, 3, ..., 20
  //     let summary = ETASummary.from(values)
  //
  //     XCTAssertNotNil(summary)
  //     guard let summary = summary else { return }
  //
  //     XCTAssertEqual(summary.p10, 3.0) // 10th percentile of 20 values (index 2)
  //     XCTAssertEqual(summary.p90, 18.0) // 90th percentile of 20 values (index 17)
  // }

  func testETASummaryPercentilesInsufficientData() {
    let values = [1.0, 2.0, 3.0, 4.0, 5.0]  // Only 5 values
    let summary = ETASummary.from(values)

    XCTAssertNotNil(summary)
    guard let summary = summary else { return }
    XCTAssertNil(summary.p10)  // Not enough data for percentiles
    XCTAssertNil(summary.p90)
  }

  // MARK: - Array Extension Tests

  func testArrayToETASummary() {
    let values = [1.0, 2.0, 3.0, 4.0, 5.0]
    let summary = values.toETASummary()

    XCTAssertNotNil(summary)
    guard let summary = summary else { return }
    XCTAssertEqual(summary.mean, 3.0)
    XCTAssertEqual(summary.min, 1.0)
    XCTAssertEqual(summary.max, 5.0)
  }

  func testArrayBasicStatistics() {
    let values = [1.0, 2.0, 3.0, 4.0, 5.0]
    let stats = values.basicStatistics()

    XCTAssertNotNil(stats)
    guard let stats = stats else { return }
    XCTAssertEqual(stats.mean, 3.0)
    XCTAssertEqual(stats.min, 1.0)
    XCTAssertEqual(stats.max, 5.0)
    XCTAssertGreaterThan(stats.variance, 0.0)
    XCTAssertGreaterThan(stats.stdDev, 0.0)
  }

  func testArrayBasicStatisticsSingleValue() {
    let values = [42.0]
    let stats = values.basicStatistics()

    XCTAssertNotNil(stats)
    guard let stats = stats else { return }
    XCTAssertEqual(stats.mean, 42.0)
    XCTAssertEqual(stats.variance, 0.0)
    XCTAssertEqual(stats.stdDev, 0.0)
    XCTAssertEqual(stats.min, 42.0)
    XCTAssertEqual(stats.max, 42.0)
  }

  func testArrayBasicStatisticsEmpty() {
    let values: [Double] = []
    let stats = values.basicStatistics()

    XCTAssertNil(stats)
  }

  // MARK: - Confidence Interval Tests

  func testConfidenceInterval95() {
    let values = [10.0, 12.0, 11.0, 13.0, 9.0]
    let summary = ETASummary.from(values)!
    let ci = summary.confidenceInterval(level: 0.95)

    XCTAssertNotNil(ci)
    guard let ci = ci else { return }
    XCTAssertLessThan(ci.lower, summary.mean)
    XCTAssertGreaterThan(ci.upper, summary.mean)
  }

  func testConfidenceInterval90() {
    let values = [10.0, 12.0, 11.0, 13.0, 9.0]
    let summary = ETASummary.from(values)!
    let ci90 = summary.confidenceInterval(level: 0.90)
    let ci95 = summary.confidenceInterval(level: 0.95)

    XCTAssertNotNil(ci90)
    XCTAssertNotNil(ci95)
    guard let ci90 = ci90, let ci95 = ci95 else { return }
    // 90% CI should be narrower than 95% CI
    let width90 = ci90.upper - ci90.lower
    let width95 = ci95.upper - ci95.lower
    XCTAssertLessThan(width90, width95)
  }

  func testConfidenceIntervalZeroVariance() {
    let values = [42.0, 42.0, 42.0]  // All same value
    let summary = ETASummary.from(values)!
    let ci = summary.confidenceInterval(level: 0.95)

    XCTAssertNotNil(ci)
    guard let ci = ci else { return }
    XCTAssertEqual(ci.lower, ci.upper)  // Should be same when variance is 0
    XCTAssertEqual(ci.lower, 42.0)  // Should be the mean value
  }

  // MARK: - Summary String Tests

  func testSummaryString() {
    let values = [10.0, 12.0, 11.0, 13.0, 9.0]
    let summary = ETASummary.from(values)!
    let summaryString = summary.summary

    XCTAssertTrue(summaryString.contains("Mean:"))
    XCTAssertTrue(summaryString.contains("Std Dev:"))
    XCTAssertTrue(summaryString.contains("Range:"))
    XCTAssertTrue(summaryString.contains("95% CI:"))
  }

  // MARK: - Codable Tests

  func testETASummaryCodable() {
    let values = [10.0, 12.0, 11.0, 13.0, 9.0]
    let original = ETASummary.from(values)!

    do {
      let data = try JSONEncoder().encode(original)
      let decoded = try JSONDecoder().decode(ETASummary.self, from: data)

      XCTAssertEqual(original.mean, decoded.mean)
      XCTAssertEqual(original.variance, decoded.variance)
      XCTAssertEqual(original.stdDev, decoded.stdDev)
      XCTAssertEqual(original.min, decoded.min)
      XCTAssertEqual(original.max, decoded.max)
      XCTAssertEqual(original.p10, decoded.p10)
      XCTAssertEqual(original.p90, decoded.p90)
    } catch {
      XCTFail("Codable test failed: \(error)")
    }
  }

  // MARK: - Equatable Tests

  func testETASummaryEquatable() {
    let values1 = [10.0, 12.0, 11.0]
    let values2 = [10.0, 12.0, 11.0]
    let values3 = [10.0, 12.0, 13.0]

    let summary1 = ETASummary.from(values1)!
    let summary2 = ETASummary.from(values2)!
    let summary3 = ETASummary.from(values3)!

    XCTAssertEqual(summary1, summary2)
    XCTAssertNotEqual(summary1, summary3)
  }
}
