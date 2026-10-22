@testable import Leo
import SwiftData
import Testing

/// Guards the stored entity and attribute names, the role `ReaderPreferencesTests.savedFormat`
/// plays for preferences: renaming a stored property without a migration stage fails here first.
@MainActor
struct RoundHistorySchemaTests {
    private var properties: [String: Set<String>] {
        Dictionary(
            uniqueKeysWithValues: Schema(versionedSchema: RoundHistorySchemaV1.self).entities.map {
                ($0.name, Set($0.properties.map(\.name)))
            },
        )
    }

    @Test func versionIsFrozen() {
        #expect(RoundHistorySchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
    }

    @Test func storedRoundAttributes() {
        #expect(properties["StoredRound"] == ["id", "finishedAt", "ageGroup", "results", "answers"])
    }

    @Test func storedAnswerAttributes() {
        #expect(properties["StoredAnswer"] == [
            "index", "exerciseID", "topicPrompt", "topicName", "topicKind", "skill", "title",
            "passage", "question", "options", "correctIndex", "selectedOption", "explanation", "round",
        ])
    }
}
