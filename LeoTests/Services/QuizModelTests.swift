import Foundation
@testable import Leo
import Testing

@MainActor
struct QuizModelTests {
    private func expectStartingState(_ quiz: QuizModel, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(quiz.phase == .welcome, sourceLocation: sourceLocation)
        #expect(quiz.currentIndex == 0, sourceLocation: sourceLocation)
        #expect(quiz.currentExercise == nil, sourceLocation: sourceLocation)
        #expect(quiz.selectedOption == nil, sourceLocation: sourceLocation)
        #expect(quiz.correctCount == 0, sourceLocation: sourceLocation)
        #expect(!quiz.isLastExercise, sourceLocation: sourceLocation)
    }

    @Test func startingState() {
        expectStartingState(QuizModel())
    }

    @Test func startBeforeConfigure() {
        let quiz = QuizModel()
        quiz.start()
        expectStartingState(quiz)
    }

    @Test func selectWithoutExercise() {
        let quiz = QuizModel()
        quiz.select(0)
        expectStartingState(quiz)
    }

    @Test func nextWithoutSelection() {
        let quiz = QuizModel()
        quiz.next()
        expectStartingState(quiz)
    }

    @Test func retryBeforeConfigure() {
        let quiz = QuizModel()
        quiz.retry()
        expectStartingState(quiz)
    }

    // MARK: - With a stub generator

    private let settings = RoundSettings(ageGroup: .nine, topics: ["owls", "rivers", "kites", "bread", "comets", "drums"])
    private let otherSettings = RoundSettings(ageGroup: .twelve, topics: ["chess", "glaciers", "radios"])
    private let failure = Result<Exercise, any Error>.failure(ExerciseGenerationError.failed)

    private func makeQuiz(_ spy: GeneratorFactorySpy) -> QuizModel {
        QuizModel { spy.make($0) }
    }

    /// Starts a round whose 6 exercises are ready, and waits until they are.
    private func startedQuiz(_ spy: GeneratorFactorySpy? = nil) async -> QuizModel {
        let spy = spy ?? GeneratorFactorySpy { .ready() }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == QuizModel.exerciseCount }
        quiz.start()
        return quiz
    }

    /// Answers the current exercise and moves on, correctly or not.
    private func answer(_ quiz: QuizModel, correctly: Bool) {
        let exercise = quiz.currentExercise!
        quiz.select(correctly ? exercise.correctIndex : (exercise.correctIndex + 1) % exercise.options.count)
        quiz.next()
    }

    // MARK: Configure

    @Test func configureStartsGenerating() async {
        let spy = GeneratorFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)

        #expect(spy.settings == [settings])
        await waitUntil { spy.latest.calls.count == 1 }
        let call = spy.latest.calls[0]
        #expect(call.topics.count == 3)
        #expect(Set(call.topics).isSubset(of: settings.topics))
        #expect(quiz.phase == .welcome)
    }

    @Test func configureWithSameSettingsKeepsRound() async {
        let spy = GeneratorFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        quiz.configure(settings)
        await settle()
        #expect(spy.settings == [settings])
        #expect(spy.latest.calls.count == 1)
    }

    @Test func configureWithNewSettingsCancelsEarlierRound() async {
        let spy = GeneratorFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.waitingCount == 1 }
        let first = spy.latest

        quiz.configure(otherSettings)
        #expect(spy.settings == [settings, otherSettings])
        await waitUntil { first.cancelledCount == 1 }
        await waitUntil { spy.latest.calls.count == 1 }
        #expect(Set(spy.latest.calls[0].topics).isSubset(of: otherSettings.topics))
    }

    @Test func lateResultOfEarlierRoundIsNotShown() async {
        var stubs = [StubGenerator(ignoresCancellation: true), StubGenerator()]
        let spy = GeneratorFactorySpy { stubs.removeFirst() }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.waitingCount == 1 }
        let first = spy.latest

        quiz.configure(otherSettings)
        quiz.start()
        first.resume(returning: .fixture(title: "Late"))
        await settle()
        #expect(quiz.phase == .loading)
        #expect(first.calls.count == 1)

        await waitUntil { spy.latest.waitingCount == 1 }
        spy.latest.resume(returning: .fixture(title: "New"))
        await waitUntil { quiz.phase == .answering }
        #expect(quiz.currentExercise?.title == "New")
    }

    // MARK: Generation order

    @Test func generatesOneAtATime() async {
        let spy = GeneratorFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        let stub = spy.latest

        for index in 0 ..< QuizModel.exerciseCount {
            await waitUntil { stub.waitingCount == 1 }
            await settle()
            #expect(stub.calls.count == index + 1)
            stub.resume(returning: .fixture())
        }
        await settle()
        #expect(stub.calls.count == QuizModel.exerciseCount)
    }

    @Test func generatesWholeRoundBeforeStart() async {
        let spy = GeneratorFactorySpy { .ready() }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == QuizModel.exerciseCount }
        await settle()
        #expect(spy.latest.calls.count == QuizModel.exerciseCount)
        #expect(quiz.phase == .welcome)
    }

    // MARK: Start

    @Test func startBeforeFirstExerciseIsReady() async {
        let spy = GeneratorFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        quiz.start()
        #expect(quiz.phase == .loading)
        #expect(quiz.currentExercise == nil)

        await waitUntil { spy.latest.waitingCount == 1 }
        spy.latest.resume(returning: .fixture(title: "First"))
        await waitUntil { quiz.phase == .answering }
        #expect(quiz.currentExercise?.title == "First")
        #expect(quiz.currentIndex == 0)
    }

    @Test func startWhenFirstExerciseIsReady() async {
        let quiz = await startedQuiz()
        #expect(quiz.phase == .answering)
        #expect(quiz.currentExercise?.title == "Exercise 1")
    }

    @Test func startUsesPreparedRound() async {
        let spy = GeneratorFactorySpy { .ready() }
        _ = await startedQuiz(spy)
        await settle()
        #expect(spy.settings.count == 1)
        #expect(spy.latest.calls.count == QuizModel.exerciseCount)
    }

    // MARK: Answering

    @Test func selectCorrectAnswer() async throws {
        let quiz = await startedQuiz()
        let exercise = try #require(quiz.currentExercise)
        quiz.select(exercise.correctIndex)
        #expect(quiz.selectedOption == exercise.correctIndex)
        #expect(quiz.correctCount == 1)
    }

    @Test func secondSelectionIsIgnored() async throws {
        let quiz = await startedQuiz()
        let exercise = try #require(quiz.currentExercise)
        let wrong = (exercise.correctIndex + 1) % exercise.options.count
        quiz.select(wrong)
        quiz.select(exercise.correctIndex)
        #expect(quiz.selectedOption == wrong)
        #expect(quiz.correctCount == 0)
    }

    @Test func selectWrongAnswer() async throws {
        let quiz = await startedQuiz()
        let exercise = try #require(quiz.currentExercise)
        quiz.select((exercise.correctIndex + 1) % exercise.options.count)
        #expect(quiz.correctCount == 0)
    }

    // MARK: Next

    @Test func nextShowsNextExercise() async {
        let quiz = await startedQuiz()
        quiz.select(0)
        quiz.next()
        #expect(quiz.phase == .answering)
        #expect(quiz.currentIndex == 1)
        #expect(quiz.currentExercise?.title == "Exercise 2")
        #expect(quiz.selectedOption == nil)
    }

    @Test func nextWaitsForExerciseThatIsNotReady() async {
        let spy = GeneratorFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.waitingCount == 1 }
        spy.latest.resume(returning: .fixture(title: "First"))
        await waitUntil { spy.latest.waitingCount == 1 }
        quiz.start()
        quiz.select(0)

        quiz.next()
        #expect(quiz.phase == .loading)
        #expect(quiz.currentIndex == 1)
        #expect(quiz.selectedOption == nil)

        spy.latest.resume(returning: .fixture(title: "Second"))
        await waitUntil { quiz.phase == .answering }
        #expect(quiz.currentExercise?.title == "Second")
    }

    @Test func lastExerciseFinishesRound() async {
        let quiz = await startedQuiz()
        for index in 0 ..< QuizModel.exerciseCount - 1 {
            #expect(!quiz.isLastExercise, "index \(index)")
            answer(quiz, correctly: true)
        }
        #expect(quiz.currentIndex == 5)
        #expect(quiz.isLastExercise)
        answer(quiz, correctly: true)
        #expect(quiz.phase == .finished)
    }

    @Test func countsCorrectAnswers() async {
        let quiz = await startedQuiz()
        for correctly in [true, false, true, true, false, true] {
            answer(quiz, correctly: correctly)
        }
        #expect(quiz.phase == .finished)
        #expect(quiz.correctCount == 4)
    }

    // MARK: Failure and retry

    @Test func failureWhileWaiting() async {
        let spy = GeneratorFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        quiz.start()
        await waitUntil { spy.latest.waitingCount == 1 }

        spy.latest.resume(with: failure)
        await waitUntil { quiz.phase != .loading }
        #expect(quiz.phase == .failed(ExerciseGenerationError.failed.localizedDescription))
        await settle()
        #expect(spy.latest.calls.count == 1)
    }

    @Test func failureShowsWhenReaderReachesIt() async {
        let spy = GeneratorFactorySpy { StubGenerator(results: [.success(.fixture()), failure]) }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == 2 }
        quiz.start()
        await settle()
        #expect(quiz.phase == .answering)
        #expect(spy.latest.calls.count == 2)

        quiz.select(0)
        #expect(quiz.phase == .answering)
        quiz.next()
        #expect(quiz.phase == .failed(ExerciseGenerationError.failed.localizedDescription))
    }

    @Test func retryGeneratesFailedExerciseAgain() async {
        let spy = GeneratorFactorySpy { StubGenerator(results: [.success(.fixture()), failure]) }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == 2 }
        quiz.start()
        quiz.select(0)
        quiz.next()
        let stub = spy.latest
        let failedCall = stub.calls[1]

        quiz.retry()
        #expect(quiz.phase == .loading)
        await waitUntil { stub.waitingCount == 1 }
        let retryCall = stub.calls[2]
        #expect(retryCall.skill == failedCall.skill)
        #expect((1 ... 3).contains(retryCall.topics.count))
        #expect(Set(retryCall.topics).isSubset(of: settings.topics))

        stub.resume(returning: .fixture(title: "Retried"))
        await waitUntil { quiz.phase == .answering }
        #expect(quiz.currentIndex == 1)
        #expect(quiz.currentExercise?.title == "Retried")
        #expect(spy.settings.count == 1)
    }

    @Test func retryWhenRoundIsGeneratedDoesNothing() async {
        let spy = GeneratorFactorySpy { .ready() }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == QuizModel.exerciseCount }

        quiz.retry()
        await settle()
        #expect(quiz.phase == .welcome)
        #expect(spy.latest.calls.count == QuizModel.exerciseCount)
    }

    // MARK: Practice again

    @Test func practiceAgainStartsNewRound() async {
        let spy = GeneratorFactorySpy { .ready() }
        let quiz = await startedQuiz(spy)
        for _ in 0 ..< QuizModel.exerciseCount {
            answer(quiz, correctly: true)
        }
        #expect(quiz.phase == .finished)

        quiz.start()
        #expect(spy.settings == [settings, settings])
        #expect(quiz.currentIndex == 0)
        #expect(quiz.correctCount == 0)
        await waitUntil { quiz.phase == .answering }
    }
}
