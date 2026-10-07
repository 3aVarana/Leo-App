import SwiftUI

struct ExerciseView: View {
    let quiz: QuizViewModel
    let exercise: Exercise

    private static let feedbackID = "feedback"

    @ScaledMetric(relativeTo: .title3) private var verdictIconSize = 22

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ProgressDots(states: dots, currentIndex: quiz.currentIndex)
                        .padding(.top, 12)

                    Kicker(verbatim: exercise.topic.name)
                        .padding(.top, 28)
                    Text(exercise.title)
                        .leoTextStyle(.title)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
                    Text(exercise.passage)
                        .leoTextStyle((quiz.roundAgeGroup ?? .nine).passageStyle)
                        .textSelection(.enabled)

                    Kicker(verbatim: exercise.skill.displayName, color: .leoAccent700)
                        .padding(.top, 28)
                    Text(exercise.question)
                        .leoTextStyle(.question)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
                    VStack(spacing: 8) {
                        ForEach(exercise.options.indices, id: \.self) { index in
                            OptionButton(
                                letter: Self.letter(index),
                                text: exercise.options[index],
                                state: quiz.optionState(at: index),
                                action: { quiz.select(index) },
                            )
                        }
                    }

                    if let isCorrect = quiz.isAnswerCorrect {
                        feedback(isCorrect: isCorrect)
                            .padding(.top, 26)
                            .id(Self.feedbackID)
                    }
                }
                .foregroundStyle(Color.leoInk)
                .leoReadableWidth()
                .padding(.bottom, 24)
            }
            .onChange(of: quiz.isAnswerCorrect) {
                withAnimation { proxy.scrollTo(Self.feedbackID, anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if quiz.isAnswerCorrect != nil {
                Button(quiz.isLastExercise ? "See results" : "Next text", action: quiz.next)
                    .buttonStyle(.leo(.primary))
                    .leoReadableWidth()
                    .padding(.top, 16)
                    .background(Color.leoBackground)
            }
        }
        .leoScreenBackground()
        .sensoryFeedback(trigger: quiz.isAnswerCorrect) { _, isCorrect in
            guard let isCorrect else { return nil }
            return isCorrect ? .success : .error
        }
    }

    private var dots: [DotState] {
        (0 ..< QuizViewModel.exerciseCount).map(quiz.dotState(at:))
    }

    /// A, B, C, D.
    private static func letter(_ index: Int) -> String {
        String(UnicodeScalar(UInt8(ascii: "A") + UInt8(index)))
    }

    private func feedback(isCorrect: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(isCorrect ? "Correct!" : "Not quite")
                    .leoTextStyle(.verdict)
            } icon: {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: verdictIconSize))
                    .symbolRenderingMode(.hierarchical)
            }
            .foregroundStyle(isCorrect ? Color.leoAccent700 : Color.leoMagenta700)
            .accessibilityAddTraits(.isHeader)
            if !isCorrect, !exercise.explanation.isEmpty {
                Text(exercise.explanation)
                    .leoTextStyle(.explanation)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OptionButton: View {
    let letter: String
    let text: String
    let state: QuizViewModel.OptionState
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakes: CGFloat = 0

    var body: some View {
        Button(action: action) {
            AnswerRow(
                marker: letter,
                text: text,
                state: state,
                note: state == .incorrect ? "Your answer" : nil,
            )
        }
        .buttonStyle(.plain)
        .modifier(ShakeEffect(shakes: shakes))
        .onChange(of: state) {
            guard state == .incorrect, !reduceMotion else { return }
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
        }
        // Not `.disabled`, which would grey out the highlighted answers.
        .allowsHitTesting(state == .idle)
        .accessibilityLabel(text)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        switch state {
        case .correct: String(localized: "Correct answer")
        case .incorrect: String(localized: "Your answer, incorrect")
        case .idle, .dimmed: ""
        }
    }
}

/// Shakes the view horizontally a few times per unit of `shakes`.
private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size _: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(shakes * .pi * 6), y: 0))
    }
}
