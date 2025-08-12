/// Feature vector for ML prediction with 14 standardized features for bridge lift prediction.
///
/// `LiftFeatures` represents a complete feature vector used by machine learning models
/// to predict whether a bridge will be lifting at a specific future horizon. The features
/// are designed to capture temporal patterns, traffic conditions, and bridge status
/// information in a format suitable for ML model training and inference.
///
/// ## Feature Overview
///
/// The 14 features are organized into logical groups:
/// - **Bridge & Time**: Bridge identifier and temporal encodings
/// - **Recent Patterns**: Bridge opening history and traffic flow
/// - **Routing Metrics**: Alternative route availability and penalties
/// - **Traffic Conditions**: Current traffic patterns and anomalies
///
/// ## Feature Schema
///
/// | # | Feature | Type | Range | Description |
/// |---|---------|------|-------|-------------|
/// | 0 | bridge_id | int | 0-6 | Stable bridge identifier |
/// | 1 | horizon_min | float | 0-20 | Minutes to arrival |
/// | 2 | minute_sin | float | -1 to 1 | sin(2π·minuteOfDay/1440) |
/// | 3 | minute_cos | float | -1 to 1 | cos(2π·minuteOfDay/1440) |
/// | 4 | dow_sin | float | -1 to 1 | sin(2π·(dow-1)/7) |
/// | 5 | dow_cos | float | -1 to 1 | cos(2π·(dow-1)/7) |
/// | 6 | recent_open_5m | float | 0-1 | Share open last 5 minutes |
/// | 7 | recent_open_30m | float | 0-1 | Share open last 30 minutes |
/// | 8 | detour_delta | float | -900 to 900 | Current vs 7-day median ETA |
/// | 9 | cross_rate_1m | float | 0-1 | k/n this minute (NaN→-1) |
/// | 10 | via_routable | float | 0/1 | Can route via bridge |
/// | 11 | via_penalty | float | 0-1 | Via route penalty (normalized) |
/// | 12 | gate_anom | float | 0-1 | Gate ETA anomaly (normalized) |
/// | 13 | detour_frac | float | 0-1 | Fraction avoiding bridge span |
///
/// ## Usage
///
/// ```swift
/// // Create features for a specific bridge and time
/// let features = LiftFeatures(
///     bridgeId: .fremont,
///     horizonMin: 5.0,
///     minuteSin: sin(2 * .pi * 480 / 1440),  // 8:00 AM
///     minuteCos: cos(2 * .pi * 480 / 1440),
///     dowSin: sin(2 * .pi * 1 / 7),          // Monday
///     dowCos: cos(2 * .pi * 1 / 7),
///     recentOpen5: 0.2,                       // 20% open last 5 min
///     recentOpen30: 0.15,                     // 15% open last 30 min
///     detourDelta: 120.0,                     // 2 min delay vs baseline
///     crossRate1m: 0.8,                       // 80% crossing rate
///     viaRoutable: 1.0,                       // Can use as via route
///     viaPenalty: 0.3,                        // 30% penalty
///     gateAnom: 0.5,                          // 50% anomaly
///     detourFrac: 0.1                         // 10% avoiding bridge
/// )
///
/// // Convert to ML-ready vector
/// let vector = features.packedVector()
/// // vector = [1.0, 5.0, 0.866, 0.5, 0.781, 0.623, 0.2, 0.15, 120.0, 0.8, 1.0, 0.3, 0.5, 0.1]
/// ```
///
/// ## ML Model Integration
///
/// When packing features for ML models that expect an integer bridge identifier,
/// convert `bridgeId` to its ordinal index in `BridgeID.allCases`:
///
/// ```swift
/// let bridgeIndex = BridgeID.allCases.firstIndex(of: features.bridgeId) ?? -1
/// // Use bridgeIndex as the integer bridge feature (0-based)
/// ```
///
/// This ensures the model receives a stable integer mapping corresponding to the
/// canonical bridge order, which is essential for model consistency.
///
/// ## Feature Engineering Notes
///
/// - **Cyclical Time Encoding**: Uses sin/cos for minute of day and day of week
///   to handle the cyclical nature of time patterns
/// - **Normalization**: Penalties and anomalies are normalized to [0,1] range
/// - **Missing Data**: Cross rate uses -1 for NaN values to distinguish from 0
/// - **Clipping**: Detour delta is clipped to ±900 seconds for stability
///
/// ## Target Variable
///
/// **Target**: `y = 1` if bridge is lifting at `t + horizon_min`, else `0`
///
/// The model predicts the probability of a bridge lift occurring at the specified
/// horizon, enabling proactive route planning and traffic management.
struct LiftFeatures {
    /// Bridge identifier (maps to BridgeID enum)
    /// 
    /// This field identifies which bridge the features represent. When converting
    /// to ML model input, this is mapped to a 0-based integer index for stability.
    let bridgeId: BridgeID
    
    /// Minutes from now until arrival at the bridge (0-20 minutes)
    /// 
    /// This is the prediction horizon - how far in the future we're predicting
    /// the bridge lift probability. Longer horizons enable earlier route planning.
    let horizonMin: Double
    
    /// Sine component of minute of day encoding (sin(2π·minuteOfDay/1440))
    /// 
    /// Part of cyclical time encoding that captures the 24-hour pattern of
    /// bridge operations. Combined with `minuteCos` for complete time representation.
    let minuteSin: Double
    
    /// Cosine component of minute of day encoding (cos(2π·minuteOfDay/1440))
    /// 
    /// Part of cyclical time encoding that captures the 24-hour pattern of
    /// bridge operations. Combined with `minuteSin` for complete time representation.
    let minuteCos: Double
    
    /// Sine component of day of week encoding (sin(2π·(dow-1)/7))
    /// 
    /// Part of cyclical time encoding that captures the weekly pattern of
    /// bridge operations. Monday=1, Sunday=7. Combined with `dowCos`.
    let dowSin: Double
    
    /// Cosine component of day of week encoding (cos(2π·(dow-1)/7))
    /// 
    /// Part of cyclical time encoding that captures the weekly pattern of
    /// bridge operations. Monday=1, Sunday=7. Combined with `dowSin`.
    let dowCos: Double
    
    /// Share of time bridge was open in the last 5 minutes (0-1)
    /// 
    /// Recent bridge opening pattern that indicates current operational status.
    /// Higher values suggest the bridge is currently active or recently active.
    let recentOpen5: Double
    
    /// Share of time bridge was open in the last 30 minutes (0-1)
    /// 
    /// Medium-term bridge opening pattern that provides context for recent
    /// operations. Useful for detecting sustained bridge activity.
    let recentOpen30: Double
    
    /// Current median across-span ETA minus 7-day median (seconds, clipped ±900)
    /// 
    /// Traffic delay indicator that compares current conditions to historical
    /// baseline. Positive values indicate delays, negative values indicate
    /// faster than usual travel times.
    let detourDelta: Double
    
    /// Vehicle crossing rate this minute (k/n, 0-1, NaN→-1)
    /// 
    /// Real-time traffic flow metric. Represents the fraction of vehicles
    /// that successfully crossed the bridge in the current minute. NaN values
    /// are converted to -1 to distinguish from 0% crossing rate.
    let crossRate1m: Double
    
    /// Whether the bridge can be used as a via route (0/1)
    /// 
    /// Binary flag indicating if the bridge is available for alternative
    /// routing. 1.0 means the bridge can be used, 0.0 means it cannot.
    let viaRoutable: Double
    
    /// Normalized penalty for using this bridge as a via route (0-1)
    /// 
    /// Penalty associated with routing via this bridge, normalized to [0,1]
    /// range. Higher values indicate greater penalties (longer travel times).
    let viaPenalty: Double
    
    /// Normalized gate ETA anomaly ratio (0-1)
    /// 
    /// Anomaly in gate ETA compared to historical baseline, normalized to [0,1].
    /// Higher values indicate more significant anomalies that might affect
    /// bridge operations or traffic flow.
    let gateAnom: Double
    
    /// Fraction of alternative routes that avoid this bridge span (0-1)
    /// 
    /// Traffic diversion metric that indicates how many alternative routes
    /// are available that bypass this bridge. Higher values suggest more
    /// traffic is being diverted around the bridge.
    let detourFrac: Double
}

extension LiftFeatures {
    /// Packs the feature vector as a flat array of Doubles for ML model input.
    ///
    /// This method converts the structured `LiftFeatures` into a flat array
    /// suitable for most machine learning frameworks. The bridge ID is mapped
    /// to an ordinal index (0-based) as required by ML models.
    ///
    /// ## Feature Order
    ///
    /// The returned array maintains the exact feature order specified in the
    /// feature schema, ensuring consistency with ML model expectations:
    ///
    /// ```swift
    /// [
    ///     bridgeIndex,      // 0: Bridge identifier (0-6)
    ///     horizonMin,       // 1: Prediction horizon (0-20 min)
    ///     minuteSin,        // 2: Minute of day (sin)
    ///     minuteCos,        // 3: Minute of day (cos)
    ///     dowSin,           // 4: Day of week (sin)
    ///     dowCos,           // 5: Day of week (cos)
    ///     recentOpen5,      // 6: Recent opening (5 min)
    ///     recentOpen30,     // 7: Recent opening (30 min)
    ///     detourDelta,      // 8: Traffic delay vs baseline
    ///     crossRate1m,      // 9: Current crossing rate
    ///     viaRoutable,      // 10: Via route availability
    ///     viaPenalty,       // 11: Via route penalty
    ///     gateAnom,         // 12: Gate ETA anomaly
    ///     detourFrac        // 13: Traffic diversion fraction
    /// ]
    /// ```
    ///
    /// ## Bridge ID Mapping
    ///
    /// The bridge ID is converted to a stable integer index:
    ///
    /// ```swift
    /// let bridgeIndex = Double(BridgeID.allCases.firstIndex(of: bridgeId) ?? -1)
    /// ```
    ///
    /// This ensures consistent integer mapping across different runs and
    /// model training sessions.
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let features = LiftFeatures(...)
    /// let vector = features.packedVector()
    ///
    /// // Use with ML model
    /// let prediction = model.predict(vector)
    /// ```
    ///
    /// - Returns: Array of 14 Double values representing the feature vector
    func packedVector() -> [Double] {
        let bridgeIndex = Double(BridgeID.allCases.firstIndex(of: bridgeId) ?? -1)
        return [
            bridgeIndex,
            horizonMin,
            minuteSin,
            minuteCos,
            dowSin,
            dowCos,
            recentOpen5,
            recentOpen30,
            detourDelta,
            crossRate1m,
            viaRoutable,
            viaPenalty,
            gateAnom,
            detourFrac
        ]
    }
}
