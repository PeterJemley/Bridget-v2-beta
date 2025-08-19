// TestSupport.swift
// Test-only error types and helpers for unit tests.

import Foundation

/// Error type for unexpected test outcomes (test-only).
public enum TestError: Error {
  case unexpectedSuccess(String)
}
