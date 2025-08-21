import SwiftUI

struct MyRoutesView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          // My Routes Overview
          VStack(alignment: .leading, spacing: 12) {
            Text("My Routes")
              .font(.title2)
              .bold()

            // Sample saved route cards
            SavedRouteCard(name: "Home to Work",
                           from: "Fremont",
                           to: "Downtown Seattle",
                           isFavorite: true,
                           lastUsed: "Today")

            SavedRouteCard(name: "Weekend Shopping",
                           from: "Ballard",
                           to: "University District",
                           isFavorite: false,
                           lastUsed: "Yesterday")

            SavedRouteCard(name: "Airport Run",
                           from: "Capitol Hill",
                           to: "Sea-Tac Airport",
                           isFavorite: true,
                           lastUsed: "3 days ago")
          }
          .padding()
        }
      }
      .navigationTitle("My Routes")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}

struct SavedRouteCard: View {
  let name: String
  let from: String
  let to: String
  let isFavorite: Bool
  let lastUsed: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(name)
          .font(.headline)
        Spacer()
        if isFavorite {
          Image(systemName: "heart.fill")
            .foregroundStyle(.red)
        }
      }

      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("From:")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(from)
            .font(.subheadline)
        }

        Spacer()

        Image(systemName: "arrow.right")
          .foregroundStyle(.secondary)

        Spacer()

        VStack(alignment: .trailing, spacing: 2) {
          Text("To:")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(to)
            .font(.subheadline)
        }
      }

      HStack {
        Text("Last used: \(lastUsed)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Use Route") {
          // Action to use this route
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
}

#Preview {
  MyRoutesView()
}

