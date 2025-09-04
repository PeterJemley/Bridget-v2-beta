# Thread Sanitizer Setup for Bridget

This document describes the Thread Sanitizer (TSan) configuration for the Bridget project, including when and how to use it effectively.

## Overview

Thread Sanitizer is a dynamic analysis tool that detects data races in multithreaded programs. It's particularly valuable for Swift Concurrency code using actors, async/await, and shared state. **Note: The project has completed comprehensive concurrency fixes and all shared instances are now properly isolated with @MainActor.**

## Configuration

The project includes two test schemes:

1. **BridgetTests** - Regular testing without Thread Sanitizer
2. **BridgetTests-TSan** - Testing with Thread Sanitizer enabled

### Build Configurations

- **Debug** - Standard debug build
- **Debug-TSan** - Debug build with Thread Sanitizer enabled
- **Release** - Release build

### TSan Options

The Thread Sanitizer is configured with the following options:
- `halt_on_error=1` - Stop execution on first data race
- `second_deadlock_stack=1` - Show second stack trace for deadlocks
- `report_signal_unsafe=0` - Disable signal-unsafe reporting
- `report_thread_leaks=0` - Disable thread leak reporting
- `history_size=7` - Set history buffer size
- `external_symbolizer_path=/usr/bin/atos` - Use atos for symbolization
- `log_path=tsan.log` - Log to tsan.log file

## Usage

### Running TSan Tests

Use the provided script for convenience:

```bash
# Run all TSan tests
./Scripts/run_tsan_tests.sh

# Run specific test
./Scripts/run_tsan_tests.sh ThreadSanitizerTests

# Run with verbose output
./Scripts/run_tsan_tests.sh -v ThreadSanitizerTests
```

### Manual Execution

```bash
# Using xcodebuild directly
xcodebuild test -scheme BridgetTests-TSan -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Using Xcode IDE
# Select "BridgetTests-TSan" scheme and run tests
```

## When to Use Thread Sanitizer

### ✅ Enable TSan When:

- **Refactoring to Swift Concurrency** - Converting synchronous code to async/await
- **Introducing new shared state** - Adding caches, aggregators, or shared data structures
- **Debugging flaky tests** - Intermittent failures that might be race conditions
- **Working with actors** - Ensuring proper actor isolation
- **Using locks or synchronization** - OSAllocatedUnfairLock, DispatchQueue, etc.
- **Testing concurrent code** - Any code that uses Task, async/await, or multiple threads

### ❌ Disable TSan When:

- **Performance benchmarking** - TSan significantly slows execution
- **Tests with tight timing** - TSan can change timing and mask races
- **CI/CD pipelines** - Unless specifically testing for races
- **Release builds** - TSan is for development/debugging only
- **Large datasets** - TSan memory overhead can be significant

## Best Practices

### Development Workflow

1. **Regular Development**: Use `BridgetTests` scheme for normal development
2. **Concurrency Work**: Switch to `BridgetTests-TSan` when working on:
   - New async functions
   - Actor implementations
   - Shared state management
   - Concurrent data access

### CI/CD Integration

Consider adding a periodic TSan job to your CI pipeline:

```yaml
# Example GitHub Actions workflow
- name: Thread Sanitizer Tests
  run: |
    ./Scripts/run_tsan_tests.sh
  # Run this as a nightly job, not on every PR
```

### Performance Considerations

- TSan typically slows execution by 5-10x
- Memory usage increases significantly
- Build times are longer due to instrumentation
- Use sparingly in performance-sensitive scenarios

## Troubleshooting

### Common Issues

1. **Build Configuration Mismatch**: Ensure both app and test targets have Debug-TSan configurations
2. **Scheme Configuration**: Verify the scheme uses Debug-TSan for both Build and Test actions
3. **Simulator Issues**: Use iOS Simulator for TSan testing (device testing may have limitations)

### False Positives

TSan may report false positives for:
- System framework calls
- SwiftUI updates
- Some Core Data operations
- Third-party library code

### Performance Issues

If TSan is too slow:
- Reduce test scope to specific test classes
- Use `-only-testing` flag to run specific tests
- Consider running TSan tests separately from regular tests

## Verification

The setup includes a test suite (`ThreadSanitizerTests`) that verifies:
- TSan is properly enabled
- Data race detection works
- Actor isolation prevents races
- Synchronized access patterns work correctly

Run these tests to verify your TSan setup is working:

```bash
./Scripts/run_tsan_tests.sh ThreadSanitizerTests
```

## Integration with Other Tools

Combine TSan with other sanitizers as needed:

- **Address Sanitizer (ASan)**: For memory errors
- **Undefined Behavior Sanitizer (UBSan)**: For undefined behavior
- **Malloc Scribble/Guard Malloc**: For heap issues

## Summary

Your Thread Sanitizer setup is now complete and working! Use it strategically during development to catch data races early, especially when working with Swift Concurrency features. The dual-scheme approach allows you to maintain fast development cycles while having powerful race detection when needed.

Remember: TSan is a development tool - keep it enabled for targeted testing but don't let it slow down your regular development workflow.
