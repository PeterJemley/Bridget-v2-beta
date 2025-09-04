//
//  RetryRecoveryService.swift
//  Bridget
//
//  ## Purpose
//  Retry mechanisms and recovery operations for robust pipeline execution
//  Implements exponential backoff, circuit breaker patterns, and recovery strategies
//
//  ## Dependencies
//  Foundation framework, OSLog for logging
//
//  ## Integration Points
//  Used by EnhancedTrainPrepService and other pipeline services
//  for handling transient failures and implementing recovery strategies
//
//  ## Key Features
//  - Exponential backoff with jitter
//  - Circuit breaker pattern
//  - Configurable retry policies
//  - Recovery checkpoint management
//

import Foundation
import OSLog

// MARK: - Retry Policies

/// Configurable retry policy for operations
public struct RetryPolicy: Sendable {
  public let maxAttempts: Int
  public let baseDelay: TimeInterval
  public let maxDelay: TimeInterval
  public let backoffMultiplier: Double
  public let enableJitter: Bool
  public let retryableErrorTypes: Set<String>  // Store error type names instead of Error instances

  public static let `default` = RetryPolicy(maxAttempts: 3,
                                            baseDelay: 1.0,
                                            maxDelay: 30.0,
                                            backoffMultiplier: 2.0,
                                            enableJitter: true,
                                            retryableErrorTypes: [])

  public init(maxAttempts: Int = 3,
              baseDelay: TimeInterval = 1.0,
              maxDelay: TimeInterval = 30.0,
              backoffMultiplier: Double = 2.0,
              enableJitter: Bool = true,
              retryableErrorTypes: Set<String> = [])
  {
    self.maxAttempts = maxAttempts
    self.baseDelay = baseDelay
    self.maxDelay = maxDelay
    self.backoffMultiplier = backoffMultiplier
    self.enableJitter = enableJitter
    self.retryableErrorTypes = retryableErrorTypes
  }
}

/// Circuit breaker state
public enum CircuitBreakerState: Sendable {
  case closed  // Normal operation
  case open  // Failing, not attempting operations
  case halfOpen  // Testing if service is recovered
}

// MARK: - Retry Service

/// Service for handling retry logic and recovery operations
public class RetryRecoveryService {
  private let logger = Logger(subsystem: "com.peterjemley.Bridget",
                              category: "RetryRecovery")
  private let policy: RetryPolicy
  private var circuitBreakerState: CircuitBreakerState = .closed
  private var failureCount: Int = 0
  private var lastFailureTime: Date?
  private let circuitBreakerThreshold: Int
  private let circuitBreakerTimeout: TimeInterval

  public init(policy: RetryPolicy = .default,
              circuitBreakerThreshold: Int = 5,
              circuitBreakerTimeout: TimeInterval = 60.0)
  {
    self.policy = policy
    self.circuitBreakerThreshold = circuitBreakerThreshold
    self.circuitBreakerTimeout = circuitBreakerTimeout
  }

  /// Execute operation with retry logic
  public func executeWithRetry<T>(_ operation: @Sendable () async throws -> T)
    async throws -> T
  {
    var lastError: Error?

    for attempt in 1 ... policy.maxAttempts {
      do {
        // Check circuit breaker
        try await checkCircuitBreaker()

        // Execute operation
        let result = try await operation()

        // Success - reset circuit breaker
        onSuccess()
        return result

      } catch {
        lastError = error
        logger.warning(
          "Operation failed on attempt \(attempt)/\(self.policy.maxAttempts): \(error.localizedDescription)"
        )

        // Check if error is retryable
        guard shouldRetry(error, attempt: attempt) else {
          logger.error(
            "Error is not retryable: \(error.localizedDescription)"
          )
          throw error
        }

        // Update circuit breaker
        onFailure()

        // If this is the last attempt, throw the error
        if attempt == policy.maxAttempts {
          logger.error(
            "Max retry attempts reached: \(error.localizedDescription)"
          )
          throw error
        }

        // Calculate delay and wait
        let delay = calculateDelay(for: attempt)
        logger.info(
          "Waiting \(delay)s before retry attempt \(attempt + 1)"
        )
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
    }

    throw lastError ?? RetryError.maxAttemptsExceeded
  }

  /// Execute operation with custom retry logic
  public func executeWithCustomRetry<T>(_ operation: @Sendable () async throws -> T,
                                        shouldRetry: @Sendable @escaping (Error, Int) -> Bool,
                                        delayCalculator: @Sendable @escaping (Int) -> TimeInterval) async throws -> T
  {
    var lastError: Error?

    for attempt in 1 ... policy.maxAttempts {
      do {
        let result = try await operation()
        onSuccess()
        return result

      } catch {
        lastError = error
        logger.warning(
          "Operation failed on attempt \(attempt)/\(self.policy.maxAttempts): \(error.localizedDescription)"
        )

        guard shouldRetry(error, attempt) else {
          logger.error(
            "Error is not retryable: \(error.localizedDescription)"
          )
          throw error
        }

        onFailure()

        if attempt == policy.maxAttempts {
          logger.error(
            "Max retry attempts reached: \(error.localizedDescription)"
          )
          throw error
        }

        let delay = delayCalculator(attempt)
        logger.info(
          "Waiting \(delay)s before retry attempt \(attempt + 1)"
        )
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
    }

    throw lastError ?? RetryError.maxAttemptsExceeded
  }

  // MARK: - Private Methods

  private func shouldRetry(_ error: Error, attempt _: Int) -> Bool {
    // Check if error is in retryable errors set
    if !policy.retryableErrorTypes.isEmpty {
      return policy.retryableErrorTypes.contains { retryableErrorType in
        // Simple type comparison - could be enhanced with more sophisticated matching
        String(describing: type(of: error)) == retryableErrorType
      }
    }

    // Default retry logic for common error types
    switch error {
    case let urlError as URLError:
      return urlError.code == .networkConnectionLost
        || urlError.code == .timedOut
        || urlError.code == .serverCertificateUntrusted
    case let posixError as POSIXError:
      return posixError.code == .EIO || posixError.code == .ENOMEM
        || posixError.code == .ETIMEDOUT
    default:
      return true  // Retry by default for unknown errors
    }
  }

  private func calculateDelay(for attempt: Int) -> TimeInterval {
    let exponentialDelay =
      policy.baseDelay
        * pow(policy.backoffMultiplier, Double(attempt - 1))
    let cappedDelay = min(exponentialDelay, policy.maxDelay)

    if policy.enableJitter {
      let jitter = Double.random(in: 0.8 ... 1.2)
      return cappedDelay * jitter
    }

    return cappedDelay
  }

  private func checkCircuitBreaker() async throws {
    switch circuitBreakerState {
    case .closed:
      return  // Normal operation

    case .open:
      if let lastFailure = lastFailureTime,
         Date().timeIntervalSince(lastFailure) >= circuitBreakerTimeout
      {
        circuitBreakerState = .halfOpen
        logger.info("Circuit breaker transitioning to half-open state")
      } else {
        throw RetryError.circuitBreakerOpen
      }

    case .halfOpen:
      // Allow one attempt to test recovery
      return
    }
  }

  private func onSuccess() {
    failureCount = 0
    circuitBreakerState = .closed
    logger.debug("Operation succeeded, circuit breaker reset to closed")
  }

  private func onFailure() {
    failureCount += 1
    lastFailureTime = Date()

    if failureCount >= circuitBreakerThreshold {
      circuitBreakerState = .open
      logger.warning(
        "Circuit breaker opened after \(self.failureCount) failures"
      )
    }
  }
}

// MARK: - Recovery Operations

/// Service for managing recovery operations and checkpoints
public class RecoveryService {
  private let logger = Logger(subsystem: "com.peterjemley.Bridget",
                              category: "Recovery")
  private let checkpointDirectory: String

  public init(checkpointDirectory: String) {
    self.checkpointDirectory = checkpointDirectory
    createCheckpointDirectoryIfNeeded()
  }

  /// Create recovery checkpoint
  public func createCheckpoint<T: Codable>(_ data: T,
                                           for stage: PipelineStage,
                                           id: String) throws
    -> String
  {
    let checkpointPath =
      "\(checkpointDirectory)/\(stage.rawValue)_\(id).checkpoint"

    do {
      let encoder = JSONEncoder.bridgeEncoder(
        outputFormatting: .prettyPrinted
      )
      let checkpointData = try encoder.encode(data)
      try checkpointData.write(to: URL(fileURLWithPath: checkpointPath))

      logger.info(
        "Created checkpoint for stage \(stage.rawValue) at \(checkpointPath)"
      )
      return checkpointPath

    } catch {
      logger.error(
        "Failed to create checkpoint for stage \(stage.rawValue): \(error.localizedDescription)"
      )
      throw RecoveryError.checkpointCreationFailed(error)
    }
  }

  /// Load recovery checkpoint
  public func loadCheckpoint<T: Codable>(_ type: T.Type,
                                         for stage: PipelineStage,
                                         id: String)
    throws -> T?
  {
    let checkpointPath =
      "\(checkpointDirectory)/\(stage.rawValue)_\(id).checkpoint"

    guard FileManagerUtils.fileExists(at: checkpointPath) else {
      logger.debug(
        "No checkpoint found for stage \(stage.rawValue) at \(checkpointPath)"
      )
      return nil
    }

    do {
      let checkpointData = try Data(
        contentsOf: URL(fileURLWithPath: checkpointPath)
      )
      let decoder = JSONDecoder.bridgeDecoder()
      let checkpoint = try decoder.decode(type, from: checkpointData)

      logger.info(
        "Loaded checkpoint for stage \(stage.rawValue) from \(checkpointPath)"
      )
      return checkpoint

    } catch {
      logger.error(
        "Failed to load checkpoint for stage \(stage.rawValue): \(error.localizedDescription)"
      )
      throw RecoveryError.checkpointLoadingFailed(error)
    }
  }

  /// Delete recovery checkpoint
  public func deleteCheckpoint(for stage: PipelineStage, id: String) throws {
    let checkpointPath =
      "\(checkpointDirectory)/\(stage.rawValue)_\(id).checkpoint"

    do {
      try FileManagerUtils.removeFile(at: checkpointPath)
      logger.info(
        "Deleted checkpoint for stage \(stage.rawValue) at \(checkpointPath)"
      )
    } catch {
      logger.error(
        "Failed to delete checkpoint for stage \(stage.rawValue): \(error.localizedDescription)"
      )
      throw RecoveryError.checkpointDeletionFailed(error)
    }
  }

  /// List available checkpoints
  public func listCheckpoints() -> [String] {
    do {
      let files = try FileManagerUtils.enumerateFiles(
        at: checkpointDirectory
      ) { url in
        url.lastPathComponent.hasSuffix(".checkpoint")
      }
      return files.map { $0.lastPathComponent }
    } catch {
      logger.error(
        "Failed to list checkpoints: \(error.localizedDescription)"
      )
      return []
    }
  }

  /// Clean up old checkpoints
  public func cleanupOldCheckpoints(olderThan age: TimeInterval) throws {
    let cutoffDate = Date().addingTimeInterval(-age)
    try FileManagerUtils.removeOldFiles(in: URL(fileURLWithPath: checkpointDirectory),
                                        olderThan: cutoffDate)
    { url in
      url.lastPathComponent.hasSuffix(".checkpoint")
    }
  }

  // MARK: - Private Methods

  private func createCheckpointDirectoryIfNeeded() {
    do {
      try FileManagerUtils.ensureDirectoryExists(at: checkpointDirectory)
      logger.info(
        "Created checkpoint directory: \(self.checkpointDirectory)"
      )
    } catch {
      logger.error(
        "Failed to create checkpoint directory: \(error.localizedDescription)"
      )
    }
  }
}

// MARK: - Error Types

public enum RetryError: LocalizedError {
  case maxAttemptsExceeded
  case circuitBreakerOpen

  public var errorDescription: String? {
    switch self {
    case .maxAttemptsExceeded:
      return "Maximum retry attempts exceeded"
    case .circuitBreakerOpen:
      return "Circuit breaker is open, operation not allowed"
    }
  }
}

public enum RecoveryError: LocalizedError {
  case checkpointCreationFailed(Error)
  case checkpointLoadingFailed(Error)
  case checkpointDeletionFailed(Error)

  public var errorDescription: String? {
    switch self {
    case let .checkpointCreationFailed(error):
      return "Failed to create checkpoint: \(error.localizedDescription)"
    case let .checkpointLoadingFailed(error):
      return "Failed to load checkpoint: \(error.localizedDescription)"
    case let .checkpointDeletionFailed(error):
      return "Failed to delete checkpoint: \(error.localizedDescription)"
    }
  }
}
