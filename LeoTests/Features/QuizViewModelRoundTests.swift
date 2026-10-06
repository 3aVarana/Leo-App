@testable import Leo
import Testing

/// What `QuizViewModel` exposes about a round for the redesigned screens: the answer history,
/// the progress dots and the topic names.
@MainActor
struct QuizViewModelRoundTests {
    private let settings = RoundSettings(
        ageGroup: .nine,
        topics: ["owls", "rivers", "kites", "bread", "comets", "drums"],
    )
    private let otherSettings = RoundSettings(ageGroup: .twelve, topics: ["chess", "glaciers", "radios"])

    private func makeQuiz(_ spy: ExerciseRepositoryFactorySpy = ExerciseRepositoryFactorySpy()) -> QuizViewModel {
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

    private let failure = Result<Exercise, any Error>.failure(ExerciseGenerationError.failed)

    /// A quiz showing the failure of its second exercise.
    private func quizFailedAtSecondExercise(
        _ spy: ExerciseRepositoryFactorySpy = ExerciseRepositoryFactorySpy {
            StubExerciseRepository(results: [.success(.fixture()), .failure(ExerciseGenerationError.failed)])
        },
    ) async -> QuizViewModel {
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == 2 }
        quiz.start()
        quiz.select(0)
        quiz.next()
        return quiz
    }

    /// Answers the current exercise and moves on, correctly or not.
    private func answer(_ quiz: QuizViewModel, correctly: Bool) {
        let exercise = quiz.currentExercise!
        quiz.select(correctly ? exercise.correctIndex : (exercise.correctIndex + 1) % exercise.options.count)
        quiz.next()
    }
}

// MARK: - Round history

extension QuizViewModelRoundTests {
    @Test func recordsAnswers() async throws {
        let quiz = await startedQuiz()
        for correctly in [true, false, true, true, false, true] {
            answer(quiz, correctly: correctly)
        }
        #expect(quiz.answers.map(\.index) == Array(0 ..< QuizViewModel.exerciseCount))
        #expect(quiz.answers.map(\.isCorrect) == [true, false, true, true, false, true])
        #expect(quiz.misses.map(\.index) == [1, 4])
        #expect(quiz.roundAgeGroup == .nine)
        let miss = try #require(quiz.misses.first)
        #expect(miss.selectedOption != miss.exercise.correctIndex)
        #expect(miss.exercise.title == "Exercise 2")
    }

    /// Saving settings from Results prepares a new round, but Results and Review keep showing this one.
    @Test func historySurvivesNewSettings() async {
        let quiz = await startedQuiz()
        for correctly in [true, false, true, true, false, true] {
            answer(quiz, correctly: correctly)
        }
        quiz.configure(otherSettings)
        #expect(quiz.phase == .finished)
        #expect(quiz.answers.count == QuizViewModel.exerciseCount)
        #expect(quiz.correctCount == 4)
        #expect(quiz.roundAgeGroup == .nine)
    }

    @Test func startClearsHistory() async {
        let spy = ExerciseRepositoryFactorySpy { .ready() }
        let quiz = await startedQuiz(spy)
        for _ in 0 ..< QuizViewModel.exerciseCount {
            answer(quiz, correctly: false)
        }
        quiz.configure(otherSettings)
        quiz.start()
        #expect(quiz.answers.isEmpty)
        #expect(quiz.roundAgeGroup == .twelve)
    }
}

// MARK: - Progress dots

extension QuizViewModelRoundTests {
    private func dots(_ quiz: QuizViewModel) -> [DotState] {
        (0 ..< QuizViewModel.exerciseCount).map(quiz.dotState(at:))
    }

    @Test func dotsOnWelcome() {
        let quiz = makeQuiz()
        #expect(dots(quiz) == Array(repeating: .upcoming, count: 6))
    }

    @Test func dotsWhileAnswering() async throws {
        let quiz = await startedQuiz()
        #expect(dots(quiz) == [.current, .upcoming, .upcoming, .upcoming, .upcoming, .upcoming])

        let exercise = try #require(quiz.currentExercise)
        quiz.select((exercise.correctIndex + 1) % exercise.options.count)
        #expect(dots(quiz) == [.currentMissed, .upcoming, .upcoming, .upcoming, .upcoming, .upcoming])

        quiz.next()
        #expect(dots(quiz) == [.done, .current, .upcoming, .upcoming, .upcoming, .upcoming])

        try quiz.select(#require(quiz.currentExercise?.correctIndex))
        #expect(dots(quiz) == [.done, .currentCorrect, .upcoming, .upcoming, .upcoming, .upcoming])
    }

    @Test func dotsWhileLoading() {
        let spy = ExerciseRepositoryFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        quiz.start()
        #expect(quiz.phase == .loading)
        #expect(dots(quiz) == [.current, .upcoming, .upcoming, .upcoming, .upcoming, .upcoming])
    }

    @Test func dotsAfterFailure() async {
        let quiz = await quizFailedAtSecondExercise()
        #expect(quiz.phase == .failed)
        #expect(dots(quiz) == [.done, .failed, .upcoming, .upcoming, .upcoming, .upcoming])
    }

    @Test func dotsWhenFinished() async {
        let quiz = await startedQuiz()
        for _ in 0 ..< QuizViewModel.exerciseCount {
            answer(quiz, correctly: true)
        }
        #expect(dots(quiz) == Array(repeating: .done, count: 6))
    }
}

// MARK: - Topic names

extension QuizViewModelRoundTests {
    /// Six topics give six different main topics, named as the reader sees them.
    @Test func plannedTopicNames() {
        let spy = ExerciseRepositoryFactorySpy()
        let quiz = makeQuiz(spy)
        #expect(quiz.plannedTopicNames.isEmpty)

        quiz.configure(settings)
        #expect(Set(quiz.plannedTopicNames) == Set(settings.topics.map(\.name)))
        #expect(quiz.plannedTopicNames.count == QuizViewModel.exerciseCount)
        #expect(quiz.plannedTopicName(at: 0) == quiz.plannedTopicNames.first)
        #expect(quiz.plannedTopicName(at: QuizViewModel.exerciseCount) == nil)
    }

    /// Three topics for six exercises: each name is listed once.
    @Test func plannedTopicNamesHaveNoRepeats() {
        let quiz = makeQuiz()
        quiz.configure(otherSettings)
        #expect(quiz.plannedTopicNames.count == 3)
        #expect(Set(quiz.plannedTopicNames) == Set(otherSettings.topics.map(\.name)))
    }

    @Test func writingTopicNameFollowsFallback() async throws {
        let spy = ExerciseRepositoryFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        quiz.start()
        await waitUntil { spy.latest.waitingCount == 1 }
        let call = spy.latest.calls[0]
        #expect(quiz.writingTopicName == call.topics[0].name)

        let report = try #require(spy.latest.attemptHandlers.first)
        report(call.topics[1])
        #expect(quiz.writingTopicName == call.topics[1].name)

        spy.latest.resume(returning: .fixture())
        await waitUntil { spy.latest.waitingCount == 1 }
        #expect(quiz.writingTopicName == spy.latest.calls[1].topics[0].name)
    }

    /// A late fallback report from a replaced round doesn't change the name.
    @Test func writingTopicNameIgnoresReplacedRound() async throws {
        let spy = ExerciseRepositoryFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.waitingCount == 1 }
        let first = spy.latest
        let report = try #require(first.attemptHandlers.first)

        quiz.configure(otherSettings)
        await waitUntil { spy.latest.waitingCount == 1 }
        let current = quiz.writingTopicName
        report("owls")
        #expect(quiz.writingTopicName == current)
    }
}

// MARK: - Retry with different topics

extension QuizViewModelRoundTests {
    @Test func retryWithDifferentTopicsAvoidsFailedTopics() async {
        let spy = ExerciseRepositoryFactorySpy { StubExerciseRepository(results: [.success(.fixture()), failure]) }
        let quiz = await quizFailedAtSecondExercise(spy)
        let stub = spy.latest
        let failedCall = stub.calls[1]

        quiz.retryWithDifferentTopics()
        #expect(quiz.phase == .loading)
        await waitUntil { stub.waitingCount == 1 }
        let retryCall = stub.calls[2]
        #expect(retryCall.skill == failedCall.skill)
        #expect(retryCall.topics.count == 3)
        #expect(Set(retryCall.topics).isDisjoint(with: failedCall.topics))
        #expect(Set(retryCall.topics).isSubset(of: settings.topics))

        stub.resume(returning: .fixture(title: "Retried"))
        await waitUntil { quiz.phase == .answering }
        #expect(quiz.currentExercise?.title == "Retried")
    }

    /// With only the 3 topics that failed, they're tried again in another order.
    @Test func retryWithDifferentTopicsWithoutOthers() async {
        let spy = ExerciseRepositoryFactorySpy { StubExerciseRepository(results: [failure]) }
        let quiz = makeQuiz(spy)
        quiz.configure(otherSettings)
        quiz.start()
        await waitUntil { quiz.phase == .failed }
        let stub = spy.latest

        quiz.retryWithDifferentTopics()
        await waitUntil { stub.waitingCount == 1 }
        #expect(Set(stub.calls[1].topics) == Set(otherSettings.topics))
    }
}
