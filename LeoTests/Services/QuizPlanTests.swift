@testable import Leo
import Testing

/// Checks `QuizModel.makePlan` over seeds `0..<100` for each topic count. With exactly 2 topics
/// the plan repeats a main topic back to back (exercises 1 and 2), but the app always has at
/// least 3, so counts below 3 aren't tested.
@MainActor
struct QuizPlanTests {
    private static let seeds: Range<UInt64> = 0 ..< 100

    private func topics(_ count: Int) -> [String] {
        (0 ..< count).map { "topic \($0)" }
    }

    private func plan(_ topics: [String], seed: UInt64) -> [QuizModel.PlanItem] {
        var rng = SplitMix64(seed: seed)
        return QuizModel.makePlan(topics: topics, using: &rng)
    }

    @Test(arguments: 3 ... 20)
    func plan(topicCount: Int) {
        let topics = topics(topicCount)
        for seed in Self.seeds {
            let plan = plan(topics, seed: seed)
            let main = plan.map { $0.topics[0] }

            #expect(plan.count == QuizModel.exerciseCount, "seed \(seed)")
            #expect(Set(plan.map(\.skill)) == Set(ComprehensionSkill.allCases), "seed \(seed)")
            if topicCount >= QuizModel.exerciseCount {
                #expect(Set(main).count == main.count, "seed \(seed)")
            } else {
                for (previous, next) in zip(main, main.dropFirst()) {
                    #expect(previous != next, "seed \(seed): \(main)")
                }
            }
            for item in plan {
                #expect(item.topics.count == 3, "seed \(seed)")
                #expect(Set(item.topics).count == item.topics.count, "seed \(seed): \(item.topics)")
                #expect(item.topics.allSatisfy(topics.contains), "seed \(seed)")
            }
        }
    }

    @Test(arguments: [3, 6, 20])
    func sameSeedSamePlan(topicCount: Int) {
        let topics = topics(topicCount)
        for seed in Self.seeds {
            #expect(plan(topics, seed: seed) == plan(topics, seed: seed), "seed \(seed)")
        }
    }
}
