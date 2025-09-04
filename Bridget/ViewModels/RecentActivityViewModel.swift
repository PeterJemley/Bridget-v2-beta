import Foundation

@MainActor
@Observable
final class RecentActivityViewModel {
  private let backgroundManager: MLPipelineBackgroundManager

  var recentActivities = [PipelineActivity]()

  // Designated initializer
  init(backgroundManager: MLPipelineBackgroundManager) {
    self.backgroundManager = backgroundManager
    refreshActivities()
  }

  // Convenience initializer that safely references the @MainActor-isolated shared instance
  convenience init() {
    self.init(backgroundManager: MLPipelineBackgroundManager.shared)
  }

  func refreshActivities() {
    recentActivities = backgroundManager.getRecentActivities()
  }

  func formatTimeAgo(from date: Date) -> String {
    let calendar = Calendar.current
    let now = Date()
    let components = calendar.dateComponents([.hour, .day],
                                             from: date,
                                             to: now)
    if let days = components.day, days > 0 {
      return days == 1 ? "1 day ago" : "\(days) days ago"
    } else if let hours = components.hour, hours > 0 {
      return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
    } else {
      return "Just now"
    }
  }
}
