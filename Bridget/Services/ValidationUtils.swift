// ValidationUtils.swift
// Common utility functions for validation patterns
//
// Created as part of the Bridget app for validating bridge and non-bridge data

import Foundation

/// Utility for checking if a string is not empty.
@inline(__always)
public func isNotEmpty(_ value: String?) -> Bool {
    guard let value = value, !value.isEmpty else { return false }
    return true
}

/// Utility for checking if a collection is not empty.
@inline(__always)
public func isNotEmpty<T: Collection>(_ value: T?) -> Bool {
    guard let value = value, !value.isEmpty else { return false }
    return true
}

/// Utility for numeric range validation.
@inline(__always)
public func isInRange<T: Comparable>(_ value: T?, _ range: ClosedRange<T>) -> Bool {
    guard let value = value else { return false }
    return range.contains(value)
}

/// Utility for optional value existence (unwraps value, returns nil if nil).
@inline(__always)
public func require<T>(_ value: T?) -> T? {
    value
}

/// Utility for validating if a string parses to a date using the given formatter.
@inline(__always)
public func isValidDate(_ string: String?, formatter: DateFormatter) -> Bool {
    guard let string = string, !string.isEmpty else { return false }
    return formatter.date(from: string) != nil
}
