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
    /// Centered above Loading, Error and Exercise; leading on Welcome.
    var alignment: HorizontalAlignment = .center

    var body: some View {
        DotRow(spacing: 8) {
            ForEach(states.indices, id: \.self) { index in
                Dot(number: index + 1, state: states[index], size: size)
            }
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
        // Six dots must fit across a phone, so the circles and their numbers stop growing past the
        // largest standard size, and the row shrinks all six equally below that when it must.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHidden(currentIndex == nil)
    }

    private var accessibilityLabel: Text {
        guard let currentIndex else { return Text(verbatim: "") }
        return Text("Text \(currentIndex + 1) of \(states.count)")
    }
}

/// One circle. Its `@ScaledMetric` diameters are read inside `ProgressDots`' Dynamic Type cap,
/// so the circle stops growing together with its number.
private struct Dot: View {
    let number: Int
    let state: DotState
    let size: ProgressDots.Size

    @ScaledMetric(relativeTo: .footnote) private var regularDiameter = 28
    @ScaledMetric(relativeTo: .footnote) private var largeDiameter = 36

    private var diameter: CGFloat {
        size == .large ? largeDiameter : regularDiameter
    }

    var body: some View {
        Text(number, format: .number)
            .leoTextStyle(LeoTextStyle(size: size == .large ? 15 : 13, weight: .semibold, relativeTo: .footnote))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(numberColor)
            // Fills whatever square `DotRow` offers; the ideal size is the capped diameter.
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .frame(idealWidth: diameter, idealHeight: diameter)
            .background(fill, in: .circle)
            .overlay {
                if let (color, width) = ring {
                    Circle().strokeBorder(color, lineWidth: width)
                }
            }
    }

    private var numberColor: Color {
        switch state {
        case .done, .currentCorrect, .currentMissed: .leoBackground
        case .current: .leoAccent700
        case .failed: .leoMagenta700
        case .upcoming: size == .large ? .leoInk : .leoNeutral700
        }
    }

    private var fill: Color {
        switch state {
        case .done: .leoInk
        case .currentCorrect: .leoAccent
        case .currentMissed: .leoMagenta
        case .current, .failed, .upcoming: .clear
        }
    }

    private var ring: (Color, CGFloat)? {
        switch state {
        case .current: (.leoAccent, 1.5)
        case .failed: (.leoMagenta, 1.5)
        case .upcoming: (.leoDivider, 1)
        case .done, .currentCorrect, .currentMissed: nil
        }
    }
}

/// A single row of square dots. Every dot gets the same side: its ideal diameter, or less when
/// the row is narrower than all of them side by side.
struct DotRow: Layout {
    var spacing: CGFloat

    /// The side of each dot. `nil` for `proposedWidth` means no limit, so the ideal diameter.
    static func side(ideal: CGFloat, count: Int, spacing: CGFloat, proposedWidth: CGFloat?) -> CGFloat {
        guard let proposedWidth, proposedWidth.isFinite, count > 0 else { return ideal }
        let fitting = (proposedWidth - spacing * CGFloat(count - 1)) / CGFloat(count)
        return max(0, min(ideal, fitting))
    }

    private func side(_ proposal: ProposedViewSize, _ subviews: Subviews) -> CGFloat {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        return Self.side(ideal: ideal, count: subviews.count, spacing: spacing, proposedWidth: proposal.width)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let side = side(proposal, subviews)
        let count = CGFloat(subviews.count)
        return CGSize(width: side * count + spacing * max(0, count - 1), height: side)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let side = side(ProposedViewSize(width: bounds.width, height: bounds.height), subviews)
        var x = bounds.minX
        for subview in subviews {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: side, height: side),
            )
            x += side + spacing
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ProgressDots(states: [.done, .current, .upcoming, .upcoming, .upcoming, .upcoming], currentIndex: 1)
        ProgressDots(states: [.done, .failed, .upcoming, .upcoming, .upcoming, .upcoming], currentIndex: 1)
        ProgressDots(states: [.done, .done, .currentCorrect, .upcoming, .upcoming, .upcoming], currentIndex: 2)
        ProgressDots(states: [.currentMissed, .upcoming, .upcoming, .upcoming, .upcoming, .upcoming], currentIndex: 0)
        ProgressDots(
            states: Array(repeating: .upcoming, count: 6),
            currentIndex: nil,
            size: .large,
            alignment: .leading,
        )
    }
    .padding(24)
    .leoScreenBackground()
}
