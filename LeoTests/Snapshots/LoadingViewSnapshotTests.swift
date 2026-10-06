@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct LoadingViewSnapshotTests {
        private func dots(current index: Int) -> [DotState] {
            (0 ..< QuizViewModel.exerciseCount).map { $0 < index ? .done : $0 == index ? .current : .upcoming }
        }

        @Test(arguments: [0, 5])
        func index(_ index: Int) {
            let view = LoadingView(index: index, dots: dots(current: index), topicName: "Volcanoes", ageGroup: .nine)
            assertViewSnapshot(of: view, named: "\(index + 1)-of-6")
        }

        /// A long topic name wraps in the headline.
        @Test func longTopic() {
            let view = LoadingView(
                index: 1,
                dots: dots(current: 1),
                topicName: "A short fictional story about a teenager facing a challenge",
                ageGroup: .fifteen,
            )
            assertViewSnapshot(of: view, named: "long-topic")
        }

        @Test func accessibilitySize() {
            let view = LoadingView(index: 1, dots: dots(current: 1), topicName: "Volcanoes", ageGroup: .nine)
            assertViewSnapshot(
                of: view,
                named: "2-of-6-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge,
                height: 1700,
            )
        }
    }
}
