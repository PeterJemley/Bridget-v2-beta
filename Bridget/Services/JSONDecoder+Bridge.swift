import Foundation

extension JSONDecoder {
  static func bridgeDecoder(dateDecodingStrategy: DateDecodingStrategy = .iso8601,
                            keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys) -> JSONDecoder
  {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = dateDecodingStrategy
    decoder.keyDecodingStrategy = keyDecodingStrategy
    return decoder
  }
}
