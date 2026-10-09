@testable import Leo
import Testing

/// Checks `QuizViewModel.makePlan` over seeds `0..<100` for each topic count. With exactly 2 topics
/// the plan repeats a main topic back to back (exercises 1 and 2), but the app always has at
/// least 3, so counts below 3 aren't tested.
@MainActor
struct QuizPlanTests {
    private static let seeds: Range<UInt64> = 0 ..< 100

    private func topics(_ count: Int) -> [RoundTopic] {
        (0 ..< count).map { RoundTopic(stringLiteral: "topic \($0)") }
    }

    private func plan(_ topics: [RoundTopic], seed: UInt64) -> [QuizViewModel.PlanItem] {
        var rng = SplitMix64(seed: seed)
        return QuizViewModel.makePlan(topics: topics, using: &rng)
    }

    @Test(arguments: 3 ... 20)
    func plan(topicCount: Int) {
        let topics = topics(topicCount)
        for seed in Self.seeds {
            let plan = plan(topics, seed: seed)
            let main = plan.map { $0.topics[0] }

            #expect(plan.count == QuizViewModel.exerciseCount, "seed \(seed)")
            #expect(Set(plan.map(\.skill)) == Set(ComprehensionSkill.allCases), "seed \(seed)")
            if topicCount >= QuizViewModel.exerciseCount {
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

    // MARK: - Replacement topics

    private func replacement(for failed: [RoundTopic], from topics: [RoundTopic], seed: UInt64) -> [RoundTopic] {
        var rng = SplitMix64(seed: seed)
        return QuizViewModel.replacementTopics(for: failed, from: topics, using: &rng)
    }

    @Test(arguments: [4, 5, 6, 20])
    func replacementTopicsPreferUntried(topicCount: Int) {
        let topics = topics(topicCount)
        let failed = Array(topics.prefix(3))
        let untriedCount = min(topicCount - 3, 3)
        for seed in Self.seeds {
            let replacement = replacement(for: failed, from: topics, seed: seed)
            #expect(replacement.count == 3, "seed \(seed)")
            #expect(Set(replacement).count == 3, "seed \(seed)")
            #expect(replacement.allSatisfy(topics.contains), "seed \(seed)")
            #expect(
                replacement.prefix(untriedCount).allSatisfy { !failed.contains($0) },
                "seed \(seed): \(replacement)",
            )
            #expect(replacement.dropFirst(untriedCount).allSatisfy(failed.contains), "seed \(seed): \(replacement)")
        }
    }

    /// With no other topics, the failed ones come back, in another order for some seeds.
    @Test func replacementTopicsWithoutOthers() {
        let topics = topics(3)
        var orders: Set<[RoundTopic]> = []
        for seed in Self.seeds {
            let replacement = replacement(for: topics, from: topics, seed: seed)
            #expect(Set(replacement) == Set(topics), "seed \(seed)")
            #expect(replacement.count == 3, "seed \(seed)")
            orders.insert(replacement)
        }
        #expect(orders.count > 1)
    }

    @Test func replacementTopicsSameSeedSameResult() {
        let topics = topics(10)
        let failed = Array(topics.prefix(3))
        for seed in Self.seeds {
            #expect(replacement(for: failed, from: topics, seed: seed) == replacement(
                for: failed,
                from: topics,
                seed: seed,
            ))
        }
    }
}
