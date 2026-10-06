import SwiftUI

/// The score of the round, a row per text, and Review for the texts the reader missed.
struct ResultView: View {
    let answers: [RoundAnswer]
    let ageGroup: AgeGroup
    let onRestart: () -> Void
    /// `nil` hides the Settings button.
    var onSettings: (() -> Void)?

    /// The position in `misses` that Review opens at.
    @State private var reviewStart: Int?
    @ScaledMetric(relativeTo: .title3) private var gearSize = 22

    var body: some View {
        ScrollingScreen {
            HStack {
                Spacer()
                if let onSettings {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: gearSize))
                            .symbolRenderingMode(.hierarchical)
                            .frame(minWidth: 44, minHeight: 44)
                            .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(Color.leoDivider) }
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Settings"))
                }
            }
            .frame(minHeight: 44)
            .padding(.top, 4)

            Kicker("Round complete · readers \(ageGroup.displayName)")
                .padding(.top, 28)
            Text("\(correctCount) of \(answers.count)")
                .leoTextStyle(.score)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 10)
            Text(message)
                .leoTextStyle(.resultMessage)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(answers) { answer in
                    row(answer)
                }
            }
            .padding(.top, 28)
            Spacer(minLength: 24)
        }
        .leoBottomBar {
            Button("Practice again", action: onRestart)
                .buttonStyle(.leo(.primary))
        }
        // The back button on Review shows this title.
        .navigationTitle(Text("Results"))
        .navigationDestination(item: $reviewStart) { start in
            ReviewView(misses: misses, startIndex: start)
        }
    }

    private var correctCount: Int {
        answers.count(where: \.isCorrect)
    }

    private var misses: [RoundAnswer] {
        answers.filter { !$0.isCorrect }
    }

    @ViewBuilder
    private func row(_ answer: RoundAnswer) -> some View {
        if answer.isCorrect {
            ResultRow(answer: answer)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Text \(answer.index + 1), \(answer.exercise.title), correct"))
        } else {
            Button {
                reviewStart = misses.firstIndex { $0.index == answer.index }
            } label: {
                ResultRow(answer: answer)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Text \(answer.index + 1), \(answer.exercise.title), missed"))
            .accessibilityHint(Text("Review"))
            .accessibilityAddTraits(.isButton)
        }
    }

    private var message: String {
        let ratio = Double(correctCount) / Double(max(answers.count, 1))
        if ratio == 1 {
            return String(localized: "Perfect score! You understood every text.")
        }
        if ratio >= 0.8 {
            return String(localized: "Great reading! You're paying close attention.")
        }
        if ratio >= 0.5 {
            return String(localized: "Good work. Keep practicing to sharpen your understanding.")
        }
        return String(localized: "Keep going! Try reading each text slowly and look for key ideas.")
    }
}

/// A text's number, its title, a dotted leader and how it went. At accessibility sizes the
/// status moves under the title and the leader is dropped.
private struct ResultRow: View {
    let answer: RoundAnswer

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .callout) private var minHeight = 44

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    number
                    VStack(alignment: .leading, spacing: 4) {
                        title
                        status
                    }
                }
                .padding(.vertical, 6)
            } else {
                // The number sits on the title's first line; the leader and the status on its last.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    number
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        title
                            .layoutPriority(1)
                        DottedLeader()
                            .frame(minWidth: 20)
                            .alignmentGuide(.lastTextBaseline) { $0[.bottom] + 5 }
                        status
                            .fixedSize()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .contentShape(.rect)
    }

    private var number: some View {
        Text(answer.index + 1, format: .number)
            .leoTextStyle(.answerMarker)
            .frame(minWidth: 16, alignment: .leading)
            .fixedSize()
    }

    private var title: some View {
        Text(answer.exercise.title)
            .leoTextStyle(LeoTextStyle(size: 16, relativeTo: .callout, lineHeight: 24))
            .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    private var status: some View {
        if answer.isCorrect {
            Text("Correct")
                .leoTextStyle(LeoTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(Color.leoAccent700)
        } else {
            HStack(spacing: 4) {
                Text("Review")
                Image(systemName: "arrow.right")
                    .imageScale(.small)
            }
            .leoTextStyle(LeoTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline))
            .foregroundStyle(Color.leoMagenta700)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(Color.leoDivider) }
        }
    }
}
