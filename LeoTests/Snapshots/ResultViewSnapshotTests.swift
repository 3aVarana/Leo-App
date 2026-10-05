import SnapshotTesting
import SwiftUI
import Testing
@testable import Leo

extension ViewSnapshots {
    @MainActor
    @Suite
    struct ResultViewSnapshotTests {
        /// Together these cover every symbol and every message.
        @Test(arguments: [6, 5, 3, 0])
        func correct(_ correct: Int) {
            assertViewSnapshot(of: ResultView(correct: correct, total: 6, onRestart: {}), named: "\(correct)-of-6")
        }

        @Test func dark() {
            assertViewSnapshot(of: ResultView(correct: 5, total: 6, onRestart: {}), named: "5-of-6-dark", colorScheme: .dark)
        }

        @Test func accessibilitySize() {
            assertViewSnapshot(of: ResultView(correct: 5, total: 6, onRestart: {}), named: "5-of-6-ax", sizeCategory: .accessibilityExtraExtraExtraLarge)
        }
    }
}
