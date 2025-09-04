import Foundation
import SwiftData

@Observable
final class QuickActionsViewModel {
  private let modelContext: ModelContext
  let backgroundManager: MLPipelineBackgroundManager
  let notificationManager: MLPipelineNotificationManager

  var isLoading: Bool = false
  var errorMessage: String?
  var lastOperationResult: String?

  @MainActor
  init(modelContext: ModelContext,
       backgroundManager: MLPipelineBackgroundManager? = nil,
       notificationManager: MLPipelineNotificationManager? = nil)
  {
    self.modelContext = modelContext
    self.backgroundManager = backgroundManager ?? .shared
    self.notificationManager = notificationManager ?? .shared
  }

  // MARK: - Actions

  @MainActor
  func populateTodayData() async {
    isLoading = true
    errorMessage = nil
    lastOperationResult = nil

    // Trigger background task for data population
    backgroundManager.triggerBackgroundTask(.dataPopulation)

    // Update the last population date
    backgroundManager.updateLastPopulationDate()

    // Add activity to recent activities
    backgroundManager.addActivity(title: "Data Population",
                                  description: "Populated today's probe tick data",
                                  type: .dataPopulation)

    // Show success notification
    notificationManager.showSuccessNotification(title: "Data Population Complete",
                                                body: "Today's data has been successfully populated.",
                                                operation: .dataPopulation)

    lastOperationResult = "Today's data populated successfully."

    isLoading = false
  }

  @MainActor
  func runMaintenance() async {
    isLoading = true
    errorMessage = nil
    lastOperationResult = nil

    // Trigger background task for maintenance
    backgroundManager.triggerBackgroundTask(.maintenance)

    // Add activity to recent activities
    backgroundManager.addActivity(title: "Maintenance",
                                  description: "Ran pipeline maintenance tasks",
                                  type: .maintenance)

    // Show success notification
    notificationManager.showSuccessNotification(title: "Maintenance Complete",
                                                body: "Pipeline maintenance tasks completed successfully.",
                                                operation: .maintenance)

    lastOperationResult = "Maintenance completed successfully."

    isLoading = false
  }
}
