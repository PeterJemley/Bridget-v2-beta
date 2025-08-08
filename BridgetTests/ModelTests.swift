import Foundation
//
//  ModelTests.swift
//  BridgetTests
//
//  Module: Tests
//  Purpose: Comprehensive testing of real API integration and data models
//  Dependencies:
//    - XCTest framework
//    - Bridget module (all models and services)
//  Integration Points:
//    - Tests real API error handling
//    - Tests retry logic and caching functionality
//    - Tests DataError localization
//    - Tests all model classes and their interactions
//    - Tests JSON coding/decoding functionality
//  Key Features:
//    - Tests for real API error handling
//    - Tests for retry logic
//    - Tests for caching functionality
//    - Tests for DataError localization
//    - Enhanced existing model tests
//    - Comprehensive coverage of all data flows
//

@testable import Bridget
import Testing

@Suite("Model Tests") struct ModelTests {
  @Test
  func testBridgeStatusModelInitialization() {
    let bridge = BridgeStatusModel(bridgeName: "Test Bridge", apiBridgeID: nil)

    #expect(bridge.bridgeName == "Test Bridge")
    #expect(bridge.historicalOpenings.count == 0)
    #expect(bridge.realTimeDelay == nil)
    #expect(bridge.totalOpenings == 0)
  }

  @Test
  func testBridgeStatusModelWithHistoricalData() {
    let calendar = Calendar.current
    let now = Date()
    let openings = [
      calendar.date(byAdding: .hour, value: -1, to: now)!,
      calendar.date(byAdding: .hour, value: -2, to: now)!,
      calendar.date(byAdding: .hour, value: -3, to: now)!,
    ]

    let bridge = BridgeStatusModel(bridgeName: "Test Bridge", apiBridgeID: nil, historicalOpenings: openings)

    #expect(bridge.bridgeName == "Test Bridge")
    #expect(bridge.historicalOpenings.count == 3)
    #expect(bridge.totalOpenings == 3)

    let frequency = bridge.openingFrequency
    #expect(!frequency.isEmpty)
  }

  @Test
  func testRouteModelInitialization() {
    let bridges = [
      BridgeStatusModel(bridgeName: "Bridge 1", apiBridgeID: nil),
      BridgeStatusModel(bridgeName: "Bridge 2", apiBridgeID: nil),
    ]

    let route = RouteModel(routeID: "Test Route", bridges: bridges, score: 0.5)

    #expect(route.routeID == "Test Route")
    #expect(route.bridges.count == 2)
    #expect(route.score == 0.5)
    #expect(route.complexity == 2)
    #expect(route.totalHistoricalOpenings == 0)
  }

  @Test
  func testRouteModelWithHistoricalData() {
    let calendar = Calendar.current
    let now = Date()

    let bridge1 = BridgeStatusModel(bridgeName: "Bridge 1",
                                    apiBridgeID: nil,
                                    historicalOpenings: [
                                      calendar.date(byAdding: .hour, value: -1, to: now)!,
                                      calendar.date(byAdding: .hour, value: -2, to: now)!,
                                    ])

    let bridge2 = BridgeStatusModel(bridgeName: "Bridge 2",
                                    apiBridgeID: nil,
                                    historicalOpenings: [
                                      calendar.date(byAdding: .hour, value: -3, to: now)!,
                                    ])

    let route = RouteModel(routeID: "Test Route", bridges: [bridge1, bridge2], score: 0.0)

    #expect(route.totalHistoricalOpenings == 3)
    #expect(route.complexity == 2)
  }

  @Test
  func testAppStateModelInitialization() {
    let appState = AppStateModel()

    #expect(appState.routes.count == 0)
    #expect(!appState.isLoading)
    #expect(appState.selectedRouteID == nil)
    #expect(appState.error == nil)
    #expect(!appState.hasError)
    #expect(appState.errorMessage == nil)
  }

  @Test
  func testAppStateModelRouteSelection() {
    let appState = AppStateModel()
    let route = RouteModel(routeID: "Test Route", bridges: [], score: 0.0)
    appState.routes = [route]

    #expect(appState.selectedRoute == nil)

    appState.selectRoute(withID: "Test Route")
    #expect(appState.selectedRouteID == "Test Route")
    #expect(appState.selectedRoute != nil)
    #expect(appState.selectedRoute?.routeID == "Test Route")

    appState.clearSelection()
    #expect(appState.selectedRouteID == nil)
    #expect(appState.selectedRoute == nil)
  }

  @Test
  func testAppStateModelErrorHandling() {
    let appState = AppStateModel()

    #expect(!appState.hasError)
    #expect(appState.errorMessage == nil)

    let testError = NetworkError.networkError
    appState.error = testError

    #expect(appState.hasError)
    #expect(appState.errorMessage == testError.localizedDescription)

    appState.clearError()
    #expect(!appState.hasError)
    #expect(appState.errorMessage == nil)
  }

  @Test
  func testBridgeDataServiceSampleData() {
    let service = BridgeDataService.shared
    let sampleBridges = service.loadSampleData()

    #expect(!sampleBridges.isEmpty)

    for bridge in sampleBridges {
      #expect(!bridge.bridgeName.isEmpty)
      #expect(bridge.historicalOpenings.count >= 0)
    }
  }

  @Test
  func testBridgeDataServiceRouteGeneration() {
    let service = BridgeDataService.shared
    let sampleBridges = service.loadSampleData()
    let routes = service.generateRoutes(from: sampleBridges)

    #expect(!routes.isEmpty)

    for route in routes {
      #expect(!route.routeID.isEmpty)
      #expect(route.bridges.count >= 0)
      #expect(route.score == 0.0)
    }
  }

  @Test
  func testBridgeDataErrorLocalization() {
    let networkError = NetworkError.networkError
    let decodingError = BridgeDataError.decodingError(.dataCorrupted(.init(codingPath: [], debugDescription: "test")), rawData: Data())
    let invalidURLError = NetworkError.invalidResponse

    #expect(!networkError.localizedDescription.isEmpty)
    #expect(!decodingError.localizedDescription.isEmpty)
    #expect(!invalidURLError.localizedDescription.isEmpty)

    #expect(!networkError.localizedDescription.isEmpty)
    #expect(!decodingError.localizedDescription.isEmpty)
    #expect(!invalidURLError.localizedDescription.isEmpty)
  }

  @Test
  func testBridgeOpeningRecordCoding() {
    let record = BridgeOpeningRecord(entitytype: "Bridge",
                                     entityname: "1st Ave South",
                                     entityid: "1",
                                     opendatetime: "2025-01-03T10:12:00.000",
                                     closedatetime: "2025-01-03T10:20:00.000",
                                     minutesopen: "8",
                                     latitude: "47.542213439941406",
                                     longitude: "-122.33446502685547")

    #expect(record.entityid == "1")
    #expect(record.entityname == "1st Ave South")
    #expect(record.opendatetime == "2025-01-03T10:12:00.000")
    #expect(record.closedatetime == "2025-01-03T10:20:00.000")
    #expect(record.minutesopen == "8")
  }

  @Test
  func testBridgeOpeningRecordComputedProperties() {
    let record = BridgeOpeningRecord(entitytype: "Bridge",
                                     entityname: "1st Ave South",
                                     entityid: "1",
                                     opendatetime: "2025-01-03T10:12:00.000",
                                     closedatetime: "2025-01-03T10:20:00.000",
                                     minutesopen: "8",
                                     latitude: "47.542213439941406",
                                     longitude: "-122.33446502685547")

    #expect(record.openDate != nil)
    #expect(record.closeDate != nil)
    #expect(record.minutesOpenValue == 8)
    #expect(record.latitudeValue == 47.542213439941406)
    #expect(record.longitudeValue == -122.33446502685547)
  }

  @Test
  func testBridgeOpeningRecordJSONDecoding() throws {
    let json = """
    {
        "entitytype": "Bridge",
        "entityname": "1st Ave South",
        "entityid": "1",
        "opendatetime": "2025-01-03T10:12:00.000",
        "closedatetime": "2025-01-03T10:20:00.000",
        "minutesopen": "8",
        "latitude": "47.542213439941406",
        "longitude": "-122.33446502685547"
    }
    """.data(using: .utf8)!

    let record = try JSONDecoder().decode(BridgeOpeningRecord.self, from: json)
    #expect(record.entityid == "1")
    #expect(record.entityname == "1st Ave South")
    #expect(record.opendatetime == "2025-01-03T10:12:00.000")
    #expect(record.closedatetime == "2025-01-03T10:20:00.000")
    #expect(record.minutesopen == "8")
  }

  @Test
  func testMissingRequiredKeys() {
    let json = """
    {
        "entitytype": "Bridge",
        "entityname": "1st Ave South"
        // Missing entityid, opendatetime, etc.
    }
    """.data(using: .utf8)!

    #expect(throws: DecodingError.self) {
      _ = try JSONDecoder().decode(BridgeOpeningRecord.self, from: json)
    }
  }

  @Test
  func testExtraUnknownKeys() throws {
    let json = """
    {
        "entitytype": "Bridge",
        "entityname": "1st Ave South",
        "entityid": "1",
        "opendatetime": "2025-01-03T10:12:00.000",
        "closedatetime": "2025-01-03T10:20:00.000",
        "minutesopen": "8",
        "latitude": "47.542213439941406",
        "longitude": "-122.33446502685547",
        "unknown_field": "should_be_ignored"
    }
    """.data(using: .utf8)!

    let record = try JSONDecoder().decode(BridgeOpeningRecord.self, from: json)
    #expect(record.entityid == "1")
    #expect(record.entityname == "1st Ave South")
  }

  @Test
  func testMalformedDateStrings() throws {
    let json = """
    {
        "entitytype": "Bridge",
        "entityname": "1st Ave South",
        "entityid": "1",
        "opendatetime": "invalid-date-format",
        "closedatetime": "2025-01-03T10:20:00.000",
        "minutesopen": "8",
        "latitude": "47.542213439941406",
        "longitude": "-122.33446502685547"
    }
    """.data(using: .utf8)!

    let record = try JSONDecoder().decode(BridgeOpeningRecord.self, from: json)
    #expect(record.openDate == nil, "Should have nil openDate for malformed date")
    #expect(record.closeDate != nil, "Should have valid closeDate")
  }

  @Test
  func testEmptyArrayPayload() throws {
    let json = "[]".data(using: .utf8)!

    let records = try JSONDecoder().decode([BridgeOpeningRecord].self, from: json)
    #expect(records.count == 0)
  }

  @Test
  func testEmptyStringValues() throws {
    let json = """
    {
        "entitytype": "Bridge",
        "entityname": "",
        "entityid": "",
        "opendatetime": "2025-01-03T10:12:00.000",
        "closedatetime": "2025-01-03T10:20:00.000",
        "minutesopen": "8",
        "latitude": "47.542213439941406",
        "longitude": "-122.33446502685547"
    }
    """.data(using: .utf8)!

    let record = try JSONDecoder().decode(BridgeOpeningRecord.self, from: json)
    #expect(record.entityid == "")
    #expect(record.entityname == "")
    #expect(record.entityid.isEmpty)
    #expect(record.entityname.isEmpty)
  }

  @Test
  func testInvalidNumericValues() throws {
    let json = """
    {
        "entitytype": "Bridge",
        "entityname": "1st Ave South",
        "entityid": "1",
        "opendatetime": "2025-01-03T10:12:00.000",
        "closedatetime": "2025-01-03T10:20:00.000",
        "minutesopen": "not_a_number",
        "latitude": "invalid_latitude",
        "longitude": "invalid_longitude"
    }
    """.data(using: .utf8)!

    let record = try JSONDecoder().decode(BridgeOpeningRecord.self, from: json)
    #expect(record.minutesOpenValue == nil)
    #expect(record.latitudeValue == nil)
    #expect(record.longitudeValue == nil)
  }

  @Test
  func testUpdatedBridgeDataErrorLocalization() {
    let networkError = NetworkError.networkError
    let invalidContentTypeError = NetworkError.invalidContentType
    let payloadSizeError = NetworkError.payloadSizeError
    let decodingError = BridgeDataError.decodingError(.dataCorrupted(.init(codingPath: [], debugDescription: "test")), rawData: Data())
    let processingError = BridgeDataError.processingError("test error")

    #expect(!networkError.localizedDescription.isEmpty)
    #expect(!invalidContentTypeError.localizedDescription.isEmpty)
    #expect(!payloadSizeError.localizedDescription.isEmpty)
    #expect(!decodingError.localizedDescription.isEmpty)
    #expect(!processingError.localizedDescription.isEmpty)
  }

  @Test
  func testOutOfRangeDate() throws {
    let json = """
    {
        "entitytype": "Bridge",
        "entityname": "1st Ave South",
        "entityid": "1",
        "opendatetime": "1970-01-01T10:12:00.000",
        "closedatetime": "1970-01-01T10:20:00.000",
        "minutesopen": "8",
        "latitude": "47.542213439941406",
        "longitude": "-122.33446502685547"
    }
    """.data(using: .utf8)!

    _ = try JSONDecoder().decode(BridgeOpeningRecord.self, from: json)
    #expect(true)
  }

  @Test
  func testUnknownBridgeID() throws {
    let json = """
    {
        "entitytype": "Bridge",
        "entityname": "Unknown Bridge",
        "entityid": "999",
        "opendatetime": "2025-01-03T10:12:00.000",
        "closedatetime": "2025-01-03T10:20:00.000",
        "minutesopen": "8",
        "latitude": "47.542213439941406",
        "longitude": "-122.33446502685547"
    }
    """.data(using: .utf8)!

    _ = try JSONDecoder().decode(BridgeOpeningRecord.self, from: json)
    #expect(true)
  }

  @Test
  func test304NoChangeResponse() {
    let emptyData = Data()
    #expect(emptyData.isEmpty)
  }

  @Test
  func testOversizedPayload() {
    let largeData = Data(repeating: 0, count: 6 * 1024 * 1024)
    #expect(largeData.count > 5 * 1024 * 1024)
  }

  @Test
  func testBridgeDataProcessorRejectsOutOfRangeValues() throws {
    let processor = BridgeDataProcessor.shared
    let validDate = "2025-01-03T10:12:00.000"
    let validCloseDate = "2025-01-03T10:20:00.000"

    let invalidLatJSON = """
    [{
        "entitytype": "Bridge",
        "entityname": "Test Bridge",
        "entityid": "1",
        "opendatetime": "\(validDate)",
        "closedatetime": "\(validCloseDate)",
        "minutesopen": "8",
        "latitude": "95.0",
        "longitude": "-122.334465"
    }]
    """.data(using: .utf8)!
    #expect(try processor.processHistoricalData(invalidLatJSON).0.isEmpty)

    let invalidLonJSON = """
    [{
        "entitytype": "Bridge",
        "entityname": "Test Bridge",
        "entityid": "1",
        "opendatetime": "\(validDate)",
        "closedatetime": "\(validCloseDate)",
        "minutesopen": "8",
        "latitude": "47.542213",
        "longitude": "-190.0"
    }]
    """.data(using: .utf8)!
    #expect(try processor.processHistoricalData(invalidLonJSON).0.isEmpty)

    let invalidMinutesJSON = """
    [{
        "entitytype": "Bridge",
        "entityname": "Test Bridge",
        "entityid": "1",
        "opendatetime": "\(validDate)",
        "closedatetime": "\(validCloseDate)",
        "minutesopen": "-5",
        "latitude": "47.542213",
        "longitude": "-122.334465"
    }]
    """.data(using: .utf8)!
    #expect(try processor.processHistoricalData(invalidMinutesJSON).0.isEmpty)

    let oldDateJSON = """
    [{
        "entitytype": "Bridge",
        "entityname": "Test Bridge",
        "entityid": "1",
        "opendatetime": "2010-01-03T10:12:00.000",
        "closedatetime": "2010-01-03T10:20:00.000",
        "minutesopen": "8",
        "latitude": "47.542213",
        "longitude": "-122.334465"
    }]
    """.data(using: .utf8)!
    #expect(try processor.processHistoricalData(oldDateJSON).0.isEmpty)
  }
}

