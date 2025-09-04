//
//  NetworkClient.swift
//  Bridget
//
//  ## Purpose
//  Handles all network operations with retry logic and validation
//
//  ## Dependencies
//  Foundation (URLSession, HTTPURLResponse)
//
//  ## Integration Points
//  - Fetches data from Seattle Open Data API
//  - Implements retry logic with exponential backoff
//  - Validates HTTP responses and payload sizes
//  - Called by BridgeDataService for network operations
//

import Foundation

// MARK: - Network Client

/// A singleton service for robust network operations with retry logic and validation.
///
/// Handles API fetching, HTTP response validation, retry logic, and error classification
/// for the Bridget app. Used by `BridgeDataService` for all network requests to the
/// Seattle Open Data API.
///
/// ## Usage
/// ```swift
/// let data = try await NetworkClient.shared.fetchData(from: url)
/// ```
///
/// ## Topics
/// - Data Fetching: `fetchData(from:)`
/// - Error Handling: `NetworkError`
/// - Retry Logic
/// - Payload Size Validation
actor NetworkClient {
  /// Shared singleton instance of `NetworkClient`.
  ///
  /// Use this instance to perform all network requests within the app,
  /// ensuring consistent retry behavior and validation.
  static let shared = NetworkClient()

  // MARK: - Configuration

  private let maxRetryAttempts = 3
  private let retryDelay: TimeInterval = 2.0
  private let maxAllowedSize: Int = 5 * 1024 * 1024  // 5MB

  private init() {}

  // MARK: - Network Fetching with Retry

  /// Fetches raw data from the specified URL with built-in retry and validation logic.
  ///
  /// This method attempts to fetch data up to 3 times using an exponential backoff strategy
  /// (2s, 4s, 6s delays) between retries. It validates the HTTP response status code,
  /// ensures the content type is JSON, and checks the payload size to prevent overly large responses.
  ///
  /// - Parameter url: The `URL` to fetch data from.
  /// - Returns: The raw `Data` received from the network response.
  /// - Throws: A `NetworkError` if the request fails due to invalid response, HTTP errors,
  ///           invalid content type, payload size issues, or general network errors.
  ///
  /// ## Example
  /// ```swift
  /// do {
  ///   let data = try await NetworkClient.shared.fetchData(from: url)
  ///   // Use the data
  /// } catch {
  ///   print("Failed to fetch data: \(error.localizedDescription)")
  /// }
  /// ```
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
            nanoseconds: UInt64(retryDelay * Double(attempt) * 1_000_000_000)
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
    guard
      let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
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
    if data.isEmpty || data.count >= maxAllowedSize {
      throw NetworkError.payloadSizeError
    }
  }
}

// MARK: - Network Error Types

/// Defines errors that can occur during network operations performed by `NetworkClient`.
///
/// Used to classify failures for invalid responses, HTTP errors,
/// content type mismatches, payload size issues, and general network errors.
enum NetworkError: Error, LocalizedError {
  /// A general network request failure.
  case networkError
  /// The response was not a valid HTTP response.
  case invalidResponse
  /// The HTTP response returned a non-200 status code.
  /// Associated value is the status code received.
  case httpError(statusCode: Int)
  /// The Content-Type header was missing or did not indicate JSON.
  case invalidContentType
  /// The payload size was either empty or exceeded the configured maximum limit.
  case payloadSizeError
  /// No data was returned from the API after batch fetching.
  case noData

  /// A human-readable description of the error.
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
    case .noData:
      return "No data returned from API"
    }
  }
}
