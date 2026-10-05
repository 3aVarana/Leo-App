import Testing
@testable import Leo

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
}
