# ML Training Data Pipeline

A comprehensive guide to generating machine learning training data from the Bridget app's bridge monitoring system.

## Overview

The ML Training Data Pipeline consists of three main components that work together to convert existing bridge data into machine learning-ready training datasets:

1. **ProbeTick Data Population** - Converts existing BridgeEvent data to per-minute ProbeTick records
2. **Daily NDJSON Export** - Exports ProbeTick data in NDJSON format for ML processing  
3. **Python Feature Engineering** - Processes exported data into ML-ready training datasets

## Quick Start

### Run the Exporter for Today

```bash
# Run the Swift script to export today's data
swift Scripts/run_exporter.swift --output-dir ~/ml_data

# This will generate:
# - minutes_YYYY-MM-DD.ndjson (main data file)
# - minutes_YYYY-MM-DD.metrics.json (export statistics)
# - .done (completion marker)
```

### Process with Python

```bash
# Install required Python packages
pip install pandas numpy

# Process the exported data
python Scripts/train_prep.py \
  --input ~/ml_data/minutes_2025-01-27.ndjson \
  --output ~/ml_data/training_data.csv \
  --horizons 0,3,6,9,12
```

## Complete Workflow

### Step 1: Data Population

The `ProbeTickDataService` converts existing `BridgeEvent` data into `ProbeTick` records:

```swift
// In your app code
let service = ProbeTickDataService(context: modelContext)

// Populate today's data
try await service.populateTodayProbeTicks()

// Or populate a date range
try await service.populateHistoricalProbeTicks(
    from: startDate, 
    to: endDate
)
```

### Step 2: Daily Export

Use the `BridgeDataExporter` to export daily NDJSON files:

```swift
let exporter = BridgeDataExporter(context: modelContext)
let today = Calendar.current.startOfDay(for: Date())
let outputURL = URL(fileURLWithPath: "/path/to/output/minutes_2025-01-27.ndjson")

try await exporter.exportDailyNDJSON(for: today, to: outputURL)
```

### Step 3: Feature Engineering

The Python script processes the NDJSON data into ML-ready features:

```bash
# Discrete horizon sampling (recommended for initial models)
python Scripts/train_prep.py \
  --input minutes_2025-01-27.ndjson \
  --output training_data.csv \
  --horizons 0,3,6,9,12

# Continuous horizon (for advanced models)
python Scripts/train_prep.py \
  --input minutes_2025-01-27.ndjson \
  --output training_data.csv \
  --continuous-horizon
```

## Feature Schema

The pipeline generates features according to the `LiftFeatures` schema:

| # | Feature | Type | Range | Description |
|---|---------|------|-------|-------------|
| 0 | bridge_id | int | 0-6 | Stable bridge identifier |
| 1 | horizon_min | float | 0-20 | Minutes to arrival |
| 2 | minute_sin | float | -1 to 1 | sin(2π·minuteOfDay/1440) |
| 3 | minute_cos | float | -1 to 1 | cos(2π·minuteOfDay/1440) |
| 4 | dow_sin | float | -1 to 1 | sin(2π·(dow-1)/7) |
| 5 | dow_cos | float | -1 to 1 | cos(2π·(dow-1)/7) |
| 6 | recent_open_5m | float | 0-1 | Share open last 5 minutes |
| 7 | recent_open_30m | float | 0-1 | Share open last 30 minutes |
| 8 | detour_delta | float | -900 to 900 | Current vs 7-day median ETA |
| 9 | cross_rate_1m | float | 0-1 | k/n this minute (NaN→-1) |
| 10 | via_routable | float | 0/1 | Can route via bridge |
| 11 | via_penalty | float | 0-1 | Via route penalty (normalized) |
| 12 | gate_anom | float | 0-1 | Gate ETA anomaly (normalized) |
| 13 | detour_frac | float | 0-1 | Fraction avoiding bridge span |

**Target**: `y = 1` if bridge is lifting at `t + horizon_min`, else `0`

## Output Files

### NDJSON Export
- **minutes_YYYY-MM-DD.ndjson**: One JSON object per line with probe data
- **minutes_YYYY-MM-DD.metrics.json**: Export statistics and validation metrics
- **.done**: Zero-byte marker file indicating successful completion

### Python Processing
- **training_data_horizon_X.csv**: Feature matrix for each horizon
- **training_data_horizon_X_train.csv**: Training split (70%)
- **training_data_horizon_X_val.csv**: Validation split (30%)

## Data Validation

The pipeline includes comprehensive validation:

- **Feature Clamping**: Ensures values stay within expected ranges
- **Data Correction**: Counts and reports corrected values
- **Completeness**: Tracks missing minutes per bridge
- **Quality Metrics**: Reports export statistics and data quality

## Integration Points

### In Your App
```swift
// Add ProbeTick to your ModelContainer schema
let schema = Schema([
    BridgeEvent.self,
    ProbeTick.self,  // Add this line
    // ... other models
])

// Use ProbeTickDataService to populate data
let service = ProbeTickDataService(context: context)
try await service.populateTodayProbeTicks()

// Export daily data
let exporter = BridgeDataExporter(context: context)
try await exporter.exportDailyNDJSON(for: today, to: outputURL)
```

### Scheduled Execution
```bash
# Add to crontab for daily exports
0 1 * * * cd /path/to/bridget && swift Scripts/run_exporter.swift --output-dir /path/to/ml_data

# Process with Python
0 2 * * * python Scripts/train_prep.py --input /path/to/ml_data/minutes_$(date +%Y-%m-%d).ndjson --output /path/to/ml_data/training_data.csv
```

## Testing

Run the test suite to verify the pipeline:

```bash
# Run tests
xcodebuild -project Bridget.xcodeproj -scheme Bridget -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# Or run specific test
xcodebuild -project Bridget.xcodeproj -scheme Bridget -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:BridgetTests/ProbeTickExportTests
```

## Troubleshooting

### Common Issues

1. **Missing ProbeTick in Schema**: Ensure `ProbeTick.self` is added to your ModelContainer schema
2. **No Data Exported**: Check that `ProbeTickDataService` has populated data before export
3. **Python Import Errors**: Install required packages: `pip install pandas numpy`
4. **File Permissions**: Ensure output directories are writable

### Debug Mode

Enable debug logging in the Python script:

```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## Next Steps

After generating training data:

1. **Model Training**: Use the CSV files to train ML models
2. **Feature Engineering**: Extend the feature set based on model performance
3. **Real-time Integration**: Integrate trained models back into the app
4. **Continuous Learning**: Set up automated retraining with new data

## Architecture Notes

- **SwiftData**: Uses SwiftData for persistence instead of CoreData
- **Observation**: Uses Observation framework instead of Combine
- **Native Frameworks**: Prioritizes Apple's native frameworks
- **Privacy**: No external analytics services, uses OSLog + MetricKit

## Related Documentation

- <doc:DataFlow> - Understanding how data flows through the Bridget system
- <doc:TestingWorkflow> - Testing strategies and workflows
- <doc:Documentation> - Main project documentation and overview
