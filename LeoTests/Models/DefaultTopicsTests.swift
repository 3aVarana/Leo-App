import Foundation
import SnapshotTesting
import Testing
@testable import Leo

@MainActor
struct DefaultTopicsTests {
    /// One main topic plus 2 backups per exercise.
    @Test(arguments: AgeGroup.allCases)
    func enoughTopics(_ group: AgeGroup) {
        let count = DefaultTopics.topics(for: group).count
        #expect(count >= ReaderPreferences.minimumEnabledTopics)
        #expect(count >= 3)
    }

    @Test(arguments: AgeGroup.allCases)
    func idsAreUniqueAndWellFormed(_ group: AgeGroup) {
        let ids = DefaultTopics.topics(for: group).map(\.id)
        #expect(Set(ids).count == ids.count)
        for id in ids {
            #expect(id.wholeMatch(of: /[a-z0-9]+(-[a-z0-9]+)*/) != nil, "\(id)")
        }
    }

    @Test(arguments: AgeGroup.allCases)
    func promptsAreUniqueAndNotEmpty(_ group: AgeGroup) {
        let prompts = DefaultTopics.topics(for: group).map(\.prompt)
        #expect(!prompts.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty })
        #expect(Set(prompts).count == prompts.count)
    }

    /// Ids are saved when the reader turns a topic off. Renaming or removing one must fail
    /// this test; adding a topic means re-recording on purpose.
    @Test func savedIds() {
        let text = AgeGroup.allCases.map { group in
            ([group.rawValue] + DefaultTopics.topics(for: group).map { "  \($0.id)" }).joined(separator: "\n")
        }.joined(separator: "\n")
        assertReferenceSnapshot(of: text, as: .lines)
    }

    @Test func comprehensionSkills() {
        #expect(ComprehensionSkill.allCases.count == 5)
        for skill in ComprehensionSkill.allCases {
            #expect(!skill.displayName.isEmpty, "\(skill)")
            #expect(!skill.promptHint.isEmpty, "\(skill)")
        }
    }

    @Test func generationErrorDescription() {
        #expect(ExerciseGenerationError.failed.errorDescription?.isEmpty == false)
    }

    @Test func customTopicRoundTrips() throws {
        let topic = CustomTopic(name: "Chess")
        let decoded = try JSONDecoder().decode(CustomTopic.self, from: JSONEncoder().encode(topic))
        #expect(decoded.id == topic.id)
        #expect(decoded.name == "Chess")
    }
}
