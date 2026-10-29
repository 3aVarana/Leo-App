import Foundation
@testable import Leo
import Testing

/// Rounds of other sizes than the default: 3 to 9 texts, set by `RoundSettings.exerciseCount`.
@MainActor
struct QuizViewModelRoundSizeTests {
    private let topics: [RoundTopic] = ["owls", "rivers", "kites", "bread", "comets", "drums"]

    private func settings(_ count: Int) -> RoundSettings {
        RoundSettings(ageGroup: .nine, topics: topics, exerciseCount: count)
    }

    private func makeQuiz(
        _ spy: ExerciseRepositoryFactorySpy,
        onRoundFinished: @escaping (RoundRecord) -> Void = { _ in },
    ) -> QuizViewModel {
        QuizViewModel(makeRepository: { spy.make($0) }, onRoundFinished: onRoundFinished)
    }

    /// Answers the current exercise and moves on.
    private func answer(_ quiz: QuizViewModel) {
        let exercise = quiz.currentExercise!
        quiz.finishReading()
        quiz.select(exercise.correctIndex)
        quiz.next()
    }

    @Test(arguments: [3, 4, 9])
    func fullRoundOfAnySize(count: Int) async {
        var finished: [RoundRecord] = []
        let spy = ExerciseRepositoryFactorySpy { .ready(count: count) }
        let quiz = makeQuiz(spy, onRoundFinished: { finished.append($0) })
        quiz.configure(settings(count))
        await waitUntil { spy.latest.calls.count == count }
        #expect(quiz.exerciseCount == count)
        #expect((0 ..< count).map(quiz.dotState(at:)) == Array(repeating: .upcoming, count: count))

        quiz.start()
        for index in 0 ..< count {
            #expect(quiz.phase == .answering)
            #expect(quiz.isLastExercise == (index == count - 1))
            answer(quiz)
        }

        #expect(quiz.phase == .finished)
        #expect(quiz.answers.count == count)
        #expect(finished.count == 1)
        #expect(finished.first?.answers.count == count)
        #expect((0 ..< count).map(quiz.dotState(at:)) == Array(repeating: .done, count: count))
    }

    @Test func plannedRoundHasTheSettingsCount() {
        let quiz = makeQuiz(ExerciseRepositoryFactorySpy())
        quiz.configure(settings(9))
        #expect(quiz.exerciseCount == 9)
        #expect(quiz.plannedTopicNames.count == topics.count)
    }

    /// Settings saved from Welcome or Results with another round size prepare a new round of that size.
    @Test func newCountPreparesANewRound() async {
        let spy = ExerciseRepositoryFactorySpy { .ready() }
        let quiz = makeQuiz(spy)
        quiz.configure(settings(6))
        await waitUntil { spy.latest.calls.count == 6 }
        #expect(quiz.exerciseCount == 6)

        quiz.configure(settings(9))
        #expect(spy.settings == [settings(6), settings(9)])
        #expect(quiz.exerciseCount == 9)
    }

    @Test func sameCountKeepsTheRound() async {
        let spy = ExerciseRepositoryFactorySpy()
        let quiz = makeQuiz(spy)
        quiz.configure(settings(4))
        quiz.configure(settings(4))
        await settle()
        #expect(spy.settings == [settings(4)])
    }

    /// Results keeps showing the finished round after the count changes, and Practice again
    /// gives a round of the new size.
    @Test func resultsKeepTheOldRoundAfterACountChange() async {
        let spy = ExerciseRepositoryFactorySpy { .ready(count: 3) }
        let quiz = makeQuiz(spy)
        quiz.configure(settings(3))
        await waitUntil { spy.latest.calls.count == 3 }
        quiz.start()
        for _ in 0 ..< 3 {
            answer(quiz)
        }

        quiz.configure(settings(5))
        #expect(quiz.phase == .finished)
        #expect(quiz.answers.count == 3)

        quiz.start()
        #expect(quiz.exerciseCount == 5)
        #expect(quiz.answers.isEmpty)
    }
}
