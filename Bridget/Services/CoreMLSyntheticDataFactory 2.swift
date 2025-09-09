import Foundation

#if DEBUG
  public enum CoreMLSyntheticDataFactory {
    /// Generates deterministic synthetic feature vectors for testing
    /// - Parameter count: Number of samples to generate
    /// - Returns: Array of FeatureVector
    public static func generate(count: Int) -> [FeatureVector] {
      var features: [FeatureVector] = []
      features.reserveCapacity(count)

      for i in 0 ..< count {
        let feature = FeatureVector(bridge_id: i % 5 + 1,
                                    horizon_min: (i % 4) * 3,
                                    min_sin: sin(Double(i) * 0.1),
                                    min_cos: cos(Double(i) * 0.1),
                                    dow_sin: sin(Double(i % 7) * 0.5),
                                    dow_cos: cos(Double(i % 7) * 0.5),
                                    open_5m: Double(i % 10) / 10.0,
                                    open_30m: Double(i % 8) / 8.0,
                                    detour_delta: Double(i % 60) - 30.0,
                                    cross_rate: Double(i % 10) / 10.0,
                                    via_routable: i % 2 == 0 ? 1.0 : 0.0,
                                    via_penalty: Double(i % 120),
                                    gate_anom: Double(i % 5) * 0.5,
                                    detour_frac: Double(i % 10) / 10.0,
                                    current_speed: 30.0 + Double(i % 20),
                                    normal_speed: 35.0,
                                    target: i % 2)
        features.append(feature)
      }

      return features
    }
  }
#endif
