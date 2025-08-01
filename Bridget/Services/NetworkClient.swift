//
//  NetworkClient.swift
//  Bridget
//
//  Purpose: Handles all network operations with retry logic and validation
//  Dependencies: Foundation (URLSession, HTTPURLResponse)
//  Integration Points:
//    - Fetches data from Seattle Open Data API
//    - Implements retry logic with exponential backoff
//    - Validates HTTP responses and payload sizes
//    - Called by BridgeDataService for network operations
//

import Foundation

// MARK: - Network Client

class NetworkClient {
  static let shared = NetworkClient()

  // MARK: - Configuration

  private let maxRetryAttempts = 3
  private let retryDelay: TimeInterval = 2.0
  private let maxAllowedSize: Int = 5 * 1024 * 1024 // 5MB

  private init() {}

  // MARK: - Network Fetching with Retry

  /// Fetches data from the network with retry logic and validation
  ///
  /// This method implements a robust network fetching strategy:
  /// 1. **Retry with exponential backoff**: Attempts network requests up to 3 times
  /// 2. **HTTP-level validation**: Validates status codes, headers, content-type
  /// 3. **Payload size validation**: Ensures response size is reasonable
  /// 4. **Error propagation**: Throws specific network errors for different failure types
  ///
  /// - Parameter url: The URL to fetch data from
  /// - Returns: Raw Data from the network response
  /// - Throws: NetworkError for various network-related failures
  func fetchData(from url: URL) async throws -> Data {
    var lastError: Error?

    for attempt in 1 ... maxRetryAttempts {
      do {
        let (data, response) = try await URLSession.shared.data(from: url)

        // Validate HTTP response
        try validateHTTPResponse(response)

        // Validate payload size
        try validatePayloadSize(data)

        return data
      } catch {
        lastError = error

        // Exponential backoff: 2s, 4s, 6s delays
        if attempt < maxRetryAttempts {
          try await Task.sleep(
            nanoseconds: UInt64(
              retryDelay * Double(attempt) * 1_000_000_000
            )
          )
        }
      }
    }

    // Throw the last network error if all attempts failed
    throw lastError ?? NetworkError.networkError
  }

  // MARK: - HTTP Response Validation

  private func validateHTTPResponse(_ response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
      throw NetworkError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      throw NetworkError.httpError(statusCode: httpResponse.statusCode)
    }

    // Validate content type
    guard let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
          contentType.contains("application/json")
    else {
      throw NetworkError.invalidContentType
    }

    #if DEBUG
      print("Content-Type: \(contentType)")
    #endif
  }

  // MARK: - Payload Size Validation

  private func validatePayloadSize(_ data: Data) throws {
    guard !data.isEmpty, data.count < maxAllowedSize else {
      throw NetworkError.payloadSizeError
    }
  }
}

// MARK: - Network Error Types

enum NetworkError: Error, LocalizedError {
  case networkError
  case invalidResponse
  case httpError(statusCode: Int)
  case invalidContentType
  case payloadSizeError

  var errorDescription: String? {
    switch self {
    case .networkError:
      return "Network request failed"
    case .invalidResponse:
      return "Invalid HTTP response"
    case let .httpError(statusCode):
      return "HTTP error with status code: \(statusCode)"
    case .invalidContentType:
      return "Invalid content type - expected JSON"
    case .payloadSizeError:
      return "Payload size is invalid (empty or too large)"
    }
  }
}
