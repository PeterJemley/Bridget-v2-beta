import Foundation
import SwiftData
import Testing

@testable import Bridget

@Suite("BasicTrafficProfileProvider Tests", .serialized)
struct BasicTrafficProfileProviderTests {
  // MARK: - Helpers

  private func makeProvider() throws -> (ModelContainer, ModelContext, BasicTrafficProfileProvider) {
    let schema = Schema([TrafficProfile.self])
    let modelConfiguration = ModelConfiguration(schema: schema,
                                                isStoredInMemoryOnly: true)
    let modelContainer = try ModelContainer(for: schema,
                                            configurations: [modelConfiguration])
    let modelContext = ModelContext(modelContainer)
    let provider = BasicTrafficProfileProvider(modelContext: modelContext)
    return (modelContainer, modelContext, provider)
  }

  private func createDate(year: Int = 2024,
                          month: Int = 1,
                          day: Int = 15,
                          hour: Int,
                          minute: Int) -> Date
  {
    let calendar = Calendar.current
    let components = DateComponents(year: year,
                                    month: month,
                                    day: day,
                                    hour: hour,
                                    minute: minute)
    return calendar.date(from: components) ?? Date()
  }

  private func createWeekendDate(hour: Int, minute: Int) -> Date {
    // January 13, 2024 is a Saturday
    return createDate(year: 2024,
                      month: 1,
                      day: 13,
                      hour: hour,
                      minute: minute)
  }

  // MARK: - Profile Management Tests

  @Test("Default profile is created on initialization")
  func createDefaultProfile() throws {
    let (_, _, provider) = try makeProvider()

    let profiles = provider.getAllProfiles()
    #expect(profiles.count == 1, "Should create one default profile")

    let defaultProfile = try #require(profiles.first)
    #expect(defaultProfile.name == "Seattle Default")
    #expect(defaultProfile.isActive)
    #expect(defaultProfile.morningRushMultiplier == 1.5)
    #expect(defaultProfile.eveningRushMultiplier == 1.8)
    #expect(defaultProfile.nightMultiplier == 0.8)
  }

  @Test("Create custom profile activates it and persists fields")
  func createCustomProfile() throws {
    let (_, _, provider) = try makeProvider()

    let customProfile = provider.createProfile(name: "Test Profile",
                                               profileDescription: "Test description")

    #expect(customProfile.name == "Test Profile")
    #expect(customProfile.profileDescription == "Test description")
    #expect(customProfile.isActive)

    let profiles = provider.getAllProfiles()
    #expect(profiles.count == 2)  // Default + custom
  }

  @Test(
    "Setting active profile deactivates others and getActiveProfile matches"
  )
  func testSetActiveProfile() throws {
    let (_, _, provider) = try makeProvider()

    let profile1 = provider.createProfile(name: "Profile 1")
    let profile2 = provider.createProfile(name: "Profile 2")

    // Set profile2 as active
    provider.setActiveProfile(profile2)

    // Verify profile2 is active and profile1 is not
    #expect(profile2.isActive)
    #expect(!profile1.isActive)

    // Verify getActiveProfile returns profile2
    let activeProfile = provider.getActiveProfile()
    #expect(activeProfile?.id == profile2.id)
  }

  @Test("Deleting a profile reduces count")
  func testDeleteProfile() throws {
    let (_, _, provider) = try makeProvider()

    let customProfile = provider.createProfile(name: "To Delete")
    let initialCount = provider.getAllProfiles().count

    provider.deleteProfile(customProfile)

    let finalCount = provider.getAllProfiles().count
    #expect(finalCount == initialCount - 1)
  }

  // MARK: - Traffic Multiplier Tests

  @Test("Traffic multiplier - morning rush on arterial")
  func getTrafficMultiplierMorningRush() throws {
    let (_, _, provider) = try makeProvider()

    let morningDate = createDate(hour: 8, minute: 0)  // 8 AM
    let multiplier = provider.getTrafficMultiplier(for: morningDate,
                                                   segmentType: .arterial)

    // Should be: morningRush (1.5) * weekday (1.0) * arterial (1.2) = 1.8
    #expect(abs(multiplier - (1.5 * 1.0 * 1.2)) <= 0.01)
  }

  @Test("Traffic multiplier - evening rush on highway")
  func getTrafficMultiplierEveningRush() throws {
    let (_, _, provider) = try makeProvider()

    let eveningDate = createDate(hour: 17, minute: 30)  // 5:30 PM
    let multiplier = provider.getTrafficMultiplier(for: eveningDate,
                                                   segmentType: .highway)

    // Should be: eveningRush (1.8) * weekday (1.0) * highway (1.0) = 1.8
    #expect(abs(multiplier - (1.8 * 1.0 * 1.0)) <= 0.01)
  }

  @Test("Traffic multiplier - night on local")
  func getTrafficMultiplierNight() throws {
    let (_, _, provider) = try makeProvider()

    let nightDate = createDate(hour: 23, minute: 0)  // 11 PM
    let multiplier = provider.getTrafficMultiplier(for: nightDate,
                                                   segmentType: .local)

    // Should be: night (0.8) * weekday (1.0) * local (1.0) = 0.8
    #expect(abs(multiplier - (0.8 * 1.0 * 1.0)) <= 0.01)
  }

  @Test("Traffic multiplier - weekend midday on arterial")
  func getTrafficMultiplierWeekend() throws {
    let (_, _, provider) = try makeProvider()

    let weekendDate = createWeekendDate(hour: 14, minute: 0)  // 2 PM Saturday
    let multiplier = provider.getTrafficMultiplier(for: weekendDate,
                                                   segmentType: .arterial)

    // Should be: midday (1.0) * weekend (0.9) * arterial (1.2) = 1.08
    #expect(abs(multiplier - (1.0 * 0.9 * 1.2)) <= 0.01)
  }

  @Test("Traffic multiplier defaults to 1.0 when no active profile")
  func getTrafficMultiplierNoActiveProfile() throws {
    let (_, _, provider) = try makeProvider()

    // Delete all profiles to test no active profile scenario
    let profiles = provider.getAllProfiles()
    for profile in profiles {
      provider.deleteProfile(profile)
    }

    let date = createDate(hour: 12, minute: 0)
    let multiplier = provider.getTrafficMultiplier(for: date,
                                                   segmentType: .highway)

    // Should return default multiplier (1.0) when no active profile
    #expect(multiplier == 1.0)
  }

  // MARK: - Time Period Tests

  @Test("TimePeriod.fromDate returns correct periods for boundary hours")
  func timePeriodFromDate() {
    #expect(
      TimePeriod.fromDate(createDate(hour: 7, minute: 30)) == .morningRush
    )
    #expect(
      TimePeriod.fromDate(createDate(hour: 8, minute: 59)) == .morningRush
    )
    #expect(TimePeriod.fromDate(createDate(hour: 9, minute: 0)) == .midday)
    #expect(
      TimePeriod.fromDate(createDate(hour: 15, minute: 59)) == .midday
    )
    #expect(
      TimePeriod.fromDate(createDate(hour: 16, minute: 0)) == .eveningRush
    )
    #expect(
      TimePeriod.fromDate(createDate(hour: 18, minute: 59))
        == .eveningRush
    )
    #expect(TimePeriod.fromDate(createDate(hour: 19, minute: 0)) == .night)
    #expect(TimePeriod.fromDate(createDate(hour: 6, minute: 59)) == .night)
  }

  // MARK: - Road Segment Type Tests

  @Test("RoadSegmentType display names are correct")
  func roadSegmentTypeDisplayNames() {
    #expect(RoadSegmentType.arterial.displayName == "Arterial")
    #expect(RoadSegmentType.highway.displayName == "Highway")
    #expect(RoadSegmentType.local.displayName == "Local")
    #expect(RoadSegmentType.bridge.displayName == "Bridge")
  }

  // MARK: - Profile Update Tests

  @Test("Updating a profile persists changes")
  func testUpdateProfile() throws {
    let (_, _, provider) = try makeProvider()

    let profile = provider.createProfile(name: "Test Update")
    let originalMultiplier = profile.morningRushMultiplier

    // Update the profile
    profile.morningRushMultiplier = 2.0
    provider.updateProfile(profile)

    // Verify the update
    let updatedProfile = provider.getActiveProfile()
    #expect(updatedProfile?.morningRushMultiplier == 2.0)
    #expect(updatedProfile?.morningRushMultiplier != originalMultiplier)
  }

  // MARK: - Edge Cases

  @Test("Only one profile is active at a time")
  func multipleProfilesOnlyOneActive() throws {
    let (_, _, provider) = try makeProvider()

    let profile1 = provider.createProfile(name: "Profile 1")
    let profile2 = provider.createProfile(name: "Profile 2")
    let profile3 = provider.createProfile(name: "Profile 3")

    // Last created should be active
    #expect(profile3.isActive)
    #expect(!profile1.isActive)
    #expect(!profile2.isActive)

    // Set profile1 as active
    provider.setActiveProfile(profile1)

    // Only profile1 should be active
    #expect(profile1.isActive)
    #expect(!profile2.isActive)
    #expect(!profile3.isActive)
  }

  @Test("TrafficProfile.getTotalMultiplier calculates combined multiplier")
  func profileTotalMultiplier() throws {
    let (_, _, provider) = try makeProvider()

    let profile = provider.createProfile(name: "Test Total")
    let date = createDate(hour: 8, minute: 0)  // Morning rush

    let totalMultiplier = profile.getTotalMultiplier(for: date,
                                                     segmentType: .arterial)
    let expectedMultiplier =
      profile.morningRushMultiplier * profile.weekdayMultiplier
        * profile.arterialMultiplier

    #expect(abs(totalMultiplier - expectedMultiplier) <= 0.01)
  }
}
