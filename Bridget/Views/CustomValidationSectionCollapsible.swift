import SwiftUI

struct CustomValidationSectionCollapsible: View {
    let results: [String: Bool]
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(results.keys.sorted()), id: \.self) { name in
                    HStack {
                        Image(systemName: results[name] == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(results[name] == true ? .green : .red)
                        Text(name).font(.subheadline)
                        Spacer()
                        Text(results[name] == true ? "Passed" : "Failed")
                            .font(.caption)
                            .foregroundColor(results[name] == true ? .green : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(results[name] == true ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            )
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.top, 8)
        } label: {
            Text("Custom Validation Results").font(.headline)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}
