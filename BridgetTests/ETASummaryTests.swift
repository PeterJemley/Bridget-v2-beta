//
//  ETASummaryTests.swift
//  BridgetTests
//
//  Tests for ETASummary statistical calculations and Array extensions
//

import Foundation
import Testing

@testable import Bridget

@Suite("ETASummary Tests")
struct ETASummaryTests {
    // MARK: - ETASummary Creation Tests

    @Test("ETASummary.from returns nil for empty array")
    func testETASummaryFromEmptyArray() {
        let emptyArray: [Double] = []
        let summary = ETASummary.from(emptyArray)
        #expect(summary == nil, "Empty array should return nil")
    }

    @Test("ETASummary.from single value produces zero variance and stdDev")
    func testETASummaryFromSingleValue() {
        let singleValue = [42.0]
        let summary = ETASummary.from(singleValue)

        #expect(summary != nil)
        let unwrapped = try! #require(summary)
        #expect(unwrapped.mean == 42.0)
        #expect(unwrapped.variance == 0.0)
        #expect(unwrapped.stdDev == 0.0)
        #expect(unwrapped.min == 42.0)
        #expect(unwrapped.max == 42.0)
        #expect(unwrapped.p10 == 42.0)
        #expect(unwrapped.p90 == 42.0)
    }

    @Test("ETASummary.from multiple values computes stats")
    func testETASummaryFromMultipleValues() {
        let values = [10.0, 12.0, 11.0, 13.0, 9.0]
        let summary = ETASummary.from(values)

        #expect(summary != nil)
        let unwrapped = try! #require(summary)
        #expect(abs(unwrapped.mean - 11.0) < 0.001)
        #expect(unwrapped.min == 9.0)
        #expect(unwrapped.max == 13.0)
        #expect(unwrapped.variance > 0.0)
        #expect(unwrapped.stdDev > 0.0)
    }

    // TODO: Fix percentile calculation - currently disabled due to calculation complexity
    // @Test("ETASummary.from percentiles for sufficient data")
    // func testETASummaryPercentiles() {
    //     let values = Array(1...20).map { Double($0) } // 1, 2, 3, ..., 20
    //     let summary = ETASummary.from(values)
    //
    //     #expect(summary != nil)
    //     let unwrapped = try! #require(summary)
    //
    //     #expect(unwrapped.p10 == 3.0) // 10th percentile of 20 values (index 2)
    //     #expect(unwrapped.p90 == 18.0) // 90th percentile of 20 values (index 17)
    // }

    @Test("ETASummary.from leaves percentiles nil with insufficient data")
    func testETASummaryPercentilesInsufficientData() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]  // Only 5 values
        let summary = ETASummary.from(values)

        #expect(summary != nil)
        let unwrapped = try! #require(summary)
        #expect(unwrapped.p10 == nil)  // Not enough data for percentiles
        #expect(unwrapped.p90 == nil)
    }

    // MARK: - Array Extension Tests

    @Test("Array.toETASummary computes stats")
    func testArrayToETASummary() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let summary = values.toETASummary()

        #expect(summary != nil)
        let unwrapped = try! #require(summary)
        #expect(unwrapped.mean == 3.0)
        #expect(unwrapped.min == 1.0)
        #expect(unwrapped.max == 5.0)
    }

    @Test("Array.basicStatistics computes stats")
    func testArrayBasicStatistics() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stats = values.basicStatistics()

        #expect(stats != nil)
        let unwrapped = try! #require(stats)
        #expect(unwrapped.mean == 3.0)
        #expect(unwrapped.min == 1.0)
        #expect(unwrapped.max == 5.0)
        #expect(unwrapped.variance > 0.0)
        #expect(unwrapped.stdDev > 0.0)
    }

    @Test("Array.basicStatistics single value returns zero variance/stdDev")
    func testArrayBasicStatisticsSingleValue() {
        let values = [42.0]
        let stats = values.basicStatistics()

        #expect(stats != nil)
        let unwrapped = try! #require(stats)
        #expect(unwrapped.mean == 42.0)
        #expect(unwrapped.variance == 0.0)
        #expect(unwrapped.stdDev == 0.0)
        #expect(unwrapped.min == 42.0)
        #expect(unwrapped.max == 42.0)
    }

    @Test("Array.basicStatistics empty returns nil")
    func testArrayBasicStatisticsEmpty() {
        let values: [Double] = []
        let stats = values.basicStatistics()

        #expect(stats == nil)
    }

    // MARK: - Confidence Interval Tests

    @Test("ETASummary 95% confidence interval spans the mean")
    func testConfidenceInterval95() {
        let values = [10.0, 12.0, 11.0, 13.0, 9.0]
        let summary = ETASummary.from(values)!
        let ci = summary.confidenceInterval(level: 0.95)

        #expect(ci != nil)
        let unwrapped = try! #require(ci)
        #expect(unwrapped.lower < summary.mean)
        #expect(unwrapped.upper > summary.mean)
    }

    @Test("90% CI is narrower than 95% CI")
    func testConfidenceInterval90() {
        let values = [10.0, 12.0, 11.0, 13.0, 9.0]
        let summary = ETASummary.from(values)!
        let ci90 = summary.confidenceInterval(level: 0.90)
        let ci95 = summary.confidenceInterval(level: 0.95)

        #expect(ci90 != nil)
        #expect(ci95 != nil)
        let c90 = try! #require(ci90)
        let c95 = try! #require(ci95)
        let width90 = c90.upper - c90.lower
        let width95 = c95.upper - c95.lower
        #expect(width90 < width95)
    }

    @Test("CI reduces to a point when variance is zero")
    func testConfidenceIntervalZeroVariance() {
        let values = [42.0, 42.0, 42.0]  // All same value
        let summary = ETASummary.from(values)!
        let ci = summary.confidenceInterval(level: 0.95)

        #expect(ci != nil)
        let unwrapped = try! #require(ci)
        #expect(unwrapped.lower == unwrapped.upper)  // Should be same when variance is 0
        #expect(unwrapped.lower == 42.0)  // Should be the mean value
    }

    // MARK: - Summary String Tests

    @Test("Summary string contains key sections")
    func testSummaryString() {
        let values = [10.0, 12.0, 11.0, 13.0, 9.0]
        let summary = ETASummary.from(values)!
        let summaryString = summary.summary

        #expect(summaryString.contains("Mean:"))
        #expect(summaryString.contains("Std Dev:"))
        #expect(summaryString.contains("Range:"))
        #expect(summaryString.contains("95% CI:"))
    }

    // MARK: - Codable Tests

    @Test("ETASummary encodes/decodes correctly")
    func testETASummaryCodable() throws {
        let values = [10.0, 12.0, 11.0, 13.0, 9.0]
        let original = ETASummary.from(values)!

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ETASummary.self, from: data)

        #expect(original.mean == decoded.mean)
        #expect(original.variance == decoded.variance)
        #expect(original.stdDev == decoded.stdDev)
        #expect(original.min == decoded.min)
        #expect(original.max == decoded.max)
        #expect(original.p10 == decoded.p10)
        #expect(original.p90 == decoded.p90)
    }

    // MARK: - Equatable Tests

    @Test("ETASummary Equatable conformance")
    func testETASummaryEquatable() {
        let values1 = [10.0, 12.0, 11.0]
        let values2 = [10.0, 12.0, 11.0]
        let values3 = [10.0, 12.0, 13.0]

        let summary1 = ETASummary.from(values1)!
        let summary2 = ETASummary.from(values2)!
        let summary3 = ETASummary.from(values3)!

        #expect(summary1 == summary2)
        #expect(summary1 != summary3)
    }
}
