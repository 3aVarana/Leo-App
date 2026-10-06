import SwiftUI

/// The texts the reader missed, one page each: their answer, the right one, why, and the text.
struct ReviewView: View {
    let misses: [RoundAnswer]

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int

    init(misses: [RoundAnswer], startIndex: Int) {
        self.misses = misses
        _selection = State(initialValue: startIndex)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(misses.indices, id: \.self) { index in
                ReviewPage(answer: misses[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .leoScreenBackground()
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(selection + 1) of \(misses.count) missed")
                    .leoTextStyle(.caption)
                    .foregroundStyle(Color.leoInkSoft)
                    .fixedSize()
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .leoBottomBar {
            if selection < misses.count - 1 {
                Button("Next missed text") {
                    withAnimation { selection += 1 }
                }
                .buttonStyle(.leo(.primary))
            } else {
                Button("Back to results") { dismiss() }
                    .buttonStyle(.leo(.primary))
            }
        }
    }
}

private struct ReviewPage: View {
    let answer: RoundAnswer

    private var exercise: Exercise {
        answer.exercise
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(
                    "Text \(answer.index + 1) · \(exercise.skill.displayName)",
                    color: .leoMagenta700,
                )
                .padding(.top, 20)
                Text(exercise.title)
                    .leoTextStyle(.title)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
                Text(exercise.question)
                    .leoTextStyle(.reviewQuestion)
                    .padding(.bottom, 12)
                VStack(spacing: 8) {
                    AnswerRow(
                        marker: String(localized: "You"),
                        text: exercise.options[answer.selectedOption],
                        state: .incorrect,
                        readsMarker: true,
                    )
                    .accessibilityElement(children: .combine)
                    AnswerRow(
                        marker: String(localized: "Answer"),
                        text: exercise.options[exercise.correctIndex],
                        state: .correct,
                        readsMarker: true,
                    )
                    .accessibilityElement(children: .combine)
                }
                if !exercise.explanation.isEmpty {
                    Text(exercise.explanation)
                        .leoTextStyle(.reviewExplanation)
                        .padding(.top, 14)
                }
                Kicker("From the text")
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 24)
                Text(exercise.passage)
                    .leoTextStyle(LeoTextStyle(size: 16, relativeTo: .callout, lineHeight: 25))
                    .textSelection(.enabled)
                    .padding(.top, 8)
            }
            .foregroundStyle(Color.leoInk)
            .leoReadableWidth()
            .padding(.bottom, 24)
        }
    }
}
