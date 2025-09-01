//
//  MetricCard.swift
//  Bridget
//
//  Shared UI Component
//  --------------------
//  Purpose:
//  - A small, reusable metric summary tile used across analytics and dashboard screens.
//
//  Usage:
//  - Display a title and a highlighted value with a color accent.
//  - Intended for quick KPIs like "Total Duration", "Success Rate", memory, counts, etc.
//
//  Ownership & Reuse:
//  - This is a shared component. Prefer using this from other views rather than re-creating similar tiles.
//  - If you need variations (icons, footers, tap actions), consider extending this component
//    or creating a sibling component in the same folder.
//
//  Style Guidance:
//  - Keep content short; this tile is designed for compact, glanceable information.
//  - For more complex layouts, use a custom component rather than overloading MetricCard.
//
//  Preview:
//  - See #Preview below for example usage.
//

import SwiftUI

struct MetricCard: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
      Text(value)
        .font(.headline)
        .foregroundStyle(color)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemBackground))
    .cornerRadius(10)
  }
}

#Preview {
  VStack(spacing: 16) {
    MetricCard(title: "Total Duration", value: "73.6s", color: .blue)
    MetricCard(title: "Total Memory", value: "3,456 MB", color: .purple)
    MetricCard(title: "Success Rate", value: "97.5%", color: .green)
  }
  .padding()
}
