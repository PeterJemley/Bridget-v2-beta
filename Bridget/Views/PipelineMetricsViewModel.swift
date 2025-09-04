import Foundation
import Observation

@MainActor
@Observable
final class PipelineMetricsViewModel {
  enum TimeRange: String, CaseIterable, Hashable {
    case lastHour = "Last Hour"
    case last24Hours = "Last 24 Hours"
    case lastWeek = "Last Week"
    case allTime = "All Time"
  }

  enum ChartKind: String, CaseIterable, Hashable {
    case performance = "Performance"
    case memory = "Memory"
  }

  enum StageFilter: String, CaseIterable, Hashable {
    case none = "None"
    case problematicOnly = "Problematic"
  }

  var metricsData: PipelineMetricsData?
  var isLoading = false
  var lastUpdateTime = Date()
  var autoRefresh = true
  var selectedTimeRange: TimeRange = .last24Hours

  var chartKind: ChartKind = .performance
  var showAllStagesInCharts = false
  var isDetailsExpanded = false
  var isCustomValidationExpanded = false
  var isUncertaintyExpanded = false

  var stageFilter: StageFilter = .none
  var validationWarningThreshold: Double = 0.95

  private var autoRefreshTask: Task<Void, Never>?

  init() {
    Task { await loadMetrics() }
    if autoRefresh { startAutoRefresh() }
  }

  func onAppear() {
    if autoRefreshTask == nil, autoRefresh { startAutoRefresh() }
  }

  func onDisappear() { stopAutoRefresh() }

  func toggleAutoRefresh(_ isOn: Bool) {
    autoRefresh = isOn
    if isOn { startAutoRefresh() } else { stopAutoRefresh() }
  }

  func refreshNow() { Task { await loadMetrics() } }

  func startAutoRefresh() {
    stopAutoRefresh()
    autoRefreshTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
        guard let self else { return }
        if self.autoRefresh { await self.loadMetrics() }
      }
    }
  }

  func stopAutoRefresh() {
    autoRefreshTask?.cancel()
    autoRefreshTask = nil
  }

  func loadMetrics() async {
    isLoading = true
    let possiblePaths = [
      "metrics/enhanced_pipeline_metrics.json",
      "Documents/metrics/enhanced_pipeline_metrics.json",
      "/tmp/bridget_metrics.json",
    ]

    for path in possiblePaths {
      let url = URL(fileURLWithPath: path)
      if let data = try? Data(contentsOf: url),
         let decoded = try? JSONDecoder.bridgeDecoder().decode(PipelineMetricsData.self,
                                                               from: data)
      {
        self.metricsData = decoded
        self.lastUpdateTime = Date()
        self.isLoading = false
        return
      }
    }

    self.metricsData = createSampleData()
    self.isLoading = false
  }

  func toggleProblematicFilter() {
    stageFilter =
      (stageFilter == .problematicOnly) ? .none : .problematicOnly
  }

  func clearFilters() { stageFilter = .none }

  func filteredStages(from data: PipelineMetricsData)
    -> [PipelineStageMetric]?
  {
    switch stageFilter {
    case .none: return nil
    case .problematicOnly:
      let threshold = validationWarningThreshold
      return data.stageMetrics.filter {
        $0.errorCount > 0 || $0.validationRate < threshold
      }
    }
  }

  // MARK: - Sample Data

  private func createSampleData() -> PipelineMetricsData {
    PipelineMetricsData(timestamp: Date(),
                        stageDurations: [
                          "dataLoading": 2.5,
                          "dataValidation": 1.8,
                          "featureEngineering": 15.2,
                          "mlMultiArrayConversion": 3.1,
                          "modelTraining": 45.7,
                          "modelValidation": 8.3,
                          "artifactExport": 1.2,
                        ],
                        memoryUsage: [
                          "dataLoading": 128,
                          "dataValidation": 256,
                          "featureEngineering": 1024,
                          "mlMultiArrayConversion": 512,
                          "modelTraining": 2048,
                          "modelValidation": 1024,
                          "artifactExport": 256,
                        ],
                        validationRates: [
                          "dataLoading": 1.0,
                          "dataValidation": 0.98,
                          "featureEngineering": 0.95,
                          "mlMultiArrayConversion": 1.0,
                          "modelTraining": 1.0,
                          "modelValidation": 0.92,
                          "artifactExport": 1.0,
                        ],
                        errorCounts: [
                          "dataLoading": 0,
                          "dataValidation": 2,
                          "featureEngineering": 5,
                          "mlMultiArrayConversion": 0,
                          "modelTraining": 0,
                          "modelValidation": 8,
                          "artifactExport": 0,
                        ],
                        recordCounts: [
                          "dataLoading": 10000,
                          "dataValidation": 10000,
                          "featureEngineering": 9800,
                          "mlMultiArrayConversion": 9800,
                          "modelTraining": 9800,
                          "modelValidation": 9800,
                          "artifactExport": 9800,
                        ],
                        customValidationResults: [
                          "NoMissingGateAnomValidator": true,
                          "DetourDeltaRangeValidator": false,
                          "DataQualityValidator": true,
                        ],
                        statisticalMetrics: createSampleStatisticalMetrics())
  }

  private func createSampleStatisticalMetrics() -> StatisticalTrainingMetrics {
    StatisticalTrainingMetrics(trainingLossStats: ETASummary(mean: 0.085,
                                                             variance: 0.002,
                                                             min: 0.082,
                                                             max: 0.089),
                               validationLossStats: ETASummary(mean: 0.092,
                                                               variance: 0.003,
                                                               min: 0.088,
                                                               max: 0.096),
                               predictionAccuracyStats: ETASummary(mean: 0.87,
                                                                   variance: 0.001,
                                                                   min: 0.86,
                                                                   max: 0.88),
                               etaPredictionVariance: ETASummary(mean: 120.5,
                                                                 variance: 25.2,
                                                                 min: 95.0,
                                                                 max: 145.0),
                               performanceConfidenceIntervals: PerformanceConfidenceIntervals(accuracy95CI: ConfidenceInterval(lower: 0.84, upper: 0.90),
                                                                                              f1Score95CI: ConfidenceInterval(lower: 0.82, upper: 0.92),
                                                                                              meanError95CI: ConfidenceInterval(lower: 0.08, upper: 0.16)),
                               errorDistribution: ErrorDistributionMetrics(absoluteErrorStats: ETASummary(mean: 0.045,
                                                                                                          variance: 0.002,
                                                                                                          min: 0.025,
                                                                                                          max: 0.065),
                                                                           relativeErrorStats: ETASummary(mean: 0.12,
                                                                                                          variance: 0.005,
                                                                                                          min: 0.08,
                                                                                                          max: 0.16),
                                                                           withinOneStdDev: 68.5,
                                                                           withinTwoStdDev: 95.2))
  }
}
