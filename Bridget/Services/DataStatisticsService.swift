//
//  DataStatisticsService.swift
//  Bridget
//
//  ## Purpose
//  Comprehensive statistics and summary utilities for bridge data analysis.
//  Provides artifacts for counts by bridge & minute, first/last timestamps,
//  and horizon completeness details beyond just error messages.
//
//  ## Dependencies
//  Foundation framework, MLTypes
//
//  ## Integration Points
//  Used by validation services and ML pipeline for data quality analysis
//  Provides artifacts for reporting and debugging data completeness
//
//  ## Key Features
//  - Bridge & minute count statistics
//  - First/last timestamp analysis
//  - Horizon completeness details
//  - Data quality metrics and artifacts
//

import Foundation

// MARK: - Statistics Models

/// Comprehensive statistics for bridge data analysis
public struct BridgeDataStatistics: Codable, Sendable {
    public let summary: DataSummary
    public let bridgeStats: [Int: BridgeStatistics]
    public let timeStats: TimeStatistics
    public let horizonStats: HorizonStatistics
    public let qualityMetrics: DataQualityMetrics

    public init(
        summary: DataSummary,
        bridgeStats: [Int: BridgeStatistics],
        timeStats: TimeStatistics,
        horizonStats: HorizonStatistics,
        qualityMetrics: DataQualityMetrics
    ) {
        self.summary = summary
        self.bridgeStats = bridgeStats
        self.timeStats = timeStats
        self.horizonStats = horizonStats
        self.qualityMetrics = qualityMetrics
    }
}

/// Overall data summary
public struct DataSummary: Codable, Sendable {
    public let totalRecords: Int
    public let uniqueBridges: Int
    public let dateRange: DateRange
    public let completenessPercentage: Double

    public init(
        totalRecords: Int,
        uniqueBridges: Int,
        dateRange: DateRange,
        completenessPercentage: Double
    ) {
        self.totalRecords = totalRecords
        self.uniqueBridges = uniqueBridges
        self.dateRange = dateRange
        self.completenessPercentage = completenessPercentage
    }
}

/// Date range information
public struct DateRange: Codable, Sendable {
    public let firstTimestamp: Date
    public let lastTimestamp: Date
    public let duration: TimeInterval

    public init(firstTimestamp: Date, lastTimestamp: Date) {
        self.firstTimestamp = firstTimestamp
        self.lastTimestamp = lastTimestamp
        self.duration = lastTimestamp.timeIntervalSince(firstTimestamp)
    }
}

/// Bridge-specific statistics
public struct BridgeStatistics: Codable, Sendable {
    public let bridgeID: Int
    public let recordCount: Int
    public let firstTimestamp: Date
    public let lastTimestamp: Date
    public let countsByMinute: [String: Int]
    public let countsByHour: [Int: Int]
    public let countsByDayOfWeek: [Int: Int]
    public let completenessPercentage: Double

    public init(
        bridgeID: Int,
        recordCount: Int,
        firstTimestamp: Date,
        lastTimestamp: Date,
        countsByMinute: [String: Int],
        countsByHour: [Int: Int],
        countsByDayOfWeek: [Int: Int],
        completenessPercentage: Double
    ) {
        self.bridgeID = bridgeID
        self.recordCount = recordCount
        self.firstTimestamp = firstTimestamp
        self.lastTimestamp = lastTimestamp
        self.countsByMinute = countsByMinute
        self.countsByHour = countsByHour
        self.countsByDayOfWeek = countsByDayOfWeek
        self.completenessPercentage = completenessPercentage
    }
}

/// Time-based statistics
public struct TimeStatistics: Codable, Sendable {
    public let countsByMinute: [String: Int]
    public let countsByHour: [Int: Int]
    public let countsByDayOfWeek: [Int: Int]
    public let peakActivityTimes: [String: Int]
    public let lowActivityTimes: [String: Int]

    public init(
        countsByMinute: [String: Int],
        countsByHour: [Int: Int],
        countsByDayOfWeek: [Int: Int],
        peakActivityTimes: [String: Int],
        lowActivityTimes: [String: Int]
    ) {
        self.countsByMinute = countsByMinute
        self.countsByHour = countsByHour
        self.countsByDayOfWeek = countsByDayOfWeek
        self.peakActivityTimes = peakActivityTimes
        self.lowActivityTimes = lowActivityTimes
    }
}

/// Horizon coverage statistics
public struct HorizonStatistics: Codable, Sendable {
    public let availableHorizons: [Int]
    public let coverageByHorizon: [Int: Double]
    public let bridgeCoverageByHorizon: [Int: [Int: Double]]
    public let missingHorizonsByBridge: [Int: [Int]]
    public let horizonGaps: [Int: [Int]]
    public let overallCompleteness: Double

    public init(
        availableHorizons: [Int],
        coverageByHorizon: [Int: Double],
        bridgeCoverageByHorizon: [Int: [Int: Double]],
        missingHorizonsByBridge: [Int: [Int]],
        horizonGaps: [Int: [Int]],
        overallCompleteness: Double
    ) {
        self.availableHorizons = availableHorizons
        self.coverageByHorizon = coverageByHorizon
        self.bridgeCoverageByHorizon = bridgeCoverageByHorizon
        self.missingHorizonsByBridge = missingHorizonsByBridge
        self.horizonGaps = horizonGaps
        self.overallCompleteness = overallCompleteness
    }
}

/// Data quality metrics
public struct DataQualityMetrics: Codable, Sendable {
    public let dataCompleteness: Double
    public let timestampValidity: Double
    public let bridgeIDValidity: Double
    public let speedDataValidity: Double
    public let duplicateCount: Int
    public let missingFieldsCount: Int
    public let nanCounts: [String: Int]
    public let infiniteCounts: [String: Int]
    public let outlierCounts: [String: Int]
    public let rangeViolations: [String: Int]
    public let nullCounts: [String: Int]

    public init(
        dataCompleteness: Double,
        timestampValidity: Double,
        bridgeIDValidity: Double,
        speedDataValidity: Double,
        duplicateCount: Int,
        missingFieldsCount: Int,
        nanCounts: [String: Int] = [:],
        infiniteCounts: [String: Int] = [:],
        outlierCounts: [String: Int] = [:],
        rangeViolations: [String: Int] = [:],
        nullCounts: [String: Int] = [:]
    ) {
        self.dataCompleteness = dataCompleteness
        self.timestampValidity = timestampValidity
        self.bridgeIDValidity = bridgeIDValidity
        self.speedDataValidity = speedDataValidity
        self.duplicateCount = duplicateCount
        self.missingFieldsCount = missingFieldsCount
        self.nanCounts = nanCounts
        self.infiniteCounts = infiniteCounts
        self.outlierCounts = outlierCounts
        self.rangeViolations = rangeViolations
        self.nullCounts = nullCounts
    }
}

// MARK: - Data Statistics Service

public class DataStatisticsService {
    public init() {}

    public func generateStatistics(from ticks: [ProbeTickRaw])
        -> BridgeDataStatistics
    {
        let summary = generateSummary(from: ticks)
        let bridgeStats = generateBridgeStatistics(from: ticks)
        let timeStats = generateTimeStatistics(from: ticks)
        let horizonStats = generateHorizonStatistics(from: ticks)
        let qualityMetrics = generateQualityMetrics(from: ticks)

        return BridgeDataStatistics(
            summary: summary,
            bridgeStats: bridgeStats,
            timeStats: timeStats,
            horizonStats: horizonStats,
            qualityMetrics: qualityMetrics
        )
    }

    public func generateStatistics(from features: [FeatureVector])
        -> BridgeDataStatistics
    {
        let summary = generateSummary(from: features)
        let bridgeStats = generateBridgeStatistics(from: features)
        let timeStats = generateTimeStatistics(from: features)
        let horizonStats = generateHorizonStatistics(from: features)
        let qualityMetrics = generateQualityMetrics(from: features)

        return BridgeDataStatistics(
            summary: summary,
            bridgeStats: bridgeStats,
            timeStats: timeStats,
            horizonStats: horizonStats,
            qualityMetrics: qualityMetrics
        )
    }

    // MARK: - Helpers for ProbeTickRaw

    private func generateSummary(from ticks: [ProbeTickRaw]) -> DataSummary {
        let total = ticks.count
        let uniqueBridges = Set(ticks.map { $0.bridge_id }).count
        let iso = ISO8601DateFormatter()

        let dates = ticks.compactMap { iso.date(from: $0.ts_utc) }
        let first = dates.min() ?? Date()
        let last = dates.max() ?? first

        // Simple completeness: fraction of ticks with a parsable timestamp
        let completeness = total > 0 ? Double(dates.count) / Double(total) : 0.0

        return DataSummary(
            totalRecords: total,
            uniqueBridges: uniqueBridges,
            dateRange: DateRange(
                firstTimestamp: first,
                lastTimestamp: last
            ),
            completenessPercentage: completeness
        )
    }

    private func generateBridgeStatistics(from ticks: [ProbeTickRaw])
        -> [Int: BridgeStatistics]
    {
        let iso = ISO8601DateFormatter()
        let calendar = Calendar(identifier: .iso8601)

        var result: [Int: BridgeStatistics] = [:]
        let groups = Dictionary(grouping: ticks, by: { $0.bridge_id })

        for (bridgeID, items) in groups {
            let parsed = items.compactMap { (item) -> (Date, ProbeTickRaw)? in
                guard let d = iso.date(from: item.ts_utc) else { return nil }
                return (d, item)
            }.sorted(by: { $0.0 < $1.0 })

            let recordCount = items.count
            let first = parsed.first?.0 ?? Date()
            let last = parsed.last?.0 ?? first

            var countsByMinute: [String: Int] = [:]
            var countsByHour: [Int: Int] = [:]
            var countsByDOW: [Int: Int] = [:]

            for (date, _) in parsed {
                let hour = calendar.component(.hour, from: date)
                let minute = calendar.component(.minute, from: date)
                let key = String(format: "%02d:%02d", hour, minute)
                countsByMinute[key, default: 0] += 1
                countsByHour[hour, default: 0] += 1
                let dow = calendar.component(.weekday, from: date)  // 1...7
                countsByDOW[dow, default: 0] += 1
            }

            // Rudimentary "completeness": share of rows with parsed timestamp
            let completeness =
                recordCount > 0
                ? Double(parsed.count) / Double(recordCount) : 0.0

            result[bridgeID] = BridgeStatistics(
                bridgeID: bridgeID,
                recordCount: recordCount,
                firstTimestamp: first,
                lastTimestamp: last,
                countsByMinute: countsByMinute,
                countsByHour: countsByHour,
                countsByDayOfWeek: countsByDOW,
                completenessPercentage: completeness
            )
        }

        return result
    }

    private func generateTimeStatistics(from ticks: [ProbeTickRaw])
        -> TimeStatistics
    {
        let iso = ISO8601DateFormatter()
        let calendar = Calendar(identifier: .iso8601)

        var countsByMinute: [String: Int] = [:]
        var countsByHour: [Int: Int] = [:]
        var countsByDOW: [Int: Int] = [:]

        for t in ticks {
            guard let d = iso.date(from: t.ts_utc) else { continue }
            let hour = calendar.component(.hour, from: d)
            let minute = calendar.component(.minute, from: d)
            let key = String(format: "%02d:%02d", hour, minute)
            countsByMinute[key, default: 0] += 1
            countsByHour[hour, default: 0] += 1
            let dow = calendar.component(.weekday, from: d)
            countsByDOW[dow, default: 0] += 1
        }

        func topN(_ dict: [String: Int], n: Int) -> [String: Int] {
            return Dictionary(
                uniqueKeysWithValues:
                    dict
                    .sorted { $0.value > $1.value }
                    .prefix(n)
                    .map { ($0.key, $0.value) }
            )
        }
        func bottomN(_ dict: [String: Int], n: Int) -> [String: Int] {
            return Dictionary(
                uniqueKeysWithValues:
                    dict
                    .sorted { $0.value < $1.value }
                    .prefix(n)
                    .map { ($0.key, $0.value) }
            )
        }

        let peaks = topN(countsByMinute, n: 5)
        let lows = bottomN(countsByMinute, n: 5)

        return TimeStatistics(
            countsByMinute: countsByMinute,
            countsByHour: countsByHour,
            countsByDayOfWeek: countsByDOW,
            peakActivityTimes: peaks,
            lowActivityTimes: lows
        )
    }

    private func generateHorizonStatistics(from _: [ProbeTickRaw])
        -> HorizonStatistics
    {
        // ProbeTickRaw does not encode horizons directly; use defaults with zero coverage
        let available = defaultHorizons
        let coverageByH: [Int: Double] = Dictionary(
            uniqueKeysWithValues:
                available.map { ($0, 0.0) }
        )
        let bridgeCoverage: [Int: [Int: Double]] = [:]
        let missingByBridge: [Int: [Int]] = [:]
        let gaps: [Int: [Int]] = [:]
        let overall = 0.0

        return HorizonStatistics(
            availableHorizons: available,
            coverageByHorizon: coverageByH,
            bridgeCoverageByHorizon: bridgeCoverage,
            missingHorizonsByBridge: missingByBridge,
            horizonGaps: gaps,
            overallCompleteness: overall
        )
    }

    private func generateQualityMetrics(from ticks: [ProbeTickRaw])
        -> DataQualityMetrics
    {
        let total = ticks.count
        let iso = ISO8601DateFormatter()

        // Timestamp validity
        let validTS = ticks.filter { iso.date(from: $0.ts_utc) != nil }.count
        let timestampValidity =
            total > 0 ? Double(validTS) / Double(total) : 0.0

        // Bridge ID validity (positive integers)
        let validBridge = ticks.filter { $0.bridge_id > 0 }.count
        let bridgeIDValidity =
            total > 0 ? Double(validBridge) / Double(total) : 0.0

        // Speed validity (if present, within [0, 120] mph)
        var speedPresent = 0
        var speedValid = 0
        var rangeViolations: [String: Int] = [:]
        for t in ticks {
            if let s = t.current_traffic_speed {
                speedPresent += 1
                if s >= 0, s <= 120 { speedValid += 1 }
                if s < 0 || s > 120 {
                    rangeViolations["current_traffic_speed", default: 0] += 1
                }
            }
            if let s = t.normal_traffic_speed {
                speedPresent += 1
                if s >= 0, s <= 120 { speedValid += 1 }
                if s < 0 || s > 120 {
                    rangeViolations["normal_traffic_speed", default: 0] += 1
                }
            }
        }
        let speedDataValidity =
            speedPresent > 0 ? Double(speedValid) / Double(speedPresent) : 1.0

        // Duplicates by (bridge_id, ts_utc)
        var seen: Set<String> = []
        var duplicateCount = 0
        for t in ticks {
            let key = "\(t.bridge_id)|\(t.ts_utc)"
            if seen.contains(key) {
                duplicateCount += 1
            } else {
                seen.insert(key)
            }
        }

        // Missing fields (simple count of critical optionals that are nil)
        var missingFieldsCount = 0
        var nullCounts: [String: Int] = [:]
        for t in ticks {
            if t.gate_anom == nil {
                missingFieldsCount += 1
                nullCounts["gate_anom", default: 0] += 1
            }
            if t.detour_delta == nil {
                missingFieldsCount += 1
                nullCounts["detour_delta", default: 0] += 1
            }
            if t.cross_k == nil {
                missingFieldsCount += 1
                nullCounts["cross_k", default: 0] += 1
            }
            if t.cross_n == nil {
                missingFieldsCount += 1
                nullCounts["cross_n", default: 0] += 1
            }
            if t.via_routable == nil {
                missingFieldsCount += 1
                nullCounts["via_routable", default: 0] += 1
            }
            if t.via_penalty_sec == nil {
                missingFieldsCount += 1
                nullCounts["via_penalty_sec", default: 0] += 1
            }
            if t.alternates_total == nil {
                missingFieldsCount += 1
                nullCounts["alternates_total", default: 0] += 1
            }
            if t.alternates_avoid == nil {
                missingFieldsCount += 1
                nullCounts["alternates_avoid", default: 0] += 1
            }
            if t.detour_frac == nil {
                missingFieldsCount += 1
                nullCounts["detour_frac", default: 0] += 1
            }
            if t.current_traffic_speed == nil {
                nullCounts["current_traffic_speed", default: 0] += 1
            }
            if t.normal_traffic_speed == nil {
                nullCounts["normal_traffic_speed", default: 0] += 1
            }
        }

        // NaN / Infinite / Outliers
        var nanCounts: [String: Int] = [:]
        var infCounts: [String: Int] = [:]
        var outlierCounts: [String: Int] = [:]

        func track(_ name: String, _ v: Double?) {
            guard let v = v else { return }
            if v.isNaN { nanCounts[name, default: 0] += 1 }
            if v.isInfinite { infCounts[name, default: 0] += 1 }
        }

        for t in ticks {
            track("cross_k", t.cross_k)
            track("cross_n", t.cross_n)
            track("via_routable", t.via_routable)
            track("via_penalty_sec", t.via_penalty_sec)
            track("gate_anom", t.gate_anom)
            track("alternates_total", t.alternates_total)
            track("alternates_avoid", t.alternates_avoid)
            track("detour_delta", t.detour_delta)
            track("detour_frac", t.detour_frac)
            track("current_traffic_speed", t.current_traffic_speed)
            track("normal_traffic_speed", t.normal_traffic_speed)

            if let dd = t.detour_delta, abs(dd) > 1000 {
                outlierCounts["detour_delta", default: 0] += 1
            }
        }

        // Data completeness as share of non-missing critical fields among records
        let dataCompleteness: Double = {
            if total == 0 { return 0.0 }
            // consider timestamp parse + non-nil gate_anom as simple proxy
            let ok = ticks.filter {
                iso.date(from: $0.ts_utc) != nil && $0.gate_anom != nil
            }.count
            return Double(ok) / Double(total)
        }()

        return DataQualityMetrics(
            dataCompleteness: dataCompleteness,
            timestampValidity: timestampValidity,
            bridgeIDValidity: bridgeIDValidity,
            speedDataValidity: speedDataValidity,
            duplicateCount: duplicateCount,
            missingFieldsCount: missingFieldsCount,
            nanCounts: nanCounts,
            infiniteCounts: infCounts,
            outlierCounts: outlierCounts,
            rangeViolations: rangeViolations,
            nullCounts: nullCounts
        )
    }

    // MARK: - Helpers for FeatureVector

    private func generateSummary(from features: [FeatureVector]) -> DataSummary
    {
        let total = features.count
        let uniqueBridges = Set(features.map { $0.bridge_id }).count
        // FeatureVector has no timestamps; use a degenerate date range
        let now = Date()
        let dateRange = DateRange(firstTimestamp: now, lastTimestamp: now)
        // Simple completeness: presence of all features (always true here)
        let completeness = total > 0 ? 1.0 : 0.0

        return DataSummary(
            totalRecords: total,
            uniqueBridges: uniqueBridges,
            dateRange: dateRange,
            completenessPercentage: completeness
        )
    }

    private func generateBridgeStatistics(from features: [FeatureVector])
        -> [Int: BridgeStatistics]
    {
        // Without timestamps in FeatureVector, synthesize minimal stats
        var result: [Int: BridgeStatistics] = [:]
        let groups = Dictionary(grouping: features, by: { $0.bridge_id })
        let now = Date()

        for (bridgeID, items) in groups {
            let recordCount = items.count
            let countsByMinute: [String: Int] = [:]
            let countsByHour: [Int: Int] = [:]
            let countsByDOW: [Int: Int] = [:]
            let completeness = 1.0

            result[bridgeID] = BridgeStatistics(
                bridgeID: bridgeID,
                recordCount: recordCount,
                firstTimestamp: now,
                lastTimestamp: now,
                countsByMinute: countsByMinute,
                countsByHour: countsByHour,
                countsByDayOfWeek: countsByDOW,
                completenessPercentage: completeness
            )
        }

        return result
    }

    private func generateTimeStatistics(from _: [FeatureVector])
        -> TimeStatistics
    {
        // No time information in FeatureVector; return empty distributions
        return TimeStatistics(
            countsByMinute: [:],
            countsByHour: [:],
            countsByDayOfWeek: [:],
            peakActivityTimes: [:],
            lowActivityTimes: [:]
        )
    }

    private func generateHorizonStatistics(from features: [FeatureVector])
        -> HorizonStatistics
    {
        let available = Array(Set(features.map { $0.horizon_min })).sorted()

        // Coverage by horizon: fraction of bridges that have at least one feature for that horizon
        let bridges = Set(features.map { $0.bridge_id })
        let totalBridges = bridges.count

        var coverageByH: [Int: Double] = [:]
        var bridgeCoverage: [Int: [Int: Double]] = [:]
        var missingByBridge: [Int: [Int]] = [:]
        var gapsByBridge: [Int: [Int]] = [:]

        let featuresByBridge = Dictionary(
            grouping: features,
            by: { $0.bridge_id }
        )

        for h in available {
            let bridgesWithH = Set(
                features.filter { $0.horizon_min == h }.map { $0.bridge_id }
            )
            let frac =
                totalBridges > 0
                ? Double(bridgesWithH.count) / Double(totalBridges) : 0.0
            coverageByH[h] = frac
        }

        for bridge in bridges {
            let hSet = Set(
                featuresByBridge[bridge, default: []].map { $0.horizon_min }
            )
            var perBridge: [Int: Double] = [:]
            for h in available {
                perBridge[h] = hSet.contains(h) ? 1.0 : 0.0
            }
            bridgeCoverage[bridge] = perBridge

            let missing = Set(available).subtracting(hSet).sorted()
            missingByBridge[bridge] = missing

            // Simple gap detection assuming step 3 between horizons
            let sortedH = hSet.sorted()
            var gaps: [Int] = []
            if sortedH.count > 1 {
                for i in 0..<(sortedH.count - 1) {
                    let a = sortedH[i]
                    let b = sortedH[i + 1]
                    var expected = a + 3
                    while expected < b {
                        gaps.append(expected)
                        expected += 3
                    }
                }
            }
            gapsByBridge[bridge] = gaps
        }

        // Overall completeness: average of per-bridge horizon coverage
        let perBridgeCoverage: [Double] = bridgeCoverage.values.map { dict in
            if dict.isEmpty { return 0.0 }
            let covered = dict.values.filter { $0 > 0.0 }.count
            return Double(covered) / Double(dict.count)
        }
        let overall =
            perBridgeCoverage.isEmpty
            ? 0.0
            : perBridgeCoverage.reduce(0, +) / Double(perBridgeCoverage.count)

        return HorizonStatistics(
            availableHorizons: available,
            coverageByHorizon: coverageByH,
            bridgeCoverageByHorizon: bridgeCoverage,
            missingHorizonsByBridge: missingByBridge,
            horizonGaps: gapsByBridge,
            overallCompleteness: overall
        )
    }

    private func generateQualityMetrics(from features: [FeatureVector])
        -> DataQualityMetrics
    {
        let total = features.count
        if total == 0 {
            return DataQualityMetrics(
                dataCompleteness: 0.0,
                timestampValidity: 0.0,
                bridgeIDValidity: 0.0,
                speedDataValidity: 0.0,
                duplicateCount: 0,
                missingFieldsCount: 0
            )
        }

        // Bridge validity
        let validBridge = features.filter { $0.bridge_id > 0 }.count
        let bridgeIDValidity = Double(validBridge) / Double(total)

        // Speed validity [0, 120] mph
        var speedPresent = 0
        var speedValid = 0
        var rangeViolations: [String: Int] = [:]

        for f in features {
            speedPresent += 2
            if f.current_speed >= 0, f.current_speed <= 120 {
                speedValid += 1
            } else {
                rangeViolations["current_speed", default: 0] += 1
            }
            if f.normal_speed >= 0, f.normal_speed <= 120 {
                speedValid += 1
            } else {
                rangeViolations["normal_speed", default: 0] += 1
            }
        }
        let speedDataValidity =
            speedPresent > 0 ? Double(speedValid) / Double(speedPresent) : 1.0

        // Duplicates by (bridge_id, horizon_min, min_sin/min_cos bucket)
        var seen: Set<String> = []
        var duplicateCount = 0
        for f in features {
            // coarse bucket on time features to avoid floating noise
            let key =
                "\(f.bridge_id)|\(f.horizon_min)|\(String(format: "%.3f", f.min_sin))|\(String(format: "%.3f", f.min_cos))"
            if seen.contains(key) {
                duplicateCount += 1
            } else {
                seen.insert(key)
            }
        }

        // Missing fields (FeatureVector is non-optional; treat NaN/Inf as missing)
        var missingFieldsCount = 0
        let nullCounts: [String: Int] = [:]
        var nanCounts: [String: Int] = [:]
        var infCounts: [String: Int] = [:]
        var outlierCounts: [String: Int] = [:]

        func check(_ name: String, _ v: Double) {
            if v.isNaN {
                nanCounts[name, default: 0] += 1
                missingFieldsCount += 1
            }
            if v.isInfinite {
                infCounts[name, default: 0] += 1
                missingFieldsCount += 1
            }
        }

        for f in features {
            check("min_sin", f.min_sin)
            check("min_cos", f.min_cos)
            check("dow_sin", f.dow_sin)
            check("dow_cos", f.dow_cos)
            check("open_5m", f.open_5m)
            check("open_30m", f.open_30m)
            check("detour_delta", f.detour_delta)
            check("cross_rate", f.cross_rate)
            check("via_routable", f.via_routable)
            check("via_penalty", f.via_penalty)
            check("gate_anom", f.gate_anom)
            check("detour_frac", f.detour_frac)
            check("current_speed", f.current_speed)
            check("normal_speed", f.normal_speed)

            if abs(f.detour_delta) > 1000 {
                outlierCounts["detour_delta", default: 0] += 1
            }
        }

        // No timestamps in FeatureVector; set timestampValidity to 1 for compatibility
        let timestampValidity = 1.0
        // Data completeness: assume 1 unless NaN/Inf flagged
        let dataCompleteness =
            missingFieldsCount == 0
            ? 1.0 : max(0.0, 1.0 - Double(missingFieldsCount) / Double(total))

        return DataQualityMetrics(
            dataCompleteness: dataCompleteness,
            timestampValidity: timestampValidity,
            bridgeIDValidity: bridgeIDValidity,
            speedDataValidity: speedDataValidity,
            duplicateCount: duplicateCount,
            missingFieldsCount: missingFieldsCount,
            nanCounts: nanCounts,
            infiniteCounts: infCounts,
            outlierCounts: outlierCounts,
            rangeViolations: rangeViolations,
            nullCounts: nullCounts
        )
    }
}

extension DataStatisticsService {
    // existing export methods unchanged
    /// Exports statistics to JSON format
    public func exportToJSON(_ statistics: BridgeDataStatistics) throws
        -> String
    {
        let encoder = JSONEncoder.bridgeEncoder(outputFormatting: [
            .prettyPrinted, .sortedKeys,
        ])

        let data = try encoder.encode(statistics)
        return String(data: data, encoding: .utf8) ?? ""
    }

    public func exportToCSV(_ statistics: BridgeDataStatistics) -> String {
        var csv =
            "Bridge ID,Record Count,First Timestamp,Last Timestamp,Completeness %\n"

        for (bridgeID, bridgeStat) in statistics.bridgeStats.sorted(by: {
            $0.key < $1.key
        }) {
            let row =
                "\(bridgeID),\(bridgeStat.recordCount),\(bridgeStat.firstTimestamp),\(bridgeStat.lastTimestamp),\(String(format: "%.2f", bridgeStat.completenessPercentage * 100))\n"
            csv += row
        }

        return csv
    }

    public func exportHorizonCoverageToCSV(_ statistics: BridgeDataStatistics)
        -> String
    {
        var csv = "Bridge ID"

        for horizon in statistics.horizonStats.availableHorizons {
            csv += ",Horizon \(horizon)min"
        }
        csv += "\n"

        for (bridgeID, _) in statistics.bridgeStats.sorted(by: {
            $0.key < $1.key
        }) {
            csv += "\(bridgeID)"

            for horizon in statistics.horizonStats.availableHorizons {
                let coverage =
                    statistics.horizonStats.bridgeCoverageByHorizon[bridgeID]?[
                        horizon
                    ] ?? 0.0
                csv += ",\(String(format: "%.2f", coverage * 100))"
            }
            csv += "\n"
        }

        return csv
    }
}
