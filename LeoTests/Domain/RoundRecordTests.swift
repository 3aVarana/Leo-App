import Foundation
@testable import Leo
import Testing

@MainActor
struct RoundRecordTests {
    @Test func correctCountAndMisses() {
        let round = RoundRecord.fixture(results: [true, false, true, true, false, true])
        #expect(round.correctCount == 4)
        #expect(round.misses.map(\.index) == [1, 4])
    }

    @Test func allCorrectHasNoMisses() {
        let round = RoundRecord.fixture(results: Array(repeating: true, count: 6))
        #expect(round.correctCount == 6)
        #expect(round.misses.isEmpty)
    }
}

struct RoundSummaryTests {
    @Test func correctCount() {
        let summary = RoundSummary(id: UUID(), finishedAt: Date(), results: [true, false, true])
        #expect(summary.correctCount == 2)
    }
}
