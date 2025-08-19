import Foundation
import Testing

@testable import Bridget

/// A suite for ensuring project-wide JSON serialization consistency using shared factories.
@Suite("Serialization Consistency Tests")
struct SerializationConsistencyTests {
  struct SampleModel: Codable, Equatable {
    let id: Int
    let name: String
    let date: Date
    let snake_case_field: String
  }

  let sampleDate = ISO8601DateFormatter().date(from: "2025-08-18T09:30:00Z")!

  @Test("round-trip encoding/decoding with bridge factories: default config")
  func roundTripDefault() async throws {
    let model = SampleModel(id: 1, name: "Test", date: sampleDate, snake_case_field: "value")
    let encoder = JSONEncoder.bridgeEncoder()
    let decoder = JSONDecoder.bridgeDecoder()
    let data = try encoder.encode(model)
    let decoded = try decoder.decode(SampleModel.self, from: data)
    #expect(model == decoded)
  }

  @Test("round-trip with prettyPrinted and sortedKeys")
  func roundTripPrettyPrintedSortedKeys() async throws {
    let model = SampleModel(id: 2, name: "Pretty", date: sampleDate, snake_case_field: "val2")
    let encoder = JSONEncoder.bridgeEncoder(outputFormatting: [.prettyPrinted, .sortedKeys])
    let decoder = JSONDecoder.bridgeDecoder()
    let data = try encoder.encode(model)
    let decoded = try decoder.decode(SampleModel.self, from: data)
    #expect(model == decoded)
  }

  @Test("snake_case key decoding")
  func snakeCaseKeyDecoding() async throws {
    let json = """
    {
        "id": 3,
        "name": "SnakeCase",
        "date": "2025-08-18T09:30:00Z",
        "snake_case_field": "snake"
    }
    """.data(using: .utf8)!
    let decoder = JSONDecoder.bridgeDecoder()
    let model = try decoder.decode(SampleModel.self, from: json)
    #expect(model.snake_case_field == "snake")
  }

  @Test("bridgeEncoder honors custom date encoding strategy")
  func customDateEncodingStrategy() async throws {
    let model = SampleModel(id: 4, name: "CustomDate", date: sampleDate, snake_case_field: "custom")
    let encoder = JSONEncoder.bridgeEncoder(dateEncodingStrategy: .millisecondsSince1970)
    let data = try encoder.encode(model)
    // decode with matching strategy
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    let decoded = try decoder.decode(SampleModel.self, from: data)
    #expect(model == decoded)
  }

  @Test("bridgeEncoder/bridgeDecoder fail on mismatched date strategy")
  func mismatchedDateStrategies() async throws {
    let model = SampleModel(id: 5, name: "Mismatch", date: sampleDate, snake_case_field: "fail")
    let encoder = JSONEncoder.bridgeEncoder(dateEncodingStrategy: .secondsSince1970)
    let data = try encoder.encode(model)
    let decoder = JSONDecoder.bridgeDecoder()
    do {
      _ = try decoder.decode(SampleModel.self, from: data)
      throw TestError.unexpectedSuccess("Mismatched date strategies should fail")
    } catch {
      // Expected failure
    }
  }
}
