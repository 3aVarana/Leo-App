/// What a round of exercises is generated from.
nonisolated struct RoundSettings: Equatable, Hashable, Sendable {
    /// How many texts a reader can ask a round to have.
    static let exerciseCountRange = 3 ... 9
    /// How many texts a round has until the reader changes it.
    static let defaultExerciseCount = 6

    let ageGroup: AgeGroup
    let topics: [RoundTopic]
    /// The number of texts in the round.
    let exerciseCount: Int

    init(ageGroup: AgeGroup, topics: [RoundTopic], exerciseCount: Int = defaultExerciseCount) {
        self.ageGroup = ageGroup
        self.topics = topics
        self.exerciseCount = exerciseCount
    }
}
