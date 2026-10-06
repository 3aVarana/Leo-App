import SwiftUI

/// Six placeholder bars for a text that's being written. They pulse, one after another,
/// unless Reduce Motion is on. Hidden from VoiceOver.
struct SkeletonLines: View {
    private static let widths: [CGFloat] = [1, 0.96, 1, 0.88, 1, 0.72]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.animatesPlaceholders) private var animatesPlaceholders
    @State private var isDimmed = false

    var body: some View {
        // Fixed bar heights, so the reader only sizes the width.
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Self.widths.indices, id: \.self) { index in
                    bar(index, width: proxy.size.width)
                }
            }
        }
        .frame(height: 9 * 6 + 12 * 5)
        .accessibilityHidden(true)
        .onAppear {
            if isPulsing {
                isDimmed = true
            }
        }
    }

    private func bar(_ index: Int, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.leoNeutral300)
            .frame(width: width * Self.widths[index], height: 9)
            .opacity(opacity)
            .animation(
                isPulsing ? .easeInOut(duration: 0.9).repeatForever().delay(Double(index) * 0.15) : nil,
                value: isDimmed,
            )
    }

    private var isPulsing: Bool {
        !reduceMotion && animatesPlaceholders
    }

    private var opacity: Double {
        guard isPulsing else { return 0.6 }
        return isDimmed ? 0.35 : 1
    }
}

#Preview {
    SkeletonLines()
        .padding(24)
        .leoScreenBackground()
}
