# Testing Workflow

## Overview

This document outlines the testing strategy and workflow for the Bridget project, including how to manage debug flags and run different types of tests.

## Test Suites

### BridgeDecoderTests

Tests for JSON date decoding functionality with enhanced logging capabilities.

**Location**: `BridgetTests/BridgeDecoderTests.swift`

**Key Features**:
- Tests various date format scenarios (valid, malformed, null)
- Uses preprocessor macro for conditional logging
- Verifies `JSONDecoder.bridgeDecoder()` functionality

## TEST_LOGGING Flag Management

### What It Does

The `TEST_LOGGING` flag enables enhanced logging during date parsing operations. When enabled:
- All date parsing attempts are logged
- Parse failures include detailed error information
- Helps debug JSON decoding issues

### How to Enable in Xcode

1. Open the project in Xcode
2. Select the **BridgetTests** target
3. Go to **Build Settings**
4. Find **"Other Swift Flags"**
5. Add: `-DTEST_LOGGING`

### When to Enable

- ✅ **During development/debugging** of date parsing issues
- ✅ **When investigating JSON decoding failures**
- ✅ **When you need detailed logging** of parse attempts and failures
- ✅ **When working on the data processing pipeline**

### When to Disable

- ❌ **During normal test runs** (to reduce noise)
- ❌ **In CI/CD pipelines** (unless debugging specific issues)
- ❌ **When running performance tests**
- ❌ **During regular development** (unless actively debugging)

## Command Line Testing

### Normal Test Run (No Logging)

```bash
xcodebuild -project Bridget.xcodeproj -scheme Bridget -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

### Test Run with Logging Enabled

```bash
xcodebuild -project Bridget.xcodeproj -scheme Bridget -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test OTHER_SWIFT_FLAGS="-DTEST_LOGGING"
```

### Test Specific Suite with Logging

```bash
xcodebuild -project Bridget.xcodeproj -scheme Bridget -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:BridgetTests/BridgeDecoderTests OTHER_SWIFT_FLAGS="-DTEST_LOGGING"
```

## Testing Framework

### Current Framework: Swift Testing

The project uses the new Swift Testing framework (`import Testing`) for modern test syntax:
- `@Suite` for test organization
- `@Test` for individual test methods
- `#expect` for assertions

### Migration Notes

- Previously used XCTest framework
- Converted to Swift Testing for better performance and modern syntax
- All tests maintain the same functionality

## Test Categories

### Unit Tests

- **ModelTests**: Core data model functionality
- **BridgeDecoderTests**: JSON decoding and date parsing

### UI Tests

- **BridgetUITests**: User interface functionality
- **BridgetUITestsLaunchTests**: App launch and basic UI behavior

## Best Practices

### Flag Management

- Keep `TEST_LOGGING` disabled by default
- Enable only when actively debugging
- Document when the flag is enabled in commit messages

### Test Organization

- Group related tests in suites
- Use descriptive test names
- Include both positive and negative test cases

### Error Handling

- Test both success and failure scenarios
- Verify error types and messages
- Test edge cases and boundary conditions

## Troubleshooting

### Common Issues

1. **Tests failing with "cannot find 'JSONDecoder'"**
   - Ensure `import Foundation` is present in test files

2. **TEST_LOGGING not working**
   - Verify the flag is added to "Other Swift Flags" in Xcode
   - Check that the flag is applied to the correct target (BridgetTests)

3. **Build errors after framework changes**
   - Clean build folder: `Product > Clean Build Folder`
   - Rebuild the project

### Debug Commands

```bash
# Clean and rebuild
xcodebuild clean -project Bridget.xcodeproj -scheme Bridget

# Show build settings
xcodebuild -project Bridget.xcodeproj -scheme Bridget -showBuildSettings | grep SWIFT_FLAGS
```

## Future Enhancements

### Planned Improvements

- [ ] Add performance benchmarks for date parsing
- [ ] Create test fixtures for various JSON formats
- [ ] Add integration tests for the full data pipeline
- [ ] Implement test coverage reporting

### Monitoring

- Track test execution time
- Monitor for flaky tests
- Regular review of test effectiveness 