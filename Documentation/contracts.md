# Bridget ML Pipeline Contracts

## Overview

This document serves as the **single source of truth** for all data contracts, shapes, units, and policies used throughout the Bridget ML pipeline. Any changes to these contracts must be reflected throughout the entire pipeline.

## Data Shapes & Dimensions

### Feature Vector Structure

**Feature Count**: 14 features (increased from 12 to include speed fields)

**Feature Schema**:
| # | Feature | Type | Range | Description | Normalization |
|---|---------|------|-------|-------------|---------------|
| 0 | bridge_id | int | 0-6 | Stable bridge identifier | Ordinal mapping |
| 1 | horizon_min | int | 0-20 | Minutes to arrival | None |
| 2 | min_sin | float | -1 to 1 | sin(2π·minuteOfDay/1440) | Cyclical encoding |
| 3 | min_cos | float | -1 to 1 | cos(2π·minuteOfDay/1440) | Cyclical encoding |
| 4 | dow_sin | float | -1 to 1 | sin(2π·(dow-1)/7) | Cyclical encoding |
| 5 | dow_cos | float | -1 to 1 | cos(2π·(dow-1)/7) | Cyclical encoding |
| 6 | open_5m | float | 0-1 | Share open last 5 minutes | Rolling average |
| 7 | open_30m | float | 0-1 | Share open last 30 minutes | Rolling average |
| 8 | detour_delta | float | -900 to 900 | Current vs 7-day median ETA | Seconds |
| 9 | cross_rate | float | 0-1 or -1 | k/n this minute (NaN→-1) | k/n ratio |
| 10 | via_routable | float | 0/1 | Can route via bridge | Boolean |
| 11 | via_penalty | float | 0-1 | Via route penalty | Clipped [0,900]/900 |
| 12 | gate_anom | float | 0-1 | Gate ETA anomaly | Clipped [1,8]/8 |
| 13 | detour_frac | float | 0-1 | Fraction avoiding bridge span | None |
| 14 | current_speed | float | 0-100 | Current traffic speed | mph |
| 15 | normal_speed | float | 0-100 | Normal traffic speed | mph |

### ML Model Shapes

**Input Shape**: `[batch_size, 14]` where 14 = `featureDimension`
**Output Shape**: `[batch_size, 1]` where 1 = `targetDimension`

**Constants**:
- `featureDimension = 14`
- `targetDimension = 1`
- `defaultInputShape = [1, 14]`
- `defaultOutputShape = [1, 1]`

### Prediction Horizons

**Default Horizons**: `[0, 3, 6, 9, 12]` minutes
- 0: Immediate prediction
- 3: 3-minute ahead prediction
- 6: 6-minute ahead prediction
- 9: 9-minute ahead prediction
- 12: 12-minute ahead prediction

## Timezone Policy

### Primary Timezone: America/Los_Angeles (Pacific)

**Policy**: All local time calculations use Pacific timezone with automatic DST handling.

**Implementation**:
```swift
let pacific = TimeZone(identifier: "America/Los_Angeles")!
```

**DST Handling**: Automatic conversion between PST/PDT with proper UTC bounds calculation.

**Data Export**: NDJSON files contain UTC timestamps, but local day boundaries are calculated in Pacific time.

### Time Encoding

**Minute of Day**: Cyclical encoding using sin/cos with 1440-minute period
**Day of Week**: Cyclical encoding using sin/cos with 7-day period (Monday=1)

## Missing Data Policy

### Null Value Handling

**ProbeTickRaw Fields**:
- `cross_k`, `cross_n`: Default to 0 if null
- `via_routable`: Default to 0.0 if null
- `via_penalty_sec`: Default to 0.0 if null
- `gate_anom`: Default to 1.0 if null
- `alternates_total`: Default to 0.0 if null
- `alternates_avoid`: Default to 0.0 if null
- `detour_delta`: Default to 0.0 if null
- `detour_frac`: Default to 0.0 if null
- `current_traffic_speed`: Default to 0.0 if null
- `normal_traffic_speed`: Default to 35.0 if null

### NaN/Infinite Value Handling

**Cross Rate Calculation**: `k/n` where `n > 0`, otherwise `-1.0`
**Speed Fields**: Clipped to valid ranges, warnings for NaN/infinite values
**Validation**: All NaN/infinite values trigger validation errors

### Data Quality Thresholds

**High Null Rate Warning**: >50% null values in any field
**Missing Minutes**: Expected 1440 minutes per bridge per day
**Validation Failures**: Records with validation errors are excluded from export

## Normalization Rules

### Value Clipping

**via_penalty_sec**: Clipped to [0, 900] seconds, normalized to [0, 1]
**gate_anom**: Clipped to [1, 8] ratio, normalized to [0, 1]
**cross_k**: Must be ≤ cross_n, negative values set to 0
**alternates_avoid**: Must be ≤ alternates_total

### Speed Normalization

**Current Speed**: Range [0, 100] mph
**Normal Speed**: Range [0, 100] mph, default 35.0 mph
**Speed Ratio**: Current/Normal ratio clipped to [0.1, 3.0]

### Bridge ID Mapping

**Stable Ordinal Mapping**: Bridge IDs mapped to 0-based indices
```swift
let bridgeIndex = Double(BridgeID.allCases.firstIndex(of: bridgeId) ?? -1)
```

## Data Validation Rules

### Required Fields

**ProbeTickRaw**: All fields must be present in NDJSON
**FeatureVector**: All 14 features must be non-null
**Timestamps**: Must be valid ISO8601 format

### Business Rules

**Bridge ID**: Must be valid bridge identifier (1, 2, 3, 4, 6, 21, 29)
**Timestamp Monotonicity**: Timestamps must be monotonically increasing
**Data Completeness**: Expected 1440 minutes per bridge per day

### Quality Gates

**Data Quality Gate**: >95% valid records required
**Coverage Gate**: >90% expected minutes covered
**Speed Quality Gate**: <10% speed anomalies

## Protocol Contracts

### Progress Delegates

**CoreMLTrainingProgressDelegate**: @MainActor, Sendable
**FeatureEngineeringProgressDelegate**: Standard protocol
**EnhancedPipelineProgressDelegate**: @MainActor, Sendable

### Error Handling

**CoreMLTrainingError**: Shape mismatch, training failure, validation failure
**BridgeDataError**: JSON decoding, validation, processing errors
**DataValidationResult**: Comprehensive validation metrics

### Retry Policies

**Network Operations**: Exponential backoff, max 3 retries
**File Operations**: Linear backoff, max 2 retries
**Training Operations**: No automatic retry (manual intervention required)

## Integration Contracts

### File Formats

**NDJSON**: Newline-delimited JSON for data export
**CSV**: Comma-separated values for ML training
**JSON**: Configuration and metrics files

### API Contracts

**BridgeDataExporter**: Daily NDJSON export with metrics
**FeatureEngineeringService**: Pure, stateless, deterministic feature generation with comprehensive validation
**CoreMLTraining**: Model training with progress reporting

### Pipeline Stages

**Data Ingestion**: Raw data to ProbeTickRaw
**Feature Engineering**: ProbeTickRaw to FeatureVector (pure, stateless, validated)
**Training**: FeatureVector to MLModel
**Validation**: Model performance evaluation
**Export**: Model and metrics export

## Change Management

### Breaking Changes

Any changes to:
- Feature count or order
- Data shapes or dimensions
- Timezone policy
- Normalization rules

Must be coordinated across:
1. MLTypes.swift constants
2. FeatureEngineeringService
3. CoreMLTraining module
4. Python train_prep.py script
5. All unit tests
6. Documentation updates

### Versioning

**Schema Version**: Incremented for breaking changes
**Feature Version**: Incremented for feature additions
**Contract Version**: Incremented for protocol changes

## Testing Contracts

### Golden Samples

**Weekday Sample**: minutes_2025-08-12.ndjson (8,640 records)
**Weekend Sample**: weekend_sample_2025-08-09.ndjson (4,320 records)
**DST Boundary**: dst_boundary_2024-11-03.ndjson (4,320 records)

### Validation Baselines

**Data Quality**: 0 validation failures expected
**Performance**: 3,302.6 records/second processing rate
**Coverage**: 100% expected minutes covered
**File Size**: ~1.9MB per day (weekday), ~1.0MB per day (weekend)

### Parity Requirements

**Before/After Refactoring**: Identical outputs required
**Cross-Platform**: Swift and Python must produce identical results
**Regression Testing**: All golden samples must pass validation
