//
//  BridgetApp.swift
//  Bridget
//
//  Main application entry point with SwiftData configuration and ML pipeline integration
//

import BackgroundTasks
import OSLog
import SwiftData
import SwiftUI

struct AppLifecycleObserver: View {
  let onDidBecomeActive: () -> Void
  let onWillResignActive: () -> Void
  let onDidEnterBackground: () -> Void
  let onWillEnterForeground: () -> Void

  var body: some View {
    Color.clear
      .task {
        let center = NotificationCenter.default

        let didBecomeActive = center.notifications(named: UIApplication.didBecomeActiveNotification)
        let willResignActive = center.notifications(named: UIApplication.willResignActiveNotification)
        let didEnterBackground = center.notifications(named: UIApplication.didEnterBackgroundNotification)
        let willEnterForeground = center.notifications(named: UIApplication.willEnterForegroundNotification)

        Task {
          for await _ in didBecomeActive {
            onDidBecomeActive()
          }
        }

        Task {
          for await _ in willResignActive {
            onWillResignActive()
          }
        }

        Task {
          for await _ in didEnterBackground {
            onDidEnterBackground()
          }
        }

        Task {
          for await _ in willEnterForeground {
            onWillEnterForeground()
          }
        }
      }
  }
}

@main
struct BridgetApp: App {
  private let sharedModelContainer: ModelContainer = {
    let schema = Schema([
      BridgeEvent.self,
      RoutePreference.self,
      TrafficInferenceCache.self,
      UserRouteHistory.self,
      ProbeTick.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  private let backgroundManager = MLPipelineBackgroundManager.shared

  private let notificationManager = MLPipelineNotificationManager.shared

  private let logger = Logger(subsystem: "Bridget", category: "App")

  var body: some Scene {
    WindowGroup {
      VStack {
        ContentView()
        AppLifecycleObserver(onDidBecomeActive: handleAppDidBecomeActive,
                             onWillResignActive: handleAppWillResignActive,
                             onDidEnterBackground: handleAppDidEnterBackground,
                             onWillEnterForeground: handleAppWillEnterForeground)
      }
      .task { initializeMLPipeline() }
    }
    .modelContainer(sharedModelContainer)
  }

  private func initializeMLPipeline() {
    logger.info("Initializing ML Training Data Pipeline")

    backgroundManager.registerBackgroundTasks()

    backgroundManager.scheduleNextExecution()

    if UserDefaults.standard.object(forKey: "MLPipelineFirstLaunch") == nil {
      showWelcomeNotification()
      UserDefaults.standard.set(Date(), forKey: "MLPipelineFirstLaunch")
    }

    logger.info("ML Training Data Pipeline initialized successfully")
  }

  private func handleAppDidBecomeActive() {
    logger.info("App became active")

    backgroundManager.scheduleNextExecution()

    checkPipelineStatus()
  }

  private func handleAppWillResignActive() {
    logger.info("App will resign active")

    backgroundManager.scheduleNextExecution()
  }

  private func handleAppDidEnterBackground() {
    logger.info("App entered background")

    backgroundManager.scheduleNextExecution()

    if notificationManager.isNotificationsEnabled {
      notificationManager.showProgressNotification(title: "ML Pipeline Active",
                                                   body: "Pipeline operations will continue in the background",
                                                   operation: .maintenance,
                                                   progress: 1.0)
    }
  }

  private func handleAppWillEnterForeground() {
    logger.info("App will enter foreground")

    checkPipelineStatus()
  }

  private func checkPipelineStatus() {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    if let lastPopulation = backgroundManager.lastPopulationDate,
       let lastExport = backgroundManager.lastExportDate
    {
      let populationAge = calendar.dateComponents([.day], from: lastPopulation, to: today).day ?? 0
      let exportAge = calendar.dateComponents([.day], from: lastExport, to: today).day ?? 0

      if populationAge > 1, notificationManager.isNotificationTypeEnabled(.health) {
        let body = "Data population is \(populationAge) days old. Consider refreshing data."
        notificationManager.showHealthNotification(title: "Pipeline Health Warning",
                                                   body: body,
                                                   healthIssue: .dataStale)
      }

      if exportAge > 1, notificationManager.isNotificationTypeEnabled(.health) {
        let body = "Data export is \(exportAge) days old. Consider running export."
        notificationManager.showHealthNotification(title: "Pipeline Health Warning",
                                                   body: body,
                                                   healthIssue: .exportFailed)
      }
    }
  }

  private func showWelcomeNotification() {
    let title = "Welcome to Bridget ML Pipeline!"
    let body = "Your ML training data pipeline is now active. Data will be collected and exported automatically."
    notificationManager.showSuccessNotification(title: title,
                                                body: body,
                                                operation: .maintenance)
  }
}
