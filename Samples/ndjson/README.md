# Golden NDJSON Samples

This directory contains the "golden" NDJSON samples used as baselines for module extraction parity testing. Each sample represents a different traffic pattern scenario to ensure comprehensive testing coverage.

## Sample Descriptions

### 1. Weekday Rush Hour (minutes_2025-08-12.ndjson)
**One-liner**: Tuesday, August 12, 2025 - Full weekday coverage with rush hour patterns, complete 24-hour data for 3 bridges, no gaps, 8,640 records, 1.9MB

**Characteristics**:
- **Date**: Tuesday, August 12, 2025 (weekday)
- **Coverage**: Full 24-hour period (07:00-06:59 UTC)
- **Bridges**: 3 bridges (IDs: 1, 2, 3)
- **Records**: 8,640 total (1,440 minutes × 3 bridges × 2 records per minute)
- **File Size**: 1.9MB
- **Data Quality**: 0 validation failures, 0 corrected rows
- **Traffic Pattern**: Normal weekday with morning (7-9 AM) and evening (4-6 PM) rush hours
- **Use Case**: Primary baseline for weekday traffic patterns and rush hour behavior

### 2. Weekend Pattern (weekend_sample_2025-08-09.ndjson)
**One-liner**: Sunday, August 9, 2025 - Weekend traffic patterns with reduced volume, 3 bridges, complete 24-hour coverage, 4,320 records, 1.0MB

**Characteristics**:
- **Date**: Sunday, August 9, 2025 (weekend)
- **Coverage**: Full 24-hour period (00:00-23:59 UTC)
- **Bridges**: 3 bridges (IDs: 1, 2, 3)
- **Records**: 4,320 total (1,440 minutes × 3 bridges)
- **File Size**: 1.0MB
- **Data Quality**: 0 validation failures, 0 corrected rows
- **Traffic Pattern**: Reduced weekend traffic (30-60% of weekday), spread out timing, lower rush hour intensity
- **Use Case**: Baseline for weekend vs weekday differences and reduced traffic scenarios

### 3. DST Boundary (dst_boundary_2024-11-03.ndjson)
**One-liner**: November 3, 2024 - Daylight Saving Time transition day with timezone handling, 3 bridges, complete 24-hour coverage, 4,320 records, 1.0MB

**Characteristics**:
- **Date**: Sunday, November 3, 2024 (DST end transition)
- **Coverage**: Full 24-hour period (00:00-23:59 UTC)
- **Bridges**: 3 bridges (IDs: 1, 2, 3)
- **Records**: 4,320 total (1,440 minutes × 3 bridges)
- **File Size**: 1.0MB
- **Data Quality**: 0 validation failures, 0 corrected rows
- **Traffic Pattern**: Normal weekday patterns with DST transition handling, timezone considerations
- **Use Case**: Baseline for timezone edge cases, DST transitions, and daylight saving time handling

## Data Schema

All samples follow the same NDJSON schema:

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

## File Structure

Each sample includes:
- **`.ndjson`**: Main data file with newline-delimited JSON records
- **`.metrics.json`**: Export statistics and validation metrics
- **`.done`**: Completion marker file

## Usage

These samples are used for:
1. **Baseline Testing**: Establishing performance benchmarks before module extraction
2. **Parity Verification**: Ensuring outputs remain consistent after refactoring
3. **Regression Detection**: Identifying performance or data quality issues
4. **Module Testing**: Comprehensive testing of individual pipeline components

## Collection Method

Samples were collected using:
- **Weekday**: Real data from Seattle Open Data API (August 12, 2025)
- **Weekend**: Generated sample with realistic weekend traffic patterns
- **DST Boundary**: Generated sample with DST transition considerations

## Validation

All samples pass the complete validation pipeline:
- Schema validation
- Business rule validation
- Data quality checks
- Completeness verification
- Bridge ID validation
- Timestamp validation

## Performance Characteristics

- **Weekday**: 8,640 records, 1.9MB, 3,302.6 records/second processing
- **Weekend**: 4,320 records, 1.0MB, realistic weekend patterns
- **DST Boundary**: 4,320 records, 1.0MB, timezone transition handling

## Next Steps

These samples provide the foundation for:
1. **Module Extraction**: Safe refactoring with known baselines
2. **Performance Monitoring**: Real-time tracking during extraction
3. **Parity Testing**: Automated comparison of before/after outputs
4. **Regression Prevention**: Immediate detection of performance issues
