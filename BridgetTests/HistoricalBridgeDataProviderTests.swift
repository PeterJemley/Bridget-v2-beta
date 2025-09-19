//
//  HistoricalBridgeDataProviderTests.swift
//  BridgetTests
//

import Foundation
import Testing

@testable import Bridget

@Suite("Historical Bridge Data Provider Tests")
struct HistoricalBridgeDataProviderTests {
    // MARK: - Simple Debug Tests

    @Test("BaselinePredictor simple defaults and support checks")
    func simpleBaselinePredictor() {
        let provider = MockHistoricalBridgeDataProvider()
        let predictor = BaselinePredictor(historicalProvider: provider)

        #expect(
            predictor.defaultProbability == 0.1,
            "Default probability should be 0.1"
        )
        #expect(predictor.maxBatchSize == 100)
        #expect(predictor.supports(bridgeID: "unknown") == false)
    }

    @Test("DateBucket basic construction")
    func simpleDateBucket() {
        let bucket = DateBucket(hour: 14, minute: 20, isWeekend: false)
        #expect(bucket.hour == 14)
        #expect(bucket.minute == 20)
        #expect(bucket.isWeekend == false)
    }

    @Test("BridgeOpeningStats raw and smoothed probabilities")
    func simpleBridgeOpeningStats() {
        let stats = BridgeOpeningStats(openCount: 3, totalCount: 10)
        #expect(abs(stats.rawProbability - 0.3) < 0.001)
        #expect(
            abs(stats.smoothedProbability(alpha: 1.0, beta: 9.0) - 0.2) < 0.001
        )
    }

    @Test("Mock provider basic set/get")
    func simpleMockProvider() {
        let provider = MockHistoricalBridgeDataProvider()

        let bucket = DateBucket(hour: 14, minute: 20, isWeekend: false)
        let stats = BridgeOpeningStats(
            openCount: 3,
            totalCount: 10,
            sampleCount: 10
        )

        provider.setMockStats(bridgeID: "ballard", bucket: bucket, stats: stats)

        let retrievedStats = provider.getOpeningStats(
            bridgeID: "ballard",
            bucket: bucket
        )
        #expect(retrievedStats != nil)
        #expect(retrievedStats?.openCount == 3)
        #expect(retrievedStats?.totalCount == 10)
    }

    @Test("BaselinePredictor default probability without historical data")
    func simplePrediction() {
        let provider = MockHistoricalBridgeDataProvider()
        let predictor = BaselinePredictor(historicalProvider: provider)

        // Bridge with no historical data should use defaultProbability
        let probability = predictor.predictOpenProbability(
            for: "unknown_bridge",
            at: Date()
        )
        #expect(abs(probability - 0.1) < 0.001)
    }
}
