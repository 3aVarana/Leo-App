@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct OnboardingSnapshotTests {
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
                sizeCategory: .accessibilityExtraExtraExtraLarge,
            )
        }

        @Test func firstScreen() {
            assertViewSnapshot(of: OnboardingView { _ in }, named: "first-screen")
        }
    }
}
