# ML Training Data Pipeline

A comprehensive guide to generating machine learning training data from the Bridget app's bridge monitoring system.

## Overview

The ML Training Data Pipeline automatically converts Bridget's historical bridge monitoring data into machine learning training datasets. It generates the exact file structure needed for ML model training:

- **Input**: Historical BridgeEvent data from Seattle Open Data API
- **Output**: ML-ready training datasets with 14 standardized features
- **Format**: CSV files with train/validation splits for multiple prediction horizons

The pipeline consists of three main components that work together:

1. **ProbeTick Data Population** - Converts existing BridgeEvent data to per-minute ProbeTick records
2. **Daily NDJSON Export** - Exports ProbeTick data in NDJSON format for ML processing  
3. **Python Feature Engineering** - Processes exported data into ML-ready training datasets

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

## Detailed Feature Schema

The pipeline generates features according to the `LiftFeatures` schema:

| # | Feature | Type | Range | Description |
|---|---------|------|-------|-------------|
| 0 | bridge_id | int | 0-6 | Stable bridge identifier |
| 1 | horizon_min | float | 0-20 | Minutes to arrival |
| 2 | minute_sin | float | -1 to 1 | sin(2π·minuteOfDay/1440) |
| 3 | minute_cos | float | -1 to 1 | cos(2π·minuteOfDay/1440) |
| 4 | dow_sin | float | -1 to 1 | sin(2π·(dow-1)/7) |

## Related Documentation

- **[Data Processing Pipeline](DataProcessingPipeline.md)** - Core data transformation and processing
- **[Baseline Metrics](Articles/BaselineMetrics.md)** - Performance metrics and safety net
- **[Dependency Recursion Workflow](Articles/DependencyRecursionWorkflow.md)** - Module extraction workflow
- **[Testing Workflow](TestingWorkflow.md)** - Testing strategies and workflows

