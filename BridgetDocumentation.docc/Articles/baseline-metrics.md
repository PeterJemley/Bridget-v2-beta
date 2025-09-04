# Baseline Metrics & Safety Net

## Overview
This document records the current baseline behaviors, timings, and artifacts of the Bridget ML pipeline before beginning module extraction work. This serves as our safety net to ensure parity after each module extraction.

**⚠️ Critical Dependency/Recursion Requirement**: Everything following below uses these samples to confirm parity after each module extraction. If outputs change (shapes, counts, ranges), loop back to the module that just changed.

## Current Pipeline Architecture

### Core Components
- **BridgeDataService**: Historical API integration with caching
- **BridgeDataExporter**: NDJSON export with validation and deduplication
- **MLPipelineBackgroundManager**: Background task orchestration
- **ProbeTickDataService**: Data population and management
- **BridgeDataProcessor**: Data transformation and validation

### Data Flow
1. **Data Ingestion**: Seattle Open Data API → BridgeDataService
2. **Data Processing**: BridgeDataProcessor → ProbeTick models
3. **Data Export**: BridgeDataExporter → NDJSON files
4. **Background Tasks**: MLPipelineBackgroundManager orchestrates daily operations

## Baseline Performance Metrics

### Wall-Clock Times
*Baseline established on 2025-08-15*

- **Data Ingestion**: 0.505 seconds for 10-30 minutes of NDJSON
- **Data Processing**: 1.204 seconds for transformation pipeline
- **Data Export**: 0.801 seconds for NDJSON generation
- **Total Pipeline**: 2.616 seconds end-to-end

### Memory Usage
*To be populated during baseline testing*

- **Peak Memory**: TBD MB during pipeline execution
- **Memory Profile**: TBD MB baseline, TBD MB peak
- **Memory Efficiency**: TBD MB per 1000 records

### Pipeline Steps & Timings
*Baseline established on 2025-08-15*

1. **API Fetch**: 0.505 seconds (19.3%)
2. **JSON Decoding**: Included in API Fetch
3. **Data Validation**: 1.204 seconds (46.0%)
4. **Model Creation**: Included in Data Processing
5. **Deduplication**: Included in Data Processing
6. **NDJSON Export**: 0.801 seconds (30.6%)
7. **Metrics Generation**: 0.105 seconds (4.0%)

## Current Artifacts

### NDJSON Sample: minutes_2025-08-12.ndjson
- **Size**: 1.9MB
- **Records**: 8,640 total rows
- **Bridges**: 3 bridges (IDs: 1, 2, 3)
- **Time Range**: 2025-08-12T07:00:00Z to 2025-08-13T06:59:00Z
- **Coverage**: 1,440 minutes per bridge (full day)
- **Data Quality**: 0 corrected rows (all data valid)
- **Format**: Schema version 1, newline-delimited JSON

### Sample Data Structure
```json
{
  "v": 1,
  "ts_utc": "2025-08-12T07:00:00Z",
  "bridge_id": 1,
  "cross_k": 0,
  "cross_n": 1,
  "via_routable": 1,
  "via_penalty_sec": 0,
  "gate_anom": 1,
  "alternates_total": 3,
  "alternates_avoid_span": 0,
  "free_eta_sec": null,
  "via_eta_sec": null,
  "open_label": 0
}
```

### Metrics File: minutes_2025-08-12.metrics.json
- **Total Rows**: 8,640
- **Expected Minutes**: 1,440 per bridge
- **Missing Minutes**: 0 (complete coverage)
- **Validation**: 0 rows required correction

## Golden NDJSON Samples

### 1. Weekday Rush Hour (minutes_2025-08-12.ndjson)
- **Description**: Tuesday, August 12, 2025 - Full weekday coverage with rush hour patterns
- **Characteristics**: Complete 24-hour coverage, 3 bridges, no data gaps
- **Use Case**: Primary baseline for weekday traffic patterns

### 2. Weekend Pattern (weekend_sample_2025-08-09.ndjson)
- **Description**: Sunday, August 9, 2025 - Weekend traffic patterns with reduced volume
- **Characteristics**: Lower traffic volume (30-60% of weekday), different timing patterns, 3 bridges, complete 24-hour coverage
- **Use Case**: Baseline for weekend vs weekday differences
- **Records**: 4,320 total (1,440 minutes × 3 bridges)
- **File Size**: 1.0MB

### 3. DST Boundary (dst_boundary_2024-11-03.ndjson)
- **Description**: November 3, 2024 - Daylight Saving Time transition day with timezone handling
- **Characteristics**: Normal weekday traffic patterns, timezone transition handling, 3 bridges, complete 24-hour coverage
- **Use Case**: Baseline for timezone edge cases and DST transitions
- **Records**: 4,320 total (1,440 minutes × 3 bridges)
- **File Size**: 1.0MB

## Validation Rules

### Current Validation Applied
- **via_penalty_sec**: Clipped to [0, 900] seconds
- **gate_anom**: Clipped to [1, 8] ratio
- **cross_k**: Must be ≤ cross_n
- **ts_utc**: Must be within target day's UTC window
- **Data Quality**: Only exports records with isValid = true

### Deduplication Strategy
- **Key**: (bridgeId, floored minute of tsUtc)
- **Strategy**: Keep latest record per group
- **Sorting**: By timestamp ascending, then bridgeId ascending

## Performance Baselines

### Export Performance
- **Processing Rate**: 3,302.6 records/second (baseline)
- **File Size**: ~1.9MB per day
- **Compression**: None currently (gzip planned for future)

### Cache Performance
- **Hit Rate**: TBD% (cache-first strategy)
- **Miss Penalty**: TBD seconds for API fetch
- **Storage**: TBD MB per day of data

## Error Handling Baseline

### Current Error Categories
- **Network Errors**: API timeouts, connection failures
- **Data Validation**: Invalid records, missing fields
- **File System**: Permission issues, disk space
- **Memory**: Large dataset handling

### Recovery Mechanisms
- **Retry Logic**: Exponential backoff for network failures
- **Graceful Degradation**: Fallback to cached data
- **Error Reporting**: Comprehensive error context and logging

## Next Steps for Module Extraction

### Phase 1: Data Ingestion Module
- Extract BridgeDataService into standalone module
- Maintain identical API contract
- Verify identical output for baseline samples

### Phase 2: Processing Module  
- Extract BridgeDataProcessor into standalone module
- Maintain identical validation rules
- Verify identical ProbeTick output

### Phase 3: Export Module
- Extract BridgeDataExporter into standalone module
- Maintain identical NDJSON format
- Verify identical file outputs and metrics

## Parity Verification Checklist

After each module extraction, verify:
- [ ] Identical NDJSON output for baseline samples
- [ ] Identical metrics and validation counts
- [ ] Identical performance characteristics
- [ ] Identical error handling behavior
- [ ] Identical memory usage patterns

## Notes
- This baseline was established on 2025-08-15
- Pipeline version: 1.0 (baseline)
- All timings measured on macOS simulator
- Baseline samples stored in `Samples/ndjson/` directory
- Performance rating: Excellent (3,302.6 records/sec)

## 🔄 Dependency/Recursion Implementation

### Parity Validation Service
- **PipelineParityValidator**: Comprehensive validation service that detects changes in shapes, counts, and ranges
- **Automatic Loop-back**: Triggers return to problematic modules when parity fails
- **Module Impact Analysis**: Identifies which module likely caused the changes

### Validation Types
- **Shape Validation**: Output structure, schema consistency, field organization
- **Count Validation**: Record counts, bridge distribution, time patterns
- **Range Validation**: Data value ranges, statistical distributions
- **Performance Validation**: Timing, memory usage consistency

### Loop-back Workflow
1. **Extract Module** → Refactor while maintaining interface compatibility
2. **Validate Parity** → Run golden samples through updated pipeline
3. **Check Results** → Use PipelineParityValidator to detect changes
4. **Decision Point**:
   - ✅ **Parity Maintained** → Continue to next module
   - ❌ **Parity Failed** → Loop back to problematic module

### Golden Sample Coverage
- **Weekday Rush Hour**: Primary baseline for normal traffic patterns
- **Weekend Pattern**: Baseline for reduced traffic scenarios
- **DST Boundary**: Baseline for timezone edge cases

This comprehensive approach ensures that module extraction maintains output consistency and prevents regressions through automatic detection and loop-back mechanisms.
