@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct RoundViewSnapshotTests {
        private func round(results: [Bool]) -> some View {
            let repository = RoundHistoryRepositorySpy()
            let viewModel = RoundHistoryViewModel(repository: repository)
            let record = RoundRecord.fixture(ageGroup: .nine, results: results)
            viewModel.ageGroup = .nine
            viewModel.record(record)
            return NavigationStack {
                RoundView(id: record.id, viewModel: viewModel)
            }
        }

        @Test func twoMissed() {
            let view = round(results: [true, false, true, true, false, true])
            assertViewSnapshot(of: view, named: "2-missed", height: 1700)
        }

        /// No misses: no bottom button.
        @Test func sixOfSix() {
            assertViewSnapshot(of: round(results: [true, true, true, true, true, true]), named: "6-of-6", height: 1500)
        }

        @Test func accessibilitySize() {
            assertViewSnapshot(
                of: round(results: [true, false, true, true, false, true]),
                named: "2-missed-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge,
                height: 2700,
            )
        }
    }
}
