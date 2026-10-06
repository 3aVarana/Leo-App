@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct SettingsViewSnapshotTests {
        private var settings: some View {
            SettingsView(preferences: .fixture(ageGroup: .twelve, custom: [.twelve: ["Chess"]])) { _ in }
        }

        @Test func screen() {
            assertViewSnapshot(of: settings, named: "12-14", height: 1300)
        }
    }
}
