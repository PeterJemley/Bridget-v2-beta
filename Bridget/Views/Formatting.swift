// Formatting.swift
import Foundation

enum Formatting {
    static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return f
    }()

    static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static let decimal1Formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 1
        return f
    }()

    static let decimal3Formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 3
        f.minimumFractionDigits = 3
        return f
    }()

    static let measurementFormatter: MeasurementFormatter = {
        let mf = MeasurementFormatter()
        mf.unitOptions = .providedUnit
        mf.unitStyle = .medium
        mf.numberFormatter = numberFormatter
        return mf
    }()

    // MARK: - Public helpers

    static func percent(_ value: Double) -> String {
        percentFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value * 100))%"
    }

    static func percentFromUnit(_ unitValue: Double) -> String {
        // 0.87 -> "87.0%"
        percentFormatter.string(from: NSNumber(value: unitValue)) ?? "\(Int(unitValue * 100))%"
    }

    static func seconds(_ seconds: Double, fractionDigits: Int = 1) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = fractionDigits
        nf.minimumFractionDigits = fractionDigits
        let number = nf.string(from: NSNumber(value: seconds)) ?? "\(seconds)"
        return "\(number)s"
    }

    static func memoryMB(_ megabytes: Int) -> String {
        // If you want localized info units, convert to bytes and format as InformationStorage.
        // For now, keep “MB” label consistent with existing UI.
        return "\(numberFormatter.string(from: NSNumber(value: megabytes)) ?? "\(megabytes)") MB"
    }

    static func integer(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func decimal1(_ value: Double) -> String {
        decimal1Formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    static func decimal3(_ value: Double) -> String {
        decimal3Formatter.string(from: NSNumber(value: value)) ?? String(format: "%.3f", value)
    }
}
