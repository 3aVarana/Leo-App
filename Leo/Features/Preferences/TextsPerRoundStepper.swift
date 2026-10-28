import SwiftUI

/// The number of texts in a round, shared by onboarding and settings. The caller puts its own heading above.
struct TextsPerRoundStepper: View {
    @Binding var count: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // The text would be squeezed beside the buttons, so they go below it.
                VStack(alignment: .leading, spacing: 8) {
                    label
                        .accessibilityHidden(true)
                    stepper { EmptyView() }
                        .labelsHidden()
                        .fixedSize()
                }
            } else {
                stepper { label }
            }
        }
        .tint(Color.leoAccent)
    }

    /// VoiceOver reads the title, the number as the value and the caption as the hint from the stepper itself,
    /// not from the visual label, which would repeat the number.
    private func stepper(@ViewBuilder label: () -> some View) -> some View {
        Stepper(value: $count, in: RoundSettings.exerciseCountRange, label: label)
            .accessibilityLabel(Text("Texts per round"))
            .accessibilityValue(Text(count, format: .number))
            .accessibilityHint(Text("How many short texts each round has, with a question after each."))
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Texts per round")
                    .leoTextStyle(LeoTextStyle(size: 17, weight: .semibold, relativeTo: .headline))
                Text(count, format: .number)
                    .leoTextStyle(LeoTextStyle(size: 17, weight: .semibold, relativeTo: .headline))
                    .monospacedDigit()
                    .foregroundStyle(Color.leoAccent)
            }
            Text("How many short texts each round has, with a question after each.")
                .leoTextStyle(.caption)
                .foregroundStyle(Color.leoInkMuted)
        }
    }
}

#Preview {
    @Previewable @State var count = RoundSettings.defaultExerciseCount
    TextsPerRoundStepper(count: $count)
        .padding(24)
        .leoScreenBackground()
}
