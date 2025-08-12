# ML Training Data Pipeline Overview

A high-level overview of Bridget's machine learning training data pipeline for bridge lift prediction.

## What It Does

The ML Training Data Pipeline automatically converts Bridget's historical bridge monitoring data into machine learning training datasets. It generates the exact file structure needed for ML model training:

- **Input**: Historical BridgeEvent data from Seattle Open Data API
- **Output**: ML-ready training datasets with 14 standardized features
- **Format**: CSV files with train/validation splits for multiple prediction horizons

## Key Components

### 1. Data Population (`ProbeTickDataService`)
- Converts BridgeEvent data to per-minute ProbeTick snapshots
- Computes ML features in real-time during data processing
- Handles historical data conversion and ongoing data collection

### 2. Daily Export (`BridgeDataExporter`)
- Exports daily NDJSON files with one row per minute per bridge
- Generates validation metrics and completion markers
- Implements atomic file operations for data integrity

### 3. Feature Engineering (`train_prep.py`)
- Processes NDJSON exports into ML-ready datasets
- Creates cyclical time encodings (minute of day, day of week)
- Generates train/validation splits with time-based partitioning

## Quick Start

```bash
# 1. Export today's data
swift Scripts/run_exporter.swift --output-dir ~/ml_data

# 2. Process with Python
python Scripts/train_prep.py \
  --input ~/ml_data/minutes_2025-01-27.ndjson \
  --output training_data.csv \
  --horizons 0,3,6,9,12
```

## Feature Schema

The pipeline generates exactly 14 features in stable order:

| # | Feature | Description |
|---|---------|-------------|
| 0 | bridge_id | Stable bridge identifier (0-6) |
| 1 | horizon_min | Minutes to arrival (0-20) |
| 2-3 | minute_sin/cos | Cyclical time encoding |
| 4-5 | dow_sin/cos | Day of week encoding |
| 6-7 | recent_open_5m/30m | Recent bridge opening patterns |
| 8 | detour_delta | Current vs historical ETA |
| 9 | cross_rate_1m | Vehicle crossing rate |
| 10-11 | via_routable/penalty | Alternative route metrics |
| 12 | gate_anom | Gate ETA anomaly |
| 13 | detour_frac | Fraction avoiding bridge |

**Target**: `y = 1` if bridge is lifting at `t + horizon_min`, else `0`

## Output Files

### NDJSON Export
- `minutes_YYYY-MM-DD.ndjson` - Main data file
- `minutes_YYYY-MM-DD.metrics.json` - Export statistics  
- `.done` - Completion marker

### ML Training Datasets
- `training_data_horizon_X.csv` - Feature matrix per horizon
- `training_data_horizon_X_train.csv` - Training split (70%)
- `training_data_horizon_X_val.csv` - Validation split (30%)

## Integration

### In Your App
```swift
// Add to ModelContainer schema
let schema = Schema([
    BridgeEvent.self,
    ProbeTick.self,  // Add this
    // ... other models
])

// Use the pipeline
let service = ProbeTickDataService(context: context)
try await service.populateTodayProbeTicks()

let exporter = BridgeDataExporter(context: context)
try await exporter.exportDailyNDJSON(for: today, to: outputURL)
```

### Automated Workflows
```bash
# Daily export at 1 AM
0 1 * * * swift Scripts/run_exporter.swift --output-dir /path/to/ml_data

# Process at 2 AM  
0 2 * * * python Scripts/train_prep.py --input /path/to/ml_data/minutes_$(date +%Y-%m-%d).ndjson --output training_data.csv
```

## Testing

```bash
# Run the complete pipeline tests
xcodebuild -project Bridget.xcodeproj -scheme Bridget -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:BridgetTests/ProbeTickExportTests
```

## Architecture Principles

- **SwiftData**: Uses SwiftData instead of CoreData
- **Observation**: Uses Observation framework instead of Combine  
- **Native Frameworks**: Prioritizes Apple's native solutions
- **Privacy**: No external analytics, uses OSLog + MetricKit

## What's Next

After generating training data:

1. **Train ML Models**: Use the CSV files with your preferred ML framework
2. **Validate Performance**: Test on the validation split
3. **Integrate Models**: Deploy trained models back into Bridget
4. **Continuous Learning**: Set up automated retraining with new data

## Documentation

- **<doc:MLTrainingDataPipeline>** - Complete detailed documentation
- **<doc:DataFlow>** - Understanding Bridget's data architecture
- **<doc:TestingWorkflow>** - Testing strategies and workflows

## Support

For questions or issues:
1. Check the test suite for working examples
2. Review the inline documentation in source files
3. Check the troubleshooting section in the detailed docs

