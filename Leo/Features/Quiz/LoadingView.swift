import SwiftUI

/// Shown while the text the reader reached is still being written.
struct LoadingView: View {
    let index: Int
    let dots: [DotState]
    /// The topic being tried, which changes when the generator falls back to a spare one.
    let topicName: String?
    let ageGroup: AgeGroup

    var body: some View {
        ScrollingScreen {
            ProgressDots(states: dots, currentIndex: index)
                .padding(.top, 12)

            TopOffset(height: 140)

            VStack(alignment: .leading, spacing: 0) {
                Kicker("Now writing", color: .leoAccent700)
                Text(topicName ?? String(localized: "Your next text"))
                    .leoTextStyle(.display(40))
                    .padding(.vertical, 10)
                Text("A \(wordCount)-word text for readers \(ageGroup.displayName). Usually ready in a few seconds.")
                    .leoTextStyle(.body)
                    .foregroundStyle(Color.leoInkSoft)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isHeader)

            SkeletonLines()
                .padding(.top, 32)
            Spacer(minLength: 24)
        }
        .onChange(of: topicName) {
            AccessibilityNotification.Announcement(accessibilityLabel).post()
        }
    }

    /// The length the model is asked for.
    private var wordCount: Int {
        let range = ageGroup.passageWordRange
        return (range.lowerBound + range.upperBound) / 2
    }

    private var accessibilityLabel: String {
        let topic = topicName ?? String(localized: "Your next text")
        return String(localized: "Writing text \(index + 1) of \(dots.count), about \(topic)")
    }
}

#Preview {
    LoadingView(
        index: 1,
        dots: [.done, .current, .upcoming, .upcoming, .upcoming, .upcoming],
        topicName: "Volcanoes",
        ageGroup: .nine,
    )
}
