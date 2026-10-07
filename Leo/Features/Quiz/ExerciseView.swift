import SwiftUI

/// An exercise in two steps: the reader reads the passage, then answers its question. After
/// answering, the passage shows again under the feedback.
struct ExerciseView: View {
    let quiz: QuizViewModel
    let exercise: Exercise
    /// Whether the question replaces the passage when its reading time runs out.
    var isReadingTimed = true

    private static let topID = "top"
    private static let feedbackID = "feedback"

    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverOn
    @AccessibilityFocusState private var isQuestionFocused: Bool
    @ScaledMetric(relativeTo: .title3) private var verdictIconSize = 22

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ProgressDots(states: dots, currentIndex: quiz.currentIndex)
                        .padding(.top, 12)
                        .id(Self.topID)

                    if quiz.isReading {
                        passage
                    } else {
                        question
                        if let isCorrect = quiz.isAnswerCorrect {
                            feedback(isCorrect: isCorrect)
                                .padding(.top, 26)
                                .id(Self.feedbackID)
                            passage
                        }
                    }
                }
                .foregroundStyle(Color.leoInk)
                .leoReadableWidth()
                .padding(.bottom, 24)
            }
            .onChange(of: quiz.isReading) {
                proxy.scrollTo(Self.topID, anchor: .top)
                isQuestionFocused = true
            }
            .onChange(of: quiz.isAnswerCorrect) {
                withAnimation { proxy.scrollTo(Self.feedbackID, anchor: .bottom) }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: quiz.isReading)
        .safeAreaInset(edge: .bottom) {
            if quiz.isReading {
                VStack(spacing: 14) {
                    if let readingTime {
                        ReadingTimer(total: readingTime, onTimeUp: quiz.finishReading)
                    }
                    Button("Answer the question", action: quiz.finishReading)
                        .buttonStyle(.leo(.primary))
                }
                .leoReadableWidth()
                .padding(.top, 16)
                .background(Color.leoBackground)
            } else if quiz.isAnswerCorrect != nil {
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

    /// The time to read the passage. `nil`, for as long as the reader needs, when the timer is off
    /// or VoiceOver is on, since reading by ear takes much longer.
    private var readingTime: Duration? {
        guard isReadingTimed, !isVoiceOverOn else { return nil }
        return quiz.readingTime
    }

    @ViewBuilder
    private var passage: some View {
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
    }

    @ViewBuilder
    private var question: some View {
        Kicker(verbatim: exercise.skill.displayName, color: .leoAccent700)
            .padding(.top, 28)
        Text(exercise.question)
            .leoTextStyle(.question)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($isQuestionFocused)
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

/// The time left to read, and a bar that empties with it. Counts down only while the app is
/// in front, and calls `onTimeUp` at zero.
private struct ReadingTimer: View {
    let total: Duration
    let onTimeUp: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var remaining: Duration

    init(total: Duration, onTimeUp: @escaping () -> Void) {
        self.total = total
        self.onTimeUp = onTimeUp
        _remaining = State(initialValue: total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Kicker("Time to read")
                Spacer()
                Text(remaining, format: .time(pattern: .minuteSecond))
                    .leoTextStyle(LeoTextStyle(size: 15, weight: .semibold, relativeTo: .subheadline))
                    .monospacedDigit()
                    .foregroundStyle(Color.leoInk)
            }
            Rectangle()
                .fill(Color.leoDivider)
                .frame(height: 2)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.leoAccent)
                        .scaleEffect(x: remaining / total, anchor: .leading)
                        .animation(.linear(duration: 1), value: remaining)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Time left to read"))
        .accessibilityValue(Text(remaining, format: .units(allowed: [.minutes, .seconds], width: .wide)))
        .task(id: scenePhase == .active) {
            guard scenePhase == .active else { return }
            while remaining > .zero {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                remaining -= .seconds(1)
            }
            onTimeUp()
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
