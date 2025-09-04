import SwiftUI

struct StatValueRow: View {
    let label: String
    let mean: Double
    let stdDev: Double
    let range: (min: Double, max: Double)
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Mean \(Formatting.decimal3(mean))  •  σ \(Formatting.decimal3(stdDev))")
                .font(.subheadline)
                .foregroundStyle(color)
            Text("Range \(Formatting.decimal3(range.min)) – \(Formatting.decimal3(range.max))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}


