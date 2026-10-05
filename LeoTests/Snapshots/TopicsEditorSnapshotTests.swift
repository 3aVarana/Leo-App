@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct TopicsEditorSnapshotTests {
        private func editor(_ preferences: ReaderPreferences) -> some View {
            List {
                TopicsEditor(preferences: .constant(preferences), group: preferences.ageGroup)
            }
        }

        private var customizedPreferences: ReaderPreferences {
            .fixture(
                ageGroup: .nine,
                disabled: [.nine: ["volcanoes", "pirates-treasure"]],
                custom: [.nine: ["Chess", "Origami"]],
            )
        }

        /// Every suggested topic in `.six` turned off except the last 3.
        private var minimumPreferences: ReaderPreferences {
            let ids = DefaultTopics.topics(for: .six).map(\.id)
            return .fixture(ageGroup: .six, disabled: [.six: Set(ids.dropLast(3))])
        }

        @Test func defaults() {
            assertViewSnapshot(of: editor(ReaderPreferences(ageGroup: .nine)), named: "9-11-defaults", height: 1250)
        }

        /// "Reset suggested topics" shows once a suggested topic is off.
        @Test func customized() {
            assertViewSnapshot(of: editor(customizedPreferences), named: "9-11-customized", height: 1250)
        }

        /// The footer shows, and the topics still on can't be turned off.
        @Test func atMinimum() {
            assertViewSnapshot(of: editor(minimumPreferences), named: "6-8-minimum", height: 1250)
        }
    }
}
