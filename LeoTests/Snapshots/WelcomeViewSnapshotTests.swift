@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct WelcomeViewSnapshotTests {
        private let topics = ["Volcanoes", "The solar system", "Pirates and treasure", "Inventors", "Rainforests"]

        private func welcome(_ group: AgeGroup, topics: [String]) -> some View {
            WelcomeView(ageGroup: group, topicNames: topics, onStart: {}, onSettings: {})
        }

        /// Different `displayName` lengths.
        @Test(arguments: [AgeGroup.six, .adult])
        func ageGroup(_ group: AgeGroup) {
            assertViewSnapshot(of: welcome(group, topics: topics), named: "\(group)")
        }

        /// Three topics or fewer are all named.
        @Test func fewTopics() {
            assertViewSnapshot(of: welcome(.nine, topics: ["Volcanoes", "Inventors"]), named: "two-topics")
        }

        /// Before the round is planned.
        @Test func noTopicsYet() {
            assertViewSnapshot(of: welcome(.nine, topics: []), named: "no-topics")
        }

        @Test func accessibilitySize() {
            assertViewSnapshot(
                of: welcome(.six, topics: topics),
                named: "six-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge,
                height: 1700,
            )
        }
    }
}
