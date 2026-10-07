@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct SettingsViewSnapshotTests {
        private func settings(_ preferences: ReaderPreferences) -> some View {
            SettingsView(viewModel: .fixture(draft: preferences))
        }

        @Test func screen() {
            let preferences = ReaderPreferences.fixture(
                ageGroup: .twelve,
                disabled: [.twelve: ["mythology"]],
                custom: [.twelve: ["Chess"]],
            )
            assertViewSnapshot(of: settings(preferences), named: "12-14", height: 1000)
        }

        /// The fewest suggested topics, and no Reset.
        @Test func sixToEight() {
            assertViewSnapshot(of: settings(ReaderPreferences(ageGroup: .six)), named: "6-8", height: 1000)
        }

        /// 25 suggested topics.
        @Test func fifteenToSeventeen() {
            assertViewSnapshot(of: settings(ReaderPreferences(ageGroup: .fifteen)), named: "15-17", height: 1200)
        }

        /// The age segments give way to a menu.
        @Test func accessibilitySize() {
            assertViewSnapshot(
                of: settings(ReaderPreferences(ageGroup: .twelve)),
                named: "12-14-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge,
                height: 2700,
            )
        }
    }
}
