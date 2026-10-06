/// What a round of exercises is generated from.
nonisolated struct RoundSettings: Equatable, Hashable, Sendable {
    let ageGroup: AgeGroup
    let topics: [RoundTopic]
}
