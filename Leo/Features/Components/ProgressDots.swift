import SwiftUI

/// The six numbered circles of a round.
struct ProgressDots: View {
    enum Size {
        /// 28 points, above Loading, Error and Exercise.
        case regular
        /// 36 points with Ink numbers, on Welcome.
        case large
    }

    let states: [DotState]
    /// Read by VoiceOver as "Text 2 of 6". `nil` hides the dots from VoiceOver.
    let currentIndex: Int?
    var size: Size = .regular

    @ScaledMetric(relativeTo: .footnote) private var regularDiameter = 28
    @ScaledMetric(relativeTo: .footnote) private var largeDiameter = 36

    var body: some View {
        HStack(spacing: 8) {
            ForEach(states.indices, id: \.self) { index in
                dot(number: index + 1, state: states[index])
            }
        }
        .frame(maxWidth: .infinity)
        // Six dots must fit across a phone, so they stop growing past the largest standard size.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHidden(currentIndex == nil)
    }

    private var accessibilityLabel: Text {
        guard let currentIndex else { return Text(verbatim: "") }
        return Text("Text \(currentIndex + 1) of \(states.count)")
    }

    private func dot(number: Int, state: DotState) -> some View {
        let diameter = size == .large ? largeDiameter : regularDiameter
        return Text(number, format: .number)
            .leoTextStyle(LeoTextStyle(size: size == .large ? 15 : 13, weight: .semibold, relativeTo: .footnote))
            .monospacedDigit()
            .foregroundStyle(numberColor(state))
            .frame(width: diameter, height: diameter)
            .background(fill(state), in: .circle)
            .overlay {
                if let (color, width) = ring(state) {
                    Circle().strokeBorder(color, lineWidth: width)
                }
            }
    }

    private func numberColor(_ state: DotState) -> Color {
        switch state {
        case .done, .currentCorrect, .currentMissed: .leoBackground
        case .current: .leoAccent700
        case .failed: .leoMagenta700
        case .upcoming: size == .large ? .leoInk : .leoNeutral700
        }
    }

    private func fill(_ state: DotState) -> Color {
        switch state {
        case .done: .leoInk
        case .currentCorrect: .leoAccent
        case .currentMissed: .leoMagenta
        case .current, .failed, .upcoming: .clear
        }
    }

    private func ring(_ state: DotState) -> (Color, CGFloat)? {
        switch state {
        case .current: (.leoAccent, 1.5)
        case .failed: (.leoMagenta, 1.5)
        case .upcoming: (.leoDivider, 1)
        case .done, .currentCorrect, .currentMissed: nil
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ProgressDots(states: [.done, .current, .upcoming, .upcoming, .upcoming, .upcoming], currentIndex: 1)
        ProgressDots(states: [.done, .failed, .upcoming, .upcoming, .upcoming, .upcoming], currentIndex: 1)
        ProgressDots(states: [.done, .done, .currentCorrect, .upcoming, .upcoming, .upcoming], currentIndex: 2)
        ProgressDots(states: [.currentMissed, .upcoming, .upcoming, .upcoming, .upcoming, .upcoming], currentIndex: 0)
        ProgressDots(states: Array(repeating: .upcoming, count: 6), currentIndex: nil, size: .large)
    }
    .padding(24)
    .leoScreenBackground()
}
