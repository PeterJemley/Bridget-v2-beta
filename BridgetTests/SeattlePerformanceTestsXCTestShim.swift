#if canImport(Testing)
  @testable import Bridget
  import Testing
  import XCTest

  /// XCTestCase shim to run Swift Testing tests through Xcode
  /// This allows you to keep using Swift Testing syntax while running tests in Xcode
  final class SeattlePerformanceTestsXCTestShim: XCTestCase {
    // MARK: - Test Execution

    func testFixtureIntegrity() throws {
      let suite = SeattlePerformanceTests()
      try suite.fixtureIntegrity()
    }

    func testSeattleDatasetLoadingPerformance() throws {
      let suite = SeattlePerformanceTests()
      try suite.seattleDatasetLoadingPerformance()
    }

    func testMemoryUsageBaseline() throws {
      let suite = SeattlePerformanceTests()
      try suite.memoryUsageBaseline()
    }

    func testShortestPathCorrectness() throws {
      let suite = SeattlePerformanceTests()
      try suite.shortestPathCorrectness()
    }

    func testGoldenPathComparison() throws {
      let suite = SeattlePerformanceTests()
      try suite.goldenPathComparison()
    }

    func testPruningWithTightMaxTimeOverShortest() throws {
      let suite = SeattlePerformanceTests()
      try suite.pruningWithTightMaxTimeOverShortest()
    }

    func testOriginDestinationPathEnumeration() throws {
      let suite = SeattlePerformanceTests()
      try suite.originDestinationPathEnumeration()
    }

    func testAlgorithmParityDFSvsYen() throws {
      let suite = SeattlePerformanceTests()
      try suite.algorithmParityDFSvsYen()
    }

    func testCachePerformance_featureCacheOnly() async throws {
      let suite = SeattlePerformanceTests()
      try await suite.cachePerformance_featureCacheOnly()
    }

    func testCachePerformance_pathMemoizationOnly() throws {
      let suite = SeattlePerformanceTests()
      try suite.cachePerformance_pathMemoizationOnly()
    }

    func testMemoryStability() async throws {
      let suite = SeattlePerformanceTests()
      try await suite.memoryStability()
    }

    func testEndToEndPipelinePerformance() async throws {
      let suite = SeattlePerformanceTests()
      try await suite.endToEndPipelinePerformance()
    }
  }

  // MARK: - Helper Extensions

  extension XCTestCase {
    func getCurrentMemoryUsage() -> UInt64 {
      var info = mach_task_basic_info()
      var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

      let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
          task_info(mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count)
        }
      }

      if kerr == KERN_SUCCESS {
        return UInt64(info.resident_size)
      } else {
        return 0
      }
    }
  }
#else
  import XCTest

  /// Placeholder test to keep XCTest-only environments green when Swift Testing is unavailable.
  /// This does not run any Swift Testing suites.
  final class SeattlePerformanceTests_XCTestPlaceholder: XCTestCase {
    func testSwiftTestingUnavailablePlaceholder() {
      XCTAssertTrue(true, "Swift Testing not available; placeholder test executed.")
    }
  }
#endif
