import Foundation
@testable import Leo
import Testing

@MainActor
struct QuizViewModelTests {
    private func expectStartingState(_ quiz: QuizViewModel, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(quiz.phase == .welcome, sourceLocation: sourceLocation)
        #expect(quiz.currentIndex == 0, sourceLocation: sourceLocation)
        #expect(quiz.currentExercise == nil, sourceLocation: sourceLocation)
        #expect(quiz.selectedOption == nil, sourceLocation: sourceLocation)
        #expect(quiz.correctCount == 0, sourceLocation: sourceLocation)
        #expect(!quiz.isLastExercise, sourceLocation: sourceLocation)
        #expect(quiz.isAnswerCorrect == nil, sourceLocation: sourceLocation)
        #expect(!quiz.isReading, sourceLocation: sourceLocation)
        #expect(quiz.readingTime == nil, sourceLocation: sourceLocation)
        #expect(quiz.optionState(at: 0) == .idle, sourceLocation: sourceLocation)
    }

    /// A quiz whose repository is never used.
    private func makeQuiz() -> QuizViewModel {
        QuizViewModel { _ in StubExerciseRepository() }
    }

    @Test func startingState() {
        expectStartingState(makeQuiz())
    }

    @Test func startBeforeConfigure() {
        let quiz = makeQuiz()
        quiz.start()
        expectStartingState(quiz)
    }

    @Test func selectWithoutExercise() {
        let quiz = makeQuiz()
        quiz.select(0)
        expectStartingState(quiz)
    }

    @Test func nextWithoutSelection() {
        let quiz = makeQuiz()
        quiz.next()
        expectStartingState(quiz)
    }

    @Test func retryBeforeConfigure() {
        let quiz = makeQuiz()
        quiz.retry()
        expectStartingState(quiz)
    }

    // MARK: - With a stub repository

    private let settings = RoundSettings(
        ageGroup: .nine,
        topics: ["owls", "rivers", "kites", "bread", "comets", "drums"],
    )
    private let otherSettings = RoundSettings(ageGroup: .twelve, topics: ["chess", "glaciers", "radios"])

    private func makeQuiz(_ spy: ExerciseRepositoryFactorySpy) -> QuizViewModel {
        QuizViewModel { spy.make($0) }
    }

    /// Starts a round whose 6 exercises are ready, and waits until they are.
    private func startedQuiz(_ spy: ExerciseRepositoryFactorySpy? = nil) async -> QuizViewModel {
        let spy = spy ?? ExerciseRepositoryFactorySpy { .ready() }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == QuizViewModel.exerciseCount }
        quiz.start()
        return quiz
    }

    /// Answers the current exercise and moves on, correctly or not.
    private func answer(_ quiz: QuizViewModel, correctly: Bool) {
        let exercise = quiz.currentExercise!
        quiz.finishReading()
        quiz.select(correctly ? exercise.correctIndex : (exercise.correctIndex + 1) % exercise.options.count)
        quiz.next()
    }
}

// MARK: - Configure

extension QuizViewModelTests {
    @Test func configureStartsGenerating() async {
        let spy = ExerciseRepositoryFactorySpy()
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
        let spy = ExerciseRepositoryFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        quiz.configure(settings)
        await settle()
        #expect(spy.settings == [settings])
        #expect(spy.latest.calls.count == 1)
    }

    @Test func configureWithNewSettingsCancelsEarlierRound() async {
        let spy = ExerciseRepositoryFactorySpy()
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
        var stubs = [StubExerciseRepository(ignoresCancellation: true), StubExerciseRepository()]
        let spy = ExerciseRepositoryFactorySpy { stubs.removeFirst() }
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
}

// MARK: - Generation order

extension QuizViewModelTests {
    @Test func generatesOneAtATime() async {
        let spy = ExerciseRepositoryFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        let stub = spy.latest

        for index in 0 ..< QuizViewModel.exerciseCount {
            await waitUntil { stub.waitingCount == 1 }
            await settle()
            #expect(stub.calls.count == index + 1)
            stub.resume(returning: .fixture())
        }
        await settle()
        #expect(stub.calls.count == QuizViewModel.exerciseCount)
    }

    @Test func generatesWholeRoundBeforeStart() async {
        let spy = ExerciseRepositoryFactorySpy { .ready() }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == QuizViewModel.exerciseCount }
        await settle()
        #expect(spy.latest.calls.count == QuizViewModel.exerciseCount)
        #expect(quiz.phase == .welcome)
    }
}

// MARK: - Start

extension QuizViewModelTests {
    @Test func startBeforeFirstExerciseIsReady() async {
        let spy = ExerciseRepositoryFactorySpy()
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
        let spy = ExerciseRepositoryFactorySpy { .ready() }
        _ = await startedQuiz(spy)
        await settle()
        #expect(spy.settings.count == 1)
        #expect(spy.latest.calls.count == QuizViewModel.exerciseCount)
    }
}

// MARK: - Answering

extension QuizViewModelTests {
    @Test func selectCorrectAnswer() async throws {
        let quiz = await startedQuiz()
        let exercise = try #require(quiz.currentExercise)
        quiz.finishReading()
        quiz.select(exercise.correctIndex)
        #expect(quiz.selectedOption == exercise.correctIndex)
        #expect(quiz.correctCount == 1)
    }

    @Test func secondSelectionIsIgnored() async throws {
        let quiz = await startedQuiz()
        let exercise = try #require(quiz.currentExercise)
        let wrong = (exercise.correctIndex + 1) % exercise.options.count
        quiz.finishReading()
        quiz.select(wrong)
        quiz.select(exercise.correctIndex)
        #expect(quiz.selectedOption == wrong)
        #expect(quiz.correctCount == 0)
    }

    @Test func selectWrongAnswer() async throws {
        let quiz = await startedQuiz()
        let exercise = try #require(quiz.currentExercise)
        quiz.finishReading()
        quiz.select((exercise.correctIndex + 1) % exercise.options.count)
        #expect(quiz.correctCount == 0)
    }
}

// MARK: - Next

extension QuizViewModelTests {
    @Test func nextShowsNextExercise() async {
        let quiz = await startedQuiz()
        quiz.finishReading()
        quiz.select(0)
        quiz.next()
        #expect(quiz.phase == .answering)
        #expect(quiz.currentIndex == 1)
        #expect(quiz.currentExercise?.title == "Exercise 2")
        #expect(quiz.selectedOption == nil)
    }

    @Test func nextWaitsForExerciseThatIsNotReady() async {
        let spy = ExerciseRepositoryFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.waitingCount == 1 }
        spy.latest.resume(returning: .fixture(title: "First"))
        await waitUntil { spy.latest.waitingCount == 1 }
        quiz.start()
        quiz.finishReading()
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
        for index in 0 ..< QuizViewModel.exerciseCount - 1 {
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
}

// MARK: - Practice again

extension QuizViewModelTests {
    @Test func practiceAgainStartsNewRound() async {
        let spy = ExerciseRepositoryFactorySpy { .ready() }
        let quiz = await startedQuiz(spy)
        for _ in 0 ..< QuizViewModel.exerciseCount {
            answer(quiz, correctly: true)
        }
        #expect(quiz.phase == .finished)

        quiz.start()
        #expect(spy.settings == [settings, settings])
        #expect(quiz.currentIndex == 0)
        #expect(quiz.correctCount == 0)
        await waitUntil { quiz.phase == .answering }
    }

    /// Each round gets 3 automatic replacements, however many the one before used.
    @Test func newRoundResetsReplacementLimit() async {
        let spy = ExerciseRepositoryFactorySpy { .scripted("F F F S S S S S S") }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        for round in 1 ... 2 {
            await waitUntil { spy.latest.calls.count == 9 }
            if round == 1 {
                quiz.start()
            }
            await waitUntil { quiz.phase == .answering }
            for _ in 0 ..< QuizViewModel.exerciseCount {
                #expect(quiz.phase == .answering, "round \(round)")
                answer(quiz, correctly: true)
            }
            #expect(quiz.phase == .finished, "round \(round)")
            if round == 1 {
                quiz.start()
            }
        }
        #expect(spy.stubs.count == 2)
    }
}
