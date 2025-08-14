#!/bin/bash

# MARK: - Layout Debugger Script for iOS Simulator
# This script provides systematic ways to inspect the iOS Simulator's screen

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}🔧 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# MARK: - Screenshot Analysis
analyze_screenshot() {
    local screenshot_path="$1"
    
    if [[ ! -f "$screenshot_path" ]]; then
        print_error "Screenshot not found: $screenshot_path"
        return 1
    fi
    
    print_header "Screenshot Analysis"
    
    # Get image dimensions using sips (macOS built-in)
    local dimensions=$(sips -g pixelWidth -g pixelHeight "$screenshot_path" 2>/dev/null | grep -E "(pixelWidth|pixelHeight)" | awk '{print $2}')
    local width=$(echo "$dimensions" | head -1)
    local height=$(echo "$dimensions" | tail -1)
    
    print_info "Image dimensions: ${width}x${height}"
    
    # Check file size
    local file_size=$(stat -f%z "$screenshot_path" 2>/dev/null || stat -c%s "$screenshot_path" 2>/dev/null)
    print_info "File size: ${file_size} bytes"
    
    # Analyze for common layout issues
    analyze_layout_issues "$screenshot_path" "$width" "$height"
}

analyze_layout_issues() {
    local screenshot_path="$1"
    local width="$2"
    local height="$3"
    
    print_header "Layout Issue Detection"
    
    # Check if image is mostly white/empty (potential layout problem)
    print_info "Checking for empty regions..."
    
    # Use ImageMagick if available, otherwise use basic analysis
    if command -v convert &> /dev/null; then
        # Advanced analysis with ImageMagick
        local white_pixels=$(convert "$screenshot_path" -format "%[fx:mean*100]" info: 2>/dev/null || echo "0")
        print_info "Average brightness: ${white_pixels}%"
        
        if (( $(echo "$white_pixels > 90" | bc -l) )); then
            print_warning "Image appears mostly white - possible layout issue"
        fi
    else
        print_info "ImageMagick not available - using basic analysis"
        print_info "Manual inspection recommended"
    fi
}

# MARK: - Accessibility Analysis
analyze_accessibility() {
    print_header "Accessibility Analysis"
    
    echo "1. Open Accessibility Inspector:"
    echo "   - Press Cmd+Shift+A in Xcode"
    echo "   - Or run: open -a 'Accessibility Inspector'"
    echo ""
    echo "2. Connect to Simulator:"
    echo "   - Select your app in the target dropdown"
    echo "   - Use the crosshair to inspect elements"
    echo ""
    echo "3. Check for issues:"
    echo "   - Missing accessibility labels"
    echo "   - Incorrect accessibility traits"
    echo "   - Poor contrast ratios"
    echo "   - Touch target sizes"
}

# MARK: - View Hierarchy Analysis
analyze_view_hierarchy() {
    print_header "View Hierarchy Analysis"
    
    echo "1. Use Xcode's View Debugger:"
    echo "   - Run app in debugger"
    echo "   - Press Cmd+Shift+D to capture view hierarchy"
    echo "   - Or use Debug > View Debugging > Capture View Hierarchy"
    echo ""
    echo "2. Examine the hierarchy:"
    echo "   - Look for hidden views"
    echo "   - Check frame/bounds"
    echo "   - Verify Auto Layout constraints"
    echo "   - Look for overlapping views"
    echo ""
    echo "3. Common issues to check:"
    echo "   - Views with zero width/height"
    echo "   - Views outside screen bounds"
    echo "   - Missing constraints"
    echo "   - Conflicting constraints"
}

# MARK: - Layout Constraints Analysis
analyze_constraints() {
    print_header "Layout Constraints Analysis"
    
    echo "1. In Xcode View Debugger:"
    echo "   - Select any view"
    echo "   - Check the Size Inspector"
    echo "   - Look for constraint warnings"
    echo ""
    echo "2. Common constraint issues:"
    echo "   - Red constraint lines (conflicts)"
    echo "   - Orange constraint lines (warnings)"
    echo "   - Missing constraints (ambiguous layout)"
    echo "   - Views with intrinsic content size issues"
    echo ""
    echo "3. Debug steps:"
    echo "   - Add temporary background colors"
    echo "   - Use layout debugging tools"
    echo "   - Check for conflicting priorities"
}

# MARK: - Performance Analysis
analyze_performance() {
    print_header "Performance Analysis"
    
    echo "1. Use Xcode Instruments:"
    echo "   - Product > Profile (Cmd+I)"
    echo "   - Select Time Profiler or Core Animation"
    echo ""
    echo "2. Check for issues:"
    echo "   - Frame drops (Core Animation)"
    echo "   - Excessive view updates"
    echo "   - Memory leaks"
    echo "   - Layout thrashing"
    echo ""
    echo "3. Console logs:"
    echo "   - Look for layout constraint warnings"
    echo "   - Check for performance warnings"
    echo "   - Monitor memory usage"
}

# MARK: - Automated Testing
generate_ui_tests() {
    print_header "UI Test Generation"
    
    echo "1. Create UI Tests:"
    echo "   - File > New > Target > UI Testing Bundle"
    echo "   - Add test cases for all interactive elements"
    echo ""
    echo "2. Test scenarios:"
    echo "   - Different screen sizes"
    echo "   - Orientation changes"
    echo "   - Accessibility features"
    echo "   - Dark/light mode"
    echo ""
    echo "3. Example test structure:"
    echo "   func testLayoutOnDifferentDevices() {"
    echo "       // Test on iPhone SE, iPhone 16 Pro, iPad"
    echo "   }"
}

# MARK: - Simulator Commands
simulator_commands() {
    print_header "Useful Simulator Commands"
    
    echo "Screenshot:"
    echo "  xcrun simctl io booted screenshot /tmp/screenshot.png"
    echo ""
    echo "App logs:"
    echo "  xcrun simctl spawn booted log show --predicate 'process == \"Bridget\"' --last 1m"
    echo ""
    echo "Install app:"
    echo "  xcrun simctl install booted /path/to/app.app"
    echo ""
    echo "Launch app:"
    echo "  xcrun simctl launch booted com.peterjemley.Bridget"
    echo ""
    echo "List devices:"
    echo "  xcrun simctl list devices"
}

# MARK: - Quick Fixes
quick_fixes() {
    print_header "Quick Layout Fixes"
    
    echo "1. Common SwiftUI fixes:"
    echo "   - Add .frame(maxWidth: .infinity) to expand views"
    echo "   - Use Spacer() for flexible spacing"
    echo "   - Check for missing .padding()"
    echo "   - Verify ScrollView content size"
    echo ""
    echo "2. Debug techniques:"
    echo "   - Add temporary background colors"
    echo "   - Use .border() to see view bounds"
    echo "   - Check for clipped content"
    echo "   - Verify navigation stack depth"
    echo ""
    echo "3. Responsive design:"
    echo "   - Use GeometryReader for dynamic sizing"
    echo "   - Implement ViewThatFits for adaptive layouts"
    echo "   - Test on multiple device sizes"
}

# MARK: - Main Function
main() {
    local command="${1:-help}"
    
    case "$command" in
        "screenshot")
            if [[ -n "$2" ]]; then
                analyze_screenshot "$2"
            else
                print_error "Please provide screenshot path"
                echo "Usage: $0 screenshot <path>"
            fi
            ;;
        "accessibility")
            analyze_accessibility
            ;;
        "hierarchy")
            analyze_view_hierarchy
            ;;
        "constraints")
            analyze_constraints
            ;;
        "performance")
            analyze_performance
            ;;
        "tests")
            generate_ui_tests
            ;;
        "simulator")
            simulator_commands
            ;;
        "fixes")
            quick_fixes
            ;;
        "all")
            analyze_accessibility
            echo ""
            analyze_view_hierarchy
            echo ""
            analyze_constraints
            echo ""
            analyze_performance
            echo ""
            generate_ui_tests
            echo ""
            simulator_commands
            echo ""
            quick_fixes
            ;;
        "help"|*)
            print_header "Layout Debugger - iOS Simulator Analysis Tool"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  screenshot <path>  - Analyze screenshot for layout issues"
            echo "  accessibility      - Show accessibility analysis steps"
            echo "  hierarchy          - Show view hierarchy analysis"
            echo "  constraints        - Show layout constraints analysis"
            echo "  performance        - Show performance analysis"
            echo "  tests              - Generate UI test suggestions"
            echo "  simulator          - Show useful simulator commands"
            echo "  fixes              - Show quick layout fixes"
            echo "  all                - Run all analyses"
            echo "  help               - Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 screenshot /tmp/simulator_screenshot.png"
            echo "  $0 all"
            echo "  $0 accessibility"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
