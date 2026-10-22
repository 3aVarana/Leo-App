import Foundation
import Observation
import OSLog

/// One group of rounds in the History list, newest group first.
struct HistorySection: Equatable {
    enum Kind: Equatable {
        case thisWeek
        case lastWeek
        /// Earlier in the current month, not in `.thisWeek` or `.lastWeek`. The month's first day.
        case earlierThisMonth(Date)
        /// A past month. The month's first day.
        case month(Date)
    }

    let kind: Kind
    var rounds: [RoundSummary]
}

/// The reader's finished rounds at one age group (H7): the History list and its totals.
@Observable
final class RoundHistoryViewModel {
    /// The age group History is showing. `nil` before onboarding. Setting it reloads `summaries`.
    var ageGroup: AgeGroup? {
        didSet {
            guard ageGroup != oldValue else { return }
            reload()
        }
    }

    private(set) var summaries: [RoundSummary] = []

    private let repository: any RoundHistoryRepository
    private let calendar: Calendar
    private let now: () -> Date
    private let logger = Logger(subsystem: "Leo", category: "RoundHistoryViewModel")

    init(
        repository: any RoundHistoryRepository,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init,
    ) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
    }

    /// Drives the entry button (H6): hidden before there's a saved round to show.
    var hasRounds: Bool {
        !summaries.isEmpty
    }

    var roundCount: Int {
        summaries.count
    }

    /// The share of every answer, across every round, that was right. `0` with no rounds.
    var correctShare: Double {
        let total = summaries.reduce(into: 0) { $0 += $1.results.count }
        guard total > 0 else { return 0 }
        let correct = summaries.reduce(into: 0) { $0 += $1.correctCount }
        return Double(correct) / Double(total)
    }

    /// `summaries` grouped by week, then month, as in `docs/Leo-Round-History-Plan.md` 1.2.
    /// A section with no rounds is left out; "Last week" wins over "Earlier in <month>" when
    /// they overlap.
    var sections: [HistorySection] {
        var sections: [HistorySection] = []
        for summary in summaries {
            let kind = sectionKind(for: summary.finishedAt)
            if sections.indices.last.map({ sections[$0].kind == kind }) == true {
                sections[sections.count - 1].rounds.append(summary)
            } else {
                sections.append(HistorySection(kind: kind, rounds: [summary]))
            }
        }
        return sections
    }

    /// Saves `round`; reloads `summaries` when it was read at the current age group.
    func record(_ round: RoundRecord) {
        do {
            try repository.save(round)
        } catch {
            logger.error("Couldn't save the finished round: \(error)")
            return
        }
        if round.ageGroup == ageGroup {
            reload()
        }
    }

    /// For the round page. `nil` when it was deleted or can't be read.
    func round(id: UUID) -> RoundRecord? {
        do {
            return try repository.round(id: id)
        } catch {
            logger.error("Couldn't read round \(id): \(error)")
            return nil
        }
    }

    func delete(id: UUID) {
        do {
            try repository.delete(id: id)
        } catch {
            logger.error("Couldn't delete round \(id): \(error)")
            return
        }
        reload()
    }

    private func reload() {
        guard let ageGroup else {
            summaries = []
            return
        }
        do {
            summaries = try repository.summaries(for: ageGroup)
        } catch {
            logger.error("Couldn't load the round history: \(error)")
            summaries = []
        }
    }

    /// Weeks follow `calendar` (its locale's first weekday).
    private func sectionKind(for date: Date) -> HistorySection.Kind {
        let today = now()
        if let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today), thisWeek.contains(date) {
            return .thisWeek
        }
        if
            let lastWeekAnchor = calendar.date(byAdding: .weekOfYear, value: -1, to: today),
            let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastWeekAnchor), lastWeek.contains(date)
        {
            return .lastWeek
        }
        if let thisMonth = calendar.dateInterval(of: .month, for: today), thisMonth.contains(date) {
            return .earlierThisMonth(thisMonth.start)
        }
        let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? date
        return .month(monthStart)
    }
}
