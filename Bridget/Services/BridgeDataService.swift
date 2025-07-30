//
//  BridgeDataService.swift
//  Bridget
//
//  Purpose: Historical bridge opening data service with caching infrastructure
//  Dependencies: Foundation (URLSession, JSONDecoder, FileManager), BridgeStatusModel
//  Integration Points: 
//    - Fetches historical data from Seattle Open Data API: https://data.seattle.gov/resource/gm8h-9449.json
//    - Implements retry logic with exponential backoff
//    - Provides offline caching to disk for historical data
//    - Creates BridgeStatusModel instances from historical API data
//    - Generates RouteModel instances for route management
//    - Called by AppStateModel to populate historical route data
//    - Future: Will integrate with real-time traffic data services (if available)
//  Key Features:
//    - Comprehensive error handling (BridgeDataError enum)
//    - Historical data fallback for testing
//    - JSON decoding with custom CodingKeys for historical records
//    - Async/await network calls for historical data
//    - Cache-first strategy for historical bridge opening records
//

import Foundation

// MARK: - Data Models for JSON Decoding
struct BridgeOpeningRecord: Codable {
    let entitytype: String
    let entityname: String
    let entityid: String
    let opendatetime: String
    let closedatetime: String
    let minutesopen: String
    let latitude: String
    let longitude: String
    
    // Computed properties for parsed values
    var openDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter.date(from: opendatetime)
    }
    
    var closeDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter.date(from: closedatetime)
    }
    
    var minutesOpenValue: Int? {
        return Int(minutesopen)
    }
    
    var latitudeValue: Double? {
        return Double(latitude)
    }
    
    var longitudeValue: Double? {
        return Double(longitude)
    }
}

// MARK: - Bridge Data Service
class BridgeDataService {
    static let shared = BridgeDataService()
    
    // MARK: - Cache Configuration
    private let cacheDirectory = "BridgeCache"
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 2.0
    
    private init() {}
    
    // MARK: - Cache Management
    private func getCacheDirectory() -> URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsPath.appendingPathComponent(cacheDirectory)
    }
    
    private func getCacheFileURL(for key: String) -> URL? {
        return getCacheDirectory()?.appendingPathComponent("\(key).json")
    }
    
    private func saveToCache<T: Codable>(_ data: T, for key: String) {
        guard let cacheURL = getCacheFileURL(for: key) else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(data)
            try data.write(to: cacheURL)
        } catch {
            print("Failed to save cache for key \(key): \(error)")
        }
    }
    
    private func loadFromCache<T: Codable>(_ type: T.Type, for key: String) -> T? {
        guard let cacheURL = getCacheFileURL(for: key) else { return nil }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            print("Failed to load cache for key \(key): \(error)")
            return nil
        }
    }
    
    private func isCacheValid(for key: String) -> Bool {
        guard let cacheURL = getCacheFileURL(for: key) else { return false }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: cacheURL.path)
            guard let modificationDate = attributes[.modificationDate] as? Date else { return false }
            
            let cacheAge = Date().timeIntervalSince(modificationDate)
            return cacheAge < cacheExpirationTime
        } catch {
            return false
        }
    }
    
    // MARK: - Historical Data Loading
    func loadHistoricalData() async throws -> [BridgeStatusModel] {
        // Check cache first
        if let cachedBridges: [BridgeStatusModel] = loadFromCache([BridgeStatusModel].self, for: "historical_bridges"),
           isCacheValid(for: "historical_bridges") {
            // Update cache metadata for all bridges
            cachedBridges.forEach { $0.updateCacheMetadata() }
            return cachedBridges
        }
        
        // Try to load from network with retry logic
        var lastError: Error?
        
        for attempt in 1...maxRetryAttempts {
            do {
                let bridges = try await fetchFromNetwork()
                
                // Update cache metadata and save to cache
                bridges.forEach { $0.updateCacheMetadata() }
                saveToCache(bridges, for: "historical_bridges")
                
                return bridges
            } catch {
                lastError = error
                
                if attempt < maxRetryAttempts {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * Double(attempt) * 1_000_000_000))
                }
            }
        }
        
        // If all attempts failed, try to load from cache even if stale
        if let cachedBridges: [BridgeStatusModel] = loadFromCache([BridgeStatusModel].self, for: "historical_bridges") {
            cachedBridges.forEach { $0.markAsStale() }
            return cachedBridges
        }
        
        throw lastError ?? BridgeDataError.networkError
    }
    
    // MARK: - Network Fetching
    private func fetchFromNetwork() async throws -> [BridgeStatusModel] {
        var components = URLComponents(string: "https://data.seattle.gov/resource/gm8h-9449.json")!
        components.queryItems = [
            URLQueryItem(name: "$limit", value: "1000"),
            URLQueryItem(name: "$order", value: "opendatetime DESC")
        ]
        
        guard let url = components.url else {
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
        
        // The API returns an array directly, not wrapped in a "data" field
        let bridgeRecords = try decoder.decode([BridgeOpeningRecord].self, from: data)
        
        // Group records by bridge ID
        let groupedRecords = Dictionary(grouping: bridgeRecords) { $0.entityid }
        
        // Convert to BridgeStatusModel instances
        var bridgeModels: [BridgeStatusModel] = []
        
        for (bridgeID, records) in groupedRecords {
            let openings = records.compactMap { record -> Date? in
                return record.openDate
            }
            
            // Use the first record's entityname as the bridge name
            let bridgeName = records.first?.entityname ?? "Unknown Bridge"
            
            let bridgeModel = BridgeStatusModel(
                bridgeID: bridgeName,
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
        // Check cache first for generated routes
        if let cachedRoutes: [RouteModel] = loadFromCache([RouteModel].self, for: "generated_routes"),
           isCacheValid(for: "generated_routes") {
            // Update cache metadata for all routes
            cachedRoutes.forEach { $0.updateScoreMetadata() }
            return cachedRoutes
        }
        
        // Generate new routes
        let routes = [
            RouteModel(routeID: "Route-1", bridges: Array(bridges.prefix(2)), score: 0.0),
            RouteModel(routeID: "Route-2", bridges: Array(bridges.suffix(2)), score: 0.0),
            RouteModel(routeID: "Route-3", bridges: bridges, score: 0.0)
        ]
        
        // Update cache metadata and save to cache
        routes.forEach { $0.updateScoreMetadata() }
        saveToCache(routes, for: "generated_routes")
        
        return routes
    }
    
    // MARK: - Cache Utilities
    func clearCache() {
        guard let cacheDir = getCacheDirectory() else { return }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }
    
    func getCacheSize() -> Int64 {
        guard let cacheDir = getCacheDirectory() else { return 0 }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey])
            return fileURLs.reduce(0) { total, fileURL in
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    return total + (attributes[.size] as? Int64 ?? 0)
                } catch {
                    return total
                }
            }
        } catch {
            return 0
        }
    }
}

// MARK: - Error Types
enum BridgeDataError: Error {
    case invalidURL
    case networkError
    case decodingError
    case processingError
} 