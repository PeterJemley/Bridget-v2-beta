#if canImport(Testing)
import Testing
#else
// Minimal shim so the file compiles if Testing isn't available.
public struct Test: Sendable {
    public init(_ name: String = "") {}
}
public struct Suite: Sendable {
    public init(_ name: String = "") {}
}
@resultBuilder
public enum TestBuilder { public static func buildBlock(_ parts: Any...) {} }
#endif

import Foundation
@testable import Bridget // or your module name

// --- Tiny, local calculator we can test in isolation ---
// If you already have a production "StatsCalculator", use that instead.
private struct Stats {
    let mean: Double
    let variance: Double
    let min: Double
    let max: Double
}

private func summarize(_ xs: [Double]) -> Stats {
    precondition(!xs.isEmpty)
    let n = Double(xs.count)
    let mean = xs.reduce(0, +) / n
    let variance = xs.reduce(0) { $0 + pow($1 - mean, 2) } / n
    return Stats(mean: mean, variance: variance, min: xs.min()!, max: xs.max()!)
}

// --- Optionally mirror your existing result types (or import the real ones) ---
private struct ETASummary: Equatable {
    let mean: Double, variance: Double, min: Double, max: Double
}
private struct ErrorDistributionMetrics: Equatable {
    let absoluteErrorStats: ETASummary
    let relativeErrorStats: ETASummary
    let withinOneStdDev: Double
    let withinTwoStdDev: Double
}
private struct StatisticalTrainingMetrics: Equatable {
    let trainingLossStats: ETASummary
    let predictionAccuracyStats: ETASummary
    let errorDistribution: ErrorDistributionMetrics
}

// --- Protocol your training object uses. Keep it minimal for the test. ---
private protocol MetricsEvaluator {
    func computeStatisticalMetrics(
        featuresCount: Int,
        lossTrend: [Double],
        accuracyTrend: [Double]
    ) -> StatisticalTrainingMetrics
}

// --- Thin wrapper to simulate your CoreMLTraining in the test ---
private struct CoreMLTraining {
    let evaluator: MetricsEvaluator

    func computeStatisticalMetrics(
        on featuresCount: Int,
        lossTrend: [Double],
        accuracyTrend: [Double]
    ) -> StatisticalTrainingMetrics {
        evaluator.computeStatisticalMetrics(
            featuresCount: featuresCount,
            lossTrend: lossTrend,
            accuracyTrend: accuracyTrend
        )
    }
}

// --- Spy to capture forwarding without Core ML types ---
private final class SpyEvaluator: MetricsEvaluator {
    var capturedFeaturesCount: Int?
    var capturedLoss: [Double] = []
    var capturedAcc: [Double] = []
    var result: StatisticalTrainingMetrics

    init(result: StatisticalTrainingMetrics) { self.result = result }

    func computeStatisticalMetrics(
        featuresCount: Int,
        lossTrend: [Double],
        accuracyTrend: [Double]
    ) -> StatisticalTrainingMetrics {
        capturedFeaturesCount = featuresCount
        capturedLoss = lossTrend
        capturedAcc = accuracyTrend
        return result
    }
}

@Suite("Statistical metrics (simple & stable)")
struct StatisticalMetricsTests {

    @Test("Pure math: summarize loss/accuracy")
    func pureMathSummaries() {
        let loss = [0.5, 0.3, 0.2]        // mean = 0.333..., variance = ~0.01556
        let acc  = [0.6, 0.75, 0.85]      // mean = 0.733..., variance = ~0.01056

        let L = summarize(loss)
        let A = summarize(acc)

        #expect(abs(L.mean - 0.3333333333) < 1e-9)
        #expect(abs(L.variance - 0.0155555556) < 1e-9)
        #expect(L.min == 0.2 && L.max == 0.5)

        #expect(abs(A.mean - 0.7333333333) < 1e-9)
        #expect(abs(A.variance - 0.0105555556) < 1e-9)
        #expect(A.min == 0.6 && A.max == 0.85)
    }

    @Test("Integration-light: training forwards arrays to evaluator")
    func forwardingToEvaluator() {
        // Build a tiny, deterministic expected result
        let expected = StatisticalTrainingMetrics(
            trainingLossStats: ETASummary(mean: 0.33, variance: 0.0156, min: 0.2, max: 0.5),
            predictionAccuracyStats: ETASummary(mean: 0.733, variance: 0.0106, min: 0.6, max: 0.85),
            errorDistribution: ErrorDistributionMetrics(
                absoluteErrorStats: ETASummary(mean: 0.05, variance: 0.01, min: 0.02, max: 0.08),
                relativeErrorStats: ETASummary(mean: 0.12, variance: 0.03, min: 0.08, max: 0.16),
                withinOneStdDev: 68.5,
                withinTwoStdDev: 95.2
            )
        )

        let spy = SpyEvaluator(result: expected)
        let training = CoreMLTraining(evaluator: spy)

        let featuresCount = 1
        let lossTrend = [0.5, 0.3, 0.2]
        let accuracyTrend = [0.6, 0.75, 0.85]

        let result = training.computeStatisticalMetrics(
            on: featuresCount,
            lossTrend: lossTrend,
            accuracyTrend: accuracyTrend
        )

        #expect(result == expected)
        #expect(spy.capturedFeaturesCount == featuresCount)
        #expect(spy.capturedLoss == lossTrend)
        #expect(spy.capturedAcc == accuracyTrend)
    }
}
