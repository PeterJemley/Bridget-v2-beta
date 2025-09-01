# Coordinate System Analysis

## Overview

This document contains the findings from **Phase 1.1: Coordinate System Identification** of the Coordinate Transformation Implementation Plan. It documents the coordinate systems used by different data sources and the systematic offset patterns discovered.

## Data Sources

### 1. Reference System: SeattleDrawbridges.bridgeLocations

**Source**: `Bridget/Models/SeattleDrawbridges.swift`
**Coordinate System**: WGS84 (World Geodetic System 1984)
**Precision**: 6 decimal places (~1 meter precision)
**Datum**: WGS84
**Projection**: Geographic (latitude/longitude)

**Bridge Coordinates:**
- **Ballard Bridge**: (47.6598, -122.3762)
- **Fremont Bridge**: (47.6475, -122.3497)
- **Montlake Bridge**: (47.6473, -122.3047)
- **University Bridge**: (47.6531, -122.3200)
- **First Avenue South Bridge**: (47.5980, -122.3320)
- **Lower Spokane Street Bridge**: (47.5800, -122.3500)
- **South Park Bridge**: (47.5293, -122.3141)

### 2. API System: Seattle Open Data API

**Source**: Seattle Open Data API (Bridge Opening Events)
**Coordinate System**: Unknown (requires official documentation)
**Precision**: 11 decimal places (excessive precision)
**Datum**: Unknown
**Projection**: Unknown

**Sample API Coordinates:**
- **Bridge 1**: (47.542213439941406, -122.33446502685547)
- **Bridge 6**: (47.57137680053711, -122.35354614257812)

## Systematic Offset Analysis

### Bridge 1 (First Avenue South Bridge)

| Metric | Value |
|--------|-------|
| Expected Lat | 47.5980° |
| API Lat | 47.542213439941406° |
| Lat Offset | -0.055786560058594° |
| Expected Lon | -122.3320° |
| API Lon | -122.33446502685547° |
| Lon Offset | -0.00246502685547° |
| Distance | 6,205 meters |
| Direction | Southwest |

### Bridge 6 (Lower Spokane Street Bridge)

| Metric | Value |
|--------|-------|
| Expected Lat | 47.5800° |
| API Lat | 47.57137680053711° |
| Lat Offset | -0.00862319946289° |
| Expected Lon | -122.3500° |
| API Lon | -122.35354614257812° |
| Lon Offset | -0.00354614257812° |
| Distance | 995 meters |
| Direction | Southwest |

## Offset Pattern Analysis

### Key Observations

1. **Consistent Direction**: Both bridges show southwest offset (negative latitude, negative longitude)
2. **Variable Magnitude**: 
   - Bridge 1: 6.2 km offset
   - Bridge 6: 1.0 km offset
3. **Non-Uniform Pattern**: The offset is not consistent across bridges, suggesting either:
   - Different coordinate systems for different bridges
   - Local coordinate system variations
   - Data entry errors in the API

### Statistical Analysis

**Bridge 1 Offset:**
- Latitude: -0.0558° ≈ -3.35 arc-minutes
- Longitude: -0.0025° ≈ -0.15 arc-minutes
- Ratio: ~22:1 (latitude offset much larger than longitude)

**Bridge 6 Offset:**
- Latitude: -0.0086° ≈ -0.52 arc-minutes  
- Longitude: -0.0035° ≈ -0.21 arc-minutes
- Ratio: ~2.5:1 (latitude offset larger than longitude)

## Coordinate System Hypotheses

### Hypothesis 1: NAD83 vs WGS84
- **Likelihood**: Medium
- **Explanation**: North American Datum 1983 vs World Geodetic System 1984
- **Expected Offset**: ~1-2 meters (too small for observed offsets)

### Hypothesis 2: Local Seattle Coordinate System
- **Likelihood**: High
- **Explanation**: Seattle may use a local coordinate system for city data
- **Expected Offset**: Variable, depending on local projection parameters

### Hypothesis 3: Data Entry Errors
- **Likelihood**: Medium
- **Explanation**: Manual coordinate entry with systematic errors
- **Expected Offset**: Inconsistent patterns (matches observations)

### Hypothesis 4: Different Precision Standards
- **Likelihood**: Low
- **Explanation**: Different precision requirements for different data sources
- **Expected Offset**: Should be consistent (doesn't match observations)

## Transformation Matrix Calculation

### Current Approach
Using observed point pairs to calculate transformation coefficients:

**Bridge 1 Transformation:**
```
ΔLat = -0.0558°
ΔLon = -0.0025°
```

**Bridge 6 Transformation:**
```
ΔLat = -0.0086°
ΔLon = -0.0035°
```

### Issues with Current Approach
1. **Inconsistent Offsets**: Different bridges have different offset patterns
2. **Limited Sample Size**: Only 2 bridges with clear offset patterns
3. **Unknown Coordinate System**: Cannot assume linear transformation without knowing source system

## Recommendations

### Immediate Actions
1. **Contact Seattle Open Data API**: Request official coordinate system documentation
2. **Expand Sample Size**: Analyze coordinates for all 7 bridges
3. **Validate Reference Coordinates**: Verify our canonical coordinates are correct

### Next Steps
1. **Phase 1.2**: Data Source Investigation
2. **Phase 1.3**: Transformation Matrix Calculation (after system identification)
3. **Phase 2**: Implementation of proper coordinate transformation

## Validation Results

### Current Thresholds
- **Hard Threshold**: 8,000 meters (8 km)
- **Soft Threshold**: 500 meters (0.5 km)
- **Bridge 1**: 6,205m (within hard threshold, accepted)
- **Bridge 6**: 995m (within hard threshold, accepted)

### Impact
- **Data Quality**: Accepting coordinates with 1-6 km offsets
- **User Experience**: May affect route accuracy
- **System Reliability**: Current thresholds prevent data loss but reduce precision

## Conclusion

The systematic offset analysis reveals significant coordinate system differences between our reference data and the Seattle Open Data API. The inconsistent offset patterns suggest either:

1. **Multiple coordinate systems** used by the API
2. **Local coordinate system** with variable parameters
3. **Data quality issues** in the API

**Next Priority**: Obtain official coordinate system documentation from Seattle Open Data API to determine the correct transformation approach.

---

*This analysis was conducted as part of Phase 1.1 of the Coordinate Transformation Implementation Plan. For the complete plan, see [CoordinateTransformationPlan](doc:CoordinateTransformationPlan).*
