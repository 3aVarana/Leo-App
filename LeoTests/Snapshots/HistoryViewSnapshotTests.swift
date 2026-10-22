@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct HistoryViewSnapshotTests {
        private var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            calendar.firstWeekday = 2
            return calendar
        }

        private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9, minute: Int = 12) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
        }

        private func history(now: Date, results: [[Bool]]) -> some View {
            let repository = RoundHistoryRepositorySpy()
            let viewModel = RoundHistoryViewModel(repository: repository, calendar: calendar, now: { now })
            viewModel.ageGroup = .nine
            for (offset, roundResults) in results.enumerated() {
                let finishedAt = offset == 0 ? now : date(2026, 2, 10 - offset)
                viewModel.record(.fixture(ageGroup: .nine, finishedAt: finishedAt, results: roundResults))
            }
            return NavigationStack {
                HistoryView(viewModel: viewModel)
            }
        }

        /// This week, last week and an older month.
        @Test func threeSections() throws {
            let now = date(2026, 3, 20)
            let thisWeek = try #require(calendar.dateInterval(of: .weekOfYear, for: now)?.start
                .addingTimeInterval(3600))
            let lastWeekAnchor = try #require(calendar.date(byAdding: .weekOfYear, value: -1, to: now))
            let lastWeek = try #require(calendar.dateInterval(of: .weekOfYear, for: lastWeekAnchor)?.start
                .addingTimeInterval(3600))
            let repository = RoundHistoryRepositorySpy()
            let viewModel = RoundHistoryViewModel(repository: repository, calendar: calendar, now: { now })
            viewModel.ageGroup = .nine
            viewModel.record(.fixture(ageGroup: .nine, finishedAt: now, results: [true, true, true, true, true, true]))
            viewModel.record(
                .fixture(ageGroup: .nine, finishedAt: thisWeek, results: [false, true, true, false, true, true]),
            )
            viewModel.record(
                .fixture(ageGroup: .nine, finishedAt: lastWeek, results: [true, true, false, true, true, true]),
            )
            let olderResults = [false, false, false, true, true, true]
            viewModel.record(.fixture(ageGroup: .nine, finishedAt: date(2026, 2, 10), results: olderResults))
            let view = NavigationStack { HistoryView(viewModel: viewModel) }
            assertViewSnapshot(of: view, named: "three-sections", height: 1700)
        }

        /// One round: the summary line uses the singular, and there's one section.
        @Test func oneRound() {
            let now = date(2026, 3, 20)
            let view = history(now: now, results: [[true, true, true, true, true, false]])
            assertViewSnapshot(of: view, named: "one-round")
        }

        @Test func accessibilitySize() {
            let now = date(2026, 3, 20)
            assertViewSnapshot(
                of: history(now: now, results: [[false, true, true, true, true, true]]),
                named: "one-round-ax",
                sizeCategory: .accessibilityExtraExtraExtraLarge,
                height: 1100,
            )
        }
    }
}
