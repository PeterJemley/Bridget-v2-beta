//
//  HistoricalBridgeDataProviderTests.swift
//  BridgetTests
//

import XCTest

@testable import Bridget

final class HistoricalBridgeDataProviderTests: XCTestCase {
  // MARK: - Simple Debug Tests

  func testSimpleBaselinePredictor() {
    let provider = MockHistoricalBridgeDataProvider()
    let predictor = BaselinePredictor(historicalProvider: provider)

    // Test basic functionality
    XCTAssertEqual(predictor.defaultProbability, 0.1, accuracy: 0.001)
    XCTAssertEqual(predictor.maxBatchSize, 100)
    XCTAssertFalse(predictor.supports(bridgeID: "unknown"))
  }

  func testSimpleDateBucket() {
    let bucket = DateBucket(hour: 14, minute: 20, isWeekend: false)
    XCTAssertEqual(bucket.hour, 14)
    XCTAssertEqual(bucket.minute, 20)
    XCTAssertFalse(bucket.isWeekend)
  }

  func testSimpleBridgeOpeningStats() {
    let stats = BridgeOpeningStats(openCount: 3, totalCount: 10)
    XCTAssertEqual(stats.rawProbability, 0.3, accuracy: 0.001)
    XCTAssertEqual(stats.smoothedProbability(alpha: 1.0, beta: 9.0), 0.2, accuracy: 0.001)
  }

  func testSimpleMockProvider() {
    let provider = MockHistoricalBridgeDataProvider()

    let bucket = DateBucket(hour: 14, minute: 20, isWeekend: false)
    let stats = BridgeOpeningStats(openCount: 3, totalCount: 10, sampleCount: 10)

    provider.setMockStats(bridgeID: "ballard", bucket: bucket, stats: stats)

    let retrievedStats = provider.getOpeningStats(bridgeID: "ballard", bucket: bucket)
    XCTAssertNotNil(retrievedStats)
    XCTAssertEqual(retrievedStats?.openCount, 3)
    XCTAssertEqual(retrievedStats?.totalCount, 10)
  }

  func testSimplePrediction() {
    let provider = MockHistoricalBridgeDataProvider()
    let predictor = BaselinePredictor(historicalProvider: provider)

    // Test bridge with no historical data
    let probability = predictor.predictOpenProbability(for: "unknown_bridge", at: Date())
    XCTAssertEqual(probability, 0.1, accuracy: 0.001)  // Default probability
  }
}
