import SwiftUI

/// Shown when a text couldn't be written, with a retry on the same topics and one on others.
struct GenerationFailedView: View {
    let index: Int
    let dots: [DotState]
    /// The main topic planned for this text.
    let topicName: String?
    let onRetry: () -> Void
    let onTryDifferentTopic: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 40

    var body: some View {
        ScrollingScreen {
            ProgressDots(states: dots, currentIndex: index)
                .padding(.top, 12)

            TopOffset(height: 140)

            Image(systemName: "exclamationmark.circle")
                .font(.system(size: iconSize))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.leoMagenta600)
                .accessibilityHidden(true)
            Kicker("Text \(index + 1) didn't print", color: .leoMagenta700)
                .padding(.top, 16)
            Text("We couldn't write this one.")
                .leoTextStyle(.display(40))
                .accessibilityAddTraits(.isHeader)
                .padding(.vertical, 10)
            Text(message)
                .leoTextStyle(.body)
                .foregroundStyle(Color.leoInkSoft)
            Spacer(minLength: 24)
        }
        .leoBottomBar {
            Button(action: onRetry) {
                Label("Try again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.leo(.primary))
            Button("Try a different topic", action: onTryDifferentTopic)
                .buttonStyle(.leo(.ghost))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
    }

    /// What went wrong, and that earlier answers are kept. Nothing is answered before text 2.
    private var message: String {
        let failure = topicName.map {
            String(localized: "Something went wrong while writing your text about \($0).")
        } ?? String(localized: "Something went wrong while writing your text.")
        let reassurance: String? = switch index {
        case 0: nil
        case 1: String(localized: "Your answer to text 1 is saved — nothing is lost.")
        default: String(localized: "Your answers so far are saved — nothing is lost.")
        }
        return [failure, reassurance].compactMap(\.self).joined(separator: " ")
    }
}

#Preview {
    GenerationFailedView(
        index: 1,
        dots: [.done, .failed, .upcoming, .upcoming, .upcoming, .upcoming],
        topicName: "Volcanoes",
        onRetry: {},
        onTryDifferentTopic: {},
    )
}
