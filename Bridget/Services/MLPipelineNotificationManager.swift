//
//  MLPipelineNotificationManager.swift
//  Bridget
//
//  Purpose: Notification management for ML pipeline operations and user feedback
//

import Foundation
import OSLog
import UserNotifications

/// Notification manager for ML pipeline operations and user feedback.
///
/// This service manages local notifications to keep users informed about:
/// - Pipeline operation status and completion
/// - Export success/failure notifications
/// - Data population progress and results
/// - Pipeline health warnings and maintenance
///
/// ## Notification Types
///
/// - **Success Notifications**: Successful operations completion
/// - **Failure Notifications**: Operation failures with error details
/// - **Progress Notifications**: Long-running operation progress
/// - **Health Notifications**: Pipeline health warnings and maintenance
/// - **Scheduled Notifications**: Upcoming scheduled operations
///
/// ## Integration Points
///
/// - **UserNotifications Framework**: For local notification delivery
/// - **OSLog**: For notification logging and debugging
/// - **UserDefaults**: For notification preferences
/// - **MLPipelineBackgroundManager**: For background task notifications
///
/// ## Usage
///
/// The notification manager is typically used by other pipeline components
/// to provide user feedback about operation status and results.
@Observable
final class MLPipelineNotificationManager {
  static let shared = MLPipelineNotificationManager()

  private let logger = Logger(subsystem: "Bridget", category: "MLPipelineNotifications")

  private let successCategoryID = "MLPipelineSuccess"
  private let failureCategoryID = "MLPipelineFailure"
  private let progressCategoryID = "MLPipelineProgress"
  private let healthCategoryID = "MLPipelineHealth"

  private let notificationsEnabledKey = "MLPipelineNotificationsEnabled"
  private let successNotificationsKey = "MLPipelineSuccessNotifications"
  private let failureNotificationsKey = "MLPipelineFailureNotifications"
  private let progressNotificationsKey = "MLPipelineProgressNotifications"
  private let healthNotificationsKey = "MLPipelineHealthNotifications"

  private init() {
    setupNotificationCategories()
    requestNotificationPermissions()
  }

  func showSuccessNotification(title: String, body: String, operation: PipelineOperation) {
    guard isNotificationTypeEnabled(.success) else { return }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.categoryIdentifier = successCategoryID
    content.userInfo = [
      "operation": operation.rawValue,
      "timestamp": Date().timeIntervalSince1970,
    ]

    let request = UNNotificationRequest(identifier: "success-\(operation.rawValue)-\(Date().timeIntervalSince1970)",
                                        content: content,
                                        trigger: nil)

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        self.logger.error("Failed to show success notification: \(error.localizedDescription)")
      } else {
        self.logger.info("Success notification scheduled for \(operation.rawValue)")
      }
    }
  }

  func showFailureNotification(title: String, body: String, operation: PipelineOperation, error: Error) {
    guard isNotificationTypeEnabled(.failure) else { return }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.categoryIdentifier = failureCategoryID
    content.userInfo = [
      "operation": operation.rawValue,
      "error": error.localizedDescription,
      "timestamp": Date().timeIntervalSince1970,
    ]

    let request = UNNotificationRequest(identifier: "failure-\(operation.rawValue)-\(Date().timeIntervalSince1970)",
                                        content: content,
                                        trigger: nil)

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        self.logger.error("Failed to show failure notification: \(error.localizedDescription)")
      } else {
        self.logger.info("Failure notification scheduled for \(operation.rawValue)")
      }
    }
  }

  func showProgressNotification(title: String, body: String, operation: PipelineOperation, progress: Double) {
    guard isNotificationTypeEnabled(.progress) else { return }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = nil
    content.categoryIdentifier = progressCategoryID
    content.userInfo = [
      "operation": operation.rawValue,
      "progress": progress,
      "timestamp": Date().timeIntervalSince1970,
    ]

    let request = UNNotificationRequest(identifier: "progress-\(operation.rawValue)-\(Date().timeIntervalSince1970)",
                                        content: content,
                                        trigger: nil)

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        self.logger.error("Failed to show progress notification: \(error.localizedDescription)")
      } else {
        self.logger.info(
          "Progress notification scheduled for \(operation.rawValue) at \(progress * 100)%")
      }
    }
  }

  func showHealthNotification(title: String, body: String, healthIssue: PipelineHealthIssue) {
    guard isNotificationTypeEnabled(.health) else { return }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.categoryIdentifier = healthCategoryID
    content.userInfo = [
      "healthIssue": healthIssue.rawValue,
      "timestamp": Date().timeIntervalSince1970,
    ]

    let request = UNNotificationRequest(identifier: "health-\(healthIssue.rawValue)-\(Date().timeIntervalSince1970)",
                                        content: content,
                                        trigger: nil)

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        self.logger.error("Failed to show health notification: \(error.localizedDescription)")
      } else {
        self.logger.info("Health notification scheduled for \(healthIssue.rawValue)")
      }
    }
  }

  func scheduleOperationNotification(title: String, body: String, operation: PipelineOperation, scheduledTime: Date) {
    guard isNotificationTypeEnabled(.progress) else { return }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.categoryIdentifier = progressCategoryID
    content.userInfo = [
      "operation": operation.rawValue,
      "scheduledTime": scheduledTime.timeIntervalSince1970,
      "timestamp": Date().timeIntervalSince1970,
    ]

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: scheduledTime.timeIntervalSinceNow,
                                                    repeats: false)

    let request = UNNotificationRequest(identifier: "scheduled-\(operation.rawValue)-\(scheduledTime.timeIntervalSince1970)",
                                        content: content,
                                        trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        self.logger.error(
          "Failed to schedule operation notification: \(error.localizedDescription)")
      } else {
        self.logger.info(
          "Operation notification scheduled for \(operation.rawValue) at \(scheduledTime)")
      }
    }
  }

  func cancelNotifications(for operation: PipelineOperation) {
    let center = UNUserNotificationCenter.current()

    center.getPendingNotificationRequests { requests in
      let operationRequests = requests.filter { request in
        request.identifier.contains(operation.rawValue)
      }

      let identifiers = operationRequests.map { $0.identifier }
      center.removePendingNotificationRequests(withIdentifiers: identifiers)

      self.logger.info("Cancelled \(identifiers.count) notifications for \(operation.rawValue)")
    }
  }

  func cancelAllNotifications() {
    let center = UNUserNotificationCenter.current()

    center.getPendingNotificationRequests { requests in
      let pipelineRequests = requests.filter { request in
        request.identifier.contains("success-") || request.identifier.contains("failure-")
          || request.identifier.contains("progress-") || request.identifier.contains("health-")
          || request.identifier.contains("scheduled-")
      }

      let identifiers = pipelineRequests.map { $0.identifier }
      center.removePendingNotificationRequests(withIdentifiers: identifiers)

      self.logger.info("Cancelled all \(identifiers.count) ML pipeline notifications")
    }
  }

  private func setupNotificationCategories() {
    let successCategory = UNNotificationCategory(identifier: successCategoryID,
                                                 actions: [
                                                   UNNotificationAction(identifier: "viewDetails",
                                                                        title: "View Details",
                                                                        options: [.foreground]),
                                                 ],
                                                 intentIdentifiers: [],
                                                 options: [])

    let failureCategory = UNNotificationCategory(identifier: failureCategoryID,
                                                 actions: [
                                                   UNNotificationAction(identifier: "retry",
                                                                        title: "Retry",
                                                                        options: [.foreground]),
                                                   UNNotificationAction(identifier: "viewDetails",
                                                                        title: "View Details",
                                                                        options: [.foreground]),
                                                 ],
                                                 intentIdentifiers: [],
                                                 options: [])

    let progressCategory = UNNotificationCategory(identifier: progressCategoryID,
                                                  actions: [
                                                    UNNotificationAction(identifier: "cancel",
                                                                         title: "Cancel",
                                                                         options: [.destructive]),
                                                  ],
                                                  intentIdentifiers: [],
                                                  options: [])

    let healthCategory = UNNotificationCategory(identifier: healthCategoryID,
                                                actions: [
                                                  UNNotificationAction(identifier: "acknowledge",
                                                                       title: "Acknowledge",
                                                                       options: []),
                                                  UNNotificationAction(identifier: "viewDetails",
                                                                       title: "View Details",
                                                                       options: [.foreground]),
                                                ],
                                                intentIdentifiers: [],
                                                options: [])

    UNUserNotificationCenter.current().setNotificationCategories([
      successCategory,
      failureCategory,
      progressCategory,
      healthCategory,
    ])

    logger.info("ML pipeline notification categories configured")
  }

  private func requestNotificationPermissions() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
      granted, error in
      if granted {
        self.logger.info("Notification permissions granted")
      } else {
        self.logger.warning("Notification permissions denied")
      }

      if let error = error {
        self.logger.error(
          "Error requesting notification permissions: \(error.localizedDescription)")
      }
    }
  }

  func isNotificationTypeEnabled(_ type: NotificationType) -> Bool {
    guard UserDefaults.standard.bool(forKey: notificationsEnabledKey) else { return false }

    switch type {
    case .success:
      return UserDefaults.standard.bool(forKey: successNotificationsKey)
    case .failure:
      return UserDefaults.standard.bool(forKey: failureNotificationsKey)
    case .progress:
      return UserDefaults.standard.bool(forKey: progressNotificationsKey)
    case .health:
      return UserDefaults.standard.bool(forKey: healthNotificationsKey)
    }
  }
}

// Pipeline enums moved to MLTypes.swift

extension MLPipelineNotificationManager {
  var isNotificationsEnabled: Bool {
    UserDefaults.standard.bool(forKey: notificationsEnabledKey)
  }

  func setNotificationsEnabled(_ enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: notificationsEnabledKey)
    logger.info("Notifications \(enabled ? "enabled" : "disabled")")
  }

  func setNotificationTypeEnabled(_ type: NotificationType, enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: "MLPipeline\(type.rawValue)Notifications")
    logger.info("\(type.rawValue) notifications \(enabled ? "enabled" : "disabled")")
  }
}
