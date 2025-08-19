import Foundation
import Testing

@Suite("Extensions")
struct ExtensionsTests {
  // MARK: - Date Extensions

  @Test("flooredToMinute returns start of minute")
  func dateFlooredToMinute() {
    let date = Date(timeIntervalSince1970: 1_701_000_356) // 2023-12-12 12:32:36 UTC
    let floored = date.flooredToMinute
    let expected = Date(timeIntervalSince1970: 1_701_000_320) // 12:32:00 UTC
    #expect(floored == expected)
  }

  @Test("minutes(since:) computes correct interval")
  func dateMinutesSince() {
    let d1 = Date(timeIntervalSince1970: 1000)
    let d2 = Date(timeIntervalSince1970: 1600)
    #expect(d2.minutes(since: d1) == 10)
    #expect(d1.minutes(since: d2) == -10)
  }

  // MARK: - Array Extensions

  @Test("safe subscript handles in-bounds and out-of-bounds")
  func arraySafeSubscript() {
    let arr = [10, 20, 30]
    #expect(arr[safe: 0] == 10)
    #expect(arr[safe: 2] == 30)
    #expect(arr[safe: 3] == nil)
    #expect(arr[safe: -1] == nil)
  }

  @Test("chunked(into:) splits array correctly")
  func arrayChunked() {
    let arr = [1, 2, 3, 4, 5, 6, 7]
    let chunks = arr.chunked(into: 3)
    #expect(chunks.count == 3)
    #expect(chunks[0] == [1, 2, 3])
    #expect(chunks[1] == [4, 5, 6])
    #expect(chunks[2] == [7])
    #expect([1, 2, 3].chunked(into: 0).isEmpty)
  }

  // MARK: - String Extensions

  @Test("trimmed removes leading/trailing whitespace")
  func stringTrimmed() {
    #expect("   hello  ".trimmed == "hello")
    #expect("\n\thello\t\n".trimmed == "hello")
    #expect("nochange".trimmed == "nochange")
    #expect("    ".trimmed == "")
  }

  @Test("isISO8601Date is true for ISO8601 date strings")
  func stringIsISO8601Date() {
    #expect("2025-01-03T10:12:00Z".isISO8601Date)
    #expect("2025-01-03T10:12:00.000Z".isISO8601Date)
    #expect(!"not-a-date".isISO8601Date)
  }
}
