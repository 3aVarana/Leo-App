@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct GenerationFailedViewSnapshotTests {
        private func failed(at index: Int) -> some View {
            let dots = (0 ..< QuizViewModel.exerciseCount).map { i -> DotState in
                i < index ? .done : i == index ? .failed : .upcoming
            }
            return GenerationFailedView(
                index: index,
                dots: dots,
                topicName: "Volcanoes",
                onRetry: {},
                onTryDifferentTopic: {},
            )
        }

        /// Text 1 has no earlier answers, text 2 one, text 3 several: each has its own reassurance.
        @Test(arguments: [0, 1, 2])
        func index(_ index: Int) {
            assertViewSnapshot(of: failed(at: index), named: "text-\(index + 1)")
        }

        @Test func accessibilitySize() {
            assertViewSnapshot(
                of: failed(at: 1),
                named: "text-2-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge,
                height: 2000,
            )
        }
    }
}
