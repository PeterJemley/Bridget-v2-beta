//
//  CoreMLTrainingPhase3Tests.swift
//  BridgetTests
//
//  Tests for Phase 3 statistical variance functionality in CoreMLTraining
//

import Foundation
import Testing

@testable import Bridget

@Suite("CoreMLTraining Phase 3 - Statistical Variance Tests")
struct CoreMLTrainingPhase3Tests {
    private var coreMLTraining: CoreMLTraining!

    private mutating func setUp() {
        coreMLTraining = CoreMLTraining(config: CoreMLTrainingConfig.validation)
    }

    // MARK: - Variance Computation Tests

    @Test("Compute training loss variance (stable trend)")
    mutating func computeTrainingLossVariance() {
        setUp()
        // Test with stable loss trend
        let stableLosses = [
            0.1, 0.095, 0.092, 0.089, 0.087, 0.085, 0.083, 0.081, 0.079, 0.077,
        ]
        let variance = coreMLTraining.computeTrainingLossVariance(
            lossTrend: stableLosses
        )

        #expect(variance != nil)
        if let variance = variance {
            #expect(abs(variance.mean - 0.078) < 0.001)
            #expect(variance.variance > 0)
            #expect(variance.variance < 0.01)  // Should be small for stable trend
        }
    }

    @Test("Compute training loss variance (unstable trend)")
    mutating func computeTrainingLossVarianceWithUnstableTrend() {
        setUp()
        // Test with unstable loss trend
        let unstableLosses = [
            0.1, 0.2, 0.05, 0.15, 0.08, 0.25, 0.03, 0.18, 0.06, 0.22,
        ]
        let variance = coreMLTraining.computeTrainingLossVariance(
            lossTrend: unstableLosses
        )

        #expect(variance != nil)
        if let variance = variance {
            // For unstable trend, variance should be significant
            // Using last 20% (2 values): [0.06, 0.22]
            // Expected mean: 0.14, variance should be around 0.0128
            #expect(variance.variance > 0.005)  // Relaxed threshold for unstable trend
        }
    }

    @Test("Compute training loss variance (empty array)")
    mutating func computeTrainingLossVarianceWithEmptyArray() {
        setUp()
        let variance = coreMLTraining.computeTrainingLossVariance(lossTrend: [])
        #expect(variance == nil)
    }

    @Test("Compute validation accuracy variance (stable trend)")
    mutating func computeValidationAccuracyVariance() {
        setUp()
        // Test with stable accuracy trend
        let stableAccuracies = [
            0.85, 0.86, 0.87, 0.88, 0.89, 0.90, 0.91, 0.92, 0.93, 0.94,
        ]
        let variance = coreMLTraining.computeValidationAccuracyVariance(
            accuracyTrend: stableAccuracies
        )

        #expect(variance != nil)
        if let variance = variance {
            #expect(abs(variance.mean - 0.935) < 0.001)
            #expect(variance.variance > 0)
            #expect(variance.variance < 0.01)  // Should be small for stable trend
        }
    }

    @Test("Compute validation accuracy variance (unstable trend)")
    mutating func computeValidationAccuracyVarianceWithUnstableTrend() {
        setUp()
        // Test with unstable accuracy trend
        let unstableAccuracies = [
            0.85, 0.75, 0.95, 0.80, 0.90, 0.70, 0.98, 0.82, 0.88, 0.72,
        ]
        let variance = coreMLTraining.computeValidationAccuracyVariance(
            accuracyTrend: unstableAccuracies
        )

        #expect(variance != nil)
        if let variance = variance {
            // For unstable trend, variance should be significant
            // Using last 20% (2 values): [0.88, 0.72]
            // Expected mean: 0.80, variance should be around 0.0128
            #expect(variance.variance > 0.005)  // Relaxed threshold for unstable trend
        }
    }

    @Test("Compute validation accuracy variance (empty array)")
    mutating func computeValidationAccuracyVarianceWithEmptyArray() {
        setUp()
        let variance = coreMLTraining.computeValidationAccuracyVariance(
            accuracyTrend: [])
        #expect(variance == nil)
    }

    // MARK: - Statistical Metrics Integration Tests

    @Test("StatisticalTrainingMetrics data structure integrity")
    mutating func statisticalMetricsDataStructure() {
        setUp()
        // Test that StatisticalTrainingMetrics can be created and accessed
        let trainingLossStats = ETASummary(
            mean: 0.1,
            variance: 0.01,
            min: 0.05,
            max: 0.15
        )
        let predictionAccuracyStats = ETASummary(
            mean: 0.85,
            variance: 0.001,
            min: 0.82,
            max: 0.88
        )
        let validationLossStats = ETASummary(
            mean: 0.12,
            variance: 0.015,
            min: 0.06,
            max: 0.18
        )
        let etaPredictionVariance = ETASummary(
            mean: 120.0,
            variance: 25.0,
            min: 90.0,
            max: 150.0
        )

        let confidenceIntervals = PerformanceConfidenceIntervals(
            accuracy95CI: ConfidenceInterval(lower: 0.82, upper: 0.88),
            f1Score95CI: ConfidenceInterval(lower: 0.80, upper: 0.90),
            meanError95CI: ConfidenceInterval(lower: 0.08, upper: 0.16)
        )

        let errorDistribution = ErrorDistributionMetrics(
            absoluteErrorStats: ETASummary(
                mean: 0.05,
                variance: 0.002,
                min: 0.02,
                max: 0.08
            ),
            relativeErrorStats: ETASummary(
                mean: 0.12,
                variance: 0.005,
                min: 0.08,
                max: 0.16
            ),
            withinOneStdDev: 68.2,
            withinTwoStdDev: 95.4
        )

        let metrics = StatisticalTrainingMetrics(
            trainingLossStats: trainingLossStats,
            validationLossStats: validationLossStats,
            predictionAccuracyStats: predictionAccuracyStats,
            etaPredictionVariance: etaPredictionVariance,
            performanceConfidenceIntervals: confidenceIntervals,
            errorDistribution: errorDistribution
        )

        // Verify all properties are accessible
        #expect(abs(metrics.trainingLossStats.mean - 0.1) < 0.001)
        #expect(abs(metrics.predictionAccuracyStats.mean - 0.85) < 0.001)
        #expect(abs(metrics.etaPredictionVariance.mean - 120.0) < 0.1)
        #expect(
            abs(
                metrics.performanceConfidenceIntervals.accuracy95CI.lower - 0.82
            ) < 0.001
        )
        #expect(abs(metrics.errorDistribution.withinOneStdDev - 68.2) < 0.1)
    }

    // MARK: - UI Integration Tests

    @Test("PipelineMetricsData can include statistical metrics")
    mutating func pipelineMetricsDataWithStatisticalMetrics() {
        setUp()
        // Test that PipelineMetricsData can include statistical metrics
        let statisticalMetrics = StatisticalTrainingMetrics(
            trainingLossStats: ETASummary(
                mean: 0.1,
                variance: 0.01,
                min: 0.05,
                max: 0.15
            ),
            validationLossStats: ETASummary(
                mean: 0.12,
                variance: 0.015,
                min: 0.06,
                max: 0.18
            ),
            predictionAccuracyStats: ETASummary(
                mean: 0.85,
                variance: 0.001,
                min: 0.82,
                max: 0.88
            ),
            etaPredictionVariance: ETASummary(
                mean: 120.0,
                variance: 25.0,
                min: 90.0,
                max: 150.0
            ),
            performanceConfidenceIntervals: PerformanceConfidenceIntervals(
                accuracy95CI: ConfidenceInterval(lower: 0.82, upper: 0.88),
                f1Score95CI: ConfidenceInterval(lower: 0.80, upper: 0.90),
                meanError95CI: ConfidenceInterval(lower: 0.08, upper: 0.16)
            ),
            errorDistribution: ErrorDistributionMetrics(
                absoluteErrorStats: ETASummary(
                    mean: 0.05,
                    variance: 0.002,
                    min: 0.02,
                    max: 0.08
                ),
                relativeErrorStats: ETASummary(
                    mean: 0.12,
                    variance: 0.005,
                    min: 0.08,
                    max: 0.16
                ),
                withinOneStdDev: 68.2,
                withinTwoStdDev: 95.4
            )
        )

        let pipelineData = PipelineMetricsData(
            timestamp: Date(),
            stageDurations: [
                "DataProcessing": 1.2,
                "FeatureEngineering": 2.1,
                "ModelTraining": 5.3,
            ],
            memoryUsage: [
                "DataProcessing": 256,
                "FeatureEngineering": 384,
                "ModelTraining": 512,
            ],
            validationRates: [
                "DataQualityValidator": 0.95,
                "SchemaValidator": 0.98,
            ],
            errorCounts: [
                "DataProcessing": 0,
                "FeatureEngineering": 1,
                "ModelTraining": 0,
            ],
            recordCounts: [
                "DataProcessing": 1000,
                "FeatureEngineering": 950,
                "ModelTraining": 900,
            ],
            customValidationResults: [
                "DataQualityValidator": true,
                "SchemaValidator": true,
            ],
            statisticalMetrics: statisticalMetrics
        )

        #expect(pipelineData.statisticalMetrics != nil)
        if let stats = pipelineData.statisticalMetrics {
            #expect(abs(stats.trainingLossStats.mean - 0.1) < 0.001)
            #expect(abs(stats.predictionAccuracyStats.mean - 0.85) < 0.001)
        }
    }

    // MARK: - Edge Cases and Error Handling

    @Test("Variance computation with single value")
    mutating func varianceComputationWithSingleValue() {
        setUp()
        let singleLoss = [0.1]
        let variance = coreMLTraining.computeTrainingLossVariance(
            lossTrend: singleLoss
        )

        #expect(variance != nil)
        if let variance = variance {
            #expect(abs(variance.mean - 0.1) < 0.001)
            #expect(abs(variance.variance - 0.0) < 0.001)  // Variance should be 0 for single value
        }
    }

    @Test("Variance computation with two values")
    mutating func varianceComputationWithTwoValues() {
        setUp()
        let twoLosses = [0.1, 0.2]
        let variance = coreMLTraining.computeTrainingLossVariance(
            lossTrend: twoLosses
        )

        #expect(variance != nil)
        if let variance = variance {
            // For 2 values, last 20% = 1 value (0.2), so mean = 0.2, variance = 0
            #expect(abs(variance.mean - 0.2) < 0.001)
            #expect(abs(variance.variance - 0.0) < 0.001)
        }
    }

    @Test("Stable epochs calculation uses last 20% of values")
    mutating func stableEpochsCalculation() {
        setUp()
        // Test that stable epochs calculation works correctly
        let manyLosses = Array(0..<100).map { Double($0) * 0.001 }  // 100 values
        let variance = coreMLTraining.computeTrainingLossVariance(
            lossTrend: manyLosses
        )

        #expect(variance != nil)
        if let variance = variance {
            // Should use last 20% (20 values) for stable epoch calculation
            let expectedMean =
                (80..<100).map { Double($0) * 0.001 }.reduce(0, +) / 20
            #expect(abs(variance.mean - expectedMean) < 0.001)
        }
    }
}
