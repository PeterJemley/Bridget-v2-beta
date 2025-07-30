//
//  BridgeDataService.swift
//  Bridget
//
//  Module: Services
//  Purpose: Handles data ingestion and processing for bridge opening data
//  Integration Points:
//    - Fetches data from Seattle Open Data API (future)
//    - Creates BridgeStatusModel instances from raw data
//    - Generates RouteModel instances for route management
//    - Called by ContentView to populate AppStateModel
//    - Future: Will integrate with real-time traffic data services
//

import Foundation

// MARK: - Data Models for JSON Decoding
struct BridgeOpeningRecord: Codable {
    let bridgeID: String
    let openingTime: String
    let closingTime: String?
    
    enum CodingKeys: String, CodingKey {
        case bridgeID = "bridge_id"
        case openingTime = "opening_time"
        case closingTime = "closing_time"
    }
}

struct SeattleBridgeData: Codable {
    let data: [BridgeOpeningRecord]
}

// MARK: - Bridge Data Service
class BridgeDataService {
    static let shared = BridgeDataService()
    
    private init() {}
    
    // MARK: - Historical Data Loading
    func loadHistoricalData() async throws -> [BridgeStatusModel] {
        // For now, we'll use a sample URL - you'll need to replace with actual Seattle Open Data endpoint
        guard let url = URL(string: "https://data.seattle.gov/resource/example-endpoint.json") else {
            throw BridgeDataError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BridgeDataError.networkError
        }
        
        return try processHistoricalData(data)
    }
    
    // MARK: - Data Processing
    private func processHistoricalData(_ data: Data) throws -> [BridgeStatusModel] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let bridgeData = try decoder.decode(SeattleBridgeData.self, from: data)
        
        // Group records by bridge ID
        let groupedRecords = Dictionary(grouping: bridgeData.data) { $0.bridgeID }
        
        // Convert to BridgeStatusModel instances
        var bridgeModels: [BridgeStatusModel] = []
        
        for (bridgeID, records) in groupedRecords {
            let openings = records.compactMap { record -> Date? in
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                return dateFormatter.date(from: record.openingTime)
            }
            
            let bridgeModel = BridgeStatusModel(
                bridgeID: bridgeID,
                historicalOpenings: openings.sorted()
            )
            
            bridgeModels.append(bridgeModel)
        }
        
        return bridgeModels
    }
    
    // MARK: - Sample Data for Testing
    func loadSampleData() -> [BridgeStatusModel] {
        let calendar = Calendar.current
        let now = Date()
        
        // Create sample bridge data for testing
        let sampleBridges = [
            ("Fremont Bridge", [
                calendar.date(byAdding: .hour, value: -2, to: now)!,
                calendar.date(byAdding: .hour, value: -4, to: now)!,
                calendar.date(byAdding: .hour, value: -6, to: now)!
            ]),
            ("Ballard Bridge", [
                calendar.date(byAdding: .hour, value: -1, to: now)!,
                calendar.date(byAdding: .hour, value: -3, to: now)!,
                calendar.date(byAdding: .hour, value: -5, to: now)!,
                calendar.date(byAdding: .hour, value: -7, to: now)!
            ]),
            ("University Bridge", [
                calendar.date(byAdding: .hour, value: -2, to: now)!,
                calendar.date(byAdding: .hour, value: -8, to: now)!
            ])
        ]
        
        return sampleBridges.map { bridgeID, openings in
            BridgeStatusModel(bridgeID: bridgeID, historicalOpenings: openings)
        }
    }
    
    // MARK: - Route Generation
    func generateRoutes(from bridges: [BridgeStatusModel]) -> [RouteModel] {
        // Simple route generation for now - in practice, this would use actual routing logic
        let routes = [
            RouteModel(routeID: "Route-1", bridges: Array(bridges.prefix(2)), score: 0.0),
            RouteModel(routeID: "Route-2", bridges: Array(bridges.suffix(2)), score: 0.0),
            RouteModel(routeID: "Route-3", bridges: bridges, score: 0.0)
        ]
        
        return routes
    }
}

// MARK: - Error Types
enum BridgeDataError: Error {
    case invalidURL
    case networkError
    case decodingError
    case processingError
} 