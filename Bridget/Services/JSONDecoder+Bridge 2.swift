import Foundation

// MARK: - JSONDecoder+Bridge Extension

extension JSONDecoder {
  // MARK: - Custom Bridge Decoder

  static func bridgeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()

    // MARK: - Custom Date Decoding

    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let dateString = try container.decode(String.self)

      let formatter = ISO8601DateFormatter()
      if let date = formatter.date(from: dateString) {
        return date
      }
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
    }

    return decoder
  }
}
