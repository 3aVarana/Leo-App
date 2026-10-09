// Generates exercises with the app's own ExerciseGenerator and prints one block per exercise,
// in the format score.py reads. Built by build.sh; see README.md.
//
//     harness <age> <skill> <topic> [count] [language]
//     harness --all [language]
//
// <age> is an AgeGroup raw value ("6-8" ... "18+"), <skill> a ComprehensionSkill raw value,
// [language] a locale identifier such as es_ES (default en_US).

import Foundation
import FoundationModels

@main
struct Main {
    /// One story topic and one informative topic per age group, all from DefaultTopics.
    /// Changing them makes new runs incomparable with the baseline in README.md.
    static let scenarioTopics: [AgeGroup: [String]] = [
        .six: ["a story about a kind robot", "insects and bugs"],
        .nine: ["a short story about a mystery at school", "volcanoes"],
        .twelve: ["a short story about friendship", "the human body"],
        .fifteen: ["a short fictional story about a teenager facing a challenge", "the science of sleep"],
        .adult: ["a short piece of literary fiction", "the history of language"],
    ]

    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard SystemLanguageModel.default.isAvailable else {
            fail("The on-device model isn't available. Turn on Apple Intelligence and try again.")
        }
        if args.first == "--all" {
            let language = language(args.count > 1 ? args[1] : nil)
            for group in AgeGroup.allCases {
                for topic in scenarioTopics[group]! {
                    for skill in ComprehensionSkill.allCases {
                        await run(group: group, skill: skill, topic: topic, count: 1, language: language)
                    }
                }
            }
            return
        }
        guard args.count >= 3,
              let group = AgeGroup(rawValue: args[0]),
              let skill = ComprehensionSkill(rawValue: args[1])
        else {
            fail("Usage: harness <age> <skill> <topic> [count] [language]  |  harness --all [language]")
        }
        let count = args.count > 3 ? Int(args[3]) ?? 1 : 1
        await run(
            group: group,
            skill: skill,
            topic: args[2],
            count: count,
            language: language(args.count > 4 ? args[4] : nil),
        )
    }

    static func language(_ identifier: String?) -> ContentLanguage {
        identifier.map { ContentLanguage(locale: Locale(identifier: $0)) } ?? .english
    }

    static func run(
        group: AgeGroup,
        skill: ComprehensionSkill,
        topic: String,
        count: Int,
        language: ContentLanguage,
    ) async {
        let generator = ExerciseGenerator(language: language, ageGroup: group)
        let roundTopic = RoundTopic(prompt: topic, name: topic)
        for index in 1 ... count {
            let header = "===== [\(group.rawValue) | \(skill.rawValue) | \(topic)] #\(index)"
            let start = Date()
            do {
                // One topic, so a rejected exercise shows up as FAILED instead of being replaced.
                let exercise = try await generator.generate(topics: [roundTopic], skill: skill)
                let seconds = String(format: "%.1fs", Date().timeIntervalSince(start))
                print("\n\(header)  words=\(exercise.passage.wordCount)  \(seconds)")
                print("TITLE: \(exercise.title)")
                print("PASSAGE: \(exercise.passage.replacingOccurrences(of: "\n", with: " "))")
                print("Q: \(exercise.question)")
                for (option, text) in exercise.options.enumerated() {
                    print("  \(option == exercise.correctIndex ? "*" : "-") \(text)")
                }
                print("EXPLANATION: \(exercise.explanation)")
            } catch {
                print("\n\(header) FAILED: \(error)")
            }
            fflush(stdout)
        }
    }

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}
