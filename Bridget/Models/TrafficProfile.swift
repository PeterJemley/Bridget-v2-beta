import Foundation
import SwiftData

// MARK: - Traffic Profile Models

/// Represents a traffic profile with time-of-day multipliers
@Model
public final class TrafficProfile {
    @Attribute(.unique) public var id: String
    public var name: String
    public var profileDescription: String
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date

    // Time-of-day multipliers (0.0 = no traffic, 1.0 = normal traffic, 2.0 = heavy traffic)
    public var morningRushMultiplier: Double  // 7-9 AM
    public var middayMultiplier: Double  // 9 AM - 4 PM
    public var eveningRushMultiplier: Double  // 4-7 PM
    public var nightMultiplier: Double  // 7 PM - 7 AM

    // Day type multipliers
    public var weekdayMultiplier: Double
    public var weekendMultiplier: Double

    // Segment type multipliers
    public var arterialMultiplier: Double
    public var highwayMultiplier: Double
    public var localMultiplier: Double

    public init(
        id: String = UUID().uuidString,
        name: String,
        profileDescription: String = "",
        isActive: Bool = true,
        morningRushMultiplier: Double = 1.5,
        middayMultiplier: Double = 1.0,
        eveningRushMultiplier: Double = 1.8,
        nightMultiplier: Double = 0.8,
        weekdayMultiplier: Double = 1.0,
        weekendMultiplier: Double = 0.9,
        arterialMultiplier: Double = 1.0,
        highwayMultiplier: Double = 1.0,
        localMultiplier: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.profileDescription = profileDescription
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.morningRushMultiplier = morningRushMultiplier
        self.middayMultiplier = middayMultiplier
        self.eveningRushMultiplier = eveningRushMultiplier
        self.nightMultiplier = nightMultiplier
        self.weekdayMultiplier = weekdayMultiplier
        self.weekendMultiplier = weekendMultiplier
        self.arterialMultiplier = arterialMultiplier
        self.highwayMultiplier = highwayMultiplier
        self.localMultiplier = localMultiplier
    }
}

// MARK: - Traffic Profile Provider Protocol

/// Protocol for traffic profile providers
public protocol TrafficProfileProvider {
    /// Get traffic multiplier for a specific time and segment type
    func getTrafficMultiplier(for date: Date, segmentType: RoadSegmentType)
        -> Double

    /// Get active traffic profile
    func getActiveProfile() -> TrafficProfile?

    /// Update traffic profile
    func updateProfile(_ profile: TrafficProfile)
}

// MARK: - Road Segment Types

public enum RoadSegmentType: String, CaseIterable, Codable {
    case arterial = "arterial"
    case highway = "highway"
    case local = "local"
    case bridge = "bridge"

    public var displayName: String {
        switch self {
        case .arterial: return "Arterial"
        case .highway: return "Highway"
        case .local: return "Local"
        case .bridge: return "Bridge"
        }
    }
}

// MARK: - Time Periods

public enum TimePeriod: String, CaseIterable {
    case morningRush = "morning_rush"  // 7-9 AM
    case midday = "midday"  // 9 AM - 4 PM
    case eveningRush = "evening_rush"  // 4-7 PM
    case night = "night"  // 7 PM - 7 AM

    public var displayName: String {
        switch self {
        case .morningRush: return "Morning Rush (7-9 AM)"
        case .midday: return "Midday (9 AM - 4 PM)"
        case .eveningRush: return "Evening Rush (4-7 PM)"
        case .night: return "Night (7 PM - 7 AM)"
        }
    }

    public static func fromDate(_ date: Date) -> TimePeriod {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 7..<9: return .morningRush
        case 9..<16: return .midday
        case 16..<19: return .eveningRush
        default: return .night
        }
    }
}
