import SnapshotTesting
import SwiftUI
import Testing
@testable import Leo

extension ViewSnapshots {
    @MainActor
    @Suite
    struct WelcomeViewSnapshotTests {
        /// Different `displayName` lengths.
        @Test(arguments: [AgeGroup.six, .adult])
        func ageGroup(_ group: AgeGroup) {
            assertViewSnapshot(of: WelcomeView(ageGroup: group, onStart: {}), named: "\(group)")
        }

        @Test func dark() {
            assertViewSnapshot(of: WelcomeView(ageGroup: .six, onStart: {}), named: "six-dark", colorScheme: .dark)
        }

        @Test func accessibilitySize() {
            assertViewSnapshot(of: WelcomeView(ageGroup: .six, onStart: {}), named: "six-ax", sizeCategory: .accessibilityExtraExtraExtraLarge)
        }
    }
}
