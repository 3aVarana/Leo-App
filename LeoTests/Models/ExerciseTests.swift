import Testing
@testable import Leo

@MainActor
struct ExerciseTests {
    private let accepted = AgeGroup.six.acceptedWordCount

    private func exercise(_ generated: GeneratedExercise) -> Exercise? {
        Exercise(generated: generated, topic: "foxes", skill: .detail, acceptedWordCount: accepted)
    }

    @Test(arguments: [
        ["Into a cave", "Up a tree"],
        ["Into a cave", "Up a tree", "Under a bridge"],
    ])
    func validInput(incorrectAnswers: [String]) throws {
        let exercise = try #require(exercise(.fixture(correctAnswer: "Across a field", incorrectAnswers: incorrectAnswers)))

        #expect(exercise.options.count == incorrectAnswers.count + 1)
        #expect(Set(exercise.options) == Set(incorrectAnswers + ["Across a field"]))
        #expect(exercise.options[exercise.correctIndex] == "Across a field")
        #expect(exercise.options.filter { $0 == "Across a field" }.count == 1)
        #expect(exercise.topic == "foxes")
        #expect(exercise.skill == .detail)
    }

    @Test func trimsWhitespaceAndNewlines() throws {
        let exercise = try #require(exercise(.fixture(
            title: "  The Quiet Field\n",
            passage: "\n " + .words(60) + " \n",
            question: "\tWhere did the fox run? ",
            correctAnswer: " Across a field\n",
            incorrectAnswers: ["  Into a cave", "Up a tree\n"],
            explanation: "\nBecause the passage says so.  "
        )))

        #expect(exercise.title == "The Quiet Field")
        #expect(exercise.passage == .words(60))
        #expect(exercise.question == "Where did the fox run?")
        #expect(Set(exercise.options) == ["Across a field", "Into a cave", "Up a tree"])
        #expect(exercise.options[exercise.correctIndex] == "Across a field")
        #expect(exercise.explanation == "Because the passage says so.")
    }

    @Test func dropsEmptyDistractors() throws {
        let exercise = try #require(exercise(.fixture(incorrectAnswers: ["Into a cave", "", "  \n", "Up a tree"])))
        #expect(Set(exercise.options) == ["Across a field", "Into a cave", "Up a tree"])
    }

    @Test func dropsDuplicateDistractorsIgnoringCase() throws {
        let exercise = try #require(exercise(.fixture(correctAnswer: "Madrid", incorrectAnswers: ["Paris", "paris", "Rome"])))
        #expect(exercise.options.count == 3)
        #expect(Set(exercise.options) == ["Madrid", "Paris", "Rome"])
    }

    @Test func dropsDistractorEqualToCorrectAnswerIgnoringCase() throws {
        let exercise = try #require(exercise(.fixture(correctAnswer: "Madrid", incorrectAnswers: ["MADRID", "Paris", "Rome"])))
        #expect(Set(exercise.options) == ["Madrid", "Paris", "Rome"])
    }

    @Test func tooFewDistractorsAfterDroppingCorrectAnswer() {
        #expect(exercise(.fixture(correctAnswer: "Madrid", incorrectAnswers: ["madrid", "Paris"])) == nil)
    }

    @Test(arguments: [
        ["Into a cave"],
        ["Into a cave", "Up a tree", "Under a bridge", "Over the hill"],
    ])
    func wrongDistractorCount(incorrectAnswers: [String]) {
        #expect(exercise(.fixture(incorrectAnswers: incorrectAnswers)) == nil)
    }

    @Test(arguments: ["", "  \n"])
    func emptyCorrectAnswer(_ answer: String) {
        #expect(exercise(.fixture(correctAnswer: answer)) == nil)
    }

    @Test(arguments: ["", "  \n"])
    func emptyQuestion(_ question: String) {
        #expect(exercise(.fixture(question: question)) == nil)
    }

    @Test(arguments: [
        (AgeGroup.six.acceptedWordCount.lowerBound, true),
        (AgeGroup.six.acceptedWordCount.upperBound, true),
        (AgeGroup.six.acceptedWordCount.lowerBound - 1, false),
        (AgeGroup.six.acceptedWordCount.upperBound + 1, false),
    ])
    func passageWordCount(words: Int, isAccepted: Bool) {
        #expect((exercise(.fixture(passage: .words(words))) != nil) == isAccepted)
    }

    @Test func emptyExplanationIsAccepted() throws {
        let exercise = try #require(exercise(.fixture(explanation: "  ")))
        #expect(exercise.explanation == "")
    }

    /// Locks current behavior: a missing title doesn't make the exercise unusable.
    @Test(arguments: ["", "  \n"])
    func emptyTitleIsAccepted(_ title: String) throws {
        let exercise = try #require(exercise(.fixture(title: title)))
        #expect(exercise.title == "")
    }

    @Test func nonRandomInitKeepsValues() {
        let exercise = Exercise.fixture(options: ["A", "B", "C"], correctIndex: 2)
        #expect(exercise.options == ["A", "B", "C"])
        #expect(exercise.correctIndex == 2)
        #expect(exercise.title == "The Sleeping Mountain")
    }

    /// The app, not the model, decides where the correct answer lands. The chance of a false
    /// failure is about 4 × (3/4)^200.
    @Test func correctAnswerLandsInEveryPosition() throws {
        var positions: Set<Int> = []
        for _ in 0..<200 {
            let exercise = try #require(exercise(.fixture()))
            positions.insert(exercise.correctIndex)
        }
        #expect(positions == [0, 1, 2, 3])
    }
}
