import SwiftUI

/// Every finished round at the current age group (H7): the header totals, then the rounds
/// grouped by when they were read. Swipe to delete a round (H3), no confirmation.
///
/// Settings isn't reachable from here (no gear), so the age group can't change while History,
/// or a round pushed from it, is on screen (5.5). If that ever changes, this view would also
/// need to react to `viewModel.ageGroup` changing underneath it, not just `hasRounds`.
struct HistoryView: View {
    let viewModel: RoundHistoryViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRound: RoundRecord?

    var body: some View {
        List {
            header
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            let sections = viewModel.sections
            ForEach(sections, id: \.kind) { section in
                Section {
                    ForEach(section.rounds) { round in
                        Button {
                            selectedRound = viewModel.round(id: round.id)
                        } label: {
                            HistoryRow(round: round)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.delete(id: round.id)
                            } label: {
                                Text("Delete")
                            }
                        }
                    }
                } header: {
                    sectionHeader(section.kind, isFirst: section.kind == sections.first?.kind)
                }
                .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .leoScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(Text(verbatim: ""))
        .navigationDestination(item: $selectedRound) { round in
            RoundView(round: round)
        }
        .onChange(of: viewModel.hasRounds) { _, hasRounds in
            // Deleting the last round closes History (1.2): the button that opened it is hidden now.
            if !hasRounds {
                dismiss()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your rounds")
                .leoTextStyle(.display(40))
                .accessibilityAddTraits(.isHeader)
            summaryLine
                .leoTextStyle(.bodyLarge)
                .foregroundStyle(Color.leoInkSoft)
        }
        .leoReadableWidth()
        .padding(.top, 20)
        .padding(.bottom, 28)
    }

    private var summaryLine: Text {
        let percent = viewModel.correctShare.formatted(.percent.precision(.fractionLength(0)))
        return Text("\(viewModel.roundCount) rounds read · \(percent) answered right")
    }

    private func sectionHeader(_ kind: HistorySection.Kind, isFirst: Bool) -> some View {
        Kicker(title(for: kind))
            .textCase(nil)
            .listRowInsets(EdgeInsets())
            .padding(.horizontal, 24)
            .padding(.top, isFirst ? 0 : 20)
            .padding(.bottom, 8)
    }

    private func title(for kind: HistorySection.Kind) -> Text {
        switch kind {
        case .thisWeek:
            Text("This week")
        case .lastWeek:
            Text("Last week")
        case let .earlierThisMonth(date):
            Text("Earlier in \(viewModel.monthName(date))")
        case let .month(date, showsYear):
            Text(verbatim: viewModel.monthName(date, showingYear: showsYear))
        }
    }
}

/// One row: the date and time, the score over the round's dots, a chevron. At accessibility sizes
/// the row stacks instead.
private struct HistoryRow: View {
    let round: RoundSummary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    dateTime
                    scoreAndDots
                }
            } else {
                HStack(spacing: 12) {
                    dateTime
                    Spacer(minLength: 8)
                    scoreAndDots
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .foregroundStyle(Color.leoInkSoft)
                }
            }
        }
        .leoReadableWidth()
        .padding(.vertical, 12)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(Text("Shows the round"))
    }

    private var dateTime: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(round.finishedAt, format: .dateTime.day().month(.abbreviated))
                .leoTextStyle(LeoTextStyle(size: 17, weight: .semibold, relativeTo: .callout))
            Text(round.finishedAt, format: .dateTime.hour().minute())
                .leoTextStyle(.bodySmall)
                .foregroundStyle(Color.leoInkSoft)
        }
        .foregroundStyle(Color.leoInk)
    }

    private var scoreAndDots: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("\(round.correctCount) of \(round.results.count)")
                .leoTextStyle(LeoTextStyle(size: 17, weight: .semibold, relativeTo: .callout))
                .foregroundStyle(Color.leoInk)
            RoundResultDots(results: round.results)
        }
    }

    private var accessibilityLabel: Text {
        let day = round.finishedAt.formatted(.dateTime.day().month(.wide))
        let time = round.finishedAt.formatted(.dateTime.hour().minute())
        return Text("\(day), \(time), \(round.correctCount) of \(round.results.count) right")
    }
}

#if DEBUG
    #Preview {
        let repository = SwiftDataRoundHistoryRepository.inMemory()
        let viewModel = RoundHistoryViewModel(repository: repository)
        for result in [
            [true, true, true, true, true, true],
            [true, false, true, true, false, true],
            [false, false, true, false, false, true],
        ] {
            try? repository.save(.previewFixture(ageGroup: .nine, results: result))
        }
        viewModel.ageGroup = .nine
        return NavigationStack {
            HistoryView(viewModel: viewModel)
        }
    }
#endif
