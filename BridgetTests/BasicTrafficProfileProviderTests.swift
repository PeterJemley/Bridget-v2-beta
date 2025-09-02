import SwiftData
import XCTest

@testable import Bridget

final class BasicTrafficProfileProviderTests: XCTestCase {
  var modelContainer: ModelContainer!
  var modelContext: ModelContext!
  var provider: BasicTrafficProfileProvider!

  override func setUpWithError() throws {
    try super.setUpWithError()

    // Create in-memory model container for testing
    let schema = Schema([TrafficProfile.self])
    let modelConfiguration = ModelConfiguration(schema: schema,
                                                isStoredInMemoryOnly: true)
    modelContainer = try ModelContainer(for: schema,
                                        configurations: [modelConfiguration])
    modelContext = ModelContext(modelContainer)
    provider = BasicTrafficProfileProvider(modelContext: modelContext)
  }

  override func tearDownWithError() throws {
    modelContainer = nil
    modelContext = nil
    provider = nil
    try super.tearDownWithError()
  }

  // MARK: - Profile Management Tests

  func testCreateDefaultProfile() throws {
    // Test that default profile is created on initialization
    let profiles = provider.getAllProfiles()
    XCTAssertEqual(profiles.count, 1, "Should create one default profile")

    let defaultProfile = profiles.first!
    XCTAssertEqual(defaultProfile.name, "Seattle Default")
    XCTAssertTrue(defaultProfile.isActive)
    XCTAssertEqual(defaultProfile.morningRushMultiplier, 1.5)
    XCTAssertEqual(defaultProfile.eveningRushMultiplier, 1.8)
    XCTAssertEqual(defaultProfile.nightMultiplier, 0.8)
  }

  func testCreateCustomProfile() throws {
    let customProfile = provider.createProfile(name: "Test Profile",
                                               profileDescription: "Test description")

    XCTAssertEqual(customProfile.name, "Test Profile")
    XCTAssertEqual(customProfile.profileDescription, "Test description")
    XCTAssertTrue(customProfile.isActive)

    let profiles = provider.getAllProfiles()
    XCTAssertEqual(profiles.count, 2)  // Default + custom
  }

  func testSetActiveProfile() throws {
    let profile1 = provider.createProfile(name: "Profile 1")
    let profile2 = provider.createProfile(name: "Profile 2")

    // Set profile2 as active
    provider.setActiveProfile(profile2)

    // Verify profile2 is active and profile1 is not
    XCTAssertTrue(profile2.isActive)
    XCTAssertFalse(profile1.isActive)

    // Verify getActiveProfile returns profile2
    let activeProfile = provider.getActiveProfile()
    XCTAssertEqual(activeProfile?.id, profile2.id)
  }

  func testDeleteProfile() throws {
    let customProfile = provider.createProfile(name: "To Delete")
    let initialCount = provider.getAllProfiles().count

    provider.deleteProfile(customProfile)

    let finalCount = provider.getAllProfiles().count
    XCTAssertEqual(finalCount, initialCount - 1)
  }

  // MARK: - Traffic Multiplier Tests

  func testGetTrafficMultiplierMorningRush() throws {
    let morningDate = createDate(hour: 8, minute: 0)  // 8 AM
    let multiplier = provider.getTrafficMultiplier(for: morningDate,
                                                   segmentType: .arterial)

    // Should be: morningRush (1.5) * weekday (1.0) * arterial (1.2) = 1.8
    XCTAssertEqual(multiplier, 1.5 * 1.0 * 1.2, accuracy: 0.01)
  }

  func testGetTrafficMultiplierEveningRush() throws {
    let eveningDate = createDate(hour: 17, minute: 30)  // 5:30 PM
    let multiplier = provider.getTrafficMultiplier(for: eveningDate,
                                                   segmentType: .highway)

    // Should be: eveningRush (1.8) * weekday (1.0) * highway (1.0) = 1.8
    XCTAssertEqual(multiplier, 1.8 * 1.0 * 1.0, accuracy: 0.01)
  }

  func testGetTrafficMultiplierNight() throws {
    let nightDate = createDate(hour: 23, minute: 0)  // 11 PM
    let multiplier = provider.getTrafficMultiplier(for: nightDate,
                                                   segmentType: .local)

    // Should be: night (0.8) * weekday (1.0) * local (1.0) = 0.8
    XCTAssertEqual(multiplier, 0.8 * 1.0 * 1.0, accuracy: 0.01)
  }

  func testGetTrafficMultiplierWeekend() throws {
    let weekendDate = createWeekendDate(hour: 14, minute: 0)  // 2 PM Saturday
    let multiplier = provider.getTrafficMultiplier(for: weekendDate,
                                                   segmentType: .arterial)

    // Should be: midday (1.0) * weekend (0.9) * arterial (1.2) = 1.08
    XCTAssertEqual(multiplier, 1.0 * 0.9 * 1.2, accuracy: 0.01)
  }

  func testGetTrafficMultiplierNoActiveProfile() throws {
    // Delete all profiles to test no active profile scenario
    let profiles = provider.getAllProfiles()
    for profile in profiles {
      provider.deleteProfile(profile)
    }

    let date = createDate(hour: 12, minute: 0)
    let multiplier = provider.getTrafficMultiplier(for: date,
                                                   segmentType: .highway)

    // Should return default multiplier (1.0) when no active profile
    XCTAssertEqual(multiplier, 1.0)
  }

  // MARK: - Time Period Tests

  func testTimePeriodFromDate() throws {
    XCTAssertEqual(TimePeriod.fromDate(createDate(hour: 7, minute: 30)),
                   .morningRush)
    XCTAssertEqual(TimePeriod.fromDate(createDate(hour: 8, minute: 59)),
                   .morningRush)
    XCTAssertEqual(TimePeriod.fromDate(createDate(hour: 9, minute: 0)),
                   .midday)
    XCTAssertEqual(TimePeriod.fromDate(createDate(hour: 15, minute: 59)),
                   .midday)
    XCTAssertEqual(TimePeriod.fromDate(createDate(hour: 16, minute: 0)),
                   .eveningRush)
    XCTAssertEqual(TimePeriod.fromDate(createDate(hour: 18, minute: 59)),
                   .eveningRush)
    XCTAssertEqual(TimePeriod.fromDate(createDate(hour: 19, minute: 0)),
                   .night)
    XCTAssertEqual(TimePeriod.fromDate(createDate(hour: 6, minute: 59)),
                   .night)
  }

  // MARK: - Road Segment Type Tests

  func testRoadSegmentTypeDisplayNames() throws {
    XCTAssertEqual(RoadSegmentType.arterial.displayName, "Arterial")
    XCTAssertEqual(RoadSegmentType.highway.displayName, "Highway")
    XCTAssertEqual(RoadSegmentType.local.displayName, "Local")
    XCTAssertEqual(RoadSegmentType.bridge.displayName, "Bridge")
  }

  // MARK: - Profile Update Tests

  func testUpdateProfile() throws {
    let profile = provider.createProfile(name: "Test Update")
    let originalMultiplier = profile.morningRushMultiplier

    // Update the profile
    profile.morningRushMultiplier = 2.0
    provider.updateProfile(profile)

    // Verify the update
    let updatedProfile = provider.getActiveProfile()
    XCTAssertEqual(updatedProfile?.morningRushMultiplier, 2.0)
    XCTAssertNotEqual(updatedProfile?.morningRushMultiplier,
                      originalMultiplier)
  }

  // MARK: - Edge Cases

  func testMultipleProfilesOnlyOneActive() throws {
    let profile1 = provider.createProfile(name: "Profile 1")
    let profile2 = provider.createProfile(name: "Profile 2")
    let profile3 = provider.createProfile(name: "Profile 3")

    // All should be active initially (last created)
    XCTAssertTrue(profile3.isActive)
    XCTAssertFalse(profile1.isActive)
    XCTAssertFalse(profile2.isActive)

    // Set profile1 as active
    provider.setActiveProfile(profile1)

    // Only profile1 should be active
    XCTAssertTrue(profile1.isActive)
    XCTAssertFalse(profile2.isActive)
    XCTAssertFalse(profile3.isActive)
  }

  func testProfileTotalMultiplier() throws {
    let profile = provider.createProfile(name: "Test Total")
    let date = createDate(hour: 8, minute: 0)  // Morning rush

    let totalMultiplier = profile.getTotalMultiplier(for: date,
                                                     segmentType: .arterial)
    let expectedMultiplier =
      profile.morningRushMultiplier * profile.weekdayMultiplier
        * profile.arterialMultiplier

    XCTAssertEqual(totalMultiplier, expectedMultiplier, accuracy: 0.01)
  }

  // MARK: - Helper Methods

  private func createDate(hour: Int, minute: Int) -> Date {
    let calendar = Calendar.current
    let components = DateComponents(year: 2024,
                                    month: 1,
                                    day: 15,
                                    hour: hour,
                                    minute: minute)
    return calendar.date(from: components) ?? Date()
  }

  private func createWeekendDate(hour: Int, minute: Int) -> Date {
    let calendar = Calendar.current
    // January 13, 2024 is a Saturday
    let components = DateComponents(year: 2024,
                                    month: 1,
                                    day: 13,
                                    hour: hour,
                                    minute: minute)
    return calendar.date(from: components) ?? Date()
  }
}
