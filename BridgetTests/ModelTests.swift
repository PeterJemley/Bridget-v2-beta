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
        
        XCTAssertEqual(bridge.historicalOpenings.count, 3)
        XCTAssertEqual(bridge.totalOpenings, 3)
        XCTAssertEqual(bridge.openingFrequency.count, 3) // 3 different hours
    }
    
    func testBridgeStatusModelOpeningFrequency() {
        let calendar = Calendar.current
        let now = Date()
        let openings = [
            calendar.date(byAdding: .hour, value: -1, to: now)!,
            calendar.date(byAdding: .hour, value: -1, to: now)!, // Same hour
            calendar.date(byAdding: .hour, value: -2, to: now)!
        ]
        
        let bridge = BridgeStatusModel(bridgeID: "Test Bridge", historicalOpenings: openings)
        let frequency = bridge.openingFrequency
        
        XCTAssertEqual(frequency.count, 2) // 2 different hours
        XCTAssertEqual(frequency["\(calendar.component(.hour, from: calendar.date(byAdding: .hour, value: -1, to: now)!)):00"], 2) // 2 openings at -1 hour
        XCTAssertEqual(frequency["\(calendar.component(.hour, from: calendar.date(byAdding: .hour, value: -2, to: now)!)):00"], 1) // 1 opening at -2 hours
    }
    
    func testRouteModelInitialization() {
        let route = RouteModel(routeID: "Test Route")
        
        XCTAssertEqual(route.routeID, "Test Route")
        XCTAssertEqual(route.bridges.count, 0)
        XCTAssertEqual(route.score, 0.0)
        XCTAssertEqual(route.complexity, 0)
        XCTAssertEqual(route.totalHistoricalOpenings, 0)
    }
    
    func testRouteModelWithBridges() {
        let bridge1 = BridgeStatusModel(bridgeID: "Bridge 1")
        let bridge2 = BridgeStatusModel(bridgeID: "Bridge 2")
        let route = RouteModel(routeID: "Test Route", bridges: [bridge1, bridge2], score: 0.8)
        
        XCTAssertEqual(route.bridges.count, 2)
        XCTAssertEqual(route.score, 0.8)
        XCTAssertEqual(route.complexity, 2)
        XCTAssertEqual(route.totalHistoricalOpenings, 0)
    }
    
    func testAppStateModelInitialization() {
        let appState = AppStateModel()
        
        XCTAssertEqual(appState.routes.count, 0)
        XCTAssertFalse(appState.isLoading)
        XCTAssertNil(appState.selectedRouteID)
        XCTAssertNil(appState.selectedRoute)
        XCTAssertEqual(appState.totalRoutes, 0)
    }
    
    func testAppStateModelRouteSelection() {
        let appState = AppStateModel()
        
        // Create test routes
        let route1 = RouteModel(routeID: "Route 1")
        let route2 = RouteModel(routeID: "Route 2")
        
        // Manually set routes for testing (since init() now auto-loads)
        appState.routes = [route1, route2]
        
        XCTAssertEqual(appState.totalRoutes, 2)
        
        appState.selectRoute(withID: "Route 1")
        XCTAssertEqual(appState.selectedRouteID, "Route 1")
        XCTAssertEqual(appState.selectedRoute?.routeID, "Route 1")
        
        appState.clearRouteSelection()
        XCTAssertNil(appState.selectedRouteID)
        XCTAssertNil(appState.selectedRoute)
    }
    
    func testBridgeDataServiceSampleData() {
        let bridges = BridgeDataService.shared.loadSampleData()
        
        XCTAssertGreaterThan(bridges.count, 0)
        
        for bridge in bridges {
            XCTAssertFalse(bridge.bridgeID.isEmpty)
            XCTAssertGreaterThanOrEqual(bridge.historicalOpenings.count, 0)
        }
    }
    
    func testBridgeDataServiceRouteGeneration() {
        let bridges = BridgeDataService.shared.loadSampleData()
        let routes = BridgeDataService.shared.generateRoutes(from: bridges)
        
        XCTAssertGreaterThan(routes.count, 0)
        
        for route in routes {
            XCTAssertFalse(route.routeID.isEmpty)
            XCTAssertGreaterThan(route.bridges.count, 0)
            XCTAssertEqual(route.score, 0.0) // Initial score
        }
    }
} 