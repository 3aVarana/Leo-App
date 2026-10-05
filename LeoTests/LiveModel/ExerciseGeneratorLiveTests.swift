@testable import Leo
import Testing

/// Results vary between runs: a failure means "look at the prompts", not a broken build.
extension LiveModel {
    @MainActor
    @Suite(.timeLimit(.minutes(1)))
    struct ExerciseGeneratorLiveTests {
        /// The generator already rejects passages outside the accepted length, so this confirms
        /// the prompts produce usable output within its 3 attempts.
        @Test(arguments: AgeGroup.allCases)
        func generatesUsableExercise(_ group: AgeGroup) async throws {
            let topics = DefaultTopics.topics(for: group).prefix(3).map(\.prompt)
            let generator = ExerciseGenerator(language: .english, ageGroup: group)

            let exercise = try await generator.generate(topics: Array(topics), skill: .mainIdea)

            #expect(group.acceptedWordCount.contains(exercise.passage.wordCount))
            #expect(topics.contains(exercise.topic))
            #expect(!exercise.question.isEmpty)
            #expect((3 ... 4).contains(exercise.options.count))
        }
    }
}
