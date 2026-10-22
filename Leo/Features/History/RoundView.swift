import SwiftUI

/// One saved round: the score and dots, then each text with its topic, skill and how it went.
/// Loads the round by id; if it's gone (deleted, unreadable) the view pops back.
struct RoundView: View {
    let id: UUID
    let viewModel: RoundHistoryViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var loadedRound: RoundRecord?
    @State private var reviewStart: Int?

    var body: some View {
        Group {
            if let loadedRound {
                content(loadedRound)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(Text(verbatim: ""))
        .task { load() }
    }

    private func content(_ round: RoundRecord) -> some View {
        ScrollingScreen {
            Kicker(verbatim: kickerText(round))
                .padding(.top, 28)
            Text("\(round.correctCount) of \(round.answers.count)")
                .leoTextStyle(.score)
                .accessibilityAddTraits(.isHeader)
            RoundResultDots(results: round.answers.map(\.isCorrect))
                .padding(.top, 14)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(round.answers) { answer in
                    row(answer, in: round)
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
        .navigationDestination(item: $reviewStart) { start in
            ReviewView(misses: round.misses, startIndex: start, backTitle: "Back to round")
        }
    }

    private func load() {
        loadedRound = viewModel.round(id: id)
        if loadedRound == nil {
            dismiss()
        }
    }

    private func kickerText(_ round: RoundRecord) -> String {
        let dateTime = round.finishedAt.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        return String(localized: "\(dateTime) · readers \(round.ageGroup.displayName)")
    }

    @ViewBuilder
    private func row(_ answer: RoundAnswer, in round: RoundRecord) -> some View {
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

/// A text's number, its title over its topic and skill, and how it went.
private struct RoundResultRow: View {
    let answer: RoundAnswer

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(answer.index + 1, format: .number)
                .leoTextStyle(.answerMarker)
                .frame(minWidth: 16, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(answer.exercise.title)
                    .leoTextStyle(LeoTextStyle(size: 17, relativeTo: .callout, lineHeight: 24))
                Text("\(answer.exercise.topic.name) · \(answer.exercise.skill.displayName)")
                    .leoTextStyle(.caption)
                    .foregroundStyle(Color.leoInkSoft)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            status
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
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

#Preview {
    let repository = SwiftDataRoundHistoryRepository.inMemory()
    let round = RoundRecord.previewFixture(ageGroup: .nine, results: [true, false, true, true, false, true])
    try? repository.save(round)
    let viewModel = RoundHistoryViewModel(repository: repository)
    return NavigationStack {
        RoundView(id: round.id, viewModel: viewModel)
    }
}

private extension RoundRecord {
    static func previewFixture(ageGroup: AgeGroup, results: [Bool]) -> RoundRecord {
        let topic = RoundTopic(prompt: "volcanoes", name: "Volcanoes")
        var answers: [RoundAnswer] = []
        for (index, isCorrect) in results.enumerated() {
            let exercise = Exercise(
                topic: topic,
                skill: .detail,
                title: "Preview text \(index + 1)",
                passage: "A short passage.",
                question: "A question?",
                options: ["A", "B", "C", "D"],
                correctIndex: 0,
                explanation: "An explanation.",
            )
            let selected = isCorrect ? 0 : 1
            answers.append(RoundAnswer(index: index, exercise: exercise, selectedOption: selected))
        }
        return RoundRecord(id: UUID(), finishedAt: Date(), ageGroup: ageGroup, answers: answers)
    }
}
