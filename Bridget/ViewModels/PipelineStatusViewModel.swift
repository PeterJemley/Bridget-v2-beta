import Foundation
import SwiftData

@MainActor
@Observable
final class PipelineStatusViewModel {
  private let backgroundManager: MLPipelineBackgroundManager
  private let modelContext: ModelContext

  // Observable properties for UI
  var isPipelineHealthy: Bool = false
  var dataAvailabilityStatus: String = "Checking..."
  var populationStatus: String = "Never"
  var exportStatus: String = "Never"

  init(backgroundManager: MLPipelineBackgroundManager? = nil,
       modelContext: ModelContext)
  {
    self.backgroundManager = backgroundManager ?? .shared
    self.modelContext = modelContext
    refreshStatus()
  }

  func refreshStatus() {
    // Pipeline health: based on recent activity
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let lastPopulation = backgroundManager.lastPopulationDate
    let lastExport = backgroundManager.lastExportDate

    // Update isPipelineHealthy
    if let lastPopulation, let lastExport {
      let populationAge =
        calendar.dateComponents([.day], from: lastPopulation, to: today)
          .day ?? 999
      let exportAge =
        calendar.dateComponents([.day], from: lastExport, to: today).day
          ?? 999
      isPipelineHealthy = (populationAge <= 1 && exportAge <= 1)
    } else {
      isPipelineHealthy = false
    }

    // Update population and export status
    populationStatus = getStatusString(for: lastPopulation)
    exportStatus = getStatusString(for: lastExport)

    // Update data availability status
    updateDataAvailabilityStatus()
  }

  private func getStatusString(for date: Date?) -> String {
    guard let date else { return "Never" }
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let age =
      calendar.dateComponents([.day], from: date, to: today).day ?? 999
    if age == 0 { return "Today" }
    if age == 1 { return "Yesterday" }
    return "\(age) days ago"
  }

  private func updateDataAvailabilityStatus() {
    do {
      let descriptor = FetchDescriptor<ProbeTick>()
      let count = try modelContext.fetchCount(descriptor)
      if count > 0 {
        // Get the most recent tick
        var recentDescriptor = FetchDescriptor<ProbeTick>(
          sortBy: [SortDescriptor(\.tsUtc, order: .reverse)]
        )
        recentDescriptor.fetchLimit = 1

        if let recentTick = try modelContext.fetch(recentDescriptor).first {
          let calendar = Calendar.current
          let today = calendar.startOfDay(for: Date())
          let age =
            calendar.dateComponents([.day],
                                    from: recentTick.tsUtc,
                                    to: today).day ?? 999
          if age == 0 {
            dataAvailabilityStatus =
              "Available (Today) - \(count) records"
          } else if age == 1 {
            dataAvailabilityStatus =
              "Available (Yesterday) - \(count) records"
          } else if age <= 7 {
            dataAvailabilityStatus =
              "Available (\(age) days ago) - \(count) records"
          } else {
            dataAvailabilityStatus =
              "Stale (\(age) days old) - \(count) records"
          }
        } else {
          dataAvailabilityStatus =
            "Available - \(count) records"
        }
      } else {
        dataAvailabilityStatus = "No Data"
      }
    } catch {
      dataAvailabilityStatus = "Error checking data"
    }
  }
}
