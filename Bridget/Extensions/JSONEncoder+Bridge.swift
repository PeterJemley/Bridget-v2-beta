//
//  JSONEncoder+Bridge.swift
//  Bridget
//
//  Centralized JSONEncoder factory for consistent encoding configuration across the app.
//
//  # Project Serialization Policy
//  All JSON encoding/decoding throughout the project MUST use the centralized
//  `bridgeEncoder`/`bridgeDecoder` factories unless a documented exception applies.
//
//  - Ensures all serialization is consistent (dates, keys, formatting).
//  - Callers may optionally override default strategies as needed for special cases.
//  - To extend or change defaults, update this file and audit usages project-wide.
//
//  ## Example Usage
//  ```swift
//  let encoder = JSONEncoder.bridgeEncoder()
//  let decoder = JSONDecoder.bridgeDecoder()
//  ```
//
//  ## Special Cases
//  If a special configuration is required (e.g., pretty-printing, sorted keys, or a different date encoding),
//  use the relevant parameters. Do not instantiate JSONEncoder/Decoder directly.
//
//  ## See Also
//  - JSONDecoder+Bridge.swift (companion factory)
//  - project-level serialization tests
//

import Foundation

extension JSONEncoder {
  /// Returns a JSONEncoder configured for the Bridget data pipeline.
  ///
  /// - Parameters:
  ///   - dateEncodingStrategy: How dates are encoded. Defaults to `.iso8601`.
  ///   - keyEncodingStrategy: How keys are encoded. Defaults to `.useDefaultKeys`.
  ///   - outputFormatting: Output formatting (pretty printing, sorting, etc). Defaults to `[]`.
  ///
  /// - Returns: A fully configured JSONEncoder instance. Use project-wide for all JSON encoding unless a documented exception applies.
  ///
  /// ## Example
  /// ```swift
  /// let encoder = JSONEncoder.bridgeEncoder(outputFormatting: [.prettyPrinted, .sortedKeys])
  /// let data = try encoder.encode(myStruct)
  /// ```
  ///
  /// ## Extending Defaults
  /// To change default encoding strategies, update this factory and audit usage project-wide for unintended consequences. See the `Bridge` project policy for more information.
  static func bridgeEncoder(dateEncodingStrategy: DateEncodingStrategy = .iso8601,
                            keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys,
                            outputFormatting: OutputFormatting = []) -> JSONEncoder
  {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = dateEncodingStrategy
    encoder.keyEncodingStrategy = keyEncodingStrategy
    encoder.outputFormatting = outputFormatting
    return encoder
  }
}
