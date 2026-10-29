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
                height: 2400,
            )
        }

        @Test func firstScreen() {
            let view = OnboardingView(viewModel: .fixture(draft: ReaderPreferences(ageGroup: .fifteen)))
            assertViewSnapshot(of: view, named: "first-screen")
        }

        /// The second screen as it's pushed, with the system back button.
        @Test(arguments: [AgeGroup.nine, .fifteen])
        func topicsScreen(_ group: AgeGroup) {
            let view = NavigationStack {
                OnboardingTopics(viewModel: .fixture(draft: ReaderPreferences(ageGroup: group)))
            }
            assertViewSnapshot(of: view, named: "topics-\(group)", height: group == .fifteen ? 1450 : nil)
        }

        /// The round section below the topics, as `OnboardingTopics` uses it. The whole topics screen at this
        /// text size is taller than the 2700 points a snapshot can capture before it comes out blank.
        @Test func roundRowAccessibilitySize() {
            let view = OnboardingRoundSection(count: .constant(RoundSettings.defaultExerciseCount))
                .foregroundStyle(Color.leoInk)
                .leoReadableWidth()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .leoScreenBackground()
            assertViewSnapshot(
                of: view,
                named: "round-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge,
                height: 700,
            )
        }
    }
}
