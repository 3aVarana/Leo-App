/// An exercise of the round and the option the reader picked, for Results and Review.
struct RoundAnswer: Identifiable {
    /// The exercise's 0-based position in the round.
    let index: Int
    let exercise: Exercise
    let selectedOption: Int

    var id: Int {
        index
    }

    var isCorrect: Bool {
        selectedOption == exercise.correctIndex
    }
}
