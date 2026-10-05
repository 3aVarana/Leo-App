import SnapshotTesting
import SwiftUI
import Testing
@testable import Leo

extension ViewSnapshots {
    @MainActor
    @Suite
    struct OnboardingSnapshotTests {
        private let testDefaults = TestDefaults()

        /// Continue is disabled until an age group is picked.
        @Test func pickerWithoutSelection() {
            assertViewSnapshot(of: AgeGroupPicker(selection: .constant(nil), onContinue: {}), named: "none")
        }

        @Test func pickerWithSelection() {
            assertViewSnapshot(of: AgeGroupPicker(selection: .constant(.twelve), onContinue: {}), named: "12-14")
        }

        @Test func pickerAccessibilitySize() {
            assertViewSnapshot(
                of: AgeGroupPicker(selection: .constant(.twelve), onContinue: {}),
                named: "12-14-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge
            )
        }

        @Test func firstScreen() {
            let view = OnboardingView()
                .environment(PreferencesStore(defaults: testDefaults.defaults))
            assertViewSnapshot(of: view, named: "first-screen")
        }
    }
}
