import CoreML
import Foundation
import SwiftData

@Observable
final class MLPipelineViewModel: CoreMLTrainingProgressDelegate {
  var pipelineStatus: PipelineStatusViewModel
  var quickActions: QuickActionsViewModel
  var recentActivity: RecentActivityViewModel

  // MARK: - Training State

  var trainingProgress: Double = 0.0
  var trainingStatus: String = ""
  var trainingError: String?
  var isTraining: Bool = false

  // MARK: - Pipeline State

  var pipelineProgress: Double = 0.0
  var pipelineStatusText: String = ""
  var trainedModels: [Int: String] = [:]

  init(modelContext: ModelContext) {
    self.pipelineStatus = PipelineStatusViewModel(modelContext: modelContext)
    self.quickActions = QuickActionsViewModel(modelContext: modelContext)
    self.recentActivity = RecentActivityViewModel()

    // Set up coordination between view models
    setupCoordination()
  }

  // MARK: - Coordination Logic

  private func setupCoordination() {
    // When quick actions complete, refresh status and activities
    Task { @MainActor in
      // This would be set up to observe changes in quick actions
      // and trigger refreshes in other view models
    }
  }

  // MARK: - Public Methods

  /// Refreshes all pipeline data and status
  func refreshAll() {
    pipelineStatus.refreshStatus()
    recentActivity.refreshActivities()
  }

  /// Triggers a data population operation
  func populateData() async {
    await quickActions.populateTodayData()
    // After population, refresh status
    pipelineStatus.refreshStatus()
    recentActivity.refreshActivities()
  }

  /// Triggers a data export operation (now handled by background automation)
  func exportData() async {
    // Export is now handled automatically by background tasks
    // Trigger the background export task
    MLPipelineBackgroundManager.shared.triggerBackgroundTask(.dataExport)
    // After export, refresh status
    pipelineStatus.refreshStatus()
    recentActivity.refreshActivities()
  }

  /// Runs maintenance operations
  func runMaintenance() async {
    await quickActions.runMaintenance()
    // After maintenance, refresh status
    pipelineStatus.refreshStatus()
    recentActivity.refreshActivities()
  }

  /// Gets the overall pipeline health status
  var isPipelineHealthy: Bool {
    pipelineStatus.isPipelineHealthy
  }

  /// Gets a summary of the pipeline status
  var pipelineStatusSummary: String {
    let healthStatus = isPipelineHealthy ? "Healthy" : "Needs Attention"
    let dataStatus = pipelineStatus.dataAvailabilityStatus
    let lastActivity = recentActivity.recentActivities.first?.title ?? "No recent activity"

    return """
    Pipeline Status: \(healthStatus)
    Data: \(dataStatus)
    Last Activity: \(lastActivity)
    """
  }

  // MARK: - Core ML Training Methods

  /// Starts the ML training pipeline with real-time progress updates.
  ///
  /// This method initiates the complete ML training pipeline from NDJSON data
  /// to trained Core ML models, with progress reporting through the delegate.
  ///
  /// - Parameters:
  ///   - ndjsonPath: Path to the NDJSON file from BridgeDataExporter
  ///   - outputDirectory: Directory to save trained models
  ///   - horizons: Array of prediction horizons to train models for
  func startTrainingPipeline(ndjsonPath: String,
                             outputDirectory: String,
                             horizons: [Int] = [0, 3, 6, 9, 12])
  {
    isTraining = true
    trainingProgress = 0.0
    trainingStatus = "Starting training pipeline..."
    trainingError = nil

    Task.detached { [weak self] in
      do {
        let models = try await TrainPrepService.createTrainingPipeline(ndjsonPath: ndjsonPath,
                                                                       outputDirectory: outputDirectory,
                                                                       horizons: horizons,
                                                                       modelConfiguration: nil,
                                                                       progressDelegate: self)

        await MainActor.run {
          self?.trainedModels = models
          self?.isTraining = false
          self?.trainingProgress = 1.0
          self?.trainingStatus = "Training completed successfully"
        }

      } catch {
        await MainActor.run {
          self?.isTraining = false
          self?.trainingError = error.localizedDescription
          self?.trainingStatus = "Training failed"
        }
      }
    }
  }

  /// Starts training for a single horizon.
  ///
  /// This method trains a model for a specific prediction horizon.
  ///
  /// - Parameters:
  ///   - csvPath: Path to the CSV file for the horizon
  ///   - horizon: The prediction horizon in minutes
  ///   - outputDirectory: Directory to save the trained model
  func startSingleHorizonTraining(csvPath: String,
                                  horizon: Int,
                                  outputDirectory: String)
  {
    isTraining = true
    trainingProgress = 0.0
    trainingStatus = "Training model for \(horizon)-minute horizon..."
    trainingError = nil

    Task.detached { [weak self] in
      do {
        let modelPath = try await TrainPrepService.trainCoreMLModel(csvPath: csvPath,
                                                                    modelName: "BridgeLiftPredictor_horizon_\(horizon)",
                                                                    outputDirectory: outputDirectory,
                                                                    configuration: nil,
                                                                    progressDelegate: self)

        await MainActor.run {
          self?.trainedModels[horizon] = modelPath
          self?.isTraining = false
          self?.trainingProgress = 1.0
          self?.trainingStatus = "Training completed for \(horizon)-minute horizon"
        }

      } catch {
        await MainActor.run {
          self?.isTraining = false
          self?.trainingError = error.localizedDescription
          self?.trainingStatus = "Training failed for \(horizon)-minute horizon"
        }
      }
    }
  }
}

// MARK: - CoreMLTrainingProgressDelegate Implementation

extension MLPipelineViewModel {
  func trainingDidStart() {
    Task { @MainActor in
      trainingStatus = "Training started..."
      trainingProgress = 0.0
    }
  }

  func trainingDidLoadData(_ count: Int) {
    Task { @MainActor in
      trainingStatus = "Loaded \(count) training samples"
    }
  }

  func trainingDidPrepareData(_ count: Int) {
    Task { @MainActor in
      trainingStatus = "Prepared \(count) training batches"
    }
  }

  func trainingDidUpdateProgress(_ progress: Double) {
    Task { @MainActor in
      trainingProgress = progress
      trainingStatus = "Training: \(Int(progress * 100))%"
    }
  }

  func trainingDidComplete(_ modelPath: String) {
    Task { @MainActor in
      trainingStatus = "Completed: \(modelPath)"
      trainingProgress = 1.0
    }
  }

  func trainingDidFail(_ error: Error) {
    Task { @MainActor in
      trainingStatus = "Failed"
      trainingError = error.localizedDescription
    }
  }

  func pipelineDidStart() {
    Task { @MainActor in
      pipelineStatusText = "Pipeline started..."
      pipelineProgress = 0.0
    }
  }

  func pipelineDidProcessData(_ fileCount: Int) {
    Task { @MainActor in
      pipelineStatusText = "Processed \(fileCount) data files"
      pipelineProgress = 0.3
    }
  }

  func pipelineDidStartTraining(_ horizon: Int) {
    Task { @MainActor in
      pipelineStatusText = "Training model for \(horizon)-minute horizon..."
      pipelineProgress = 0.4 + (Double(horizon) * 0.1)
    }
  }

  func pipelineDidCompleteTraining(_ horizon: Int, modelPath _: String) {
    Task { @MainActor in
      pipelineStatusText = "Completed training for \(horizon)-minute horizon"
      pipelineProgress = 0.5 + (Double(horizon) * 0.1)
    }
  }

  func pipelineDidComplete(_ models: [Int: String]) {
    Task { @MainActor in
      pipelineStatusText = "Pipeline completed with \(models.count) trained models"
      pipelineProgress = 1.0
    }
  }
}
