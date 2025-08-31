#!/bin/bash

# Thread Sanitizer Test Runner for Bridget
# Usage: ./Scripts/run_tsan_tests.sh [test_pattern] [options]

set -e

# Default values
SCHEME="BridgetTests-TSan"
DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro"
TEST_PATTERN=""
VERBOSE=false
CLEAN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Usage: $0 [test_pattern] [options]"
            echo ""
            echo "Options:"
            echo "  -h, --help          Show this help message"
            echo "  -v, --verbose       Enable verbose output"
            echo "  -c, --clean         Clean build before running tests"
            echo "  -s, --scheme        Specify scheme (default: BridgetTests-TSan)"
            echo "  -d, --destination   Specify destination (default: iPhone 16 Pro)"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Run all TSan tests"
            echo "  $0 PathScoringServiceTests           # Run specific test class"
            echo "  $0 -v -c                             # Verbose with clean build"
            echo "  $0 -s BridgetTests                   # Use regular scheme (no TSan)"
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -s|--scheme)
            SCHEME="$2"
            shift 2
            ;;
        -d|--destination)
            DESTINATION="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
        *)
            TEST_PATTERN="$1"
            shift
            ;;
    esac
done

# Build the xcodebuild command
CMD="xcodebuild test -scheme $SCHEME -destination '$DESTINATION'"

# Add clean if requested
if [ "$CLEAN" = true ]; then
    CMD="xcodebuild clean && $CMD"
fi

# Add test pattern if specified
if [ -n "$TEST_PATTERN" ]; then
    CMD="$CMD -only-testing:BridgetTests/$TEST_PATTERN"
fi

# Add verbose output if requested
if [ "$VERBOSE" = true ]; then
    CMD="$CMD -verbose"
fi

# Display what we're about to run
echo "Running Thread Sanitizer tests..."
echo "Scheme: $SCHEME"
echo "Destination: $DESTINATION"
if [ -n "$TEST_PATTERN" ]; then
    echo "Test pattern: $TEST_PATTERN"
fi
if [ "$CLEAN" = true ]; then
    echo "Clean build: enabled"
fi
if [ "$VERBOSE" = true ]; then
    echo "Verbose output: enabled"
fi
echo ""

# Set TSan environment variables for better output
export TSAN_OPTIONS="halt_on_error=1:second_deadlock_stack=1:report_signal_unsafe=0:report_thread_leaks=0:history_size=7:external_symbolizer_path=/usr/bin/atos:log_path=tsan.log"

echo "TSAN_OPTIONS: $TSAN_OPTIONS"
echo ""

# Run the command
echo "Executing: $CMD"
echo "=================================="
eval $CMD

# Check exit status
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Thread Sanitizer tests completed successfully!"
    echo "No data races detected."
else
    echo ""
    echo "❌ Thread Sanitizer tests failed!"
    echo "Check the output above for data race reports."
    echo ""
    echo "Common next steps:"
    echo "1. Review the TSan reports for data race locations"
    echo "2. Look for shared mutable state accessed from multiple threads"
    echo "3. Consider using actors or other synchronization primitives"
    echo "4. Check the tsan.log file for detailed reports"
    exit 1
fi
