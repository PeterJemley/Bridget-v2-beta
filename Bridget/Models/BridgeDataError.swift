//
//  BridgeDataError.swift
//  Bridget
//
//  Defines the error type for data processing failures in Bridget.
//

import Foundation

/// Error type representing failures during bridge data decoding or business logic processing.
///
enum BridgeDataError: Error, LocalizedError {
  /// JSON decoding failure (wraps DecodingError and the raw data payload)
  case decodingError(DecodingError, rawData: Data)
  /// Business logic or processing failure (with a message)
  case processingError(String)

  /// Human-readable error message for the user interface.
  var errorDescription: String? {
    switch self {
    case .decodingError(let decodingError, _):
      return
        "Failed to decode bridge data: \(decodingError.localizedDescription)"
    case .processingError(let message):
      return "Bridge data processing error: \(message)"
    }
  }

  /// Localized error description for system integration.
  var localizedDescription: String {
    errorDescription ?? "Unknown error"
  }
}
