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
    let snakeCaseField: String

    enum CodingKeys: String, CodingKey {
      case id
      case name
      case date
      case snakeCaseField = "snake_case_field"
    }
  }

  let sampleDate = ISO8601DateFormatter().date(from: "2025-08-18T09:30:00Z")!

  @Test("round-trip encoding/decoding with bridge factories: default config")
  func roundTripDefault() async throws {
    let model = SampleModel(id: 1, name: "Test", date: sampleDate, snakeCaseField: "value")
    let encoder = JSONEncoder.bridgeEncoder()
    let decoder = JSONDecoder.bridgeDecoder()
    let data = try encoder.encode(model)
    let decoded = try decoder.decode(SampleModel.self, from: data)
    #expect(model == decoded)
  }

  @Test("round-trip with prettyPrinted and sortedKeys")
  func roundTripPrettyPrintedSortedKeys() async throws {
    let model = SampleModel(id: 2, name: "Pretty", date: sampleDate, snakeCaseField: "val2")
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
    #expect(model.snakeCaseField == "snake")
  }

  @Test("bridgeEncoder honors custom date encoding strategy")
  func customDateEncodingStrategy() async throws {
    let model = SampleModel(id: 4, name: "CustomDate", date: sampleDate, snakeCaseField: "custom")
    let encoder = JSONEncoder.bridgeEncoder(dateEncodingStrategy: .iso8601)
    let data = try encoder.encode(model)
    // decode with bridge decoder (which handles ISO8601)
    let decoder = JSONDecoder.bridgeDecoder()
    let decoded = try decoder.decode(SampleModel.self, from: data)
    #expect(model == decoded)
  }

  @Test("bridgeEncoder/bridgeDecoder fail on mismatched date strategy")
  func mismatchedDateStrategies() async throws {
    let model = SampleModel(id: 5, name: "Mismatch", date: sampleDate, snakeCaseField: "fail")
    let encoder = JSONEncoder.bridgeEncoder(dateEncodingStrategy: .secondsSince1970)
    let data = try encoder.encode(model)
    let decoder = JSONDecoder.bridgeDecoder()

    // Expect this to fail due to mismatched date strategies
    #expect(throws: DecodingError.self) {
      try decoder.decode(SampleModel.self, from: data)
    }
  }
}
