// PipelineMetricsModels.swift
import Foundation
import SwiftUI

// Represents per-stage metrics used by charts and detail views
struct PipelineStageMetric: Identifiable, Hashable, Codable {
    // Stable identifier (stage key)
    var id: String { stage }

    // Raw stage key (e.g., "dataLoading", "mlMultiArrayConversion")
    let stage: String

    // Metrics
    let duration: Double
    let memory: Int
    let errorCount: Int
    let recordCount: Int
    let validationRate: Double

    // Human-readable display name mapping
    var displayName: String {
        switch stage {
        case "dataLoading": return "Data Loading"
        case "dataValidation": return "Data Validation"
        case "featureEngineering": return "Feature Engineering"
        case "mlMultiArrayConversion": return "ML Array Conversion" // matches test expectation
        case "modelTraining": return "Model Training"
        case "modelValidation": return "Model Validation"
        case "artifactExport": return "Artifact Export"
        default:
            // Simple capitalization to match test "Unknownstage"
            guard let first = stage.first else { return "" }
            return String(first).uppercased() + stage.dropFirst().lowercased()
        }
    }

    // Status color based on errors and validation rate
    var statusColor: Color {
        if errorCount > 0 { return .red }
        if validationRate < 0.95 { return .orange }
        return .green
    }
}

// Aggregate metrics data used to build charts and sections
struct PipelineMetricsData: Codable {
    let timestamp: Date

    // Raw metrics keyed by stage key
    let stageDurations: [String: Double]
    let memoryUsage: [String: Int]
    let validationRates: [String: Double]
    let errorCounts: [String: Int]
    let recordCounts: [String: Int]

    // Optional extras
    let customValidationResults: [String: Bool]?
    let statisticalMetrics: StatisticalTrainingMetrics?

    // Computed list used by UI (sorted by duration desc by default)
    var stageMetrics: [PipelineStageMetric] {
        // Union of all stage keys present in any dictionary
        let allKeys = Set(stageDurations.keys)
            .union(memoryUsage.keys)
            .union(validationRates.keys)
            .union(errorCounts.keys)
            .union(recordCounts.keys)

        let metrics = allKeys.map { key in
            PipelineStageMetric(
                stage: key,
                duration: stageDurations[key] ?? 0.0,
                memory: memoryUsage[key] ?? 0,
                errorCount: errorCounts[key] ?? 0,
                recordCount: recordCounts[key] ?? 0,
                validationRate: validationRates[key] ?? 1.0
            )
        }

        return metrics.sorted { $0.duration > $1.duration }
    }

    // Totals and summaries
    var totalDuration: Double {
        stageDurations.values.reduce(0, +)
    }

    var totalMemory: Int {
        memoryUsage.values.reduce(0, +)
    }

    // Average of provided validation rates; empty -> 1.0 per tests
    var averageValidationRate: Double {
        guard !validationRates.isEmpty else { return 1.0 }
        let sum = validationRates.values.reduce(0, +)
        return sum / Double(validationRates.count)
    }

    // Helpers for charts
    func topStagesByDuration(limit: Int) -> [PipelineStageMetric] {
        Array(stageMetrics.sorted { $0.duration > $1.duration }.prefix(limit))
    }

    func topStagesByMemory(limit: Int) -> [PipelineStageMetric] {
        Array(stageMetrics.sorted { $0.memory > $1.memory }.prefix(limit))
    }
}
