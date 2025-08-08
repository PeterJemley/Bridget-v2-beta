# Enhanced Data Processing Pipeline

A comprehensive roadmap for improving JSON decoding, business validation, data grouping, and model creation in the Bridget data processing pipeline.

## Overview

This document outlines the next phase of development for the data processing pipeline, focusing on four key areas:

1. **JSON Decoding** - Robust date parsing with fallback strategies
2. **Business Validation** - Modular validation with comprehensive error reporting
3. **Data Grouping** - Flexible, reusable grouping logic
4. **Model Creation** - Enhanced aggregates and error handling

## JSON Decoding Enhancements

### 1. Extract Decoder Configuration

Create a centralized decoder factory to ensure consistent JSON decoding across the application.

```swift
extension JSONDecoder {
    static func bridgeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            // Custom date strategy implementation
        }
        return decoder
    }
}
```

**Implementation Notes:**
- Ensures all JSON decoding configuration lives in one place
- Provides consistent behavior across all API calls
- Enables easy testing and modification of decoding strategies

**Documentation Requirements:**
- Link decoder factory in PR descriptions
- Reference relevant tickets/issues

### 2. Implement Custom Date Strategy

Create a robust date parsing strategy that handles the specific format used by the Seattle Open Data API.

```swift
decoder.dateDecodingStrategy = .custom { decoder in
    let container = try decoder.singleValueContainer()
    let dateString = try container.decode(String.self)
    
    // Primary format: "2024-05-01T14:33:00.101"
    if let date = BridgeOpeningRecord.dateFormatter.date(from: dateString) {
        return date
    }
    
    // ISO-8601 fallback
    if let date = ISO8601DateFormatter().date(from: dateString) {
        return date
    }
    
    throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid date format: \(dateString)"
    )
}
```

**Implementation Notes:**
- Guarantees strict format consistency for primary format
- Provides ISO-8601 fallback for edge cases
- Throws descriptive errors for debugging

**Documentation Requirements:**
- Document supported formats in README
- Note strategy choice rationale in DocC comments
- Link to test fixtures demonstrating format handling

### 3. Add ISO-8601 Fallback

Implement graceful fallback to ISO-8601 parsing when primary format fails.

**Implementation Notes:**
- Maintains backward compatibility
- Handles edge cases in API responses
- Preserves strict validation for primary format

**Documentation Requirements:**
- Clearly document fallback behavior in code comments
- Add "Supported Formats" section to README
- Include examples of supported date strings

### 4. Unit-Test Date Parsing Variants

Create comprehensive test coverage for all date parsing scenarios.

**Test Cases:**
- Valid date strings in primary format
- Valid date strings in ISO-8601 format
- Missing/null date values
- Malformed date strings
- Extra/unexpected fields

**Test Structure:**
```swift
class DateParsingTests: XCTestCase {
    func testValidPrimaryFormat() throws { /* ... */ }
    func testValidISO8601Format() throws { /* ... */ }
    func testMissingDate() throws { /* ... */ }
    func testMalformedDate() throws { /* ... */ }
    func testUnexpectedFields() throws { /* ... */ }
}
```

**Documentation Requirements:**
- Link each fixture file in PR descriptions
- Reference test classes for reviewer ease
- Document expected behavior for each test case

### 5. Update Documentation Comments

Enhance DocC documentation to explain implementation choices and supported formats.

**Documentation Updates:**
- Explain choice of `.custom` over `.iso8601`
- List all supported date formats
- Link to relevant tests and documentation
- Provide usage examples

## Business Validation Enhancements

### 1. Define Validation Failure Reasons

Create a structured approach to validation error reporting.

```swift
enum ValidationFailureReason {
    case emptyEntityID
    case unknownBridgeID(String)
    case malformedOpenDate(String)
    case invalidLatitude(Double)
    case invalidLongitude(Double)
    case negativeMinutesOpen(Int)
    
    var description: String {
        switch self {
        case .emptyEntityID:
            return "Empty entityid"
        case .unknownBridgeID(let id):
            return "Unknown bridge ID: \(id)"
        case .malformedOpenDate(let date):
            return "Malformed open date: \(date)"
        case .invalidLatitude(let value):
            return "Invalid latitude: \(value) (must be between -90 and 90)"
        case .invalidLongitude(let value):
            return "Invalid longitude: \(value) (must be between -180 and 180)"
        case .negativeMinutesOpen(let value):
            return "Negative minutes open: \(value)"
        }
    }
}
```

### 2. Build Validation and Filtering Logic

Implement comprehensive validation with detailed error reporting.

```swift
func validateAndFilterRecords(_ records: [BridgeOpeningRecord]) -> (valid: [BridgeOpeningRecord], failures: [ValidationFailureReason]) {
    var validRecords: [BridgeOpeningRecord] = []
    var failures: [ValidationFailureReason] = []
    
    for record in records {
        if let failure = validationFailureReason(for: record) {
            failures.append(failure)
        } else {
            validRecords.append(record)
        }
    }
    
    return (validRecords, failures)
}
```

### 3. Expand Error and Validation Reporting

Implement comprehensive logging and monitoring for validation failures.

```swift
#if DEBUG
    for failure in failures {
        print("Validation failure: \(failure.description)")
    }
#endif

// Production monitoring
#if !DEBUG
    for failure in failures {
        // Send to monitoring service (Sentry, DataDog, etc.)
        MonitoringService.recordValidationFailure(failure)
    }
#endif
```

**Implementation Notes:**
- Debug logging for development
- Production monitoring for operational insights
- Configurable error reporting destinations

**Documentation Requirements:**
- Specify error reporting destinations in architecture docs
- Document monitoring service integration
- Include error handling examples

### 4. Unit-Test Each Validation Rule

Create comprehensive test coverage for all validation scenarios.

```swift
class ValidationTests: XCTestCase {
    func testEmptyEntityID() throws { /* ... */ }
    func testUnknownBridgeID() throws { /* ... */ }
    func testMalformedOpenDate() throws { /* ... */ }
    func testInvalidLatitude() throws { /* ... */ }
    func testInvalidLongitude() throws { /* ... */ }
    func testNegativeMinutesOpen() throws { /* ... */ }
}
```

**Documentation Requirements:**
- Link each test method in PR descriptions
- Document expected failure messages
- Include test fixtures for complex scenarios

### 5. Document Possible Failure Reasons

Create comprehensive documentation of all validation rules and error messages.

**Documentation Structure:**
- List all validation rules
- Provide example error messages
- Include troubleshooting guidance
- Reference monitoring and logging documentation

## Data Grouping Enhancements

### 1. Extract Generic Grouping Logic

Create a flexible, reusable grouping mechanism.

```swift
func groupRecords<T: Hashable>(
    _ records: [BridgeOpeningRecord],
    by keyPath: KeyPath<BridgeOpeningRecord, T>,
    includeOrphans: Bool = true
) -> [T: [BridgeOpeningRecord]] {
    let grouped = Dictionary(grouping: records, by: { $0[keyPath: keyPath] })
    
    if includeOrphans {
        return grouped
    } else {
        return grouped.filter { !$0.value.isEmpty }
    }
}
```

**Implementation Notes:**
- Generic implementation for maximum flexibility
- Configurable orphan handling
- Foundation for specialized grouping helpers

### 2. Replace Inline Grouping

Update all existing grouping logic to use the new helper.

**Migration Strategy:**
- Identify all `Dictionary(grouping: ...)` calls
- Replace with `groupRecords(_:by:)` calls
- Update tests to reflect new behavior
- Document migration in changelog

### 3. Decide Orphan-Group Behavior

Parameterize and document orphan group handling.

**Options:**
- Include empty arrays for missing keys
- Drop keys with no associated records
- Configurable behavior based on use case

**Documentation Requirements:**
- Document behavior choice in code comments
- Update README with grouping examples
- Include configuration guidance

### 4. Add Alternative Group-By Helpers

Create specialized grouping functions for common use cases.

```swift
extension BridgeOpeningRecord {
    func groupByWeek(_ records: [BridgeOpeningRecord]) -> [Int: [BridgeOpeningRecord]] {
        return groupRecords(records, by: \.weekOfYear)
    }
    
    func groupByLocation(_ records: [BridgeOpeningRecord]) -> [String: [BridgeOpeningRecord]] {
        return groupRecords(records, by: \.entityid)
    }
}
```

### 5. Unit-Test Grouping Logic

Create comprehensive test coverage for grouping scenarios.

**Test Cases:**
- Grouping by entity ID
- Grouping by week of year
- Empty record sets
- Orphan handling
- Edge cases and boundary conditions

**Documentation Requirements:**
- Link test files in PR descriptions
- Document expected grouping behavior
- Include performance considerations

## Model Creation Enhancements

### 1. Enhance Model Creation with Aggregates

Add computed aggregates to bridge models.

```swift
func createBridgeModels(from groupedRecords: [String: [BridgeOpeningRecord]]) -> [BridgeStatusModel] {
    return groupedRecords.compactMap { entityID, records in
        guard let firstRecord = records.first,
              !firstRecord.entityname.isEmpty else {
            return nil
        }
        
        let totalMinutesOpen = records.compactMap(\.minutesOpenValue).reduce(0, +)
        let totalOpenings = records.count
        
        return BridgeStatusModel(
            bridgeName: firstRecord.entityname,
            apiBridgeID: entityID,
            historicalOpenings: records.compactMap(\.openDate),
            totalMinutesOpen: totalMinutesOpen,
            totalOpenings: totalOpenings
        )
    }
}
```

**New Properties:**
- `totalMinutesOpen`: Sum of all opening durations
- `totalOpenings`: Count of opening events
- Additional computed properties as needed

### 2. Add Error-Handling Paths

Implement graceful handling of missing or invalid data.

**Error Handling Strategy:**
- Skip records with missing entity names
- Log validation failures for monitoring
- Provide fallback values where appropriate
- Document behavior in comments and README

### 3. Log Model-Level Aggregates

Implement comprehensive logging for model creation.

```swift
#if DEBUG
    for model in models {
        print("\(model.bridgeName): \(model.totalOpenings) openings, \(model.totalMinutesOpen) total minutes")
    }
#endif

#if !DEBUG
    // Send summary statistics to monitoring service
    MonitoringService.recordModelAggregates(models)
#endif
```

### 4. Unit-Test Model Building

Create comprehensive test coverage for model creation.

**Test Scenarios:**
- Valid grouped data
- Missing entity names
- Empty record sets
- Edge cases and boundary conditions
- Aggregate computation accuracy

**Documentation Requirements:**
- Link test fixtures in PR descriptions
- Document expected model properties
- Include performance benchmarks

### 5. Update Documentation Comments

Enhance DocC documentation for all new properties and behaviors.

**Documentation Updates:**
- Describe each aggregate property
- Link to related tests and documentation
- Provide usage examples
- Include performance considerations

## Implementation Checklist

### JSON Decoding
- [x] Extract decoder configuration
- [x] Implement custom date strategy
- [x] Add ISO-8601 fallback
- [x] Create comprehensive test suite
- [x] Update documentation

### Business Validation
- [ ] Define validation failure reasons
- [ ] Build validation and filtering logic
- [ ] Implement error reporting
- [ ] Create unit tests
- [ ] Document validation rules

### Data Grouping
- [ ] Extract generic grouping logic
- [ ] Replace inline grouping
- [ ] Implement orphan handling
- [ ] Add specialized helpers
- [ ] Create unit tests

### Model Creation
- [ ] Enhance model creation with aggregates
- [ ] Implement error handling
- [ ] Add logging and monitoring
- [ ] Create unit tests
- [ ] Update documentation

## Best Practices

### PR Guidelines
- Link relevant tests and documentation in PR descriptions
- Include performance impact analysis
- Provide migration guidance for breaking changes
- Reference related tickets and issues

### Documentation Standards
- Document all configuration choices
- Include usage examples
- Link to test fixtures
- Provide troubleshooting guidance

### Testing Requirements
- Comprehensive unit test coverage
- Performance benchmarks for critical paths
- Integration tests for end-to-end scenarios
- Documentation of test fixtures and expected behavior

### Monitoring and Logging
- Specify error reporting destinations
- Document monitoring service integration
- Include performance metrics collection
- Provide operational guidance

## Related Documentation

- [Architecture Overview](doc:ArchitectureOverview)
- [Data Flow](doc:DataFlow)
- [Error Handling](doc:ErrorHandling)
- [Caching Strategy](doc:CachingStrategy) 
