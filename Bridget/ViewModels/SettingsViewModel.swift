import Foundation
import SwiftUI

@Observable
final class SettingsViewModel {
  // MARK: - Persisted Settings

  @AppStorage("MLAutoExportEnabled") @ObservationIgnored var autoExportEnabled: Bool = false
  @AppStorage("MLAutoExportTime") @ObservationIgnored var autoExportTime: String = "01:00" // "HH:mm"

  // MARK: - Notification Settings

  @AppStorage("MLPipelineNotificationsEnabled") @ObservationIgnored var notificationsEnabled: Bool = true
  @AppStorage("MLPipelineSuccessNotifications") @ObservationIgnored var successNotifications: Bool = true
  @AppStorage("MLPipelineFailureNotifications") @ObservationIgnored var failureNotifications: Bool = true
  @AppStorage("MLPipelineProgressNotifications") @ObservationIgnored var progressNotifications: Bool = false
  @AppStorage("MLPipelineHealthNotifications") @ObservationIgnored var healthNotifications: Bool = true

  // MARK: - UI State

  var showingTimePicker = false
  var tempTime = Date()

  // MARK: - Computed Properties

  // MARK: - Methods

  func configureNotifications() {
    let notificationManager = MLPipelineNotificationManager.shared
    notificationManager.setNotificationsEnabled(notificationsEnabled)
    notificationManager.setNotificationTypeEnabled(.success, enabled: successNotifications)
    notificationManager.setNotificationTypeEnabled(.failure, enabled: failureNotifications)
    notificationManager.setNotificationTypeEnabled(.progress, enabled: progressNotifications)
    notificationManager.setNotificationTypeEnabled(.health, enabled: healthNotifications)
  }

  func scheduleAutoExport() {
    if autoExportEnabled {
      // Schedule background task for auto export
      MLPipelineBackgroundManager.shared.scheduleNextExecution()
    }
  }
}
