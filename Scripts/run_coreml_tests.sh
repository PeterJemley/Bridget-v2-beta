#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Core ML Swift Testing Runner
# =============================================================================
# Runs Core ML tests with different configurations using Swift Testing
# and environment variables to avoid resource contention.

# =============================================================================
# Configuration (customize as needed)
# =============================================================================

SCHEME="Bridget"
PROJECT="Bridget.xcodeproj"
DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro"
DERIVED_DATA="${PWD}/DerivedData"

# Test configurations to run (order matters - fastest first)
CONFIGURATIONS=(
    "CPU_ONLY_LOW_PRECISION"
    "CPU_ONLY"
    "CPU_AND_GPU_LOW_PRECISION"
    "CPU_AND_GPU"
    "ALL_LOW_PRECISION"
    "ALL"
    "CI"
)

# =============================================================================
# Artifact Management
# =============================================================================

STAMP=$(date +"%Y%m%d-%H%M%S")
ARTIFACTS_DIR="${PWD}/TestResults/${STAMP}"
mkdir -p "${ARTIFACTS_DIR}"

echo "📁 Artifacts will be stored in: ${ARTIFACTS_DIR}"

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_error() {
    echo "❌ $1" >&2
}

log_section() {
    echo ""
    echo "🔹 $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# =============================================================================
# Environment Variable Configuration
# =============================================================================

get_environment_variables() {
    local config_name="$1"
    
    case "$config_name" in
        "CPU_ONLY")
            echo "ML_BATCH_SIZE=32 ML_PREDICTION_TIMEOUT=60.0 ML_ALLOW_LOW_PRECISION=false ML_PREFER_ANE=false ML_COMPUTE_UNITS=CPU_ONLY"
            ;;
        "CPU_ONLY_LOW_PRECISION")
            echo "ML_BATCH_SIZE=16 ML_PREDICTION_TIMEOUT=30.0 ML_ALLOW_LOW_PRECISION=true ML_PREFER_ANE=false ML_COMPUTE_UNITS=CPU_ONLY"
            ;;
        "CPU_AND_GPU")
            echo "ML_BATCH_SIZE=32 ML_PREDICTION_TIMEOUT=60.0 ML_ALLOW_LOW_PRECISION=false ML_PREFER_ANE=false ML_COMPUTE_UNITS=CPU_AND_GPU"
            ;;
        "CPU_AND_GPU_LOW_PRECISION")
            echo "ML_BATCH_SIZE=32 ML_PREDICTION_TIMEOUT=45.0 ML_ALLOW_LOW_PRECISION=true ML_PREFER_ANE=false ML_COMPUTE_UNITS=CPU_AND_GPU"
            ;;
        "ALL")
            echo "ML_BATCH_SIZE=32 ML_PREDICTION_TIMEOUT=60.0 ML_ALLOW_LOW_PRECISION=false ML_PREFER_ANE=true ML_COMPUTE_UNITS=ALL"
            ;;
        "ALL_LOW_PRECISION")
            echo "ML_BATCH_SIZE=32 ML_PREDICTION_TIMEOUT=45.0 ML_ALLOW_LOW_PRECISION=true ML_PREFER_ANE=true ML_COMPUTE_UNITS=ALL"
            ;;
        "CI")
            echo "ML_BATCH_SIZE=16 ML_PREDICTION_TIMEOUT=120.0 ML_ALLOW_LOW_PRECISION=true ML_PREFER_ANE=false ML_COMPUTE_UNITS=CPU_ONLY"
            ;;
        *)
            log_error "Unknown configuration: $config_name"
            return 1
            ;;
    esac
}

# =============================================================================
# Test Execution
# =============================================================================

run_configuration() {
    local config_name="$1"
    local env_vars
    local result_bundle="${ARTIFACTS_DIR}/${config_name}.xcresult"
    
    env_vars=$(get_environment_variables "$config_name")
    
    log_section "Running: $config_name"
    
    # Build command
    local CMD=(
        "xcodebuild"
        "-project" "${PROJECT}"
        "-scheme" "${SCHEME}"
        "-destination" "${DESTINATION}"
        "-derivedDataPath" "${DERIVED_DATA}"
        "-resultBundlePath" "${result_bundle}"
        "test"
    )
    
    # Execute command with environment variables
    log_info "Command: ${CMD[*]}"
    log_info "Environment: $env_vars"
    log_info "Destination: $DESTINATION"
    
    if env $env_vars "${CMD[@]}" | xcpretty; then
        log_success "Configuration completed: $config_name"
        log_info "Results stored at: $result_bundle"
        return 0
    else
        log_error "Configuration failed: $config_name"
        return 1
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

log_section "Starting Core ML Swift Testing Execution"

# Track overall success
OVERALL_SUCCESS=true
FAILED_CONFIGURATIONS=()

# Run each configuration
for config in "${CONFIGURATIONS[@]}"; do
    if ! run_configuration "$config"; then
        OVERALL_SUCCESS=false
        FAILED_CONFIGURATIONS+=("$config")
    fi
done

# =============================================================================
# Results Summary
# =============================================================================

log_section "Execution Summary"

if [ "$OVERALL_SUCCESS" = true ]; then
    log_success "All configurations completed successfully!"
    echo ""
    echo "📊 Results:"
    echo "   • Total configurations: ${#CONFIGURATIONS[@]}"
    echo "   • Successful: ${#CONFIGURATIONS[@]}"
    echo "   • Failed: 0"
    echo "   • Artifacts: ${ARTIFACTS_DIR}"
    exit 0
else
    log_error "Some configurations failed!"
    echo ""
    echo "📊 Results:"
    echo "   • Total configurations: ${#CONFIGURATIONS[@]}"
    echo "   • Successful: $((${#CONFIGURATIONS[@]} - ${#FAILED_CONFIGURATIONS[@]}))"
    echo "   • Failed: ${#FAILED_CONFIGURATIONS[@]}"
    echo "   • Artifacts: ${ARTIFACTS_DIR}"
    echo ""
    echo "❌ Failed configurations:"
    for config in "${FAILED_CONFIGURATIONS[@]}"; do
        echo "   • $config"
    done
    exit 1
fi


