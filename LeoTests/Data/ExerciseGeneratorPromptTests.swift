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
        #expect(instructions.hasPrefix(language.localeInstruction))
        #expect(instructions.contains("You are an expert reading teacher"))
        #expect(instructions
            .contains("You MUST write the passage, title, question, answers and explanation in \(language.name)."))
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
        #expect(prompt.contains("Skill to test: \(skill.promptHint)"))
    }

    @Test func promptStatesTheKindOfPassage() {
        let generator = ExerciseGenerator(language: .english, ageGroup: .nine)
        let informative = generator.prompt(topic: RoundTopic(prompt: "volcanoes", name: "Volcanoes"), skill: .detail)
        let story = generator.prompt(
            topic: RoundTopic(prompt: "a story about a kind robot", name: "A kind robot", kind: .story),
            skill: .detail,
        )
        #expect(informative.contains("informative text that explains real, well-known facts about volcanoes"))
        #expect(!informative.contains("The passage is a story"))
        #expect(story.contains("The passage is a story."))
        #expect(!story.contains("informative text"))
    }

    @Test func onlyInformativePromptsAskForWellKnownFacts() {
        let generator = ExerciseGenerator(language: .english, ageGroup: .nine)
        let facts = "Use well-known facts, and avoid exact figures and dates unless they are famous."
        #expect(generator.prompt(topic: RoundTopic(prompt: "volcanoes", name: "Volcanoes"), skill: .detail)
            .contains(facts))
        #expect(!generator.prompt(topic: RoundTopic(prompt: "a story", name: "A story", kind: .story), skill: .detail)
            .contains(facts))
    }

    @Test func temperatureByKind() {
        #expect(ExerciseGenerator.temperature(for: .story) == 0.8)
        #expect(ExerciseGenerator.temperature(for: .informative) == 0.5)
    }

    @Test func spanishInstructionsStartWithTheLocale() {
        let instructions = ExerciseGenerator(language: Self.spanish, ageGroup: .nine).instructions
        #expect(instructions.hasPrefix("The person's locale is es_ES.\nYou are an expert reading teacher"))
    }

    /// Prompt changes show up in review. Re-record when tuning prompts on purpose.
    @Test(arguments: AgeGroup.allCases)
    func promptSnapshot(_ group: AgeGroup) {
        let generator = ExerciseGenerator(language: .english, ageGroup: group)
        let text = generator.instructions + "\n\n---\n\n" + generator.prompt(topic: "volcanoes", skill: .inference)
        assertReferenceSnapshot(of: text, as: .lines, named: "\(group)")
    }
}
