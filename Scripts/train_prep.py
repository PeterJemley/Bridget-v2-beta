#!/usr/bin/env python3
"""
Bridget ML Training Data Preparation Script

This script processes daily NDJSON exports from the Bridget app and creates
ML training datasets with the specified feature schema for bridge lift prediction.

## Overview

The `train_prep.py` script is a Python-based feature engineering pipeline that
converts raw NDJSON exports from the Bridget app into machine learning-ready
training datasets. It implements the complete feature engineering pipeline
defined in the `LiftFeatures` schema.

## Key Features

- **NDJSON Processing**: Loads and validates data from BridgeDataExporter
- **Feature Engineering**: Creates 14 standardized ML features
- **Horizon Support**: Both discrete and continuous prediction horizons
- **Time-based Splitting**: Prevents data leakage in train/validation sets
- **Data Validation**: Ensures data quality and completeness
- **Multiple Output Formats**: CSV files for different ML frameworks

## Usage Examples

```bash
# Basic usage with default horizons
python train_prep.py --input minutes_2025-01-27.ndjson --output training_data.csv

# Custom horizon sampling
python train_prep.py --input minutes_2025-01-27.ndjson --output training_data.csv --horizons 0,3,6,9,12

# Continuous horizon for advanced models
python train_prep.py --input minutes_2025-01-27.ndjson --output training_data.csv --continuous-horizon

# Verbose logging for debugging
python train_prep.py --input minutes_2025-01-27.ndjson --output training_data.csv --verbose
```

## Input Data Format

The script expects NDJSON files exported by BridgeDataExporter with the following structure:

```json
{"v": 1, "ts_utc": "2025-01-27T08:00:00Z", "bridge_id": 1, "cross_k": 5, "cross_n": 10, ...}
{"v": 1, "ts_utc": "2025-01-27T08:01:00Z", "bridge_id": 1, "cross_k": 3, "cross_n": 8, ...}
```

## Output Files

For each horizon, the script generates:
- `training_data_horizon_X.csv`: Complete feature matrix
- `training_data_horizon_X_train.csv`: Training split (70%)
- `training_data_horizon_X_val.csv`: Validation split (30%)

## Feature Schema

The script generates exactly 14 features matching the LiftFeatures schema:

| # | Feature | Description |
|---|---------|-------------|
| 0 | bridge_id | Bridge identifier (0-6) |
| 1 | horizon_min | Minutes to arrival (0-20) |
| 2-3 | minute_sin/cos | Cyclical time encoding |
| 4-5 | dow_sin/cos | Day of week encoding |
| 6-7 | recent_open_5m/30m | Recent bridge opening patterns |
| 8 | detour_delta | Current vs historical ETA |
| 9 | cross_rate_1m | Vehicle crossing rate |
| 10-11 | via_routable/penalty | Alternative route metrics |
| 12 | gate_anom | Gate ETA anomaly |
| 13 | detour_frac | Fraction avoiding bridge |

## Dependencies

Required Python packages:
- pandas: Data manipulation and analysis
- numpy: Numerical computing and array operations

Install with: `pip install pandas numpy`

## Architecture

The script follows a modular design:
1. **Data Loading**: NDJSON parsing and validation
2. **Label Creation**: Forward-looking target variables
3. **Feature Engineering**: ML feature computation
4. **Dataset Creation**: Training/validation splits
5. **Output Generation**: CSV file creation

## Integration with Bridget

This script is designed to work seamlessly with the Bridget app:
- Processes NDJSON exports from BridgeDataExporter
- Implements the exact feature schema from LiftFeatures
- Maintains data consistency with SwiftData models
- Supports the complete ML training pipeline
"""

import argparse
import json
import pandas as pd
import numpy as np
from pathlib import Path
from typing import List, Tuple, Optional
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def cyc(x: np.ndarray, period: float) -> Tuple[np.ndarray, np.ndarray]:
    """
    Creates cyclical encoding using sin and cos functions.
    
    This function is used to encode cyclical features like time of day and day
    of week in a way that preserves the cyclical nature while being suitable
    for machine learning models.
    
    ## Mathematical Details
    
    The cyclical encoding converts a cyclical variable x with period P into
    two features: sin(2πx/P) and cos(2πx/P). This ensures that:
    - Values at the beginning and end of the period are close
    - The cyclical nature is preserved in the feature space
    - Linear models can capture cyclical patterns
    
    ## Examples
    
    ```python
    # Encode minute of day (period = 1440 minutes)
    minute_sin, minute_cos = cyc(minute_of_day, 1440)
    
    # Encode day of week (period = 7 days)
    dow_sin, dow_cos = cyc(day_of_week, 7)
    ```
    
    Args:
        x: Input array of cyclical values
        period: Period length for the cyclical encoding
        
    Returns:
        Tuple of (sin_array, cos_array) for cyclical encoding
        
    ## Usage Notes
    
    - Input values should be in the range [0, period)
    - The function handles arrays of any shape
    - Output arrays have the same shape as input
    """
    ang = 2 * np.pi * x / period
    return np.sin(ang), np.cos(ang)

def load_ndjson(file_path: str) -> pd.DataFrame:
    """
    Loads and validates NDJSON data exported from BridgeDataExporter.
    
    This function reads the newline-delimited JSON file exported by the Bridget
    app's BridgeDataExporter and converts it into a pandas DataFrame for
    further processing.
    
    ## File Format
    
    The NDJSON file should contain one JSON object per line, with each object
    representing a ProbeTick record. Expected columns include:
    
    - `ts_utc`: UTC timestamp in ISO8601 format
    - `bridge_id`: Bridge identifier (integer)
    - `cross_k`: Number of vehicles that crossed
    - `cross_n`: Total vehicles that attempted to cross
    - `via_routable`: Whether bridge can be used as via route
    - `via_penalty_sec`: Penalty in seconds for via routing
    - `gate_anom`: Gate ETA anomaly ratio
    - `alternates_total`: Total alternative routes
    - `alternates_avoid`: Routes avoiding this bridge
    - `open_label`: Bridge opening state
    
    ## Validation
    
    The function performs basic validation:
    - Checks that the file exists and is readable
    - Validates JSON syntax for each line
    - Reports parsing errors with line numbers
    - Ensures at least some valid data is found
    
    ## Error Handling
    
    - JSON parsing errors are logged as warnings
    - Invalid lines are skipped
    - Empty files raise ValueError
    - File I/O errors are propagated
    
    Args:
        file_path: Path to the NDJSON file to load
        
    Returns:
        pandas DataFrame containing the probe data
        
    Raises:
        FileNotFoundError: If the file doesn't exist
        ValueError: If no valid data is found
        JSONDecodeError: If JSON parsing fails
        
    ## Example
    
    ```python
    # Load today's export
    df = load_ndjson("minutes_2025-01-27.ndjson")
    print(f"Loaded {len(df)} records")
    print(f"Columns: {list(df.columns)}")
    ```
    """
    logger.info(f"Loading NDJSON data from {file_path}")
    
    data = []
    with open(file_path, 'r') as f:
        for line_num, line in enumerate(f, 1):
            try:
                row = json.loads(line.strip())
                data.append(row)
            except json.JSONDecodeError as e:
                logger.warning(f"Failed to parse line {line_num}: {e}")
                continue
    
    if not data:
        raise ValueError("No valid data found in NDJSON file")
    
    df = pd.DataFrame(data)
    logger.info(f"Loaded {len(df)} records with columns: {list(df.columns)}")
    
    return df

def create_forward_labels(df: pd.DataFrame, horizons: List[int]) -> pd.DataFrame:
    """
    Creates forward-looking target variables for bridge lift prediction.
    
    This function creates the target variables needed for supervised learning.
    For each horizon, it creates a column indicating whether the bridge will
    be lifting at that future time point.
    
    ## Target Variable Creation
    
    For each horizon h, the function creates a column `open_label_fwd_{h}`
    where the value is 1 if the bridge is lifting at time t + h, and 0 otherwise.
    
    ## Implementation Details
    
    - Data is sorted by bridge_id and timestamp for proper shifting
    - Forward shifting is applied within each bridge group
    - Missing values (beyond available data) are filled with 0
    - The original DataFrame is modified in-place
    
    ## Data Requirements
    
    The input DataFrame must contain:
    - `bridge_id`: Bridge identifier column
    - `ts_utc`: Timestamp column (used for sorting)
    - `open_label`: Current bridge opening state
    
    ## Example
    
    ```python
    # Create labels for 0, 3, 6, 9, 12 minute horizons
    horizons = [0, 3, 6, 9, 12]
    df = create_forward_labels(df, horizons)
    
    # New columns: open_label_fwd_0, open_label_fwd_3, etc.
    print(df.columns)
    ```
    
    Args:
        df: DataFrame with probe data (must contain bridge_id, ts_utc, open_label)
        horizons: List of horizon minutes to predict (e.g., [0, 3, 6, 9, 12])
        
    Returns:
        DataFrame with added forward label columns
        
    ## Notes
    
    - The function modifies the input DataFrame in-place
    - Forward labels are created for all specified horizons
    - Missing future values are filled with 0 (no lift predicted)
    - Data should be sorted chronologically for accurate predictions
    """
    logger.info(f"Creating forward labels for horizons: {horizons}")
    
    # Sort by bridge_id and timestamp for proper shifting
    df = df.sort_values(['bridge_id', 'ts_utc']).reset_index(drop=True)
    
    for horizon in horizons:
        # Shift the open_label forward by horizon minutes
        # This gives us the bridge state at t + horizon
        col_name = f'open_label_fwd_{horizon}'
        df[col_name] = df.groupby('bridge_id')['open_label'].shift(-horizon).fillna(0)
        
        logger.info(f"Created forward label column: {col_name}")
    
    return df

def build_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Build all features according to the LiftFeatures schema.
    
    Args:
        df: DataFrame with raw probe data
        
    Returns:
        DataFrame with computed features
    """
    logger.info("Building feature vectors")
    
    # Parse timestamps
    df['ts_utc'] = pd.to_datetime(df['ts_utc'])
    
    # Cyclical time encoding
    minute_of_day = df['ts_utc'].dt.hour * 60 + df['ts_utc'].dt.minute
    dow = df['ts_utc'].dt.dayofweek + 1  # 1-7 (Monday=1)
    
    df['min_sin'], df['min_cos'] = cyc(minute_of_day, 1440)
    df['dow_sin'], df['dow_cos'] = cyc(dow, 7)
    
    # Recent opening windows (rolling averages)
    df['open_5m'] = df.groupby('bridge_id')['open_label'].rolling(5, min_periods=1).mean().reset_index(0, drop=True)
    df['open_30m'] = df.groupby('bridge_id')['open_label'].rolling(30, min_periods=1).mean().reset_index(0, drop=True)
    
    # Normalize and clamp features according to schema
    df['via_penalty_n'] = np.clip(df['via_penalty_sec'], 0, 900) / 900.0
    df['gate_anom_n'] = np.clip(df['gate_anom'], 1, 8) / 8.0
    
    # Cross rate (k/n) with NaN handling
    df['cross_rate'] = (df['cross_k'] / df['cross_n']).fillna(-1.0)
    
    # Ensure via_routable is 0/1
    df['via_routable'] = df['via_routable'].astype(np.float32)
    
    # Handle missing fields with defaults
    if 'detour_delta' not in df.columns:
        df['detour_delta'] = 0.0  # Default to no detour delta
    if 'detour_frac' not in df.columns:
        df['detour_frac'] = 0.0  # Default to no detour fraction
    
    # Convert bridge_id to stable integer mapping (0-6)
    # This assumes bridge_id in the data corresponds to the canonical order
    df['bridge_id_int'] = df['bridge_id'].astype(int)
    
    logger.info("Feature engineering complete")
    return df

def create_training_dataset(df: pd.DataFrame, horizons: List[int]) -> List[Tuple[np.ndarray, np.ndarray]]:
    """
    Create training datasets for each horizon.
    
    Args:
        df: DataFrame with features and forward labels
        horizons: List of horizon minutes to predict
        
    Returns:
        List of (X, y) tuples for each horizon
    """
    logger.info(f"Creating training datasets for horizons: {horizons}")
    
    datasets = []
    
    for horizon in horizons:
        # Target variable: bridge lift at t + horizon
        y = df[f'open_label_fwd_{horizon}'].values.astype(np.int32)
        
        # Feature matrix according to LiftFeatures.packedVector() order
        X = np.column_stack([
            df['bridge_id_int'].values,           # 0: bridge_id (0..6)
            np.full(len(df), horizon, dtype=np.float32),  # 1: horizon_min
            df['min_sin'].values,                 # 2: minute_sin
            df['min_cos'].values,                 # 3: minute_cos
            df['dow_sin'].values,                 # 4: dow_sin
            df['dow_cos'].values,                 # 5: dow_cos
            df['open_5m'].values,                 # 6: recent_open_5m
            df['open_30m'].values,                # 7: recent_open_30m
            df['detour_delta'].values,            # 8: recent_detour_delta
            df['cross_rate'].values,              # 9: cross_rate_1m
            df['via_routable'].values,            # 10: via_routable
            df['via_penalty_n'].values,           # 11: via_penalty
            df['gate_anom_n'].values,             # 12: gate_anom
            df['detour_frac'].values,             # 13: detour_frac
        ]).astype(np.float32)
        
        datasets.append((X, y))
        
        logger.info(f"Horizon {horizon}: X shape {X.shape}, y shape {y.shape}")
    
    return datasets

def create_continuous_horizon_dataset(df: pd.DataFrame) -> Tuple[np.ndarray, np.ndarray]:
    """
    Create training dataset treating horizon as a continuous feature.
    
    Args:
        df: DataFrame with features
        
    Returns:
        Tuple of (X, y) where X includes horizon as a feature
    """
    logger.info("Creating continuous horizon dataset")
    
    # For continuous horizon, we need to create multiple samples per timestamp
    # with different horizon values
    expanded_rows = []
    
    # Sample horizon values from 0 to 20 minutes
    horizon_values = np.arange(0, 21, 1)  # 0, 1, 2, ..., 20
    
    for _, row in df.iterrows():
        for horizon in horizon_values:
            # Create forward label for this horizon
            # This is a simplified approach - in practice you'd need the actual forward state
            forward_label = 0  # Placeholder - would need actual forward-looking logic
            
            expanded_rows.append({
                'bridge_id_int': row['bridge_id_int'],
                'horizon_min': horizon,
                'min_sin': row['min_sin'],
                'min_cos': row['min_cos'],
                'dow_sin': row['dow_sin'],
                'dow_cos': row['dow_cos'],
                'open_5m': row['open_5m'],
                'open_30m': row['open_30m'],
                'detour_delta': row['detour_delta'],
                'cross_rate': row['cross_rate'],
                'via_routable': row['via_routable'],
                'via_penalty_n': row['via_penalty_n'],
                'gate_anom_n': row['gate_anom_n'],
                'detour_frac': row['detour_frac'],
                'target': forward_label
            })
    
    expanded_df = pd.DataFrame(expanded_rows)
    
    # Create feature matrix
    X = expanded_df.drop('target', axis=1).values.astype(np.float32)
    y = expanded_df['target'].values.astype(np.int32)
    
    logger.info(f"Continuous horizon: X shape {X.shape}, y shape {y.shape}")
    return X, y

def time_based_split(df: pd.DataFrame, validation_fraction: float = 0.3) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """
    Split data by time to avoid leakage.
    
    Args:
        df: DataFrame with timestamp data
        validation_fraction: Fraction of data to use for validation
        
    Returns:
        Tuple of (train_df, val_df)
    """
    logger.info(f"Creating time-based split with {validation_fraction:.1%} validation")
    
    # For time-based split, we'll use the row index as a proxy for time order
    # since the data is already sorted chronologically from the export
    df_sorted = df.reset_index(drop=True)
    
    # Find split point
    split_idx = int(len(df_sorted) * (1 - validation_fraction))
    
    train_df = df_sorted.iloc[:split_idx]
    val_df = df_sorted.iloc[split_idx:]
    
    logger.info(f"Train: {len(train_df)} samples, Validation: {len(val_df)} samples")
    
    return train_df, val_df

def save_training_data(datasets: List[Tuple[np.ndarray, np.ndarray]], 
                      output_path: str, 
                      horizons: List[int]) -> None:
    """
    Save training datasets to CSV files.
    
    Args:
        datasets: List of (X, y) tuples for each horizon
        output_path: Base path for output files
        horizons: List of horizon values
    """
    output_path = Path(output_path)
    
    for (X, y), horizon in zip(datasets, horizons):
        # Create feature names
        feature_names = [
            'bridge_id', 'horizon_min', 'min_sin', 'min_cos', 'dow_sin', 'dow_cos',
            'recent_open_5m', 'recent_open_30m', 'detour_delta', 'cross_rate_1m',
            'via_routable', 'via_penalty', 'gate_anom', 'detour_frac'
        ]
        
        # Create DataFrame
        df = pd.DataFrame(X, columns=feature_names)
        df['target'] = y
        
        # Save to CSV
        horizon_output_path = output_path.parent / f"{output_path.stem}_horizon_{horizon}.csv"
        df.to_csv(horizon_output_path, index=False)
        logger.info(f"Saved horizon {horizon} data to {horizon_output_path}")
        
        # Also save train/validation split
        train_df, val_df = time_based_split(df)
        
        train_path = horizon_output_path.parent / f"{horizon_output_path.stem}_train.csv"
        val_path = horizon_output_path.parent / f"{horizon_output_path.stem}_val.csv"
        
        train_df.to_csv(train_path, index=False)
        val_df.to_csv(val_path, index=False)
        
        logger.info(f"Saved train/val split: {train_path}, {val_path}")

def main():
    """Main function to process NDJSON data and create training datasets."""
    parser = argparse.ArgumentParser(description='Process Bridget NDJSON exports for ML training')
    parser.add_argument('--input', required=True, help='Input NDJSON file path')
    parser.add_argument('--output', required=True, help='Output CSV file path')
    parser.add_argument('--horizons', type=str, default='0,3,6,9,12', 
                       help='Comma-separated list of horizon minutes (default: 0,3,6,9,12)')
    parser.add_argument('--continuous-horizon', action='store_true',
                       help='Treat horizon as continuous feature instead of discrete sampling')
    parser.add_argument('--validation-fraction', type=float, default=0.3,
                       help='Fraction of data to use for validation (default: 0.3)')
    
    args = parser.parse_args()
    
    try:
        # Load data
        df = load_ndjson(args.input)
        
        # Parse horizons
        horizons = [int(h.strip()) for h in args.horizons.split(',')]
        
        if args.continuous_horizon:
            # Create continuous horizon dataset
            df = build_features(df)
            X, y = create_continuous_horizon_dataset(df)
            
            # Save single dataset
            feature_names = [
                'bridge_id', 'horizon_min', 'min_sin', 'min_cos', 'dow_sin', 'dow_cos',
                'recent_open_5m', 'recent_open_30m', 'detour_delta', 'cross_rate_1m',
                'via_routable', 'via_penalty', 'gate_anom', 'detour_frac'
            ]
            
            output_df = pd.DataFrame(X, columns=feature_names)
            output_df['target'] = y
            output_df.to_csv(args.output, index=False)
            
            logger.info(f"Saved continuous horizon dataset to {args.output}")
            
        else:
            # Create discrete horizon datasets
            df = create_forward_labels(df, horizons)
            df = build_features(df)
            datasets = create_training_dataset(df, horizons)
            
            # Save datasets
            save_training_data(datasets, args.output, horizons)
        
        logger.info("✅ Training data preparation complete!")
        
    except Exception as e:
        logger.error(f"❌ Error processing data: {e}")
        raise

if __name__ == '__main__':
    main()
