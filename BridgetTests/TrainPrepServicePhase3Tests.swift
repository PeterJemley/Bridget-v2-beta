//
//  TrainPrepServicePhase3Tests.swift
//  BridgetTests
//
//  Tests for Phase 3 statistical metrics functionality in TrainPrepService
//

import Foundation
import Testing

@testable import Bridget

@Suite("TrainPrepService Phase 3 Tests")
struct TrainPrepServicePhase3Tests {
    private var service: TrainPrepService

    init() {
        self.service = TrainPrepService()
    }

    // MARK: - StatisticalTrainingMetrics Tests

    @Test("StatisticalTrainingMetrics creation")
    func statisticalTrainingMetricsCreation() throws {
        let trainingLossStats = ETASummary(
            mean: 0.1,
            variance: 0.01,
            min: 0.05,
            max: 0.15
        )
        let validationLossStats = ETASummary(
            mean: 0.12,
            variance: 0.015,
            min: 0.06,
            max: 0.18
        )
        let predictionAccuracyStats = ETASummary(
            mean: 0.85,
            variance: 0.001,
            min: 0.82,
            max: 0.88
        )
        let etaPredictionVariance = ETASummary(
            mean: 300.0,
            variance: 900.0,
            min: 240.0,
            max: 360.0
        )

        let confidenceIntervals = PerformanceConfidenceIntervals(
            accuracy95CI: ConfidenceInterval(lower: 0.82, upper: 0.88),
            f1Score95CI: ConfidenceInterval(lower: 0.80, upper: 0.86),
            meanError95CI: ConfidenceInterval(lower: 0.0, upper: 0.1)
        )

        let errorDistribution = ErrorDistributionMetrics(
            absoluteErrorStats: ETASummary(
                mean: 0.05,
                variance: 0.001,
                min: 0.0,
                max: 0.15
            ),
            relativeErrorStats: ETASummary(
                mean: 5.0,
                variance: 1.0,
                min: 0.0,
                max: 15.0
            ),
            withinOneStdDev: 68.0,
            withinTwoStdDev: 95.0
        )

        let metrics = StatisticalTrainingMetrics(
            trainingLossStats: trainingLossStats,
            validationLossStats: validationLossStats,
            predictionAccuracyStats: predictionAccuracyStats,
            etaPredictionVariance: etaPredictionVariance,
            performanceConfidenceIntervals: confidenceIntervals,
            errorDistribution: errorDistribution
        )

        #expect(metrics.trainingLossStats.mean == 0.1)
        #expect(metrics.validationLossStats.mean == 0.12)
        #expect(metrics.predictionAccuracyStats.mean == 0.85)
        #expect(metrics.etaPredictionVariance.mean == 300.0)
        #expect(
            metrics.performanceConfidenceIntervals.accuracy95CI.lower == 0.82
        )
        #expect(
            metrics.performanceConfidenceIntervals.accuracy95CI.upper == 0.88
        )
        #expect(metrics.errorDistribution.withinOneStdDev == 68.0)
        #expect(metrics.errorDistribution.withinTwoStdDev == 95.0)
    }

    // MARK: - PerformanceConfidenceIntervals Tests

    @Test("PerformanceConfidenceIntervals creation")
    func performanceConfidenceIntervalsCreation() throws {
        let intervals = PerformanceConfidenceIntervals(
            accuracy95CI: ConfidenceInterval(lower: 0.80, upper: 0.90),
            f1Score95CI: ConfidenceInterval(lower: 0.75, upper: 0.85),
            meanError95CI: ConfidenceInterval(lower: 0.0, upper: 0.05)
        )

        #expect(intervals.accuracy95CI.lower == 0.80)
        #expect(intervals.accuracy95CI.upper == 0.90)
        #expect(intervals.f1Score95CI.lower == 0.75)
        #expect(intervals.f1Score95CI.upper == 0.85)
        #expect(intervals.meanError95CI.lower == 0.0)
        #expect(intervals.meanError95CI.upper == 0.05)
    }

    // MARK: - ErrorDistributionMetrics Tests

    @Test("ErrorDistributionMetrics creation")
    func errorDistributionMetricsCreation() throws {
        let absoluteErrorStats = ETASummary(
            mean: 0.03,
            variance: 0.0009,
            min: 0.0,
            max: 0.08
        )
        let relativeErrorStats = ETASummary(
            mean: 3.0,
            variance: 0.5,
            min: 0.0,
            max: 8.0
        )

        let errorDistribution = ErrorDistributionMetrics(
            absoluteErrorStats: absoluteErrorStats,
            relativeErrorStats: relativeErrorStats,
            withinOneStdDev: 70.0,
            withinTwoStdDev: 96.0
        )

        #expect(errorDistribution.absoluteErrorStats.mean == 0.03)
        #expect(errorDistribution.relativeErrorStats.mean == 3.0)
        #expect(errorDistribution.withinOneStdDev == 70.0)
        #expect(errorDistribution.withinTwoStdDev == 96.0)
    }

    // MARK: - ConfidenceInterval Tests

    @Test("ConfidenceInterval creation")
    func confidenceIntervalCreation() throws {
        let interval = ConfidenceInterval(lower: 0.75, upper: 0.85)

        #expect(interval.lower == 0.75)
        #expect(interval.upper == 0.85)
    }

    @Test("ConfidenceInterval Equatable conformance")
    func confidenceIntervalEquality() throws {
        let interval1 = ConfidenceInterval(lower: 0.75, upper: 0.85)
        let interval2 = ConfidenceInterval(lower: 0.75, upper: 0.85)
        let interval3 = ConfidenceInterval(lower: 0.80, upper: 0.85)

        #expect(interval1 == interval2)
        #expect(interval1 != interval3)
    }

    // MARK: - Codable Tests

    @Test("StatisticalTrainingMetrics Codable round-trip")
    func statisticalTrainingMetricsCodable() throws {
        let trainingLossStats = ETASummary(
            mean: 0.1,
            variance: 0.01,
            min: 0.05,
            max: 0.15
        )
        let validationLossStats = ETASummary(
            mean: 0.12,
            variance: 0.015,
            min: 0.06,
            max: 0.18
        )
        let predictionAccuracyStats = ETASummary(
            mean: 0.85,
            variance: 0.001,
            min: 0.82,
            max: 0.88
        )
        let etaPredictionVariance = ETASummary(
            mean: 300.0,
            variance: 900.0,
            min: 240.0,
            max: 360.0
        )

        let confidenceIntervals = PerformanceConfidenceIntervals(
            accuracy95CI: ConfidenceInterval(lower: 0.82, upper: 0.88),
            f1Score95CI: ConfidenceInterval(lower: 0.80, upper: 0.86),
            meanError95CI: ConfidenceInterval(lower: 0.0, upper: 0.1)
        )

        let errorDistribution = ErrorDistributionMetrics(
            absoluteErrorStats: ETASummary(
                mean: 0.05,
                variance: 0.001,
                min: 0.0,
                max: 0.15
            ),
            relativeErrorStats: ETASummary(
                mean: 5.0,
                variance: 1.0,
                min: 0.0,
                max: 15.0
            ),
            withinOneStdDev: 68.0,
            withinTwoStdDev: 95.0
        )

        let originalMetrics = StatisticalTrainingMetrics(
            trainingLossStats: trainingLossStats,
            validationLossStats: validationLossStats,
            predictionAccuracyStats: predictionAccuracyStats,
            etaPredictionVariance: etaPredictionVariance,
            performanceConfidenceIntervals: confidenceIntervals,
            errorDistribution: errorDistribution
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalMetrics)

        let decoder = JSONDecoder()
        let decodedMetrics = try decoder.decode(
            StatisticalTrainingMetrics.self,
            from: data
        )

        #expect(
            originalMetrics.trainingLossStats.mean
                == decodedMetrics.trainingLossStats.mean
        )
        #expect(
            originalMetrics.validationLossStats.mean
                == decodedMetrics.validationLossStats.mean
        )
        #expect(
            originalMetrics.predictionAccuracyStats.mean
                == decodedMetrics.predictionAccuracyStats.mean
        )
        #expect(
            originalMetrics.etaPredictionVariance.mean
                == decodedMetrics.etaPredictionVariance.mean
        )
        #expect(
            originalMetrics.performanceConfidenceIntervals.accuracy95CI.lower
                == decodedMetrics.performanceConfidenceIntervals.accuracy95CI
                .lower
        )
        #expect(
            originalMetrics.performanceConfidenceIntervals.accuracy95CI.upper
                == decodedMetrics.performanceConfidenceIntervals.accuracy95CI
                .upper
        )
        #expect(
            originalMetrics.errorDistribution.withinOneStdDev
                == decodedMetrics.errorDistribution.withinOneStdDev
        )
        #expect(
            originalMetrics.errorDistribution.withinTwoStdDev
                == decodedMetrics.errorDistribution.withinTwoStdDev
        )
    }

    @Test("ConfidenceInterval Codable round-trip")
    func confidenceIntervalCodable() throws {
        let originalInterval = ConfidenceInterval(lower: 0.75, upper: 0.85)

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalInterval)

        let decoder = JSONDecoder()
        let decodedInterval = try decoder.decode(
            ConfidenceInterval.self,
            from: data
        )

        #expect(originalInterval.lower == decodedInterval.lower)
        #expect(originalInterval.upper == decodedInterval.upper)
    }
}
