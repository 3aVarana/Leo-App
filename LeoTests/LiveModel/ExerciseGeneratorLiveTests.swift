import Foundation
@testable import Leo
import Testing

/// Results vary between runs: a failure means "look at the prompts", not a broken build.
extension LiveModel {
    @MainActor
    @Suite(.timeLimit(.minutes(1)))
    struct ExerciseGeneratorLiveTests {
        private nonisolated static let spanish = ContentLanguage(locale: Locale(identifier: "es_ES"))

        /// The generator already repairs and validates its output, so this confirms the prompts
        /// produce usable exercises within its 3 attempts, and that the rules held.
        @Test(arguments: AgeGroup.allCases)
        func generatesUsableExercise(_ group: AgeGroup) async throws {
            try await expectUsableExercise(group: group, skill: .mainIdea, language: .english)
        }

        @Test(arguments: [AgeGroup.nine, .adult], ComprehensionSkill.allCases)
        func generatesEverySkill(_ group: AgeGroup, skill: ComprehensionSkill) async throws {
            try await expectUsableExercise(group: group, skill: skill, language: .english)
        }

        @Test func generatesSpanishExercise() async throws {
            try await expectUsableExercise(group: .nine, skill: .inference, language: Self.spanish)
        }

        private func expectUsableExercise(
            group: AgeGroup,
            skill: ComprehensionSkill,
            language: ContentLanguage,
        ) async throws {
            let topics = Array(DefaultTopics.topics(for: group).prefix(3).map(\.roundTopic))
            let generator = ExerciseGenerator(language: language, ageGroup: group)

            let exercise = try await generator.generate(topics: topics, skill: skill)

            #expect(group.acceptedWordCount.contains(exercise.passage.wordCount))
            #expect(topics.contains(exercise.topic))
            #expect(!exercise.question.isEmpty)
            #expect(exercise.options.count == 4)
            #expect(!ExerciseRepair.refersToItself(exercise.passage, language: language))
            #expect(ExerciseRepair.removingMarkdown(exercise.passage) == exercise.passage)
            #expect(ExerciseRepair.matchingPunctuation(exercise.options) == exercise.options)
            #expect(ExerciseRepair.completeExplanation(exercise.explanation) == exercise.explanation)
            var distractors = exercise.options
            let correct = distractors.remove(at: exercise.correctIndex)
            #expect(!ExerciseRepair.correctAnswerStandsOut(correct, distractors: distractors))
        }
    }
}
