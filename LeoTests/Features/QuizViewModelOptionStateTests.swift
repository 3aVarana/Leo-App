@testable import Leo
import Testing

/// How `QuizViewModel` presents the options of the current exercise, for `ExerciseView`.
@MainActor
struct QuizViewModelOptionStateTests {
    /// A started round whose exercises are all ready. The fixture exercise has 4 options.
    private func startedQuiz() async -> QuizViewModel {
        let stub = StubExerciseRepository.ready()
        let quiz = QuizViewModel { _ in stub }
        quiz.configure(RoundSettings(ageGroup: .nine, topics: ["owls", "rivers", "kites"]))
        await waitUntil { stub.calls.count == QuizViewModel.exerciseCount }
        quiz.start()
        return quiz
    }

    private func optionStates(_ quiz: QuizViewModel) -> [QuizViewModel.OptionState] {
        quiz.currentExercise!.options.indices.map(quiz.optionState(at:))
    }

    @Test func optionStatesBeforeAnswering() async {
        let quiz = await startedQuiz()
        #expect(optionStates(quiz) == [.idle, .idle, .idle, .idle])
        #expect(quiz.isAnswerCorrect == nil)
    }

    @Test func optionStatesAfterCorrectAnswer() async throws {
        let quiz = await startedQuiz()
        let exercise = try #require(quiz.currentExercise)
        quiz.finishReading()
        quiz.select(exercise.correctIndex)

        var expected = [QuizViewModel.OptionState](repeating: .dimmed, count: exercise.options.count)
        expected[exercise.correctIndex] = .correct
        #expect(optionStates(quiz) == expected)
        #expect(quiz.isAnswerCorrect == true)
    }

    @Test func optionStatesAfterWrongAnswer() async throws {
        let quiz = await startedQuiz()
        let exercise = try #require(quiz.currentExercise)
        let wrong = (exercise.correctIndex + 1) % exercise.options.count
        quiz.finishReading()
        quiz.select(wrong)

        var expected = [QuizViewModel.OptionState](repeating: .dimmed, count: exercise.options.count)
        expected[exercise.correctIndex] = .correct
        expected[wrong] = .incorrect
        #expect(optionStates(quiz) == expected)
        #expect(quiz.isAnswerCorrect == false)
    }

    @Test func optionStatesResetOnNext() async {
        let quiz = await startedQuiz()
        quiz.finishReading()
        quiz.select(0)
        quiz.next()
        #expect(optionStates(quiz) == [.idle, .idle, .idle, .idle])
        #expect(quiz.isAnswerCorrect == nil)
    }
}
