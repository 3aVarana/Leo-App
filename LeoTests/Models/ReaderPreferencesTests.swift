import Foundation
import SnapshotTesting
import Testing
@testable import Leo

@MainActor
@Suite(.snapshots(record: .missing))
struct ReaderPreferencesTests {
    private func decode(_ json: String) throws -> ReaderPreferences {
        try JSONDecoder().decode(ReaderPreferences.self, from: Data(json.utf8))
    }

    @Test func decodesVersion1Data() throws {
        let preferences = try decode(#"{"ageGroup":"9-11"}"#)
        #expect(preferences.ageGroup == .nine)
        #expect(preferences.disabledDefaultTopics.isEmpty)
        #expect(preferences.customTopics.isEmpty)
    }

    @Test func unknownAgeGroupThrows() {
        #expect(throws: DecodingError.self) { try decode(#"{"ageGroup":"99"}"#) }
    }

    @Test func roundTrips() throws {
        let preferences = ReaderPreferences.fixture(
            ageGroup: .twelve,
            disabled: [.twelve: ["mythology", "inventions"], .six: ["dinosaurs"]],
            custom: [.twelve: ["Chess", "Origami"], .adult: ["Jazz"]]
        )
        let decoded = try JSONDecoder().decode(ReaderPreferences.self, from: JSONEncoder().encode(preferences))
        #expect(decoded == preferences)
        #expect(decoded.customTopics[.twelve]?.map(\.id) == preferences.customTopics[.twelve]?.map(\.id))
    }

    /// Any change to the saved format must show up in review. One disabled id per group,
    /// since a `Set` with more encodes in an order that changes between runs.
    @Test func savedFormat() {
        var preferences = ReaderPreferences(ageGroup: .nine)
        preferences.disabledDefaultTopics = [.nine: ["volcanoes"], .twelve: ["mythology"]]
        preferences.customTopics = [
            .nine: [
                CustomTopic(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Chess"),
                CustomTopic(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Origami"),
            ],
            .adult: [CustomTopic(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Jazz")],
        ]
        assertReferenceSnapshot(of: preferences, as: .json)
    }

    @Test func isEnabled() throws {
        let topic = try #require(DefaultTopics.topics(for: .nine).first)
        var preferences = ReaderPreferences(ageGroup: .nine)
        #expect(preferences.isEnabled(topic, in: .nine))

        preferences.disabledDefaultTopics[.nine, default: []].insert(topic.id)
        #expect(!preferences.isEnabled(topic, in: .nine))
        #expect(preferences.isEnabled(topic, in: .twelve))
    }

    @Test func enabledTopicPromptsKeepsOrder() {
        let preferences = ReaderPreferences.fixture(ageGroup: .nine, custom: [.nine: ["Chess", "Origami"]])
        let suggested = DefaultTopics.topics(for: .nine).map(\.prompt)
        #expect(preferences.enabledTopicPrompts(for: .nine) == suggested + ["Chess", "Origami"])
    }

    @Test func enabledTopicPromptsExcludesDisabled() {
        let preferences = ReaderPreferences.fixture(ageGroup: .nine, disabled: [.nine: ["volcanoes", "recycling"]])
        let prompts = preferences.enabledTopicPrompts(for: .nine)
        let expected = DefaultTopics.topics(for: .nine).filter { !["volcanoes", "recycling"].contains($0.id) }.map(\.prompt)
        #expect(prompts == expected)
    }

    @Test func enabledTopicPromptsExcludesOtherGroupsCustomTopics() {
        let preferences = ReaderPreferences.fixture(ageGroup: .nine, custom: [.twelve: ["Chess"]])
        #expect(!preferences.enabledTopicPrompts(for: .nine).contains("Chess"))
        #expect(preferences.enabledTopicPrompts(for: .twelve).last == "Chess")
    }

    @Test func enabledTopicPromptsIgnoresUnknownDisabledIds() {
        let preferences = ReaderPreferences.fixture(ageGroup: .nine, disabled: [.nine: ["no-such-topic"]])
        #expect(preferences.enabledTopicPrompts(for: .nine) == DefaultTopics.topics(for: .nine).map(\.prompt))
    }

    /// Only possible with stale data, since the editor keeps a minimum enabled.
    @Test func enabledTopicPromptsFallsBackToAllSuggested() {
        let all = DefaultTopics.topics(for: .six)
        let preferences = ReaderPreferences.fixture(ageGroup: .six, disabled: [.six: Set(all.map(\.id))])
        #expect(preferences.enabledTopicPrompts(for: .six) == all.map(\.prompt))
    }

    /// `QuizModel.configure` relies on equal preferences giving equal settings to skip work.
    @Test func roundSettings() {
        let preferences = ReaderPreferences.fixture(ageGroup: .twelve, custom: [.twelve: ["Chess"]])
        #expect(preferences.roundSettings.ageGroup == .twelve)
        #expect(preferences.roundSettings.topics == preferences.enabledTopicPrompts(for: .twelve))
        #expect(preferences.roundSettings == preferences.roundSettings)

        var copy = preferences
        #expect(copy.roundSettings == preferences.roundSettings)
        copy.disabledDefaultTopics[.twelve, default: []].insert("mythology")
        #expect(copy.roundSettings != preferences.roundSettings)
    }

    @Test func limits() {
        #expect(ReaderPreferences.minimumEnabledTopics == 3)
        #expect(ReaderPreferences.maximumCustomTopics == 20)
    }
}
