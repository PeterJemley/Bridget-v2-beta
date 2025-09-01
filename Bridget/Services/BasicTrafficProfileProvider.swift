import Foundation
import Observation
import SwiftData

// MARK: - Basic Traffic Profile Provider

/// Basic implementation of TrafficProfileProvider using SwiftData
@Observable
public final class BasicTrafficProfileProvider: TrafficProfileProvider {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupDefaultProfileIfNeeded()
    }

    // MARK: - TrafficProfileProvider Implementation

    public func getTrafficMultiplier(
        for date: Date,
        segmentType: RoadSegmentType
    ) -> Double {
        guard let profile = getActiveProfile() else {
            return 1.0  // Default multiplier if no profile
        }

        let timePeriod = TimePeriod.fromDate(date)
        let isWeekend = Calendar.current.isDateInWeekend(date)

        // Get base multiplier for time period
        let timeMultiplier = getTimeMultiplier(
            for: timePeriod,
            profile: profile
        )

        // Get day type multiplier
        let dayMultiplier =
            isWeekend ? profile.weekendMultiplier : profile.weekdayMultiplier

        // Get segment type multiplier
        let segmentMultiplier = getSegmentMultiplier(
            for: segmentType,
            profile: profile
        )

        // Combine multipliers
        return timeMultiplier * dayMultiplier * segmentMultiplier
    }

    public func getActiveProfile() -> TrafficProfile? {
        do {
            let descriptor = FetchDescriptor<TrafficProfile>(
                predicate: #Predicate<TrafficProfile> { profile in
                    profile.isActive == true
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )

            let profiles = try modelContext.fetch(descriptor)
            return profiles.first
        } catch {
            print(
                "⚠️ BasicTrafficProfileProvider: Failed to fetch active profile: \(error)"
            )
            return nil
        }
    }

    public func updateProfile(_ profile: TrafficProfile) {
        profile.updatedAt = Date()

        do {
            try modelContext.save()
        } catch {
            print(
                "⚠️ BasicTrafficProfileProvider: Failed to update profile: \(error)"
            )
        }
    }

    // MARK: - Public Methods

    /// Create a new traffic profile
    public func createProfile(name: String, profileDescription: String = "")
        -> TrafficProfile
    {
        let profile = TrafficProfile(
            name: name,
            profileDescription: profileDescription
        )
        modelContext.insert(profile)

        // Deactivate all other profiles and activate this one
        setActiveProfile(profile)

        return profile
    }

    /// Get all traffic profiles
    public func getAllProfiles() -> [TrafficProfile] {
        do {
            let descriptor = FetchDescriptor<TrafficProfile>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        } catch {
            print(
                "⚠️ BasicTrafficProfileProvider: Failed to fetch profiles: \(error)"
            )
            return []
        }
    }

    /// Set a profile as active (deactivates others)
    public func setActiveProfile(_ profile: TrafficProfile) {
        // Deactivate all profiles
        let allProfiles = getAllProfiles()
        for existingProfile in allProfiles {
            existingProfile.isActive = false
        }

        // Activate the selected profile
        profile.isActive = true
        profile.updatedAt = Date()

        do {
            try modelContext.save()
        } catch {
            print(
                "⚠️ BasicTrafficProfileProvider: Failed to set active profile: \(error)"
            )
        }
    }

    /// Delete a traffic profile
    public func deleteProfile(_ profile: TrafficProfile) {
        modelContext.delete(profile)

        do {
            try modelContext.save()
        } catch {
            print(
                "⚠️ BasicTrafficProfileProvider: Failed to delete profile: \(error)"
            )
        }
    }

    // MARK: - Private Methods

    private func getTimeMultiplier(
        for timePeriod: TimePeriod,
        profile: TrafficProfile
    ) -> Double {
        switch timePeriod {
        case .morningRush:
            return profile.morningRushMultiplier
        case .midday:
            return profile.middayMultiplier
        case .eveningRush:
            return profile.eveningRushMultiplier
        case .night:
            return profile.nightMultiplier
        }
    }

    private func getSegmentMultiplier(
        for segmentType: RoadSegmentType,
        profile: TrafficProfile
    ) -> Double {
        switch segmentType {
        case .arterial:
            return profile.arterialMultiplier
        case .highway:
            return profile.highwayMultiplier
        case .local:
            return profile.localMultiplier
        case .bridge:
            return 1.0  // Bridges use base multiplier for now
        }
    }

    private func setupDefaultProfileIfNeeded() {
        let profiles = getAllProfiles()

        if profiles.isEmpty {
            // Create default Seattle traffic profile
            let defaultProfile = TrafficProfile(
                name: "Seattle Default",
                profileDescription:
                    "Default traffic profile for Seattle area with typical rush hour patterns",
                morningRushMultiplier: 1.5,  // 7-9 AM: 50% slower
                middayMultiplier: 1.0,  // 9 AM - 4 PM: normal
                eveningRushMultiplier: 1.8,  // 4-7 PM: 80% slower
                nightMultiplier: 0.8,  // 7 PM - 7 AM: 20% faster
                weekdayMultiplier: 1.0,  // Weekdays: normal
                weekendMultiplier: 0.9,  // Weekends: 10% faster
                arterialMultiplier: 1.2,  // Arterials: 20% slower
                highwayMultiplier: 1.0,  // Highways: normal
                localMultiplier: 1.0  // Local roads: normal
            )

            modelContext.insert(defaultProfile)

            do {
                try modelContext.save()
                print(
                    "✅ BasicTrafficProfileProvider: Created default Seattle traffic profile"
                )
            } catch {
                print(
                    "⚠️ BasicTrafficProfileProvider: Failed to create default profile: \(error)"
                )
            }
        }
    }
}

// MARK: - Traffic Profile Extensions

extension TrafficProfile {
    /// Get the total multiplier for a specific time and segment
    public func getTotalMultiplier(for date: Date, segmentType: RoadSegmentType)
        -> Double
    {
        let timePeriod = TimePeriod.fromDate(date)
        let isWeekend = Calendar.current.isDateInWeekend(date)

        let timeMultiplier = getTimeMultiplier(for: timePeriod)
        let dayMultiplier = isWeekend ? weekendMultiplier : weekdayMultiplier
        let segmentMultiplier = getSegmentMultiplier(for: segmentType)

        return timeMultiplier * dayMultiplier * segmentMultiplier
    }

    private func getTimeMultiplier(for timePeriod: TimePeriod) -> Double {
        switch timePeriod {
        case .morningRush: return morningRushMultiplier
        case .midday: return middayMultiplier
        case .eveningRush: return eveningRushMultiplier
        case .night: return nightMultiplier
        }
    }

    private func getSegmentMultiplier(for segmentType: RoadSegmentType)
        -> Double
    {
        switch segmentType {
        case .arterial: return arterialMultiplier
        case .highway: return highwayMultiplier
        case .local: return localMultiplier
        case .bridge: return 1.0
        }
    }
}
