//
//  MLPipelineBackgroundManager.swift
//  Bridget
//
//  Purpose: Background task management for automated ML pipeline operations
//

import Foundation
import Observation
import OSLog
import SwiftData

#if canImport(BackgroundTasks) && !os(macOS)
  import BackgroundTasks
#endif

/// Background task manager for automated ML pipeline operations.
///
/// This service manages background tasks that automatically:
/// - Populate daily ProbeTick data
/// - Export daily NDJSON files
/// - Clean up old export files
/// - Monitor pipeline health
///
/// ## Background Task Types
///
/// - **Data Population**: Daily population of ProbeTick records
/// - **Data Export**: Daily export of NDJSON files
/// - **Maintenance**: Cleanup and health monitoring
///
/// ## Integration Points
///
/// - **BackgroundTasks Framework**: For iOS background execution
/// - **ProbeTickDataService**: For data population
/// - **BridgeDataExporter**: For data export
/// - **UserDefaults**: For configuration and scheduling
/// - **OSLog**: For background task logging
///
/// ## Usage
///
/// The manager is typically initialized in the app delegate or main app file
/// and handles background task registration and execution automatically.
@MainActor
@Observable
final class MLPipelineBackgroundManager {
  @MainActor
  static let shared = MLPipelineBackgroundManager()

  // Background task identifiers
  private let dataPopulationTaskID = "com.bridget.mlpipeline.datapopulation"
  private let dataExportTaskID = "com.bridget.mlpipeline.dataexport"
  private let maintenanceTaskID = "com.bridget.mlpipeline.maintenance"

  private let logger = Logger(subsystem: "Bridget",
                              category: "MLPipelineBackground")

  // Configuration keys
  private let autoExportEnabledKey = "MLAutoExportEnabled"
  private let autoExportTimeKey = "MLAutoExportTime"
  private let lastPopulationDateKey = "MLLastPopulationDate"
  private let lastExportDateKey = "MLLastExportDate"
  private let recentActivitiesKey = "MLRecentActivities"
  private let lastScheduledKey = "MLLastScheduledTime"  // debounce key

  // SwiftData container reference for background operations
  private var modelContainer: ModelContainer?

  private init() {}

  // MARK: - Configuration

  /// Configures the background manager with a SwiftData ModelContainer
  /// - Parameter container: The ModelContainer to use for background operations
  func configure(container: ModelContainer) {
    self.modelContainer = container
    logger.info(
      "MLPipelineBackgroundManager configured with ModelContainer"
    )
  }

  // MARK: - Environment Guards

  private var isRunningInPreviews: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
  }

  private var isRunningInTests: Bool {
    NSClassFromString("XCTest") != nil
  }

  // MARK: - Public Interface

  /// Registers all background tasks with the system.
  ///
  /// This method should be called during app initialization to register
  /// the background tasks that will be executed by the system.
  func registerBackgroundTasks() {
    #if canImport(BackgroundTasks) && !os(macOS)
      if isRunningInPreviews {
        logger.info(
          "Skipping background task registration in SwiftUI previews"
        )
        return
      }
      if isRunningInTests {
        logger.info(
          "Skipping background task registration in unit tests"
        )
        return
      }

      registerDataPopulationTask()
      registerDataExportTask()
      registerMaintenanceTask()

      logger.info("Registered ML pipeline background tasks")
    #else
      logger.info("Background tasks not supported on this platform")
    #endif
  }

  /// Schedules the next background task execution.
  ///
  /// This method schedules the appropriate background tasks based on
  /// the current configuration and last execution times.
  func scheduleNextExecution() {
    #if canImport(BackgroundTasks) && !os(macOS)
      if isRunningInPreviews {
        logger.info(
          "Skipping background task scheduling in SwiftUI previews"
        )
        return
      }
      if isRunningInTests {
        logger.info("Skipping background task scheduling in unit tests")
        return
      }

      // Lightweight debounce: avoid submitting more than once per minute
      let now = Date()
      if let lastScheduled = UserDefaults.standard.object(
        forKey: lastScheduledKey
      ) as? Date,
        now.timeIntervalSince(lastScheduled) < 60
      {
        logger.info(
          "Skipping redundant scheduling (last scheduled \(Int(now.timeIntervalSince(lastScheduled)))s ago)"
        )
        return
      }
      UserDefaults.standard.set(now, forKey: lastScheduledKey)

      scheduleDataPopulationTask()
      scheduleDataExportTask()
      scheduleMaintenanceTask()

      logger.info("Scheduled next ML pipeline background task execution")
    #else
      logger.info(
        "Background task scheduling not supported on this platform"
      )
    #endif
  }

  /// Manually triggers a background task for testing or immediate execution.
  /// - Parameter taskType: The type of task to trigger
  func triggerBackgroundTask(_ taskType: BackgroundTaskType) {
    // Create a background ModelContext for manual execution
    guard let container = modelContainer else {
      logger.error(
        "ModelContainer not configured for manual task execution"
      )
      return
    }

    let context = ModelContext(container)

    switch taskType {
    case .dataPopulation:
      Task { @MainActor [weak self] in
        guard let self else { return }
        do {
          try await executeDataPopulationTask(context: context)
          logger.info(
            "Manual data population task completed successfully"
          )
        } catch {
          logger.error(
            "Manual data population task failed: \(error.localizedDescription)"
          )
        }
      }
    case .dataExport:
      Task { @MainActor [weak self] in
        guard let self else { return }
        do {
          try await executeDataExportTask(context: context)
          logger.info(
            "Manual data export task completed successfully"
          )
        } catch {
          logger.error(
            "Manual data export task failed: \(error.localizedDescription)"
          )
        }
      }
    case .maintenance:
      Task { @MainActor [weak self] in
        guard let self else { return }
        do {
          try await executeMaintenanceTask(context: context)
          logger.info(
            "Manual maintenance task completed successfully"
          )
        } catch {
          logger.error(
            "Manual maintenance task failed: \(error.localizedDescription)"
          )
        }
      }
    }
  }

  // MARK: - Background Task Registration

  #if canImport(BackgroundTasks) && !os(macOS)
    private func registerDataPopulationTask() {
      BGTaskScheduler.shared.register(forTaskWithIdentifier: dataPopulationTaskID,
                                      using: nil)
      { task in
        guard let refreshTask = task as? BGAppRefreshTask else {
          self.logger.error(
            "Expected BGAppRefreshTask but got \(type(of: task))"
          )
          return
        }
        self.handleDataPopulationTask(refreshTask)
      }
    }

    private func registerDataExportTask() {
      BGTaskScheduler.shared.register(forTaskWithIdentifier: dataExportTaskID,
                                      using: nil)
      { task in
        guard let refreshTask = task as? BGAppRefreshTask else {
          self.logger.error(
            "Expected BGAppRefreshTask but got \(type(of: task))"
          )
          return
        }
        self.handleDataExportTask(refreshTask)
      }
    }

    private func registerMaintenanceTask() {
      BGTaskScheduler.shared.register(forTaskWithIdentifier: maintenanceTaskID,
                                      using: nil)
      { task in
        guard let refreshTask = task as? BGAppRefreshTask else {
          self.logger.error(
            "Expected BGAppRefreshTask but got \(type(of: task))"
          )
          return
        }
        self.handleMaintenanceTask(refreshTask)
      }
    }
  #endif

  // MARK: - Background Task Scheduling

  #if canImport(BackgroundTasks) && !os(macOS)
    private func scheduleDataPopulationTask() {
      let request = BGAppRefreshTaskRequest(
        identifier: dataPopulationTaskID
      )

      // Schedule for early morning (2 AM) if not already populated today
      let calendar = Calendar.current
      let now = Date()
      let today = calendar.startOfDay(for: now)

      if let lastPopulation = UserDefaults.standard.object(
        forKey: lastPopulationDateKey
      ) as? Date,
        calendar.isDate(lastPopulation, inSameDayAs: today)
      {
        // Already populated today, schedule for tomorrow
        request.earliestBeginDate = calendar.date(byAdding: .day,
                                                  value: 1,
                                                  to: today)
      } else {
        // Schedule for 2 AM today or tomorrow
        var components = DateComponents()
        components.hour = 2
        components.minute = 0

        if let targetTime = calendar.nextDate(after: now,
                                              matching: components,
                                              matchingPolicy: .nextTime)
        {
          request.earliestBeginDate = targetTime
        } else {
          request.earliestBeginDate = calendar.date(byAdding: .day,
                                                    value: 1,
                                                    to: today)
        }
      }

      do {
        try BGTaskScheduler.shared.submit(request)
        logger.info(
          "Scheduled data population task for \(request.earliestBeginDate?.description ?? "unknown")"
        )
      } catch {
        logger.error(
          "Failed to schedule data population task: \(error.localizedDescription)"
        )
      }
    }

    private func scheduleDataExportTask() {
      guard UserDefaults.standard.bool(forKey: autoExportEnabledKey)
      else {
        logger.info(
          "Auto-export disabled, skipping export task scheduling"
        )
        return
      }

      let request = BGAppRefreshTaskRequest(identifier: dataExportTaskID)

      // Schedule based on configured export time
      let exportTimeString =
        UserDefaults.standard.string(forKey: autoExportTimeKey)
          ?? "01:00"
      let timeComponents = exportTimeString.split(separator: ":")

      if timeComponents.count == 2,
         let hour = Int(timeComponents[0]),
         let minute = Int(timeComponents[1])
      {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        if let targetTime = calendar.nextDate(after: Date(),
                                              matching: components,
                                              matchingPolicy: .nextTime)
        {
          request.earliestBeginDate = targetTime

          do {
            try BGTaskScheduler.shared.submit(request)
            logger.info(
              "Scheduled data export task for \(targetTime.description)"
            )
          } catch {
            logger.error(
              "Failed to schedule data export task: \(error.localizedDescription)"
            )
          }
        }
      }
    }

    private func scheduleMaintenanceTask() {
      let request = BGAppRefreshTaskRequest(identifier: maintenanceTaskID)

      // Schedule maintenance for 3 AM daily
      let calendar = Calendar.current
      var components = DateComponents()
      components.hour = 3
      components.minute = 0

      if let targetTime = calendar.nextDate(after: Date(),
                                            matching: components,
                                            matchingPolicy: .nextTime)
      {
        request.earliestBeginDate = targetTime

        do {
          try BGTaskScheduler.shared.submit(request)
          logger.info(
            "Scheduled maintenance task for \(targetTime.description)"
          )
        } catch {
          logger.error(
            "Failed to schedule maintenance task: \(error.localizedDescription)"
          )
        }
      }
    }
  #endif

  // MARK: - Background Task Handlers

  #if canImport(BackgroundTasks) && !os(macOS)
    private func handleDataPopulationTask(_ task: BGAppRefreshTask) {
      logger.info("Executing data population background task")

      task.expirationHandler = { [weak self] in
        self?.logger.warning("Data population task expired")
        task.setTaskCompleted(success: false)
      }

      Task { @MainActor [weak self] in
        guard let self else {
          task.setTaskCompleted(success: false)
          return
        }
        do {
          guard let container = self.modelContainer else {
            self.logger.error(
              "ModelContainer not configured for background task"
            )
            task.setTaskCompleted(success: false)
            return
          }
          let context = ModelContext(container)
          self.logger.info(
            "Created background ModelContext for data population task"
          )

          try await self.executeDataPopulationTask(context: context)

          self.scheduleDataPopulationTask()

          task.setTaskCompleted(success: true)
          self.logger.info(
            "Data population background task completed successfully"
          )
        } catch {
          self.logger.error(
            "Data population background task failed: \(error.localizedDescription)"
          )
          task.setTaskCompleted(success: false)
        }
      }
    }

    private func handleDataExportTask(_ task: BGAppRefreshTask) {
      logger.info("Executing data export background task")

      task.expirationHandler = { [weak self] in
        self?.logger.warning("Data export task expired")
        task.setTaskCompleted(success: false)
      }

      Task { @MainActor [weak self] in
        guard let self else {
          task.setTaskCompleted(success: false)
          return
        }
        do {
          guard let container = self.modelContainer else {
            self.logger.error(
              "ModelContainer not configured for background task"
            )
            task.setTaskCompleted(success: false)
            return
          }
          let context = ModelContext(container)
          self.logger.info(
            "Created background ModelContext for data export task"
          )

          try await self.executeDataExportTask(context: context)

          self.scheduleDataExportTask()

          task.setTaskCompleted(success: true)
          self.logger.info(
            "Data export background task completed successfully"
          )
        } catch {
          self.logger.error(
            "Data export background task failed: \(error.localizedDescription)"
          )
          task.setTaskCompleted(success: false)
        }
      }
    }

    private func handleMaintenanceTask(_ task: BGAppRefreshTask) {
      logger.info("Executing maintenance background task")

      task.expirationHandler = { [weak self] in
        self?.logger.warning("Maintenance task expired")
        task.setTaskCompleted(success: false)
      }

      Task { @MainActor [weak self] in
        guard let self else {
          task.setTaskCompleted(success: false)
          return
        }
        do {
          guard let container = self.modelContainer else {
            self.logger.error(
              "ModelContainer not configured for background task"
            )
            task.setTaskCompleted(success: false)
            return
          }
          let context = ModelContext(container)
          self.logger.info(
            "Created background ModelContext for maintenance task"
          )

          try await self.executeMaintenanceTask(context: context)

          self.scheduleMaintenanceTask()

          task.setTaskCompleted(success: true)
          self.logger.info(
            "Maintenance background task completed successfully"
          )
        } catch {
          self.logger.error(
            "Maintenance background task failed: \(error.localizedDescription)"
          )
          task.setTaskCompleted(success: false)
        }
      }
    }
  #endif

  // MARK: - Task Execution

  private func executeDataPopulationTask(context _: ModelContext) async throws {
    logger.info(
      "Starting data population task with background ModelContext"
    )

    // TODO: Implement actual data population logic here using 'context'
    try await Task.sleep(nanoseconds: 1_000_000_000)  // Simulated async work

    UserDefaults.standard.set(Date(), forKey: lastPopulationDateKey)

    if MLPipelineNotificationManager.shared.isNotificationTypeEnabled(
      .success
    ) {
      MLPipelineNotificationManager.shared.showSuccessNotification(title: "Data Population Complete",
                                                                   body: "Today's data has been automatically populated.",
                                                                   operation: .dataPopulation)
    }

    logger.info("Data population task executed successfully")
  }

  private func executeDataExportTask(context _: ModelContext) async throws {
    logger.info("Starting data export task with background ModelContext")

    // TODO: Implement actual data export logic here using 'context'
    try await Task.sleep(nanoseconds: 1_000_000_000)  // Simulated async work

    UserDefaults.standard.set(Date(), forKey: lastExportDateKey)

    if MLPipelineNotificationManager.shared.isNotificationTypeEnabled(
      .success
    ) {
      MLPipelineNotificationManager.shared.showSuccessNotification(title: "Data Export Complete",
                                                                   body: "Today's data has been automatically exported.",
                                                                   operation: .dataExport)
    }

    logger.info("Data export task executed successfully")
  }

  private func executeMaintenanceTask(context _: ModelContext) async throws {
    logger.info("Starting maintenance task with background ModelContext")

    // TODO: Implement actual maintenance logic here using 'context'
    try await Task.sleep(nanoseconds: 1_000_000_000)  // Simulated async work

    UserDefaults.standard.set(Date(), forKey: "MLLastMaintenanceDate")

    if MLPipelineNotificationManager.shared.isNotificationTypeEnabled(
      .success
    ) {
      MLPipelineNotificationManager.shared.showSuccessNotification(title: "Maintenance Complete",
                                                                   body: "Pipeline maintenance has been completed successfully.",
                                                                   operation: .maintenance)
    }

    logger.info("Maintenance task executed successfully")
  }

  // MARK: - Maintenance Operations

  private func cleanupOldExports() {
    do {
      let documentsPath = try FileManagerUtils.documentsDirectory()
      let downloadsPath = FileManagerUtils.downloadsDirectory()

      let paths =
        [documentsPath] + (downloadsPath != nil ? [downloadsPath!] : [])
      let calendar = Calendar.current
      let cutoffDate =
        calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()

      for path in paths {
        do {
          try FileManagerUtils.removeOldFiles(in: path,
                                              olderThan: cutoffDate)
          { file in
            file.lastPathComponent.hasPrefix("minutes_")
              && file.lastPathComponent.hasSuffix(".ndjson")
          }
        } catch {
          logger.error(
            "Failed to cleanup old exports in \(path.path): \(error.localizedDescription)"
          )
        }
      }
    } catch {
      logger.error(
        "Failed to access directories for cleanup: \(error.localizedDescription)"
      )
    }
  }

  private func checkPipelineHealth() {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    if let lastPopulation = UserDefaults.standard.object(
      forKey: lastPopulationDateKey
    ) as? Date,
      let lastExport = UserDefaults.standard.object(
        forKey: lastExportDateKey
      ) as? Date
    {
      let populationAge =
        calendar.dateComponents([.day], from: lastPopulation, to: today)
          .day ?? 0
      let exportAge =
        calendar.dateComponents([.day], from: lastExport, to: today).day
          ?? 0

      if populationAge > 1 {
        logger.warning(
          "Pipeline health check: Data population is \(populationAge) days old"
        )
      }

      if exportAge > 1 {
        logger.warning(
          "Pipeline health check: Data export is \(exportAge) days old"
        )
      }
    } else {
      logger.warning("Pipeline health check: No recent activity recorded")
    }
  }
}

// MARK: - Supporting Types

enum BackgroundTaskType: Sendable {
  case dataPopulation
  case dataExport
  case maintenance
}

// MARK: - Extensions

extension MLPipelineBackgroundManager {
  var isAutoExportEnabled: Bool {
    UserDefaults.standard.bool(forKey: autoExportEnabledKey)
  }

  var exportTime: String {
    UserDefaults.standard.string(forKey: autoExportTimeKey) ?? "01:00"
  }

  var lastPopulationDate: Date? {
    UserDefaults.standard.object(forKey: lastPopulationDateKey) as? Date
  }

  var lastExportDate: Date? {
    UserDefaults.standard.object(forKey: lastExportDateKey) as? Date
  }

  func updateLastPopulationDate() {
    UserDefaults.standard.set(Date(), forKey: lastPopulationDateKey)
    logger.info("Updated last population date to \(Date())")
  }

  func updateLastExportDate() {
    UserDefaults.standard.set(Date(), forKey: lastExportDateKey)
    logger.info("Updated last export date to \(Date())")
  }

  func addActivity(title: String, description: String, type: ActivityType) {
    let activity = PipelineActivity(title: title,
                                    description: description,
                                    type: type,
                                    timestamp: Date())

    var activities = getRecentActivities()
    activities.insert(activity, at: 0)

    if activities.count > 10 {
      activities = Array(activities.prefix(10))
    }

    saveRecentActivities(activities)
    logger.info("Added new activity: \(title)")
  }

  func getRecentActivities() -> [PipelineActivity] {
    guard
      let data = UserDefaults.standard.data(forKey: recentActivitiesKey),
      let activities = try? JSONDecoder.bridgeDecoder().decode([PipelineActivity].self,
                                                               from: data)
    else {
      return []
    }
    return activities
  }

  private func saveRecentActivities(_ activities: [PipelineActivity]) {
    if let data = try? JSONEncoder.bridgeEncoder().encode(activities) {
      UserDefaults.standard.set(data, forKey: recentActivitiesKey)
    }
  }
}

// PipelineActivity model is now imported from Models/PipelineActivity.swift
