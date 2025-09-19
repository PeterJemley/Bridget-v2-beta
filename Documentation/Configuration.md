# Bridget Configuration Overview

This document provides a centralized view of all configuration settings, thresholds, and feature flags in the Bridget application.

## 🎯 **Current Status: Production Ready** ✅

**Last Updated**: January 2025  
**Configuration Version**: Phase 5 Step 3 Complete  
**Status**: All systems operational with 100% feature flag rollout + SIMD/vDSP optimizations

---

## 📊 **Feature Flags**

### **Coordinate Transformation System** ✅ **ENABLED**
- **Status**: `enabled: true`
- **Rollout**: `100%` (oneHundredPercent)
- **A/B Testing**: `disabled: false`
- **Description**: "Coordinate transformation system enabled"
- **Phase**: 4.1
- **Safety Level**: high
- **Enabled At**: Current timestamp

### **Other Feature Flags** 🔄 **DISABLED**
- **Enhanced Validation**: `disabled: false` (default)
- **Statistical Uncertainty**: `disabled: false` (default)
- **Traffic Profile Integration**: `disabled: false` (default)

---

## 🎯 **Validation Thresholds**

### **Geospatial Validation**
- **Tight Threshold**: `500.0 meters` (with coordinate transformation)
- **Fallback Threshold**: `8000.0 meters` (without transformation)
- **Purpose**: Tight validation for transformed coordinates, fallback for untransformed

### **Data Quality Thresholds**
- **Max NaN Rate**: `0.05` (5%)
- **Min Validation Rate**: `0.95` (95%)
- **Max Invalid Record Rate**: `0.02` (2%)
- **Min Data Volume**: `1000` records

### **Model Performance Thresholds**
- **Min Accuracy**: `0.75` (75%)
- **Max Loss**: `0.5`
- **Min F1 Score**: `0.70` (70%)

---

## ⚡ **Performance Configuration**

### **ML Pipeline Settings**
- **Enable Parallelization**: `true`
- **Max Concurrent Horizons**: `4`
- **Batch Size**: `1000`
- **Max Retry Attempts**: `3`
- **Retry Backoff Multiplier**: `2.0`
- **Enable Checkpointing**: `true`
- **Memory Optimization Level**: `balanced`

### **Validation Performance**
- **Enable Parallel Validation**: `true`
- **Max Concurrent Validators**: `4`
- **Batch Size**: `1000`

---

## 🚨 **Alert Configuration**

### **Transformation Monitoring Alerts**
- **Min Success Rate**: `0.95` (95%)
- **Max Processing Time**: `100.0 ms`
- **Min Distance Improvement**: `100.0 meters`
- **Alert Cooldown**: `300 seconds` (5 minutes)

### **Alert Types**
- **Success Rate Alert**: Triggers when success rate drops below 95%
- **Performance Alert**: Triggers when processing time exceeds 100ms
- **Accuracy Alert**: Triggers when distance improvement is below 100m

---

## 🔧 **Coordinate Transformation Settings**

### **Transformation Matrices**
- **Bridge 1**: `latOffset: -0.05578656, lonOffset: -0.00246503`
- **Bridge 6**: `latOffset: -0.009, lonOffset: -0.004`
- **Default Matrix**: Identity matrix (no transformation)

### **Coordinate Systems**
- **Seattle API**: Source coordinate system
- **Reference System**: Target coordinate system
- **Transformation Method**: Translation-only (no rotation/scaling)

### **Matrix Caching Configuration** ✅ **ENABLED**
- **Enable Matrix Caching**: `true` (default)
- **Cache Capacity**: `512` matrices (LRU eviction)
- **Cache Type**: Synchronous LRU cache on @MainActor
- **Hit/Miss Tracking**: Enabled with metrics collection
- **Cache Versioning**: Automatic invalidation on config changes

### **Performance Optimizations** ✅ **ENABLED**
- **SIMD Single-Point**: Enabled for all single-point transformations
- **vDSP Batch Processing**: Enabled for batch operations
- **Small Input Threshold**: `< 32 points` (falls back to SIMD)
- **Double Precision**: Maintained end-to-end with 1e-12 tolerance
- **Zero-Rotation Fast Path**: Optimized for matrices with no rotation

### **TransformCache Configuration** (Advanced)
- **Matrix Capacity**: `512` (LRU cache)
- **Point Capacity**: `2048` (LRU cache)
- **Point TTL**: `60 seconds`
- **Point Cache Enabled**: `true`
- **Quantization Precision**: `6` decimal places
- **Cache Type**: Actor-based async cache

---

## 📁 **File Paths & Directories**

### **Default Paths**
- **Output Directory**: `FileManagerUtils.temporaryDirectory().path`
- **Checkpoint Directory**: `nil` (uses default)
- **Metrics Export Path**: `nil` (disabled by default)
- **Input Path**: `"minutes_2025-01-27.ndjson"`

### **UserDefaults Keys**
- **Feature Flags**: `"BridgetFeatureFlags"`
- **Monitoring Data**: `"BridgetMonitoringData"`
- **Alert Configuration**: `"BridgetAlertConfig"`

---

## 🎛️ **UI Configuration**

### **Developer Tools**
- **Enable Developer Tools**: `@AppStorage("enableDeveloperTools")`
- **Pipeline Dashboard**: Available when developer tools enabled
- **ML Training**: Available when developer tools enabled
- **Metrics Dashboard**: Available when developer tools enabled
- **Plugin Management**: Available when developer tools enabled
- **Troubleshooting**: Available when developer tools enabled

### **Dashboard Settings**
- **Default Time Range**: Last 24 hours
- **Refresh Interval**: Manual refresh
- **Export Format**: JSON
- **Alert Display**: Real-time

---

## 🔄 **Rollout Configuration**

### **Feature Flag Rollout Percentages**
- **Disabled**: `0%`
- **Ten Percent**: `10%`
- **Twenty Five Percent**: `25%`
- **Fifty Percent**: `50%`
- **Seventy Five Percent**: `75%`
- **One Hundred Percent**: `100%`

### **A/B Test Variants**
- **Control**: Original implementation
- **Treatment**: New implementation

---

## 📊 **Monitoring Configuration**

### **Metrics Collection**
- **Event Retention**: 30 days
- **Metrics Calculation**: Real-time
- **Export Frequency**: On-demand
- **Alert Frequency**: Real-time with cooldown

### **Time Ranges**
- **Last Hour**: `1 hour`
- **Last 24 Hours**: `24 hours`
- **Last 7 Days**: `7 days`
- **Last 30 Days**: `30 days`
- **Custom Range**: User-defined

---

## 🛡️ **Safety & Fallback Settings**

### **Fallback Behavior**
- **Coordinate Transformation Failure**: Falls back to 8km threshold
- **Feature Flag Disabled**: Uses original validation logic
- **Service Unavailable**: Graceful degradation

### **Error Handling**
- **Max Retry Attempts**: `3`
- **Retry Backoff**: Exponential (2.0x multiplier)
- **Timeout**: Default system timeouts
- **Logging**: Detailed error logging enabled

---

## 🔍 **Debug & Development Settings**

### **Logging Configuration**
- **Enable Detailed Logging**: `true`
- **Enable Progress Reporting**: `true`
- **Log Level**: Debug (development), Info (production)
- **Log Retention**: 7 days

### **Testing Configuration**
- **Test Data Path**: `TestResources/`
- **Mock Services**: Available in test environment
- **Performance Benchmarks**: Enabled
- **Concurrency Testing**: Thread Sanitizer enabled

### **Performance Testing Configuration**
- **Enable Performance Tests**: `ENABLE_PERF_TESTS=true` (environment variable)
- **Test Point Count**: `3000` points (reduced from 10,000 for stability)
- **Tolerance Settings**: `1e-12` absolute, `1e-10` relative
- **Performance Thresholds**: 
  - SIMD vs Scalar: `≤ 1.1x` (allowing measurement variance)
  - vDSP vs SIMD: `≤ 0.9x` (batch should be faster)
- **Test Coverage**: 6 property tests with 100,000+ validation points

---

## 📝 **Configuration Management**

### **How to Update Settings**
1. **Feature Flags**: Use `FeatureFlagService.updateConfig()`
2. **Validation Thresholds**: Modify `BridgeRecordValidator` constants
3. **Alert Settings**: Use `AlertConfigurationView` in UI
4. **Performance Settings**: Update `MLPipelineConfig` or `TrainingConfig`

### **Configuration Validation**
- **Feature Flags**: Validated on startup
- **Thresholds**: Range-checked during initialization
- **Paths**: Verified for accessibility
- **Dependencies**: Checked for availability

### **Backup & Recovery**
- **Configuration Backup**: Automatic via UserDefaults
- **Recovery**: Reset to defaults available
- **Version Control**: Configuration changes tracked in git
- **Rollback**: Feature flag rollback available

---

## 🎯 **Quick Reference**

### **Critical Settings**
- **Coordinate Transformation**: ✅ **ENABLED** (100% rollout)
- **Matrix Caching**: ✅ **ENABLED** (512 capacity)
- **SIMD Optimizations**: ✅ **ENABLED** (single-point)
- **vDSP Batch Processing**: ✅ **ENABLED** (chunked)
- **Tight Validation**: ✅ **500m threshold**
- **Fallback Validation**: ✅ **8km threshold**
- **Monitoring**: ✅ **ACTIVE**
- **Alerting**: ✅ **CONFIGURED**

### **Performance Targets**
- **Validation Time**: < 0.139ms per record
- **Success Rate**: > 95%
- **Error Rate**: < 1%
- **Distance Improvement**: > 100m average
- **SIMD Performance**: ≤ 1.1x scalar time (with variance)
- **vDSP Batch Performance**: ≤ 0.9x individual SIMD time
- **Mathematical Precision**: 1e-12 absolute tolerance

### **Safety Thresholds**
- **Min Success Rate**: 95%
- **Max Processing Time**: 100ms
- **Min Distance Improvement**: 100m
- **Alert Cooldown**: 5 minutes

---

**Note**: This configuration is production-ready and has been tested extensively. All settings are optimized for the current Phase 4 implementation with coordinate transformation system fully operational.

