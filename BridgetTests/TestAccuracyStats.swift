import Foundation
import Testing

// Shared thresholds for accuracy guard tests
public enum TestAccuracyThresholds {
    public static let medianEps: Double = 1e-12
    public static let p95Eps: Double = 1e-10
    public static let maxEps: Double = 1e-9

    // Enhanced thresholds
    public static let meanBiasEps: Double = 1e-13
    public static let stdEps: Double = 1e-11
    public static let p99Eps: Double = 1e-9
    public static let skewAbsLimit: Double = 2.0
    public static let exactMatchRateMin: Double = 0.95
}

// Shared dataset sizing defaults for accuracy tests
public enum TestAccuracyDatasetConfig {
    // ~400 total across two pairs when used with 2 pairs
    public static let countPerPair: Int = 200
    // Grid size for Gate G skeleton test
    public static let gridSize: Int = 12
}

// MARK: - Statistical Utilities
public enum TestAccuracyStats {
    // Deterministic percentile with linear interpolation
    public static func percentile(_ data: [Double], _ p: Double) -> Double {
        precondition(!data.isEmpty)
        let sorted = data.sorted()
        let clamped = max(0.0, min(100.0, p))
        let rank = clamped / 100.0 * Double(sorted.count - 1)
        let lower = Int(floor(rank))
        let upper = Int(ceil(rank))
        if lower == upper { return sorted[lower] }
        let weight = rank - Double(lower)
        return sorted[lower] * (1.0 - weight) + sorted[upper] * weight
    }

    public static func median(_ data: [Double]) -> Double {
        percentile(data, 50)
    }

    public static func mean(_ data: [Double]) -> Double {
        data.reduce(0, +) / Double(data.count)
    }

    public static func stddev(_ data: [Double]) -> Double {
        let m = mean(data)
        let variance =
            data.map {
                let d = $0 - m
                return d * d
            }.reduce(0, +) / Double(data.count)
        return sqrt(variance)
    }

    // Fisher-Pearson standardized moment coefficient
    public static func skewness(_ data: [Double]) -> Double {
        let n = Double(data.count)
        let m = mean(data)
        let sd = stddev(data)
        guard sd > 0, data.count > 2 else { return 0 }
        let m3 = data.map { pow($0 - m, 3) }.reduce(0, +) / n
        return m3 / pow(sd, 3)
    }
}

// MARK: - Dataset Generation
public struct AccuracyTestPoint {
    public let lat: Double
    public let lon: Double
    public let fromSystem: Any
    public let toSystem: Any
    public let bridgeId: String

    public init(
        lat: Double,
        lon: Double,
        fromSystem: Any,
        toSystem: Any,
        bridgeId: String
    ) {
        self.lat = lat
        self.lon = lon
        self.fromSystem = fromSystem
        self.toSystem = toSystem
        self.bridgeId = bridgeId
    }
}

public enum TestAccuracyDatasetFactory {
    // Generic generator; caller provides system pairs and point builder
    public static func generateGrid(
        countPerPair: Int = TestAccuracyDatasetConfig.countPerPair,
        centerLat: Double = 47.60,
        centerLon: Double = -122.33,
        halfSpanLat: Double = 0.05,
        halfSpanLon: Double = 0.05,
        bridgeIds: [String] = ["1", "6"],
        systemPairs: [(from: Any, to: Any)],
        makePoint: (
            _ lat: Double, _ lon: Double, _ from: Any, _ to: Any,
            _ bridgeId: String
        ) -> AccuracyTestPoint
    ) -> [AccuracyTestPoint] {
        var points: [AccuracyTestPoint] = []
        let gridSide = Int(ceil(sqrt(Double(countPerPair))))
        let totalPerPair = gridSide * gridSide

        for (fromSys, toSys) in systemPairs {
            for i in 0..<totalPerPair {
                let gx = i % gridSide
                let gy = i / gridSide

                let u = Double(gx) / Double(max(gridSide - 1, 1))
                let v = Double(gy) / Double(max(gridSide - 1, 1))

                var lat = centerLat - halfSpanLat + 2 * halfSpanLat * v
                var lon = centerLon - halfSpanLon + 2 * halfSpanLon * u

                // Small deterministic jitter to decorrelate grid
                let jitterLat =
                    (sin(Double(i) * 12.9898) * 43758.5453).truncatingRemainder(
                        dividingBy: 1.0
                    ) * 1e-6
                let jitterLon =
                    (cos(Double(i) * 78.233) * 12345.6789).truncatingRemainder(
                        dividingBy: 1.0
                    ) * 1e-6
                lat += jitterLat
                lon += jitterLon

                let bridgeId = bridgeIds[i % bridgeIds.count]
                points.append(makePoint(lat, lon, fromSys, toSys, bridgeId))
            }
        }

        let target = systemPairs.count * countPerPair
        return Array(points.prefix(target))
    }
}

#if canImport(Bridget)
    import Bridget
#endif

public enum TestAccuracyDatasetFactoryCS {
    public static func generateGrid(
        countPerPair: Int = TestAccuracyDatasetConfig.countPerPair,
        centerLat: Double = 47.60,
        centerLon: Double = -122.33,
        halfSpanLat: Double = 0.05,
        halfSpanLon: Double = 0.05,
        bridgeIds: [String] = ["1", "6"],
        systemPairs: [(from: CoordinateSystem, to: CoordinateSystem)]
    ) -> [AccuracyTestPoint] {
        return TestAccuracyDatasetFactory.generateGrid(
            countPerPair: countPerPair,
            centerLat: centerLat,
            centerLon: centerLon,
            halfSpanLat: halfSpanLat,
            halfSpanLon: halfSpanLon,
            bridgeIds: bridgeIds,
            systemPairs: systemPairs.map { (from: $0.from, to: $0.to) },
            makePoint: { lat, lon, fromAny, toAny, bridgeId in
                let from = fromAny as! CoordinateSystem
                let to = toAny as! CoordinateSystem
                return AccuracyTestPoint(
                    lat: lat,
                    lon: lon,
                    fromSystem: from,
                    toSystem: to,
                    bridgeId: bridgeId
                )
            }
        )
    }
}

// MARK: - Convenience Assertions
public enum TestAccuracyAsserts {
    public struct Residuals {
        public let latResiduals: [Double]
        public let lonResiduals: [Double]
        public let exactMatchRate: Double
    }

    public static func computeResidualStats(
        latResiduals: [Double],
        lonResiduals: [Double]
    ) -> (
        latMed: Double, latP95: Double, latMax: Double, lonMed: Double,
        lonP95: Double, lonMax: Double, latMean: Double, latStd: Double,
        latP99: Double, latSkew: Double, lonMean: Double, lonStd: Double,
        lonP99: Double, lonSkew: Double
    ) {
        let latMed = TestAccuracyStats.median(latResiduals)
        let latP95 = TestAccuracyStats.percentile(latResiduals, 95)
        let latMax = latResiduals.max() ?? 0
        let lonMed = TestAccuracyStats.median(lonResiduals)
        let lonP95 = TestAccuracyStats.percentile(lonResiduals, 95)
        let lonMax = lonResiduals.max() ?? 0
        let latMean = TestAccuracyStats.mean(latResiduals)
        let latStd = TestAccuracyStats.stddev(latResiduals)
        let latP99 = TestAccuracyStats.percentile(latResiduals, 99)
        let latSkew = TestAccuracyStats.skewness(latResiduals)
        let lonMean = TestAccuracyStats.mean(lonResiduals)
        let lonStd = TestAccuracyStats.stddev(lonResiduals)
        let lonP99 = TestAccuracyStats.percentile(lonResiduals, 99)
        let lonSkew = TestAccuracyStats.skewness(lonResiduals)
        return (
            latMed, latP95, latMax, lonMed, lonP95, lonMax, latMean, latStd,
            latP99, latSkew, lonMean, lonStd, lonP99, lonSkew
        )
    }

    // Asserts the full Step 6 bundle (basic + enhanced)
    public static func assertStep6Bundle(
        latResiduals: [Double],
        lonResiduals: [Double],
        exactMatchRate: Double
    ) {
        let stats = computeResidualStats(
            latResiduals: latResiduals,
            lonResiduals: lonResiduals
        )

        #expect(
            stats.latMed <= TestAccuracyThresholds.medianEps,
            "Lat median residual too high: \(stats.latMed)"
        )
        #expect(
            stats.latP95 <= TestAccuracyThresholds.p95Eps,
            "Lat P95 residual too high: \(stats.latP95)"
        )
        #expect(
            stats.latMax <= TestAccuracyThresholds.maxEps,
            "Lat max residual too high: \(stats.latMax)"
        )

        #expect(
            stats.lonMed <= TestAccuracyThresholds.medianEps,
            "Lon median residual too high: \(stats.lonMed)"
        )
        #expect(
            stats.lonP95 <= TestAccuracyThresholds.p95Eps,
            "Lon P95 residual too high: \(stats.lonP95)"
        )
        #expect(
            stats.lonMax <= TestAccuracyThresholds.maxEps,
            "Lon max residual too high: \(stats.lonMax)"
        )

        #expect(
            abs(stats.latMean) <= TestAccuracyThresholds.meanBiasEps,
            "Lat mean residual indicates bias: \(stats.latMean)"
        )
        #expect(
            stats.latStd <= TestAccuracyThresholds.stdEps,
            "Lat residual std too high: \(stats.latStd)"
        )
        #expect(
            stats.latP99 <= TestAccuracyThresholds.p99Eps,
            "Lat P99 residual too high: \(stats.latP99)"
        )
        #expect(
            abs(stats.latSkew) <= TestAccuracyThresholds.skewAbsLimit,
            "Lat residual distribution too skewed: \(stats.latSkew)"
        )

        #expect(
            abs(stats.lonMean) <= TestAccuracyThresholds.meanBiasEps,
            "Lon mean residual indicates bias: \(stats.lonMean)"
        )
        #expect(
            stats.lonStd <= TestAccuracyThresholds.stdEps,
            "Lon residual std too high: \(stats.lonStd)"
        )
        #expect(
            stats.lonP99 <= TestAccuracyThresholds.p99Eps,
            "Lon P99 residual too high: \(stats.lonP99)"
        )
        #expect(
            abs(stats.lonSkew) <= TestAccuracyThresholds.skewAbsLimit,
            "Lon residual distribution too skewed: \(stats.lonSkew)"
        )

        #expect(
            exactMatchRate >= TestAccuracyThresholds.exactMatchRateMin,
            "Exact match rate too low: \(exactMatchRate)"
        )
    }
}

public enum TestAccuracyDiagnostics {
    public static func logResidualStats(
        latResiduals: [Double],
        lonResiduals: [Double],
        label: String = "Residual Stats"
    ) {
        guard !latResiduals.isEmpty, !lonResiduals.isEmpty else {
            print("[TestAccuracyDiagnostics] \(label): No residuals to report")
            return
        }
        let stats = TestAccuracyAsserts.computeResidualStats(
            latResiduals: latResiduals,
            lonResiduals: lonResiduals
        )
        print("[TestAccuracyDiagnostics] \(label):")
        print(
            "  Lat  median=\(stats.latMed)  p95=\(stats.latP95)  p99=\(stats.latP99)  max=\(stats.latMax)  mean=\(stats.latMean)  std=\(stats.latStd)  skew=\(stats.latSkew)"
        )
        print(
            "  Lon  median=\(stats.lonMed)  p95=\(stats.lonP95)  p99=\(stats.lonP99)  max=\(stats.lonMax)  mean=\(stats.lonMean)  std=\(stats.lonStd)  skew=\(stats.lonSkew)"
        )
    }
}
