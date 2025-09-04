import SwiftUI

struct StatMiniCard: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
        .accessibilityIdentifier("StatMiniCardLabel")
      Text(value)
        .font(.headline)
        .foregroundStyle(color)
        .accessibilityIdentifier("StatMiniCardValue")
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemBackground))
    .cornerRadius(10)
    .accessibilityIdentifier("StatMiniCard")
  }
}
