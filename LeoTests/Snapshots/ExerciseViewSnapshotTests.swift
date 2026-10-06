@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct ExerciseViewSnapshotTests {
        /// A started round whose exercises are all ready, the first one being `first`.
        private func startedQuiz(first: Exercise = .fixture()) async -> QuizViewModel {
            let results = [first] + (1 ..< QuizViewModel.exerciseCount).map { _ in Exercise.fixture() }
            let stub = StubExerciseRepository(results: results.map { .success($0) })
            let quiz = QuizViewModel { _ in stub }
            quiz.configure(RoundSettings(ageGroup: .nine, topics: ["volcanoes", "rivers", "comets"]))
            await waitUntil { stub.calls.count == QuizViewModel.exerciseCount }
            quiz.start()
            return quiz
        }

        /// The exercise screen as `RootView` shows it, in a navigation stack.
        private func screen(_ quiz: QuizViewModel) -> some View {
            NavigationStack {
                ExerciseView(quiz: quiz, exercise: quiz.currentExercise!)
            }
        }

        @Test func beforeAnswering() async {
            let quiz = await startedQuiz()
            assertViewSnapshot(of: screen(quiz), named: "unanswered")
        }

        @Test func beforeAnsweringAccessibilitySize() async {
            let quiz = await startedQuiz()
            assertViewSnapshot(
                of: screen(quiz),
                named: "unanswered-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge,
                height: 2700,
            )
        }

        @Test func correctAnswer() async throws {
            let quiz = await startedQuiz()
            try quiz.select(#require(quiz.currentExercise?.correctIndex))
            assertViewSnapshot(of: screen(quiz), named: "correct", height: 1000)
        }

        @Test func wrongAnswer() async {
            let quiz = await startedQuiz()
            quiz.select(0)
            assertViewSnapshot(of: screen(quiz), named: "wrong", height: 1000)
        }

        @Test func wrongAnswerWithoutExplanation() async {
            let quiz = await startedQuiz(first: .fixture(explanation: ""))
            quiz.select(0)
            assertViewSnapshot(of: screen(quiz), named: "wrong-no-explanation", height: 1000)
        }

        /// The button reads "See results".
        @Test func lastExerciseAnswered() async throws {
            let quiz = await startedQuiz()
            for _ in 0 ..< QuizViewModel.exerciseCount - 1 {
                quiz.select(0)
                quiz.next()
            }
            try quiz.select(#require(quiz.currentExercise?.correctIndex))
            assertViewSnapshot(of: screen(quiz), named: "last-answered", height: 1000)
        }
    }
}
