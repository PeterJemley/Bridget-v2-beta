import Foundation

// MARK: - Activity Types

/// Types of pipeline activities
enum ActivityType: String, Codable {
  case dataPopulation = "data_population"
  case dataExport = "data_export"
  case maintenance
  case error
}

// MARK: - Pipeline Activity Model

/// Represents a pipeline activity
struct PipelineActivity: Codable, Identifiable {
  let id: UUID
  let title: String
  let description: String
  let type: ActivityType
  let timestamp: Date

  init(title: String,
       description: String,
       type: ActivityType,
       timestamp: Date)
  {
    self.id = UUID()
    self.title = title
    self.description = description
    self.type = type
    self.timestamp = timestamp
  }
}
