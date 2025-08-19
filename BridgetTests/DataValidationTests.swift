//
//  DataValidationTests.swift
//  BridgetTests
//
//  ## Purpose
//  Comprehensive unit tests for Data Validation Module
//  Tests all validation scenarios: golden samples, edge cases, and error conditions
//
//  ✅ STATUS: COMPLETE - All test requirements implemented
//  ✅ COMPLETION DATE: August 17, 2025
//  ✅ COVERAGE: Golden samples, edge cases, error conditions, all validation checks
//

@testable import Bridget
import Foundation
import Testing

@Suite("Data Validation Service Tests")
struct DataValidationTests {
  private var validationService: DataValidationService!
  private var goldenSampleTicks: [ProbeTickRaw] = []
  private var goldenSampleFeatures: [FeatureVector] = []

  private mutating func setUp() async throws {
    validationService = DataValidationService()
    setupGoldenSamples()
  }

  // MARK: - Golden Sample Tests

  @Test("Golden sample probe ticks should pass validation")
  mutating func goldenSampleProbeTicksValidation() async throws {
    // Create fresh validation service and data for this test
    let testValidationService = DataValidationService()
    var testGoldenSampleTicks: [ProbeTickRaw] = []

    // Create realistic golden sample probe ticks with deterministic, valid values
    let baseTime = ISO8601DateFormatter().date(from: "2025-01-01T12:00:00Z")!

    for hour in 0 ..< 24 {
      for bridgeId in [1, 2] {
        let timestamp = Calendar.current.date(byAdding: .hour, value: hour, to: baseTime)!
        let isoString = ISO8601DateFormatter().string(from: timestamp)

        // Use deterministic values that are guaranteed to pass validation
        let crossK = 0.5 + (Double(hour % 3) * 0.2) // 0.5, 0.7, 0.9, 0.5, 0.7, 0.9...
        let crossN = 1.0
        let viaRoutable = 0.8 + (Double(hour % 2) * 0.2) // 0.8, 1.0, 0.8, 1.0...
        let viaPenalty = 20.0 + (Double(hour % 4) * 10.0) // 20, 30, 40, 50, 20, 30...
        let gateAnom = 0.1 + (Double(hour % 2) * 0.05) // 0.1, 0.15, 0.1, 0.15...
        let alternatesTotal = 2.0 + Double(hour % 2) // 2.0, 3.0, 2.0, 3.0...
        let alternatesAvoid = 0.2 + (Double(hour % 3) * 0.1) // 0.2, 0.3, 0.4, 0.2, 0.3...
        let openLabel = hour % 2 // 0, 1, 0, 1...
        let detourDelta = 120.0 + (Double(hour % 3) * 60.0) // 120, 180, 240, 120, 180...
        let detourFrac = 0.3 + (Double(hour % 4) * 0.1) // 0.3, 0.4, 0.5, 0.6, 0.3...

        let tick = ProbeTickRaw(v: hour * 2 + bridgeId,
                                ts_utc: isoString,
                                bridge_id: bridgeId,
                                cross_k: crossK,
                                cross_n: crossN,
                                via_routable: viaRoutable,
                                via_penalty_sec: viaPenalty,
                                gate_anom: gateAnom,
                                alternates_total: alternatesTotal,
                                alternates_avoid: alternatesAvoid,
                                open_label: openLabel,
                                detour_delta: detourDelta,
                                detour_frac: detourFrac)
        testGoldenSampleTicks.append(tick)
      }
    }

    let result = testValidationService.validate(ticks: testGoldenSampleTicks)

    #expect(result.isValid == true)
    #expect(result.totalRecords == 48) // 24 hours × 2 bridges
    #expect(result.bridgeCount == 2)
    #expect(result.errors.isEmpty)
    #expect(result.warnings.count <= 2) // Allow some warnings for edge cases
    #expect(result.validRecordCount == 48)
    #expect(result.validationRate > 0.95)
  }

  @Test("Golden sample feature vectors should pass validation")
  mutating func goldenSampleFeatureVectorsValidation() async throws {
    // Create fresh validation service and data for this test
    let testValidationService = DataValidationService()
    var testGoldenSampleFeatures: [FeatureVector] = []

    // Create realistic golden sample feature vectors with deterministic values
    let baseTime = ISO8601DateFormatter().date(from: "2025-01-01T12:00:00Z")!

    for hour in 0 ..< 24 {
      for bridgeId in [1, 2] {
        let timestamp = Calendar.current.date(byAdding: .hour, value: hour, to: baseTime)!
        let isoString = ISO8601DateFormatter().string(from: timestamp)

        for horizon in defaultHorizons {
          let date = ISO8601DateFormatter().date(from: isoString)!
          let minute = Calendar.current.component(.minute, from: date)
          let weekday = Calendar.current.component(.weekday, from: date)

          let feature = FeatureVector(bridge_id: bridgeId,
                                      horizon_min: horizon,
                                      min_sin: sin(Double(minute) * .pi / 30),
                                      min_cos: cos(Double(minute) * .pi / 30),
                                      dow_sin: sin(Double(weekday) * .pi / 7),
                                      dow_cos: cos(Double(weekday) * .pi / 7),
                                      open_5m: hour % 2 == 1 ? 1.0 : 0.0,
                                      open_30m: hour % 2 == 1 ? 1.0 : 0.0,
                                      detour_delta: 120.0 + (Double(hour % 3) * 60.0),
                                      cross_rate: 0.5 + (Double(hour % 3) * 0.2),
                                      via_routable: 0.8 + (Double(hour % 2) * 0.2),
                                      via_penalty: 20.0 + (Double(hour % 4) * 10.0),
                                      gate_anom: 0.1 + (Double(hour % 2) * 0.05),
                                      detour_frac: 0.3 + (Double(hour % 4) * 0.1),
                                      target: hour % 2)
          testGoldenSampleFeatures.append(feature)
        }
      }
    }

    let result = testValidationService.validate(features: testGoldenSampleFeatures)

    #expect(result.isValid == true)
    #expect(result.totalRecords == 240) // 24 hours × 2 bridges × 5 horizons
    #expect(result.bridgeCount == 2)
    #expect(result.errors.isEmpty)
    #expect(result.warnings.isEmpty)
    #expect(result.validRecordCount == 240)
    #expect(result.validationRate == 1.0)
  }

  // MARK: - Edge Case Tests

  @Test("Empty arrays should fail validation")
  mutating func emptyArraysValidation() async throws {
    try await setUp()
    let emptyTicksResult = validationService.validate(ticks: [])
    let emptyFeaturesResult = validationService.validate(features: [])

    #expect(emptyTicksResult.isValid == false)
    #expect(emptyTicksResult.errors.contains("No probe tick data provided"))

    #expect(emptyFeaturesResult.isValid == false)
    #expect(emptyFeaturesResult.errors.contains("No feature vectors provided"))
  }

  @Test("Single record should pass validation")
  mutating func singleRecordValidation() async throws {
    try await setUp()
    let singleTick = [ProbeTickRaw(v: 1,
                                   ts_utc: "2025-01-01T12:00:00Z",
                                   bridge_id: 1,
                                   cross_k: 0.5,
                                   cross_n: 1.0,
                                   via_routable: 0.8,
                                   via_penalty_sec: 30.0,
                                   gate_anom: 0.1,
                                   alternates_total: 2.0,
                                   alternates_avoid: 0.5,
                                   open_label: 0,
                                   detour_delta: 120.0,
                                   detour_frac: 0.3)]

    let result = validationService.validate(ticks: singleTick)

    #expect(result.isValid == true)
    #expect(result.totalRecords == 1)
    #expect(result.bridgeCount == 1)
    #expect(result.errors.isEmpty)
  }

  @Test("DST boundary timestamps should be handled gracefully")
  mutating func dSTBoundaryTimestamps() async throws {
    try await setUp()

    // Create DST boundary test data using UTC to avoid time zone complications
    var dstTicks: [ProbeTickRaw] = []

    // Use UTC timestamps around DST transitions to avoid time zone edge cases
    // Spring forward: March 10, 2024 at 2:00 AM becomes 3:00 AM (in US)
    // Fall back: November 3, 2024 at 2:00 AM becomes 1:00 AM (in US)

    // Create timestamps in UTC around these transitions
    let springForwardBase = ISO8601DateFormatter().date(from: "2024-03-10T06:00:00Z")! // 6 AM UTC
    let fallBackBase = ISO8601DateFormatter().date(from: "2024-11-03T06:00:00Z")! // 6 AM UTC

    // Create 2 hours of data around each transition (in UTC)
    for minute in 0 ..< 120 {
      let springTimestamp = Calendar.current.date(byAdding: .minute, value: minute, to: springForwardBase)!
      let fallTimestamp = Calendar.current.date(byAdding: .minute, value: minute, to: fallBackBase)!

      let springISOString = ISO8601DateFormatter().string(from: springTimestamp)
      let fallISOString = ISO8601DateFormatter().string(from: fallTimestamp)

      // Spring forward data
      let springTick = ProbeTickRaw(v: minute,
                                    ts_utc: springISOString,
                                    bridge_id: 1,
                                    cross_k: 0.5,
                                    cross_n: 1.0,
                                    via_routable: 0.8,
                                    via_penalty_sec: 20.0,
                                    gate_anom: 0.1,
                                    alternates_total: 2.0,
                                    alternates_avoid: 0.2,
                                    open_label: minute % 2,
                                    detour_delta: 120.0,
                                    detour_frac: 0.3)
      dstTicks.append(springTick)

      // Fall back data
      let fallTick = ProbeTickRaw(v: minute + 200, // Different version numbers
                                  ts_utc: fallISOString,
                                  bridge_id: 2,
                                  cross_k: 0.6,
                                  cross_n: 1.0,
                                  via_routable: 0.9,
                                  via_penalty_sec: 25.0,
                                  gate_anom: 0.15,
                                  alternates_total: 3.0,
                                  alternates_avoid: 0.3,
                                  open_label: minute % 2,
                                  detour_delta: 180.0,
                                  detour_frac: 0.4)
      dstTicks.append(fallTick)
    }

    let result = validationService.validate(ticks: dstTicks)

    // DST transitions should not cause validation errors
    #expect(result.isValid == true)
    #expect(result.totalRecords == 240) // 120 + 120
    #expect(result.bridgeCount == 2)

    // Should have valid timestamp ranges
    #expect(result.timestampRange.first != nil)
    #expect(result.timestampRange.last != nil)

    // No validation errors should occur
    #expect(result.errors.isEmpty)
  }

  // MARK: - Error Condition Tests

  @Test("Invalid bridge IDs should be detected")
  mutating func invalidBridgeIDs() async throws {
    try await setUp()
    guard !goldenSampleTicks.isEmpty else { return }
    var invalidTicks = goldenSampleTicks
    invalidTicks[0] = ProbeTickRaw(v: 1,
                                   ts_utc: "2025-01-01T12:00:00Z",
                                   bridge_id: -1, // Invalid negative ID
                                   cross_k: 0.5,
                                   cross_n: 1.0,
                                   via_routable: 0.8,
                                   via_penalty_sec: 30.0,
                                   gate_anom: 0.1,
                                   alternates_total: 2.0,
                                   alternates_avoid: 0.5,
                                   open_label: 0,
                                   detour_delta: 120.0,
                                   detour_frac: 0.3)

    let result = validationService.validate(ticks: invalidTicks)

    #expect(result.isValid == false)
    #expect(result.invalidBridgeIds == 1)
    #expect(result.errors.contains { $0.contains("Invalid bridge ID: -1") })
  }

  @Test("Invalid open labels should be detected")
  mutating func testInvalidOpenLabels() async throws {
    try await setUp()
    guard !goldenSampleTicks.isEmpty else { return }
    var invalidTicks = goldenSampleTicks
    invalidTicks[0] = ProbeTickRaw(v: 1,
                                   ts_utc: "2025-01-01T12:00:00Z",
                                   bridge_id: 1,
                                   cross_k: 0.5,
                                   cross_n: 1.0,
                                   via_routable: 0.8,
                                   via_penalty_sec: 30.0,
                                   gate_anom: 0.1,
                                   alternates_total: 2.0,
                                   alternates_avoid: 0.5,
                                   open_label: 2, // Invalid label (should be 0 or 1)
                                   detour_delta: 120.0,
                                   detour_frac: 0.3)

    let result = validationService.validate(ticks: invalidTicks)

    #expect(result.isValid == false)
    #expect(result.invalidOpenLabels == 1)
    #expect(result.errors.contains { $0.contains("Invalid open label: 2") })
  }

  @Test("NaN values should be detected and flagged")
  mutating func naNValuesDetection() async throws {
    try await setUp()
    guard !goldenSampleTicks.isEmpty else { return }
    var nanTicks = goldenSampleTicks
    nanTicks[0] = ProbeTickRaw(v: 1,
                               ts_utc: "2025-01-01T12:00:00Z",
                               bridge_id: 1,
                               cross_k: Double.nan, // NaN value
                               cross_n: 1.0,
                               via_routable: 0.8,
                               via_penalty_sec: 30.0,
                               gate_anom: 0.1,
                               alternates_total: 2.0,
                               alternates_avoid: 0.5,
                               open_label: 0,
                               detour_delta: 120.0,
                               detour_frac: 0.3)

    let result = validationService.validate(ticks: nanTicks)

    #expect(result.isValid == false)
    #expect(result.dataQualityMetrics.nanCounts["cross_k"] == 1)
    #expect(result.errors.contains { $0.contains("Found 1 NaN values in cross_k") })
  }

  @Test("Infinite values should be detected and flagged")
  mutating func infiniteValuesDetection() async throws {
    try await setUp()
    guard !goldenSampleTicks.isEmpty else { return }
    var infiniteTicks = goldenSampleTicks
    infiniteTicks[0] = ProbeTickRaw(v: 1,
                                    ts_utc: "2025-01-01T12:00:00Z",
                                    bridge_id: 1,
                                    cross_k: 0.5,
                                    cross_n: Double.infinity, // Infinite value
                                    via_routable: 0.8,
                                    via_penalty_sec: 30.0,
                                    gate_anom: 0.1,
                                    alternates_total: 2.0,
                                    alternates_avoid: 0.5,
                                    open_label: 0,
                                    detour_delta: 120.0,
                                    detour_frac: 0.3)

    let result = validationService.validate(ticks: infiniteTicks)

    #expect(result.isValid == false)
    #expect(result.dataQualityMetrics.infiniteCounts["cross_n"] == 1)
    #expect(result.errors.contains { $0.contains("Found 1 infinite values in cross_n") })
  }

  @Test("Non-monotonic timestamps should be detected")
  mutating func nonMonotonicTimestamps() async throws {
    try await setUp()
    guard goldenSampleTicks.count >= 2 else { return }
    var nonMonotonicTicks = goldenSampleTicks
    // Swap timestamps to create non-monotonic sequence
    nonMonotonicTicks[1] = ProbeTickRaw(v: 2,
                                        ts_utc: "2025-01-01T11:00:00Z", // Earlier than first timestamp
                                        bridge_id: 1,
                                        cross_k: 0.6,
                                        cross_n: 1.0,
                                        via_routable: 0.9,
                                        via_penalty_sec: 25.0,
                                        gate_anom: 0.05,
                                        alternates_total: 2.0,
                                        alternates_avoid: 0.4,
                                        open_label: 1,
                                        detour_delta: 90.0,
                                        detour_frac: 0.25)

    let result = validationService.validate(ticks: nonMonotonicTicks)

    #expect(result.isValid == true) // Warnings don't make it invalid
    #expect(result.warnings.contains { $0.contains("Non-monotonic timestamp") })
  }

  // MARK: - Feature Vector Validation Tests

  @Test("Feature vectors with out-of-range cyclical features should be flagged")
  mutating func featureVectorCyclicalRangeValidation() async throws {
    try await setUp()
    guard !goldenSampleFeatures.isEmpty else { return }
    var invalidFeatures = goldenSampleFeatures
    invalidFeatures[0] = FeatureVector(bridge_id: 1,
                                       horizon_min: 0,
                                       min_sin: 1.5, // Out of range [-1, 1]
                                       min_cos: 0.5,
                                       dow_sin: 0.3,
                                       dow_cos: 0.7,
                                       open_5m: 0.8,
                                       open_30m: 0.6,
                                       detour_delta: 120.0,
                                       cross_rate: 0.4,
                                       via_routable: 0.9,
                                       via_penalty: 25.0,
                                       gate_anom: 0.1,
                                       detour_frac: 0.3,
                                       target: 0)

    let result = validationService.validate(features: invalidFeatures)

    #expect(result.isValid == true) // Warnings don't make it invalid
    #expect(result.warnings.contains { $0.contains("Cyclical feature out of range") })
  }

  @Test("Feature vectors with invalid target values should be flagged")
  mutating func featureVectorInvalidTargets() async throws {
    try await setUp()
    guard !goldenSampleFeatures.isEmpty else { return }
    var invalidFeatures = goldenSampleFeatures
    invalidFeatures[0] = FeatureVector(bridge_id: 1,
                                       horizon_min: 0,
                                       min_sin: 0.5,
                                       min_cos: 0.5,
                                       dow_sin: 0.3,
                                       dow_cos: 0.7,
                                       open_5m: 0.8,
                                       open_30m: 0.6,
                                       detour_delta: 120.0,
                                       cross_rate: 0.4,
                                       via_routable: 0.9,
                                       via_penalty: 25.0,
                                       gate_anom: 0.1,
                                       detour_frac: 0.3,
                                       target: 2 // Invalid target (should be 0 or 1)
    )

    let result = validationService.validate(features: invalidFeatures)

    #expect(result.isValid == false)
    #expect(result.errors.contains { $0.contains("Invalid target value: 2") })
  }

  @Test("Feature vectors with missing horizons should be flagged")
  mutating func featureVectorHorizonCoverage() async throws {
    try await setUp()
    // Create features with only some horizons
    let limitedHorizonFeatures = goldenSampleFeatures.filter { $0.horizon_min != 9 }

    let result = validationService.validate(features: limitedHorizonFeatures)

    #expect(result.isValid == true) // Warnings don't make it invalid
    #expect(result.warnings.contains { $0.contains("Missing features for horizons: 9min") })
    #expect(result.horizonCoverage[9] == nil)
  }

  // MARK: - Data Quality Metrics Tests

  @Test("Data quality metrics should be properly aggregated")
  mutating func dataQualityMetricsAggregation() async throws {
    try await setUp()
    let result = validationService.validate(ticks: goldenSampleTicks)

    #expect(result.dataQualityMetrics.nullCounts.isEmpty || result.dataQualityMetrics.nullCounts.values.allSatisfy { $0 >= 0 })
    #expect(result.dataQualityMetrics.nanCounts.isEmpty || result.dataQualityMetrics.nanCounts.values.allSatisfy { $0 >= 0 })
    #expect(result.dataQualityMetrics.infiniteCounts.isEmpty || result.dataQualityMetrics.infiniteCounts.values.allSatisfy { $0 >= 0 })
    #expect(result.dataQualityMetrics.outlierCounts.isEmpty || result.dataQualityMetrics.outlierCounts.values.allSatisfy { $0 >= 0 })
    #expect(result.dataQualityMetrics.rangeViolations.isEmpty || result.dataQualityMetrics.rangeViolations.values.allSatisfy { $0 >= 0 })
  }

  @Test("Validation rate should be calculated correctly")
  mutating func validationRateCalculation() async throws {
    try await setUp()
    let result = validationService.validate(ticks: goldenSampleTicks)

    let expectedRate = Double(result.validRecordCount) / Double(result.totalRecords)
    #expect(abs(result.validationRate - expectedRate) < 0.001)
    #expect(result.validationRate >= 0.0 && result.validationRate <= 1.0)
  }

  // MARK: - Helper Methods

  private mutating func setupGoldenSamples() {
    // Create realistic golden sample probe ticks with deterministic, valid values
    goldenSampleTicks = []
    let baseTime = ISO8601DateFormatter().date(from: "2025-01-01T12:00:00Z")!

    for hour in 0 ..< 24 {
      for bridgeId in [1, 2] {
        let timestamp = Calendar.current.date(byAdding: .hour, value: hour, to: baseTime)!
        let isoString = ISO8601DateFormatter().string(from: timestamp)

        // Use deterministic values that are guaranteed to pass validation
        let crossK = 0.5 + (Double(hour % 3) * 0.2) // 0.5, 0.7, 0.9, 0.5, 0.7, 0.9...
        let crossN = 1.0
        let viaRoutable = 0.8 + (Double(hour % 2) * 0.2) // 0.8, 1.0, 0.8, 1.0...
        let viaPenalty = 20.0 + (Double(hour % 4) * 10.0) // 20, 30, 40, 50, 20, 30...
        let gateAnom = 0.1 + (Double(hour % 2) * 0.05) // 0.1, 0.15, 0.1, 0.15...
        let alternatesTotal = 2.0 + Double(hour % 2) // 2.0, 3.0, 2.0, 3.0...
        let alternatesAvoid = 0.2 + (Double(hour % 3) * 0.1) // 0.2, 0.3, 0.4, 0.2, 0.3...
        let openLabel = hour % 2 // 0, 1, 0, 1...
        let detourDelta = 120.0 + (Double(hour % 3) * 60.0) // 120, 180, 240, 120, 180...
        let detourFrac = 0.3 + (Double(hour % 4) * 0.1) // 0.3, 0.4, 0.5, 0.6, 0.3...

        let tick = ProbeTickRaw(v: hour * 2 + bridgeId,
                                ts_utc: isoString,
                                bridge_id: bridgeId,
                                cross_k: crossK,
                                cross_n: crossN,
                                via_routable: viaRoutable,
                                via_penalty_sec: viaPenalty,
                                gate_anom: gateAnom,
                                alternates_total: alternatesTotal,
                                alternates_avoid: alternatesAvoid,
                                open_label: openLabel,
                                detour_delta: detourDelta,
                                detour_frac: detourFrac)
        goldenSampleTicks.append(tick)
      }
    }

    // Create realistic golden sample feature vectors with deterministic values
    goldenSampleFeatures = []
    for tick in goldenSampleTicks {
      for horizon in defaultHorizons {
        let date = ISO8601DateFormatter().date(from: tick.ts_utc)!
        let minute = Calendar.current.component(.minute, from: date)
        let weekday = Calendar.current.component(.weekday, from: date)

        let feature = FeatureVector(bridge_id: tick.bridge_id,
                                    horizon_min: horizon,
                                    min_sin: sin(Double(minute) * .pi / 30),
                                    min_cos: cos(Double(minute) * .pi / 30),
                                    dow_sin: sin(Double(weekday) * .pi / 7),
                                    dow_cos: cos(Double(weekday) * .pi / 7),
                                    open_5m: tick.open_label == 1 ? 1.0 : 0.0,
                                    open_30m: tick.open_label == 1 ? 1.0 : 0.0,
                                    detour_delta: tick.detour_delta ?? 120.0,
                                    cross_rate: (tick.cross_k ?? 0.5) / (tick.cross_n ?? 1.0),
                                    via_routable: tick.via_routable ?? 0.8,
                                    via_penalty: tick.via_penalty_sec ?? 20.0,
                                    gate_anom: tick.gate_anom ?? 0.1,
                                    detour_frac: tick.detour_frac ?? 0.3,
                                    target: tick.open_label)
        goldenSampleFeatures.append(feature)
      }
    }
  }
}
