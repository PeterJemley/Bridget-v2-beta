//
//  MetricCard.swift
//  Bridget
//
//  Shared UI Component
//  --------------------
//  Purpose:
//  - A small, reusable metric summary tile used across analytics and dashboard screens.
//
//  Additions:
//  - Optional icon (SF Symbol)
//  - Optional subtitle and accessory text
//  - Optional tap action (automatically wraps in Button with PlainButtonStyle)
//  - Light styling knobs and accessibility improvements
//
//  Backwards compatibility:
//  - Existing call sites using (title:value:color:) continue to work unchanged.
//

import SwiftUI

struct MetricCard: View {
  let title: String
  let value: String
  let color: Color

  // Optional enhancements (all defaulted to preserve old API)
  var iconSystemName: String? = nil
  var iconColor: Color? = nil
  var subtitle: String? = nil
  var accessoryText: String? = nil
  var background: Color = .init(.secondarySystemBackground)
  var cornerRadius: CGFloat = 10
  var action: (() -> Void)? = nil
  var provideHapticOnTap: Bool = false

  var body: some View {
    Group {
      if let action {
        Button(action: {
          if provideHapticOnTap {
            #if canImport(UIKit)
              UIImpactFeedbackGenerator(style: .light)
                .impactOccurred()
            #endif
          }
          action()
        }) {
          content
        }
        .buttonStyle(.plain)
      } else {
        content
      }
    }
    // Accessibility
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(title))
    .accessibilityValue(Text(value))
    .accessibilityHint(Text(subtitle ?? ""))
    .accessibilityIdentifier("MetricCard")
  }

  private var content: some View {
    HStack(alignment: .center, spacing: 12) {
      if let iconSystemName {
        ZStack {
          Circle()
            .fill(color.opacity(0.12))
            .frame(width: 32, height: 32)
          Image(systemName: iconSystemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(iconColor ?? color)
        }
        .accessibilityHidden(true)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .accessibilityIdentifier("MetricCardTitle")

        Text(value)
          .font(.headline)
          .foregroundStyle(color)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .accessibilityIdentifier("MetricCardValue")

        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
      }

      Spacer(minLength: 8)

      if let accessoryText, !accessoryText.isEmpty {
        Text(accessoryText)
          .font(.caption2)
          .foregroundColor(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.gray.opacity(0.12))
          .clipShape(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
          )
          .accessibilityHidden(true)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(background)
    .clipShape(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    )
    .contentShape(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    )
  }
}

#Preview {
  VStack(spacing: 16) {
    // Backward-compatible usage (no icon, no action)
    MetricCard(title: "Total Duration", value: "73.6s", color: .blue)

    // With icon and subtitle
    MetricCard(title: "Success Rate",
               value: "97.5%",
               color: .green,
               iconSystemName: "checkmark.seal.fill",
               subtitle: "vs. last 24h +1.2%")

    // With accessory and tap action
    MetricCard(title: "Total Memory",
               value: "3,456 MB",
               color: .purple,
               iconSystemName: "memorychip",
               accessoryText: "P95",
               action: { print("Tapped memory card") },
               provideHapticOnTap: true)

    // Alternate background and corner radius
    MetricCard(title: "Error Count",
               value: "12",
               color: .red,
               iconSystemName: "exclamationmark.triangle.fill",
               background: Color(.tertiarySystemBackground),
               cornerRadius: 14)
  }
  .padding()
}
