import SwiftUI

/// A saved round's score as dots: one per answer, filled for right, ringed for missed. Unlike
/// `ProgressDots`, these carry no numbers and no current position — just the shape of the result.
struct RoundResultDots: View {
    /// Whether each answer was right, in round order.
    let results: [Bool]

    @ScaledMetric(relativeTo: .footnote) private var diameter = 8

    var body: some View {
        DotRow(spacing: 4) {
            ForEach(results.indices, id: \.self) { index in
                dot(correct: results[index])
            }
        }
        // Capped like `ProgressDots`, so a row of six still fits across a phone.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        // The row and column already say the score; VoiceOver doesn't need the dots too.
        .accessibilityHidden(true)
    }

    private func dot(correct: Bool) -> some View {
        Circle()
            .fill(correct ? Color.leoInk : .clear)
            .overlay {
                if !correct {
                    Circle().strokeBorder(Color.leoMagenta, lineWidth: 1.5)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .frame(idealWidth: diameter, idealHeight: diameter)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        RoundResultDots(results: [true, true, true, true, true, true])
        RoundResultDots(results: [true, false, true, true, false, true])
        RoundResultDots(results: [false, false, false, false, false, false])
    }
    .padding(24)
    .leoScreenBackground()
}
