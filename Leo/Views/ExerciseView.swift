import SwiftUI

struct ExerciseView: View {
    let quiz: QuizModel
    let exercise: Exercise

    private static let feedbackID = "feedback"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    VStack(alignment: .leading, spacing: 12) {
                        Text(exercise.title)
                            .font(.title2.bold())
                        Text(exercise.passage)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.fill.quaternary, in: .rect(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        Text(exercise.skill.displayName.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(exercise.question)
                            .font(.headline)
                        ForEach(exercise.options.indices, id: \.self) { index in
                            OptionButton(
                                text: exercise.options[index],
                                state: state(for: index),
                                action: { quiz.select(index) },
                            )
                        }
                    }

                    if quiz.selectedOption != nil {
                        feedback
                            .id(Self.feedbackID)
                    }
                }
                .padding()
            }
            .onChange(of: quiz.selectedOption) {
                withAnimation { proxy.scrollTo(Self.feedbackID, anchor: .bottom) }
            }
        }
        .sensoryFeedback(trigger: quiz.selectedOption) { _, selected in
            guard let selected else { return nil }
            return selected == exercise.correctIndex ? .success : .error
        }
        .navigationTitle("Exercise \(quiz.currentIndex + 1)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: Double(quiz.currentIndex + 1), total: Double(QuizModel.exerciseCount))
            Text("\(quiz.currentIndex + 1) of \(QuizModel.exerciseCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var feedback: some View {
        let isCorrect = quiz.selectedOption == exercise.correctIndex
        return VStack(spacing: 16) {
            Label(
                isCorrect ? "Correct!" : "Not quite",
                systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill",
            )
            .font(.headline)
            .foregroundStyle(isCorrect ? .green : .red)
            if !isCorrect, !exercise.explanation.isEmpty {
                Text(exercise.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: quiz.next) {
                Text(quiz.isLastExercise ? "See results" : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
    }

    private func state(for index: Int) -> OptionButton.State {
        guard let selected = quiz.selectedOption else { return .idle }
        if index == exercise.correctIndex {
            return .correct
        }
        if index == selected {
            return .incorrect
        }
        return .dimmed
    }
}

private struct OptionButton: View {
    enum State { case idle, correct, incorrect, dimmed }

    let text: String
    let state: State
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SwiftUI.State private var shakes: CGFloat = 0

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Always laid out, so the text keeps the same width when the icon appears.
                Image(systemName: icon ?? "checkmark.circle.fill")
                    .foregroundStyle(border)
                    .opacity(icon == nil ? 0 : 1)
                    .accessibilityHidden(icon == nil)
            }
            .padding()
            .foregroundStyle(foreground)
            .background(background, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(border, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .modifier(ShakeEffect(shakes: shakes))
        .onChange(of: state) {
            guard state == .incorrect, !reduceMotion else { return }
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
        }
        // Not `.disabled`, which would grey out the highlighted answers.
        .allowsHitTesting(state == .idle)
        .accessibilityValue(accessibilityValue)
    }

    private var icon: String? {
        switch state {
        case .correct: "checkmark.circle.fill"
        case .incorrect: "xmark.circle.fill"
        case .idle, .dimmed: nil
        }
    }

    private var foreground: Color {
        state == .dimmed ? .secondary : .primary
    }

    private var background: Color {
        switch state {
        case .correct: .green.opacity(0.15)
        case .incorrect: .red.opacity(0.15)
        case .idle, .dimmed: .clear
        }
    }

    private var border: Color {
        switch state {
        case .correct: .green
        case .incorrect: .red
        case .idle, .dimmed: .secondary.opacity(0.4)
        }
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
