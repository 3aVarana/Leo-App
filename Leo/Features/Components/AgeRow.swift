import SwiftUI

/// An age group in onboarding: its label, a description, and a check or an empty ring.
struct AgeRow: View {
    let label: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var checkSize = 28
    @ScaledMetric(relativeTo: .title2) private var ringSize = 24

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .leoTextStyle(.ageLabel)
                        .foregroundStyle(isSelected ? Color.leoAccent700 : Color.leoInk)
                    Text(description)
                        .leoTextStyle(.caption)
                        .foregroundStyle(Color.leoInkMuted)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: checkSize))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.leoAccent)
                } else {
                    Circle()
                        .strokeBorder(Color.leoNeutral600, lineWidth: 1.5)
                        .frame(width: ringSize, height: ringSize)
                        .padding(.horizontal, (checkSize - ringSize) / 2)
                }
            }
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(spacing: 2) {
        AgeRow(label: "6 to 8", description: "Short stories · 50–80 words", isSelected: false) {}
        AgeRow(label: "9 to 11", description: "Everyday words · 80–120 words", isSelected: true) {}
    }
    .padding(24)
    .leoScreenBackground()
}
