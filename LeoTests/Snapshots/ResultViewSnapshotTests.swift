@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

/// A round's answers, `true` for each text answered correctly. Titles are taken from `titles`.
@MainActor
func roundAnswers(_ results: [Bool], titles: [String] = ResultViewSnapshotTitles.english) -> [RoundAnswer] {
    results.enumerated().map { index, isCorrect in
        let exercise = Exercise.fixture(title: titles[index % titles.count])
        let wrong = (exercise.correctIndex + 1) % exercise.options.count
        return RoundAnswer(index: index, exercise: exercise, selectedOption: isCorrect ? exercise.correctIndex : wrong)
    }
}

enum ResultViewSnapshotTitles {
    static let english = [
        "The Sleeping Mountain",
        "Pirates of the Silver Bay",
        "Exploring the Sun and Planets",
        "The Inventor's Notebook",
        "A Walk Through the Rainforest Canopy at Dawn",
        "Ancient Egypt's Lost City",
    ]
}

extension ViewSnapshots {
    @MainActor
    struct ResultViewSnapshotTests {
        private func results(_ correct: [Bool]) -> some View {
            NavigationStack {
                ResultView(answers: roundAnswers(correct), ageGroup: .nine, onRestart: {}, onSettings: {})
                    .toolbar(.hidden, for: .navigationBar)
            }
        }

        /// Together these cover every message: 6/6 has no Review rows, 0/6 only Review rows.
        @Test(arguments: [
            ("6", [true, true, true, true, true, true]),
            ("5", [false, true, true, true, true, true]),
            ("3", [true, false, true, false, false, true]),
            ("0", [false, false, false, false, false, false]),
        ])
        func correct(_ name: String, _ answers: [Bool]) {
            assertViewSnapshot(of: results(answers), named: "\(name)-of-6", height: 1000)
        }

        /// The rows stack, without leaders.
        @Test func accessibilitySize() {
            assertViewSnapshot(
                of: results([false, true, true, true, true, true]),
                named: "5-of-6-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge,
                height: 2700,
            )
        }
    }
}
