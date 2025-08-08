@testable import Bridget
import Foundation
import SwiftData
import Testing

@Suite("Item Model Tests")
struct ItemTests {
  @Test("Initialization with specific date")
  func initializationWithDate() async throws {
    let testDate = Date(timeIntervalSince1970: 123_456_789)
    let item = Item(timestamp: testDate)
    #expect(item.timestamp == testDate)
  }

  @Test("Initialization with current date")
  func initializationWithCurrentDate() async throws {
    let now = Date()
    let item = Item(timestamp: now)
    // Allow small difference for timing
    let diff = abs(item.timestamp.timeIntervalSince(now))
    #expect(diff < 0.001)
  }

  @Test("Initialization with distantPast and distantFuture")
  func initializationWithExtremeDates() async throws {
    let past = Date.distantPast
    let future = Date.distantFuture
    let itemPast = Item(timestamp: past)
    let itemFuture = Item(timestamp: future)
    #expect(itemPast.timestamp == past)
    #expect(itemFuture.timestamp == future)
  }

  @Test("Mutating timestamp property")
  func mutatingTimestamp() async throws {
    let initial = Date()
    let newDate = initial.addingTimeInterval(1000)
    let item = Item(timestamp: initial)
    item.timestamp = newDate
    #expect(item.timestamp == newDate)
  }
}
