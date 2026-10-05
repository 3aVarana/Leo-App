import SnapshotTesting
import SwiftUI
import Testing
@testable import Leo

extension ViewSnapshots {
    @MainActor
    @Suite
    struct SettingsViewSnapshotTests {
        private let testDefaults = TestDefaults()

        private var settings: some View {
            SettingsView(preferences: .fixture(ageGroup: .twelve, custom: [.twelve: ["Chess"]]))
                .environment(PreferencesStore(defaults: testDefaults.defaults))
        }

        @Test func light() {
            assertViewSnapshot(of: settings, named: "12-14", height: 1300)
        }

        @Test func dark() {
            assertViewSnapshot(of: settings, named: "12-14-dark", colorScheme: .dark, height: 1300)
        }
    }
}
