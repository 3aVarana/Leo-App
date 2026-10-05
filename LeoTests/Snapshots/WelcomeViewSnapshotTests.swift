@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct WelcomeViewSnapshotTests {
        /// Different `displayName` lengths.
        @Test(arguments: [AgeGroup.six, .adult])
        func ageGroup(_ group: AgeGroup) {
            assertViewSnapshot(of: WelcomeView(ageGroup: group, onStart: {}), named: "\(group)")
        }

        @Test func accessibilitySize() {
            assertViewSnapshot(
                of: WelcomeView(ageGroup: .six, onStart: {}),
                named: "six-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge,
            )
        }
    }
}
