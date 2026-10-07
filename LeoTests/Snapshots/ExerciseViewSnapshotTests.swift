@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct ExerciseViewSnapshotTests {
        /// A started round whose exercises are all ready, the first one being `first`.
        private func startedQuiz(first: Exercise = .fixture(), ageGroup: AgeGroup = .nine) async -> QuizViewModel {
            let results = [first] + (1 ..< QuizViewModel.exerciseCount).map { _ in Exercise.fixture() }
            let stub = StubExerciseRepository(results: results.map { .success($0) })
            let quiz = QuizViewModel { _ in stub }
            quiz.configure(RoundSettings(ageGroup: ageGroup, topics: ["volcanoes", "rivers", "comets"]))
            await waitUntil { stub.calls.count == QuizViewModel.exerciseCount }
            quiz.start()
            return quiz
        }

        /// The exercise screen as `RootView` shows it, in a navigation stack.
        private func screen(_ quiz: QuizViewModel, isReadingTimed: Bool = true) -> some View {
            NavigationStack {
                ExerciseView(quiz: quiz, exercise: quiz.currentExercise!, isReadingTimed: isReadingTimed)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }

        /// The passage, with the full reading time left.
        @Test func reading() async {
            let quiz = await startedQuiz()
            assertViewSnapshot(of: screen(quiz), named: "reading")
        }

        /// The timer is off in Settings: only the button.
        @Test func readingUntimed() async {
            let quiz = await startedQuiz()
            assertViewSnapshot(of: screen(quiz, isReadingTimed: false), named: "reading-untimed")
        }

        /// The largest passage text, for the youngest readers.
        @Test func youngestReaders() async {
            let quiz = await startedQuiz(ageGroup: .six)
            assertViewSnapshot(of: screen(quiz), named: "reading-6-8", height: 1000)
        }

        @Test func readingAccessibilitySize() async {
            let quiz = await startedQuiz()
            assertViewSnapshot(
                of: screen(quiz),
                named: "reading-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge,
                height: 2400,
            )
        }

        /// The question replaced the passage.
        @Test func beforeAnswering() async {
            let quiz = await startedQuiz()
            quiz.finishReading()
            assertViewSnapshot(of: screen(quiz), named: "unanswered")
        }

        @Test func beforeAnsweringAccessibilitySize() async {
            let quiz = await startedQuiz()
            quiz.finishReading()
            assertViewSnapshot(
                of: screen(quiz),
                named: "unanswered-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge,
                height: 2000,
            )
        }

        @Test func correctAnswer() async throws {
            let quiz = await startedQuiz()
            quiz.finishReading()
            try quiz.select(#require(quiz.currentExercise?.correctIndex))
            assertViewSnapshot(of: screen(quiz), named: "correct", height: 1250)
        }

        @Test func wrongAnswer() async {
            let quiz = await startedQuiz()
            quiz.finishReading()
            quiz.select(0)
            assertViewSnapshot(of: screen(quiz), named: "wrong", height: 1250)
        }

        @Test func wrongAnswerWithoutExplanation() async {
            let quiz = await startedQuiz(first: .fixture(explanation: ""))
            quiz.finishReading()
            quiz.select(0)
            assertViewSnapshot(of: screen(quiz), named: "wrong-no-explanation", height: 1250)
        }

        /// The button reads "See results".
        @Test func lastExerciseAnswered() async throws {
            let quiz = await startedQuiz()
            for _ in 0 ..< QuizViewModel.exerciseCount - 1 {
                quiz.finishReading()
                quiz.select(0)
                quiz.next()
            }
            quiz.finishReading()
            try quiz.select(#require(quiz.currentExercise?.correctIndex))
            assertViewSnapshot(of: screen(quiz), named: "last-answered", height: 1250)
        }

        /// A wrong pick on the last text: the button reads "See results".
        @Test func lastExerciseMissed() async {
            let quiz = await startedQuiz()
            for _ in 0 ..< QuizViewModel.exerciseCount - 1 {
                quiz.finishReading()
                quiz.select(0)
                quiz.next()
            }
            quiz.finishReading()
            quiz.select(0)
            assertViewSnapshot(of: screen(quiz), named: "last-missed", height: 1250)
        }
    }
}
