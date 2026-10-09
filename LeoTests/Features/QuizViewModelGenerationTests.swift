@testable import Leo
import Testing

/// How `QuizViewModel` keeps generating after a failed exercise, replaces it, and retries by hand.
@MainActor
struct QuizViewModelGenerationTests {
    private let settings = RoundSettings(
        ageGroup: .nine,
        topics: ["owls", "rivers", "kites", "bread", "comets", "drums"],
    )
    private let failure = Result<Exercise, any Error>.failure(ExerciseGenerationError.failed)

    private func makeQuiz(_ spy: ExerciseRepositoryFactorySpy) -> QuizViewModel {
        QuizViewModel { spy.make($0) }
    }

    /// Answers the current exercise and moves on, correctly or not.
    private func answer(_ quiz: QuizViewModel, correctly: Bool) {
        let exercise = quiz.currentExercise!
        quiz.finishReading()
        quiz.select(correctly ? exercise.correctIndex : (exercise.correctIndex + 1) % exercise.options.count)
        quiz.next()
    }
}

// MARK: - Failure and replacement

extension QuizViewModelGenerationTests {
    @Test func failureWhileWaitingShowsNextReady() async {
        let spy = ExerciseRepositoryFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        quiz.start()
        await waitUntil { spy.latest.waitingCount == 1 }

        spy.latest.resume(with: failure)
        await waitUntil { spy.latest.waitingCount == 1 }
        #expect(quiz.phase == .loading)
        #expect(spy.latest.calls.count == 2)

        spy.latest.resume(returning: .fixture(title: "Second"))
        await waitUntil { quiz.phase == .answering }
        #expect(quiz.currentIndex == 0)
        #expect(quiz.currentExercise?.title == "Second")
    }

    @Test func failureIsReplacedWithSameSkill() async {
        let spy = ExerciseRepositoryFactorySpy { .scripted("S F S S S S S") }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == 7 }
        await settle()
        let calls = spy.latest.calls
        #expect(calls.count == 7)
        #expect(calls[6].skill == calls[1].skill)
        #expect(Set(calls[6].topics).isDisjoint(with: calls[1].topics))

        quiz.start()
        for _ in 0 ..< QuizViewModel.exerciseCount {
            #expect(quiz.phase == .answering)
            answer(quiz, correctly: true)
        }
        #expect(quiz.phase == .finished)
    }

    @Test func generationContinuesAfterFailure() async {
        let spy = ExerciseRepositoryFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        let stub = spy.latest
        await waitUntil { stub.waitingCount == 1 }
        stub.resume(with: failure)

        for count in 2 ... QuizViewModel.exerciseCount {
            await waitUntil { stub.waitingCount == 1 }
            #expect(stub.calls.count == count)
            stub.resume(returning: .fixture())
        }
        await waitUntil { stub.waitingCount == 1 }
        #expect(stub.calls.count == 7)
        #expect(stub.calls[6].skill == stub.calls[0].skill)
    }

    /// The reader waits on the second exercise; it fails and they get the third one in its place.
    @Test func readerGetsNextReadyExercise() async {
        let spy = ExerciseRepositoryFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        let stub = spy.latest
        await waitUntil { stub.waitingCount == 1 }
        stub.resume(returning: .fixture(title: "First"))
        await waitUntil { stub.waitingCount == 1 }
        quiz.start()
        answer(quiz, correctly: true)
        #expect(quiz.phase == .loading)

        stub.resume(with: failure)
        await waitUntil { stub.waitingCount == 1 }
        #expect(quiz.phase == .loading)
        stub.resume(returning: .fixture(title: "Third"))
        await waitUntil { quiz.phase == .answering }
        #expect(quiz.currentIndex == 1)
        #expect(quiz.currentExercise?.title == "Third")
    }

    @Test func replacementLimitIsThreePerRound() async {
        let spy = ExerciseRepositoryFactorySpy { .scripted("S F S S S S F F F") }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == 9 }
        await settle()
        #expect(spy.latest.calls.count == 9)
        #expect(spy.latest.waitingCount == 0)
        #expect(quiz.jobCount == QuizViewModel.exerciseCount)

        quiz.start()
        for _ in 0 ..< QuizViewModel.exerciseCount - 1 {
            #expect(quiz.phase == .answering)
            answer(quiz, correctly: true)
        }
        #expect(quiz.currentIndex == 5)
        #expect(quiz.phase == .failed)
    }

    /// Jobs 1 to 4 fail, using up the replacements on the first 3, and jobs 5 and 6 still run.
    /// The replacement of job 1 fails too, so the round ends 2 exercises short.
    @Test func failureAfterLimitStillGeneratesTheRest() async {
        let spy = ExerciseRepositoryFactorySpy { .scripted("F F F F S S F S") }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        let stub = spy.latest
        await waitUntil { stub.waitingCount == 1 }
        #expect(stub.calls.count == 9)
        stub.resume(returning: .fixture())
        await settle()
        #expect(stub.calls.count == 9)
        #expect(quiz.jobCount == QuizViewModel.exerciseCount)

        quiz.start()
        for _ in 0 ..< 4 {
            #expect(quiz.phase == .answering)
            answer(quiz, correctly: true)
        }
        #expect(quiz.currentIndex == 4)
        #expect(quiz.phase == .failed)
    }

    @Test func failureShowsWhenReaderReachesIt() async {
        let spy = ExerciseRepositoryFactorySpy { .scripted("S F S S S S F F F") }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == 9 }
        quiz.start()
        await settle()
        #expect(quiz.phase == .answering)

        for _ in 0 ..< QuizViewModel.exerciseCount - 2 {
            answer(quiz, correctly: true)
        }
        quiz.finishReading()
        quiz.select(0)
        #expect(quiz.phase == .answering)
        quiz.next()
        #expect(quiz.phase == .failed)
    }

    @Test func jobCountInvariant() async {
        let spy = ExerciseRepositoryFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        let stub = spy.latest
        #expect(quiz.jobCount == QuizViewModel.exerciseCount)

        // Jobs 1, 3 and 4 are replaced, job 5 isn't, and the replacement of job 4 fails.
        for succeeds in [false, true, false, false, false, true, true, true, false] {
            await waitUntil { stub.waitingCount == 1 }
            #expect(quiz.jobCount == QuizViewModel.exerciseCount)
            stub.resume(with: succeeds ? .success(.fixture()) : failure)
        }
        await settle()
        #expect(quiz.jobCount == QuizViewModel.exerciseCount)
        #expect(stub.calls.count == 9)

        quiz.start()
        for _ in 0 ..< 4 {
            answer(quiz, correctly: true)
        }
        #expect(quiz.phase == .failed)

        quiz.retry()
        for succeeds in [true, false] {
            await waitUntil { stub.waitingCount == 1 }
            #expect(quiz.jobCount == QuizViewModel.exerciseCount)
            stub.resume(with: succeeds ? .success(.fixture()) : failure)
        }
        await settle()
        #expect(quiz.jobCount == QuizViewModel.exerciseCount)
        #expect(stub.calls.count == 11)
    }
}

// MARK: - Retry

extension QuizViewModelGenerationTests {
    /// A quiz showing the failure of its last exercise: the second exercise and its 3 replacements fail.
    private func quizFailedAtLastExercise(
        _ spy: ExerciseRepositoryFactorySpy = ExerciseRepositoryFactorySpy { .scripted("S F S S S S F F F") },
    ) async -> QuizViewModel {
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == 9 }
        quiz.start()
        for _ in 0 ..< QuizViewModel.exerciseCount - 1 {
            answer(quiz, correctly: true)
        }
        return quiz
    }

    @Test func retryGeneratesFailedExerciseAgain() async {
        let spy = ExerciseRepositoryFactorySpy { .scripted("S F S S S S F F F") }
        let quiz = await quizFailedAtLastExercise(spy)
        #expect(quiz.phase == .failed)
        let stub = spy.latest
        let failedCall = stub.calls[8]

        quiz.retry()
        #expect(quiz.phase == .loading)
        await waitUntil { stub.waitingCount == 1 }
        #expect(stub.calls.count == 10)
        #expect(stub.calls[9] == failedCall)

        stub.resume(returning: .fixture(title: "Retried"))
        await waitUntil { quiz.phase == .answering }
        #expect(quiz.currentIndex == 5)
        #expect(quiz.currentExercise?.title == "Retried")
        #expect(spy.settings.count == 1)
    }

    /// A failed retry shows the failure again without an automatic replacement, and a second
    /// retry makes one call again.
    @Test func manualRetryDoesNotUseOrResetLimit() async {
        let spy = ExerciseRepositoryFactorySpy { .scripted("S F S S S S F F F") }
        let quiz = await quizFailedAtLastExercise(spy)
        let stub = spy.latest

        for calls in [10, 11] {
            quiz.retry()
            await waitUntil { stub.waitingCount == 1 }
            stub.resume(with: failure)
            await waitUntil { quiz.phase == .failed }
            await settle()
            #expect(stub.calls.count == calls)
            #expect(stub.waitingCount == 0)
        }
    }

    /// Job 2 and 3 fail, and so do the replacements: two failed jobs are left, and a retry
    /// requests both. The first succeeds and the reader answers it; the second fails again.
    @Test func manualRetryRequeuesEveryFailedJob() async {
        let spy = ExerciseRepositoryFactorySpy { .scripted("S F F S S S F F F") }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == 9 }
        quiz.start()
        for _ in 0 ..< 4 {
            answer(quiz, correctly: true)
        }
        #expect(quiz.phase == .failed)
        let stub = spy.latest
        let failedCalls = Array(stub.calls[7 ... 8])

        quiz.retry()
        await waitUntil { stub.waitingCount == 1 }
        stub.resume(returning: .fixture(title: "Retried"))
        await waitUntil { quiz.phase == .answering }
        #expect(quiz.currentIndex == 4)
        #expect(quiz.currentExercise?.title == "Retried")

        await waitUntil { stub.waitingCount == 1 }
        #expect(Array(stub.calls[9 ... 10]) == failedCalls)
        stub.resume(with: failure)
        await settle()
        answer(quiz, correctly: true)
        #expect(quiz.currentIndex == 5)
        #expect(quiz.phase == .failed)
    }

    @Test func retryWhenRoundIsGeneratedDoesNothing() async {
        let spy = ExerciseRepositoryFactorySpy { .ready() }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.calls.count == QuizViewModel.exerciseCount }

        quiz.retry()
        await settle()
        #expect(quiz.phase == .welcome)
        #expect(spy.latest.calls.count == QuizViewModel.exerciseCount)
    }

    @Test func retryWhileGeneratingDoesNothing() async {
        let spy = ExerciseRepositoryFactorySpy { .scripted("F") }
        let quiz = makeQuiz(spy)
        quiz.configure(settings)
        await waitUntil { spy.latest.waitingCount == 1 }

        quiz.retry()
        quiz.retryWithDifferentTopics()
        await settle()
        #expect(quiz.phase == .welcome)
        #expect(spy.latest.calls.count == 2)
        #expect(spy.latest.cancelledCount == 0)
    }
}
