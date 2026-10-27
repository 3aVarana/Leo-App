import Foundation
import FoundationModels
@testable import Leo
import Testing

/// Measures 15–17 passage lengths on the device that runs it, for docs/Leo-Passage-Length-Plan.md
/// (step 0). Same cases as the Mac harness run in that plan: one attempt per run, with no
/// replacement topic and no runaway check. It records numbers instead of checking them: read the
/// `PASSAGE-LENGTH` lines in the test output, and the passages in the `PASSAGE-TEXT` lines.
extension LiveModel {
    @MainActor
    @Suite(.timeLimit(.minutes(2)))
    struct PassageLengthLiveTests {
        private static let group = AgeGroup.fifteen
        private nonisolated static let topicIDs = ["ancient-civilizations", "sports-science", "animal-behavior"]
        private static let runs = 2

        @Test(arguments: topicIDs, ComprehensionSkill.allCases)
        func passageLengths(topicID: String, skill: ComprehensionSkill) async throws {
            let topic = try #require(DefaultTopics.topics(for: Self.group).first { $0.id == topicID }).roundTopic
            let generator = ExerciseGenerator(language: .english, ageGroup: Self.group)
            for run in 1 ... Self.runs {
                let session = LanguageModelSession(instructions: generator.instructions)
                let clock = ContinuousClock()
                let start = clock.now
                var line = "PASSAGE-LENGTH | \(Self.group.rawValue) | \(skill.rawValue) | \(topicID) | #\(run)"
                do {
                    let generated = try await session.respond(
                        to: generator.prompt(topic: topic, skill: skill),
                        generating: GeneratedExercise.self,
                        options: ExerciseGenerator.generationOptions,
                    ).content
                    let passage = generated.passage.trimmingCharacters(in: .whitespacesAndNewlines)
                    line += " | words=\(passage.wordCount) | sentences=\(Self.sentenceCount(passage))"
                    line += " | \(Self.outcome(generated, topic: topic, skill: skill))"
                    let flatPassage = passage.replacingOccurrences(of: "\n", with: " / ")
                    let header = "PASSAGE-TEXT | \(skill.rawValue) | \(topicID) | #\(run) | \(generated.title)"
                    print(header + " | " + flatPassage)
                } catch {
                    line += " | error: \(error)"
                }
                let elapsed = clock.now - start
                print(line + " | \(elapsed.formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1))))")
            }
        }

        private static func outcome(
            _ generated: GeneratedExercise,
            topic: RoundTopic,
            skill: ComprehensionSkill,
        ) -> String {
            do {
                _ = try Exercise(
                    generated: generated,
                    topic: topic,
                    skill: skill,
                    acceptedWordCount: group.acceptedWordCount,
                    language: .english,
                )
                return "accepted"
            } catch {
                return "rejected: \(error.rawValue)"
            }
        }

        private static func sentenceCount(_ text: String) -> Int {
            var count = 0
            let options: String.EnumerationOptions = [.bySentences, .substringNotRequired]
            text.enumerateSubstrings(in: text.startIndex..., options: options) { _, _, _, _ in count += 1 }
            return count
        }
    }
}
