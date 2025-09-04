// JSONCoding+Bridge.swift
import Foundation

public extension JSONDecoder {
  static func bridgeDecoder(dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .iso8601,
                            keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = dateDecodingStrategy
    decoder.keyDecodingStrategy = keyDecodingStrategy
    return decoder
  }
}

public extension JSONEncoder {
  static func bridgeEncoder(dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .iso8601,
                            keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
                            outputFormatting: JSONEncoder.OutputFormatting = []) -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = dateEncodingStrategy
    encoder.keyEncodingStrategy = keyEncodingStrategy
    encoder.outputFormatting = outputFormatting
    return encoder
  }
}
