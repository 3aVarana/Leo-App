/// How one dot of `ProgressDots` is drawn. `QuizViewModel.dotState(at:)` decides it.
enum DotState: Equatable {
    /// A text already answered. Neutral, whatever the answer was.
    case done
    /// The text being written or read.
    case current
    /// The current text, answered correctly, while its feedback shows.
    case currentCorrect
    /// The current text, answered wrongly, while its feedback shows.
    case currentMissed
    /// The text that couldn't be written.
    case failed
    case upcoming
}
