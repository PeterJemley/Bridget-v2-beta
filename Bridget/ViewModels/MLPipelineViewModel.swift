import CoreML
import Foundation
import SwiftData

@Observable
@MainActor
final class MLPipelineViewModel: CoreMLTrainingProgressDelegate, TrainPrepProgressDelegate {
  let pipelineStatus: PipelineStatusViewModel
  let quickActions: QuickActionsViewModel
  let recentActivity: RecentActivityViewModel

  // MARK: - Training State

  var trainingProgress = 0.0
  var trainingStatus = ""
  var trainingError: String?
  var isTraining = false

  // MARK: - Pipeline State

  var pipelineProgress = 0.0
  var pipelineStatusText = ""
  var trainedModels = [Int: String]()

  init(modelContext: ModelContext) {
    pipelineStatus = PipelineStatusViewModel(modelContext: modelContext)
    quickActions = QuickActionsViewModel(modelContext: modelContext)
    recentActivity = RecentActivityViewModel()

    setupCoordination()
  }

  // MARK: - Coordination Logic

  private func setupCoordination() {
    Task { @MainActor in
      // This would be set up to observe changes in quick actions
      // and trigger refreshes in other view models
    }
  }

  // MARK: - Public Methods

  func refreshAll() {
    pipelineStatus.refreshStatus()
    recentActivity.refreshActivities()
  }

  func populateData() async {
    await quickActions.populateTodayData()
    pipelineStatus.refreshStatus()
    recentActivity.refreshActivities()
  }

  func exportData() async {
    MLPipelineBackgroundManager.shared.triggerBackgroundTask(.dataExport)
    pipelineStatus.refreshStatus()
    recentActivity.refreshActivities()
  }

  func runMaintenance() async {
    await quickActions.runMaintenance()
    pipelineStatus.refreshStatus()
    recentActivity.refreshActivities()
  }

  var isPipelineHealthy: Bool {
    pipelineStatus.isPipelineHealthy
  }

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

  func startTrainingPipeline(
    ndjsonPath: String,
    outputDirectory: String,
    horizons _: [Int] = defaultHorizons
  ) {
    isTraining = true
    trainingProgress = 0.0
    trainingStatus = "Starting training pipeline..."
    trainingError = nil

    Task.detached { [weak self] in
      guard let self = self else { return }
      do {
        // Use the new Step 5 orchestrator service
        let config = CoreMLTrainingConfig(
          modelType: .neuralNetwork,
          epochs: 100,
          learningRate: 0.001,
          batchSize: 32,
          useANE: true)

        let url = URL(fileURLWithPath: ndjsonPath)
        let (_, _) = try await TrainPrepService().runPipeline(
          from: url,
          config: config,
          progress: self)

        // For now, store the model path as a placeholder
        // In a real implementation, you would save the model to disk
        let modelPath = "\(outputDirectory)/trained_model.mlmodel"

        await MainActor.run {
          self.trainedModels = [6: modelPath]  // Default horizon
          self.isTraining = false
          self.trainingProgress = 1.0
          self.trainingStatus = "Training completed successfully"
        }

      } catch {
        await MainActor.run {
          self.isTraining = false
          self.trainingError = error.localizedDescription
          self.trainingStatus = "Training failed"
        }
      }
    }
  }

  func startSingleHorizonTraining(
    csvPath: String,
    horizon: Int,
    outputDirectory: String
  ) {
    isTraining = true
    trainingProgress = 0.0
    trainingStatus = "Training model for \(horizon)-minute horizon..."
    trainingError = nil

    Task.detached { [weak self] in
      guard let self = self else { return }
      do {
        // Use the new Step 5 orchestrator service for single horizon training
        let config = CoreMLTrainingConfig(
          modelType: .neuralNetwork,
          epochs: 100,
          learningRate: 0.001,
          batchSize: 32,
          useANE: true)

        // For single horizon training, we would need to create a CSV-like input
        // For now, this is a placeholder that would need to be implemented
        let url = URL(fileURLWithPath: csvPath)
        let (_, _) = try await TrainPrepService().runPipeline(
          from: url,
          config: config,
          progress: self)

        let modelPath = "\(outputDirectory)/BridgeLiftPredictor_horizon_\(horizon).mlmodel"

        await MainActor.run {
          self.trainedModels[horizon] = modelPath
          self.isTraining = false
          self.trainingProgress = 1.0
          self.trainingStatus = "Training completed for \(horizon)-minute horizon"
        }

      } catch {
        await MainActor.run {
          self.isTraining = false
          self.trainingError = error.localizedDescription
          self.trainingStatus = "Training failed for \(horizon)-minute horizon"
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

// MARK: - TrainPrepProgressDelegate Implementation

extension MLPipelineViewModel {
  func trainPrepDidStart() {
    Task { @MainActor in
      trainingStatus = "Training preparation started..."
      trainingProgress = 0.0
    }
  }

  func trainPrepDidLoadData(_ count: Int) {
    Task { @MainActor in
      trainingStatus = "Loaded \(count) probe ticks"
      trainingProgress = 0.1
    }
  }

  func trainPrepDidProcessHorizon(_ horizon: Int, featureCount: Int) {
    Task { @MainActor in
      trainingStatus = "Processed \(horizon)-minute horizon with \(featureCount) features"
      trainingProgress = 0.3
    }
  }

  func trainPrepDidSaveHorizon(_ horizon: Int, to path: String) {
    Task { @MainActor in
      trainingStatus = "Saved \(horizon)-minute horizon to \(path)"
      trainingProgress = 0.4
    }
  }

  func trainPrepDidComplete() {
    Task { @MainActor in
      trainingStatus = "Training preparation completed"
      trainingProgress = 0.5
    }
  }

  func trainPrepDidFail(_ error: Error) {
    Task { @MainActor in
      trainingStatus = "Training preparation failed"
      trainingError = error.localizedDescription
    }
  }
}
