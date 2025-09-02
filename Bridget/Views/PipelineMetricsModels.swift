import SwiftUI
import Foundation

struct PipelineStageMetric: Codable, Identifiable, Equatable, Hashable {
    var id: String { stage }
    let stage: String
    let duration: Double
    let memory: Int
    let errorCount: Int
    let recordCount: Int
    let validationRate: Double

    var displayName: String {
        switch stage {
        case "dataLoading": return "Data Loading"
        case "dataValidation": return "Data Validation"
        case "featureEngineering": return "Feature Engineering"
        case "mlMultiArrayConversion": return "ML Array Conversion"
        case "modelTraining": return "Model Training"
        case "modelValidation": return "Model Validation"
        case "artifactExport": return "Artifact Export"
        default: return stage.capitalized
        }
    }

    var statusColor: Color {
        if errorCount > 0 { return .red }
        else if validationRate < 0.95 { return .orange }
        else { return .green }
    }
}

struct PipelineMetricsData: Codable, Equatable {
    let timestamp: Date
    let stageDurations: [String: Double]
    let memoryUsage: [String: Int]
    let validationRates: [String: Double]
    let errorCounts: [String: Int]
    let recordCounts: [String: Int]
    let customValidationResults: [String: Bool]?
    let statisticalMetrics: StatisticalTrainingMetrics?

    var stageMetrics: [PipelineStageMetric] {
        stageDurations.keys.map { stage in
            PipelineStageMetric(
                stage: stage,
                duration: stageDurations[stage] ?? 0.0,
                memory: memoryUsage[stage] ?? 0,
                errorCount: errorCounts[stage] ?? 0,
                recordCount: recordCounts[stage] ?? 0,
                validationRate: validationRates[stage] ?? 1.0
            )
        }.sorted { $0.duration > $1.duration }
    }

    var totalDuration: Double { stageDurations.values.reduce(0, +) }
    var totalMemory: Int { memoryUsage.values.reduce(0, +) }

    var averageValidationRate: Double {
        guard !validationRates.isEmpty else { return 1.0 }
        return validationRates.values.reduce(0, +) / Double(validationRates.count)
    }

    func topStagesByDuration(limit: Int) -> [PipelineStageMetric] {
        Array(stageMetrics.sorted { $0.duration > $1.duration }.prefix(limit))
    }

    func topStagesByMemory(limit: Int) -> [PipelineStageMetric] {
        Array(stageMetrics.sorted { $0.memory > $1.memory }.prefix(limit))
    }
}
