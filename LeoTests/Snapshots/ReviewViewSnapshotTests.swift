@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct ReviewViewSnapshotTests {
        /// Review as Results pushes it, with the system back button.
        private func review(_ misses: [RoundAnswer], start: Int = 0) -> some View {
            NavigationStack {
                Color.clear
                    .navigationTitle(Text("Results"))
                    .navigationDestination(isPresented: .constant(true)) {
                        ReviewView(misses: misses, startIndex: start)
                    }
            }
        }

        private func misses(_ results: [Bool]) -> [RoundAnswer] {
            roundAnswers(results).filter { !$0.isCorrect }
        }

        /// The only miss: "Back to results".
        @Test func oneMiss() {
            assertViewSnapshot(of: review(misses([false, true, true, true, true, true])), named: "1-of-1", height: 1300)
        }

        /// The second of three misses: "Next missed text".
        @Test func secondOfThree() {
            let misses = misses([true, false, true, false, false, true])
            assertViewSnapshot(of: review(misses, start: 1), named: "2-of-3", height: 1300)
        }

        @Test func withoutExplanation() {
            let exercise = Exercise.fixture(explanation: "")
            let miss = RoundAnswer(index: 2, exercise: exercise, selectedOption: 0)
            assertViewSnapshot(of: review([miss]), named: "no-explanation", height: 1300)
        }

        @Test func accessibilitySize() {
            assertViewSnapshot(
                of: review(misses([false, true, true, true, true, true])),
                named: "1-of-1-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge,
                height: 2700,
            )
        }
    }
}
