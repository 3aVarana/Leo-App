import Foundation
@testable import Leo
import Testing

@MainActor
struct RoundHistoryViewModelTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeViewModel(
        repository: RoundHistoryRepositorySpy = RoundHistoryRepositorySpy(),
        now: Date,
    ) -> RoundHistoryViewModel {
        RoundHistoryViewModel(repository: repository, calendar: calendar, now: { now })
    }
}

// MARK: - Age group and totals

extension RoundHistoryViewModelTests {
    @Test func hasRoundsFollowsTheAgeGroup() {
        let viewModel = makeViewModel(now: date(2026, 3, 20))
        viewModel.ageGroup = .nine
        viewModel.record(.fixture(ageGroup: .nine))
        #expect(viewModel.hasRounds)

        viewModel.ageGroup = .twelve
        #expect(!viewModel.hasRounds)

        viewModel.ageGroup = .nine
        #expect(viewModel.hasRounds)
    }

    @Test func ageGroupChangeReloads() {
        let viewModel = makeViewModel(now: date(2026, 3, 20))
        viewModel.ageGroup = .nine
        viewModel.record(.fixture(ageGroup: .nine))
        viewModel.ageGroup = .twelve
        viewModel.record(.fixture(ageGroup: .twelve))

        viewModel.ageGroup = .nine
        #expect(viewModel.roundCount == 1)
        viewModel.ageGroup = .twelve
        #expect(viewModel.roundCount == 1)
        viewModel.ageGroup = .six
        #expect(viewModel.roundCount == 0)
    }

    @Test func totals() {
        let viewModel = makeViewModel(now: date(2026, 3, 20))
        viewModel.ageGroup = .nine
        #expect(viewModel.roundCount == 0)
        #expect(viewModel.correctShare == 0)

        viewModel.record(.fixture(ageGroup: .nine, results: [true, false, true, true, false, true])) // 4 of 6
        viewModel.record(.fixture(ageGroup: .nine, results: [true, true, true])) // 3 of 3

        #expect(viewModel.roundCount == 2)
        #expect(viewModel.correctShare == 7.0 / 9.0)
    }

    @Test func recordForAnotherAgeGroupDoesNotShow() {
        let viewModel = makeViewModel(now: date(2026, 3, 20))
        viewModel.ageGroup = .nine
        viewModel.record(.fixture(ageGroup: .twelve))
        #expect(!viewModel.hasRounds)
        #expect(viewModel.roundCount == 0)
    }

    @Test func deleteReloads() {
        let viewModel = makeViewModel(now: date(2026, 3, 20))
        viewModel.ageGroup = .nine
        let round = RoundRecord.fixture(ageGroup: .nine)
        viewModel.record(round)
        #expect(viewModel.roundCount == 1)

        viewModel.delete(id: round.id)
        #expect(viewModel.roundCount == 0)
        #expect(viewModel.round(id: round.id) == nil)
    }

    @Test func saveFailureKeepsTheList() {
        let repository = RoundHistoryRepositorySpy()
        let viewModel = makeViewModel(repository: repository, now: date(2026, 3, 20))
        viewModel.ageGroup = .nine
        viewModel.record(.fixture(ageGroup: .nine))
        #expect(viewModel.roundCount == 1)

        repository.errorToThrow = NSError(domain: "RoundHistoryViewModelTests", code: 1)
        viewModel.record(.fixture(ageGroup: .nine))
        #expect(viewModel.roundCount == 1)
    }
}

// MARK: - Sections

extension RoundHistoryViewModelTests {
    @Test func sectionsGroupByWeekThenMonth() throws {
        let now = date(2026, 3, 20)
        let viewModel = makeViewModel(now: now)
        viewModel.ageGroup = .nine

        let thisWeek = try #require(calendar.dateInterval(of: .weekOfYear, for: now))
        let thisWeekDate = thisWeek.start.addingTimeInterval(3600)
        let lastWeekAnchor = try #require(calendar.date(byAdding: .weekOfYear, value: -1, to: now))
        let lastWeek = try #require(calendar.dateInterval(of: .weekOfYear, for: lastWeekAnchor))
        let lastWeekDate = lastWeek.start.addingTimeInterval(3600)
        let thisMonth = try #require(calendar.dateInterval(of: .month, for: now))
        let earlierThisMonthDate = thisMonth.start.addingTimeInterval(3600)
        let olderMonthDate = date(2026, 2, 10)
        let olderMonthStart = try #require(calendar.dateInterval(of: .month, for: olderMonthDate)).start
        let lastYearDate = date(2025, 12, 5)
        let lastYearMonthStart = try #require(calendar.dateInterval(of: .month, for: lastYearDate)).start
        // No round falls in January 2026: its section must be left out entirely.
        let skippedMonthStart = try #require(calendar.dateInterval(of: .month, for: date(2026, 1, 15))).start

        for date in [thisWeekDate, lastWeekDate, earlierThisMonthDate, olderMonthDate, lastYearDate] {
            viewModel.record(.fixture(ageGroup: .nine, finishedAt: date))
        }

        let sections = viewModel.sections
        #expect(sections.map(\.kind) == [
            .thisWeek,
            .lastWeek,
            .earlierThisMonth(thisMonth.start),
            .month(olderMonthStart, showsYear: false),
            .month(lastYearMonthStart, showsYear: true),
        ])
        #expect(sections.map(\.rounds.count) == [1, 1, 1, 1, 1])
        #expect(!sections.map(\.kind).contains(.month(skippedMonthStart, showsYear: false)))
    }

    /// When last week reaches back into the previous month, a round from those days is still
    /// "Last week", not grouped under that older month.
    @Test func lastWeekWinsOverThePreviousMonth() throws {
        let now = date(2026, 3, 3)
        let viewModel = makeViewModel(now: now)
        viewModel.ageGroup = .nine

        let lastWeekAnchor = try #require(calendar.date(byAdding: .weekOfYear, value: -1, to: now))
        let lastWeekStart = try #require(calendar.dateInterval(of: .weekOfYear, for: lastWeekAnchor)).start
        // This case only exists to test when last week reaches into February.
        #expect(calendar.component(.month, from: lastWeekStart) == 2)

        viewModel.record(.fixture(ageGroup: .nine, finishedAt: lastWeekStart.addingTimeInterval(3600)))
        #expect(viewModel.sections.map(\.kind) == [.lastWeek])
    }
}

// MARK: - Month names

extension RoundHistoryViewModelTests {
    /// The month's first day at midnight in `calendar` is still that month, whatever the device's
    /// time zone: west of UTC it would otherwise read as the month before.
    @Test func monthNameFollowsTheCalendarTimeZone() {
        let viewModel = makeViewModel(now: date(2026, 3, 20))
        #expect(viewModel.monthName(date(2026, 2, 1)) == viewModel.monthName(date(2026, 2, 15)))
        #expect(viewModel.monthName(date(2026, 2, 1)) != viewModel.monthName(date(2026, 1, 31)))
    }

    @Test func monthNameShowsTheYearOnlyWhenAsked() {
        let viewModel = makeViewModel(now: date(2026, 3, 20))
        #expect(!viewModel.monthName(date(2025, 12, 1)).contains("2025"))
        #expect(viewModel.monthName(date(2025, 12, 1), showingYear: true).contains("2025"))
    }
}
