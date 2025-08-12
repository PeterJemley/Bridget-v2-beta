//
//  ProbeTickExportTests.swift
//  BridgetTests
//
//  Purpose: Test the complete ProbeTick data pipeline and export functionality
//  Dependencies: XCTest, SwiftData, ProbeTickDataService, BridgeDataExporter
//  Integration Points:
//    - Tests ProbeTick data population from BridgeEvent data
//    - Tests daily NDJSON export functionality
//    - Demonstrates the complete ML training data pipeline
//  Key Features:
//    - End-to-end testing of the data collection and export pipeline
//    - Validation of exported file formats and content
//    - Performance testing for large datasets
//

@testable import Bridget
import Foundation
import SwiftData
import XCTest

/// Tests the complete ProbeTick data pipeline and export functionality.
///
/// This test suite demonstrates how to:
/// 1. Populate ProbeTick data from existing BridgeEvent records
/// 2. Export daily NDJSON files for ML training
/// 3. Validate the exported data format and content
final class ProbeTickExportTests: XCTestCase {
  var modelContainer: ModelContainer!
  var context: ModelContext!
  var probeTickService: ProbeTickDataService!
  var exporter: BridgeDataExporter!

  override func setUpWithError() throws {
    // Create an in-memory SwiftData container for testing
    let schema = Schema([
      BridgeEvent.self,
      ProbeTick.self,
      RoutePreference.self,
      TrafficInferenceCache.self,
      UserRouteHistory.self,
    ])

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    modelContainer = try ModelContainer(for: schema, configurations: [config])
    context = ModelContext(modelContainer)

    probeTickService = ProbeTickDataService(context: context)
    exporter = BridgeDataExporter(context: context)
  }

  override func tearDownWithError() throws {
    modelContainer = nil
    context = nil
    probeTickService = nil
    exporter = nil
  }

  /// Test the complete pipeline: populate ProbeTick data and export to NDJSON.
  func testCompleteExportPipeline() async throws {
    // Step 1: Create sample BridgeEvent data for testing
    try await createSampleBridgeEvents()

    // Step 2: Populate ProbeTick data from BridgeEvent data
    try await probeTickService.populateTodayProbeTicks()

    // Step 3: Verify ProbeTick data was created
    let tickCount = try context.fetch(FetchDescriptor<ProbeTick>()).count
    XCTAssertGreaterThan(tickCount, 0, "Should have created ProbeTick records")

    // Step 4: Export today's data to NDJSON
    let today = Calendar.current.startOfDay(for: Date())
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_export")
      .appendingPathComponent("minutes_\(formatDate(today)).ndjson")

    // Ensure output directory exists
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)

    // Run the export
    try await exporter.exportDailyNDJSON(for: today, to: outputURL)

    // Step 5: Verify the exported files exist and have content
    XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "NDJSON file should exist")

    let fileSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64 ?? 0
    XCTAssertGreaterThan(fileSize, 0, "NDJSON file should not be empty")

    // Step 6: Verify metrics file was created
    let metricsURL = outputURL.deletingPathExtension().appendingPathExtension("metrics.json")
    XCTAssertTrue(FileManager.default.fileExists(atPath: metricsURL.path), "Metrics file should exist")

    // Step 7: Verify .done marker file was created
    let doneURL = outputURL.deletingPathExtension().appendingPathExtension("done")
    XCTAssertTrue(FileManager.default.fileExists(atPath: doneURL.path), ".done marker file should exist")

    // Clean up test files
    try FileManager.default.removeItem(at: outputURL.deletingLastPathComponent())
  }

  /// Test exporting data for a specific date range.
  func testExportDateRange() async throws {
    // Create sample data for the last week
    try await createSampleBridgeEvents()
    try await probeTickService.populateLastWeekProbeTicks()

    // Export for a specific date
    let calendar = Calendar.current
    let testDate = calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date()
    let startOfTestDate = calendar.startOfDay(for: testDate)

    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_range_export")
      .appendingPathComponent("minutes_\(formatDate(startOfTestDate)).ndjson")

    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)

    try await exporter.exportDailyNDJSON(for: startOfTestDate, to: outputURL)

    // Verify export
    XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

    // Clean up
    try FileManager.default.removeItem(at: outputURL.deletingLastPathComponent())
  }

  /// Test the feature computation and validation.
  func testFeatureComputation() async throws {
    // Create sample data
    try await createSampleBridgeEvents()
    try await probeTickService.populateTodayProbeTicks()

    // Fetch some ProbeTick records and verify feature values
    let ticks = try context.fetch(FetchDescriptor<ProbeTick>())
    XCTAssertFalse(ticks.isEmpty, "Should have ProbeTick records")

    for tick in ticks.prefix(5) { // Check first 5 records
      // Verify feature ranges
      XCTAssertGreaterThanOrEqual(tick.viaPenaltySec, 0, "viaPenaltySec should be >= 0")
      XCTAssertLessThanOrEqual(tick.viaPenaltySec, 900, "viaPenaltySec should be <= 900")
      XCTAssertGreaterThanOrEqual(tick.gateAnom, 1.0, "gateAnom should be >= 1.0")
      XCTAssertLessThanOrEqual(tick.gateAnom, 8.0, "gateAnom should be <= 8.0")
      XCTAssertGreaterThanOrEqual(tick.alternatesTotal, 1, "alternatesTotal should be >= 1")
      XCTAssertGreaterThanOrEqual(tick.alternatesAvoid, 0, "alternatesAvoid should be >= 0")
      XCTAssertLessThanOrEqual(tick.alternatesAvoid, tick.alternatesTotal, "alternatesAvoid should be <= alternatesTotal")
    }
  }

  // MARK: - Helper Methods

  /// Creates sample BridgeEvent data for testing.
  private func createSampleBridgeEvents() async throws {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Create sample events for different bridges
    let bridgeIDs = ["1", "2", "3"] // First Ave South, Ballard, Fremont
    let bridgeNames = ["First Avenue South Bridge", "Ballard Bridge", "Fremont Bridge"]

    for (index, bridgeID) in bridgeIDs.enumerated() {
      // Create a morning opening event
      let morningOpen = calendar.date(byAdding: .hour, value: 8, to: today) ?? today
      let morningClose = calendar.date(byAdding: .minute, value: 15, to: morningOpen) ?? morningOpen

      let morningEvent = BridgeEvent(bridgeID: bridgeID,
                                     bridgeName: bridgeNames[index],
                                     openDateTime: morningOpen,
                                     closeDateTime: morningClose,
                                     minutesOpen: 15,
                                     latitude: 47.5422,
                                     longitude: -122.3344,
                                     entityType: "Bridge",
                                     isValidated: true)

      // Create an afternoon opening event
      let afternoonOpen = calendar.date(byAdding: .hour, value: 17, to: today) ?? today
      let afternoonClose = calendar.date(byAdding: .minute, value: 12, to: afternoonOpen) ?? afternoonOpen

      let afternoonEvent = BridgeEvent(bridgeID: bridgeID,
                                       bridgeName: bridgeNames[index],
                                       openDateTime: afternoonOpen,
                                       closeDateTime: afternoonClose,
                                       minutesOpen: 12,
                                       latitude: 47.5422,
                                       longitude: -122.3344,
                                       entityType: "Bridge",
                                       isValidated: true)

      context.insert(morningEvent)
      context.insert(afternoonEvent)
    }

    try context.save()
  }

  /// Formats a date as YYYY-MM-DD for file naming.
  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}

// MARK: - Usage Examples

extension ProbeTickExportTests {
  /// Example: How to run the exporter for today in production code.
  ///
  /// This demonstrates the complete workflow for generating ML training data:
  /// 1. Populate ProbeTick data from existing BridgeEvent records
  /// 2. Export daily NDJSON files
  /// 3. Process with Python for ML training
  func exampleProductionWorkflow() async throws {
    // This would typically be called from a background task or scheduled job

    // Step 1: Populate today's ProbeTick data
    try await probeTickService.populateTodayProbeTicks()

    // Step 2: Export today's data
    let today = Calendar.current.startOfDay(for: Date())
    let outputURL = URL(fileURLWithPath: "/path/to/ml/data/minutes_\(formatDate(today)).ndjson")

    try await exporter.exportDailyNDJSON(for: today, to: outputURL)

    // Step 3: The exported files can now be processed with Python:
    // python train_prep.py --input minutes_2025-01-27.ndjson --output training_data.csv

    print("✅ Daily export complete: \(outputURL.path)")
    print("📊 Files generated:")
    print("   - \(outputURL.lastPathComponent)")
    print("   - \(outputURL.deletingPathExtension().appendingPathExtension("metrics.json").lastPathComponent)")
    print("   - \(outputURL.deletingPathExtension().appendingPathExtension("done").lastPathComponent)")
  }
}

