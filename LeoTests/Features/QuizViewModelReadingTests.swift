@testable import Leo
import Testing

/// The reading step: each exercise shows its passage first, and its question once the reader
/// finishes reading.
@MainActor
struct QuizViewModelReadingTests {
    private let settings = RoundSettings(ageGroup: .nine, topics: ["owls", "rivers", "kites"])

    private func makeQuiz(_ spy: ExerciseRepositoryFactorySpy) -> QuizViewModel {
        QuizViewModel { spy.make($0) }
    }

    /// Starts a round whose 6 exercises are ready, and waits until they are.
    private func startedQuiz() async -> QuizViewModel {
        let spy = ExerciseRepositoryFactorySpy { .ready() }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == QuizViewModel.exerciseCount }
        quiz.start()
        return quiz
    }

    @Test func exerciseStartsWithPassage() async {
        let quiz = await startedQuiz()
        #expect(quiz.phase == .answering)
        #expect(quiz.isReading)
    }

    @Test func selectWhileReadingIsIgnored() async {
        let quiz = await startedQuiz()
        quiz.select(0)
        #expect(quiz.selectedOption == nil)
        #expect(quiz.answers.isEmpty)
        #expect(quiz.isReading)
    }

    @Test func finishReadingShowsQuestion() async {
        let quiz = await startedQuiz()
        quiz.finishReading()
        #expect(!quiz.isReading)
        quiz.select(0)
        #expect(quiz.selectedOption == 0)
    }

    @Test func nextExerciseStartsWithPassage() async {
        let quiz = await startedQuiz()
        quiz.finishReading()
        quiz.select(0)
        quiz.next()
        #expect(quiz.currentIndex == 1)
        #expect(quiz.isReading)
    }

    /// The reader can't skip the passage of an exercise that isn't ready yet.
    @Test func finishReadingWhileLoadingDoesNothing() async {
        let spy = ExerciseRepositoryFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        quiz.start()
        #expect(quiz.phase == .loading)
        quiz.finishReading()

        await waitUntil { spy.latest.waitingCount == 1 }
        spy.latest.resume(returning: .fixture())
        await waitUntil { quiz.phase == .answering }
        #expect(quiz.isReading)
    }

    @Test func readingTimeFollowsPassageAndRoundAgeGroup() async throws {
        let quiz = await startedQuiz()
        let exercise = try #require(quiz.currentExercise)
        #expect(quiz.readingTime == settings.ageGroup.readingTime(wordCount: exercise.passage.wordCount))
    }
}
