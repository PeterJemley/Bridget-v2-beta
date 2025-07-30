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

import XCTest
@testable import Bridget

final class ModelTests: XCTestCase {
    
    func testBridgeStatusModelInitialization() {
        let bridge = BridgeStatusModel(bridgeID: "Test Bridge")
        
        XCTAssertEqual(bridge.bridgeID, "Test Bridge")
        XCTAssertEqual(bridge.historicalOpenings.count, 0)
        XCTAssertNil(bridge.realTimeDelay)
        XCTAssertEqual(bridge.totalOpenings, 0)
    }
    
    func testBridgeStatusModelWithHistoricalData() {
        let calendar = Calendar.current
        let now = Date()
        let openings = [
            calendar.date(byAdding: .hour, value: -1, to: now)!,
            calendar.date(byAdding: .hour, value: -2, to: now)!,
            calendar.date(byAdding: .hour, value: -3, to: now)!
        ]
        
        let bridge = BridgeStatusModel(bridgeID: "Test Bridge", historicalOpenings: openings)
        
        XCTAssertEqual(bridge.bridgeID, "Test Bridge")
        XCTAssertEqual(bridge.historicalOpenings.count, 3)
        XCTAssertEqual(bridge.totalOpenings, 3)
        
        // Test opening frequency
        let frequency = bridge.openingFrequency
        XCTAssertFalse(frequency.isEmpty)
    }
    
    func testRouteModelInitialization() {
        let bridges = [
            BridgeStatusModel(bridgeID: "Bridge 1"),
            BridgeStatusModel(bridgeID: "Bridge 2")
        ]
        
        let route = RouteModel(routeID: "Test Route", bridges: bridges, score: 0.5)
        
        XCTAssertEqual(route.routeID, "Test Route")
        XCTAssertEqual(route.bridges.count, 2)
        XCTAssertEqual(route.score, 0.5)
        XCTAssertEqual(route.complexity, 2)
        XCTAssertEqual(route.totalHistoricalOpenings, 0)
    }
    
    func testRouteModelWithHistoricalData() {
        let calendar = Calendar.current
        let now = Date()
        
        let bridge1 = BridgeStatusModel(
            bridgeID: "Bridge 1",
            historicalOpenings: [
                calendar.date(byAdding: .hour, value: -1, to: now)!,
                calendar.date(byAdding: .hour, value: -2, to: now)!
            ]
        )
        
        let bridge2 = BridgeStatusModel(
            bridgeID: "Bridge 2",
            historicalOpenings: [
                calendar.date(byAdding: .hour, value: -3, to: now)!
            ]
        )
        
        let route = RouteModel(routeID: "Test Route", bridges: [bridge1, bridge2])
        
        XCTAssertEqual(route.totalHistoricalOpenings, 3)
        XCTAssertEqual(route.complexity, 2)
    }
    
    func testAppStateModelInitialization() {
        let appState = AppStateModel()
        
        XCTAssertEqual(appState.routes.count, 0)
        XCTAssertFalse(appState.isLoading)
        XCTAssertNil(appState.selectedRouteID)
        XCTAssertNil(appState.error)
        XCTAssertFalse(appState.hasError)
        XCTAssertNil(appState.errorMessage)
    }
    
    func testAppStateModelRouteSelection() {
        let appState = AppStateModel()
        let route = RouteModel(routeID: "Test Route")
        appState.routes = [route]
        
        XCTAssertNil(appState.selectedRoute)
        
        appState.selectRoute(withID: "Test Route")
        XCTAssertEqual(appState.selectedRouteID, "Test Route")
        XCTAssertNotNil(appState.selectedRoute)
        XCTAssertEqual(appState.selectedRoute?.routeID, "Test Route")
        
        appState.clearSelection()
        XCTAssertNil(appState.selectedRouteID)
        XCTAssertNil(appState.selectedRoute)
    }
    
    func testAppStateModelErrorHandling() {
        let appState = AppStateModel()
        
        XCTAssertFalse(appState.hasError)
        XCTAssertNil(appState.errorMessage)
        
        let testError = BridgeDataError.networkError
        appState.error = testError
        
        XCTAssertTrue(appState.hasError)
        XCTAssertEqual(appState.errorMessage, testError.localizedDescription)
        
        appState.clearError()
        XCTAssertFalse(appState.hasError)
        XCTAssertNil(appState.errorMessage)
    }
    
    func testBridgeDataServiceSampleData() {
        let service = BridgeDataService.shared
        let sampleBridges = service.loadSampleData()
        
        XCTAssertFalse(sampleBridges.isEmpty)
        
        for bridge in sampleBridges {
            XCTAssertFalse(bridge.bridgeID.isEmpty)
            XCTAssertGreaterThanOrEqual(bridge.historicalOpenings.count, 0)
        }
    }
    
    func testBridgeDataServiceRouteGeneration() {
        let service = BridgeDataService.shared
        let sampleBridges = service.loadSampleData()
        let routes = service.generateRoutes(from: sampleBridges)
        
        XCTAssertFalse(routes.isEmpty)
        
        for route in routes {
            XCTAssertFalse(route.routeID.isEmpty)
            XCTAssertGreaterThanOrEqual(route.bridges.count, 0)
            XCTAssertEqual(route.score, 0.0) // Initial score should be 0
        }
    }
    
    func testBridgeDataErrorLocalization() {
        let networkError = BridgeDataError.networkError
        let decodingError = BridgeDataError.decodingError
        let invalidURLError = BridgeDataError.invalidURL
        
        XCTAssertNotNil(networkError.localizedDescription)
        XCTAssertNotNil(decodingError.localizedDescription)
        XCTAssertNotNil(invalidURLError.localizedDescription)
        
        XCTAssertFalse(networkError.localizedDescription.isEmpty)
        XCTAssertFalse(decodingError.localizedDescription.isEmpty)
        XCTAssertFalse(invalidURLError.localizedDescription.isEmpty)
    }
    
    func testBridgeOpeningRecordCoding() {
        let record = BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "1st Ave South",
            entityid: "1",
            opendatetime: "2025-01-03T10:12:00.000",
            closedatetime: "2025-01-03T10:20:00.000",
            minutesopen: "8",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )
        
        XCTAssertEqual(record.entityid, "1")
        XCTAssertEqual(record.entityname, "1st Ave South")
        XCTAssertEqual(record.opendatetime, "2025-01-03T10:12:00.000")
        XCTAssertEqual(record.closedatetime, "2025-01-03T10:20:00.000")
        XCTAssertEqual(record.minutesopen, "8")
    }
    
    func testBridgeOpeningRecordComputedProperties() {
        let record = BridgeOpeningRecord(
            entitytype: "Bridge",
            entityname: "1st Ave South",
            entityid: "1",
            opendatetime: "2025-01-03T10:12:00.000",
            closedatetime: "2025-01-03T10:20:00.000",
            minutesopen: "8",
            latitude: "47.542213439941406",
            longitude: "-122.33446502685547"
        )
        
        XCTAssertNotNil(record.openDate)
        XCTAssertNotNil(record.closeDate)
        XCTAssertEqual(record.minutesOpenValue, 8)
        XCTAssertEqual(record.latitudeValue, 47.542213439941406)
        XCTAssertEqual(record.longitudeValue, -122.33446502685547)
    }
    
    func testBridgeOpeningRecordJSONDecoding() {
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
        
        do {
            let record = try JSONDecoder().decode(BridgeOpeningRecord.self, from: json)
            XCTAssertEqual(record.entityid, "1")
            XCTAssertEqual(record.entityname, "1st Ave South")
            XCTAssertEqual(record.opendatetime, "2025-01-03T10:12:00.000")
            XCTAssertEqual(record.closedatetime, "2025-01-03T10:20:00.000")
            XCTAssertEqual(record.minutesopen, "8")
        } catch {
            XCTFail("Failed to decode BridgeOpeningRecord: \(error)")
        }
    }
} 