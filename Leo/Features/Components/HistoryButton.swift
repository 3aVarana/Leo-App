import SwiftUI

/// The entry into round history (H5), beside the gear on Welcome and Results. For `.six`, a text
/// button with the clock icon; every other age group gets the icon alone, like the gear.
struct HistoryButton: View {
    let ageGroup: AgeGroup
    let action: () -> Void

    @ScaledMetric(relativeTo: .title3) private var iconSize = 24
    @ScaledMetric(relativeTo: .subheadline) private var textButtonIconSize = 20

    var body: some View {
        if ageGroup == .six {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: textButtonIconSize))
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)
                        .fixedSize()
                    Text("Past rounds")
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.leo(.ghost))
            // Shares the header with the wordmark and the gear: stops growing past this size so
            // the row keeps fitting, like `ProgressDots`.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        } else {
            Button(action: action) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: iconSize))
                    .symbolRenderingMode(.hierarchical)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Past rounds"))
        }
    }
}

#Preview {
    HStack(spacing: 4) {
        HistoryButton(ageGroup: .six, action: {})
        HistoryButton(ageGroup: .nine, action: {})
    }
    .padding(24)
    .leoScreenBackground()
}
