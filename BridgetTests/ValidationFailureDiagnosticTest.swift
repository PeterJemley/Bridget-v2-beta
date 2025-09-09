import SwiftData
import Testing

@testable import Bridget

@Suite("Validation failure diagnostics")
struct ValidationFailureDiagnosticTest {
  @Test
  @MainActor
  func validationFailureDiagnostic() async throws {
    // Create a model container with all required models
    let schema = Schema([
      BridgeEvent.self,
      RoutePreference.self,
      TrafficInferenceCache.self,
      UserRouteHistory.self,
      ProbeTick.self,
      TrafficProfile.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema,
                                                isStoredInMemoryOnly: true)
    let modelContainer = try ModelContainer(for: schema,
                                            configurations: [modelConfiguration])
    let modelContext = ModelContext(modelContainer)

    // Create AppStateModel to trigger validation failure logging
    _ = AppStateModel(modelContext: modelContext)

    // Trigger data loading which will run validation and log failures
    // This should trigger the validation failure logging in AppStateModel.swift
    let (_, apiValidationFailures) =
      try await BridgeDataService.shared.loadHistoricalData()

    // The validation failures should be logged to console with the grouped output
    // We can see the counts and sample records for the top reasons
    print("🔎 Validation failures: \(apiValidationFailures.count) total")

    if !apiValidationFailures.isEmpty {
      let grouped = Dictionary(grouping: apiValidationFailures,
                               by: { $0.reason })
      let sortedReasons = grouped.keys.sorted {
        (grouped[$0]?.count ?? 0) > (grouped[$1]?.count ?? 0)
      }
      for reason in sortedReasons {
        let count = grouped[reason]?.count ?? 0
        print(" • \(reason): \(count)")
      }
    }

    // The validation failures should be logged to console with the grouped output
    // We can see the counts and sample records for the top reasons

    // Just verify the test runs without crashing
    #expect(true)
  }
}
