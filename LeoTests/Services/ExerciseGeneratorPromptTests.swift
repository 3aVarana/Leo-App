import Foundation
@testable import Leo
import SnapshotTesting
import Testing

@MainActor
struct ExerciseGeneratorPromptTests {
    // nonisolated: `@Test(arguments:)` reads it outside the main actor.
    private nonisolated static let spanish = ContentLanguage(locale: Locale(identifier: "es_ES"))

    @Test(arguments: [AgeGroup.six, .nine, .twelve])
    func wordRangeWithSentences(_ group: AgeGroup) {
        #expect(ExerciseGenerator(language: .english, ageGroup: group).wordRange.contains("in 10 to 13 sentences"))
    }

    @Test(arguments: [AgeGroup.fifteen, .adult])
    func wordRangeWithoutSentences(_ group: AgeGroup) {
        #expect(!ExerciseGenerator(language: .english, ageGroup: group).wordRange.contains("sentences"))
    }

    @Test(arguments: AgeGroup.allCases)
    func wordRangeBoundsAndMidpoint(_ group: AgeGroup) {
        let range = group.passageWordRange
        let midpoint = (range.lowerBound + range.upperBound) / 2
        let wordRange = ExerciseGenerator(language: .english, ageGroup: group).wordRange
        #expect(wordRange
            .contains("between \(range.lowerBound) and \(range.upperBound) words long, about \(midpoint) words"))
    }

    @Test func wordRangeExample() {
        #expect(ExerciseGenerator(language: .english, ageGroup: .six).wordRange
            .hasPrefix("between 50 and 80 words long, about 65 words"))
    }

    @Test(arguments: AgeGroup.allCases, [ContentLanguage.english, spanish])
    func instructions(_ group: AgeGroup, language: ContentLanguage) {
        let instructions = ExerciseGenerator(language: language, ageGroup: group).instructions
        #expect(instructions.contains(group.promptAudience))
        #expect(instructions.contains(group.styleGuidance))
        #expect(instructions.contains(language.name))
    }

    @Test(arguments: [ContentLanguage.english, spanish], ComprehensionSkill.allCases)
    func prompt(language: ContentLanguage, skill: ComprehensionSkill) {
        let generator = ExerciseGenerator(language: language, ageGroup: .nine)
        let prompt = generator.prompt(topic: "volcanoes", skill: skill)
        #expect(prompt.contains("volcanoes"))
        #expect(prompt.contains(language.name))
        #expect(prompt.contains(generator.wordRange))
        #expect(prompt.contains(skill.promptHint))
    }

    /// Prompt changes show up in review. Re-record when tuning prompts on purpose.
    @Test(arguments: AgeGroup.allCases)
    func promptSnapshot(_ group: AgeGroup) {
        let generator = ExerciseGenerator(language: .english, ageGroup: group)
        let text = generator.instructions + "\n\n---\n\n" + generator.prompt(topic: "volcanoes", skill: .inference)
        assertReferenceSnapshot(of: text, as: .lines, named: "\(group)")
    }
}
