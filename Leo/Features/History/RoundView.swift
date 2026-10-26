import SwiftUI

/// One saved round: the score and dots, then each text with its topic, skill and how it went.
/// `HistoryView` loads the round before pushing this, so there's no async load and no blank
/// first frame; a round that goes missing mid-push (deleted, unreadable) just doesn't push.
struct RoundView: View {
    let round: RoundRecord

    @State private var reviewStart: Int?

    var body: some View {
        ScrollingScreen {
            Kicker(verbatim: kickerText)
                .padding(.top, 28)
            Text("\(round.correctCount) of \(round.answers.count)")
                .leoTextStyle(.score)
                .accessibilityAddTraits(.isHeader)
            RoundResultDots(results: round.answers.map(\.isCorrect))
                .padding(.top, 14)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(round.answers) { answer in
                    row(answer)
                }
            }
            .padding(.top, 24)
            Spacer(minLength: 24)
        }
        .leoBottomBar {
            if !round.misses.isEmpty {
                Button {
                    reviewStart = 0
                } label: {
                    Text("Review \(round.misses.count) missed")
                }
                .buttonStyle(.leo(.secondary))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(Text(verbatim: ""))
        .navigationDestination(item: $reviewStart) { start in
            ReviewView(misses: round.misses, startIndex: start, backTitle: "Back to round")
        }
    }

    private var kickerText: String {
        let dateTime = round.finishedAt.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        return String(localized: "\(dateTime) · readers \(round.ageGroup.displayName)")
    }

    @ViewBuilder
    private func row(_ answer: RoundAnswer) -> some View {
        if answer.isCorrect {
            RoundResultRow(answer: answer)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    Text("Text \(answer.index + 1), \(answer.exercise.title), \(subtitle(answer)), correct"),
                )
        } else {
            Button {
                reviewStart = round.misses.firstIndex { $0.index == answer.index }
            } label: {
                RoundResultRow(answer: answer)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                Text("Text \(answer.index + 1), \(answer.exercise.title), \(subtitle(answer)), missed"),
            )
            .accessibilityHint(Text("Review"))
            .accessibilityAddTraits(.isButton)
        }
    }

    private func subtitle(_ answer: RoundAnswer) -> String {
        String(localized: "\(answer.exercise.topic.name) · \(answer.exercise.skill.displayName)")
    }
}

/// A text's number, its title over its topic and skill, and how it went. At accessibility sizes
/// the status moves under the title, like `ResultRow` on Results.
private struct RoundResultRow: View {
    let answer: RoundAnswer

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        number
                        title
                    }
                    subtitle
                    status
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    number
                    VStack(alignment: .leading, spacing: 2) {
                        title
                        subtitle
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 8)
                    status
                }
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private var number: some View {
        Text(answer.index + 1, format: .number)
            .leoTextStyle(.answerMarker)
            .frame(minWidth: 16, alignment: .leading)
    }

    private var title: some View {
        Text(answer.exercise.title)
            .leoTextStyle(LeoTextStyle(size: 17, relativeTo: .callout, lineHeight: 24))
    }

    private var subtitle: some View {
        Text("\(answer.exercise.topic.name) · \(answer.exercise.skill.displayName)")
            .leoTextStyle(.caption)
            .foregroundStyle(Color.leoInkSoft)
    }

    @ViewBuilder
    private var status: some View {
        if answer.isCorrect {
            Text("Correct")
                .leoTextStyle(LeoTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(Color.leoAccent700)
        } else {
            ReviewLabel()
        }
    }
}

#if DEBUG
    #Preview {
        let round = RoundRecord.previewFixture(ageGroup: .nine, results: [true, false, true, true, false, true])
        return NavigationStack {
            RoundView(round: round)
        }
    }
#endif
