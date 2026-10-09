import Foundation
@testable import Leo
import SnapshotTesting
import Testing

@MainActor
struct ReaderPreferencesTests {
    private func decode(_ json: String) throws -> ReaderPreferences {
        try JSONDecoder().decode(ReaderPreferences.self, from: Data(json.utf8))
    }

    @Test func decodesVersion1Data() throws {
        let preferences = try decode(#"{"ageGroup":"9-11"}"#)
        #expect(preferences.ageGroup == .nine)
        #expect(preferences.disabledDefaultTopics.isEmpty)
        #expect(preferences.customTopics.isEmpty)
        #expect(preferences.isReadingTimerOn)
    }

    @Test func decodesReadingTimerOff() throws {
        let preferences = try decode(#"{"ageGroup":"9-11","isReadingTimerOn":false}"#)
        #expect(!preferences.isReadingTimerOn)
    }

    @Test func unknownAgeGroupThrows() {
        #expect(throws: DecodingError.self) { try decode(#"{"ageGroup":"99"}"#) }
    }

    @Test func roundTrips() throws {
        let preferences = ReaderPreferences.fixture(
            ageGroup: .twelve,
            disabled: [.twelve: ["mythology", "inventions"], .six: ["dinosaurs"]],
            custom: [.twelve: ["Chess", "Origami"], .adult: ["Jazz"]],
        )
        let decoded = try JSONDecoder().decode(ReaderPreferences.self, from: JSONEncoder().encode(preferences))
        #expect(decoded == preferences)
        #expect(decoded.customTopics[.twelve]?.map(\.id) == preferences.customTopics[.twelve]?.map(\.id))
    }

    /// Any change to the saved format must show up in review. One disabled id per group,
    /// since a `Set` with more encodes in an order that changes between runs.
    @Test func savedFormat() throws {
        var preferences = ReaderPreferences(ageGroup: .nine)
        preferences.disabledDefaultTopics = [.nine: ["volcanoes"], .twelve: ["mythology"]]
        preferences.customTopics = try [
            .nine: [
                CustomTopic(id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")), name: "Chess"),
                CustomTopic(id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002")), name: "Origami"),
            ],
            .adult: [CustomTopic(id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000003")), name: "Jazz")],
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

    @Test func enabledTopicsKeepsOrder() {
        let preferences = ReaderPreferences.fixture(ageGroup: .nine, custom: [.nine: ["Chess", "Origami"]])
        let suggested = DefaultTopics.topics(for: .nine).map(\.prompt)
        #expect(preferences.enabledTopics(for: .nine).map(\.prompt) == suggested + ["Chess", "Origami"])
    }

    /// Suggested topics show their localized name; the reader's own show what they typed.
    @Test func enabledTopicsNames() throws {
        let preferences = ReaderPreferences.fixture(ageGroup: .nine, custom: [.nine: ["Chess"]])
        let topics = preferences.enabledTopics(for: .nine)
        let mystery = try #require(topics.first { $0.prompt == "a short story about a mystery at school" })
        #expect(mystery.name == "A mystery at school")
        #expect(topics.last == RoundTopic(prompt: "Chess", name: "Chess"))
    }

    @Test func enabledTopicsExcludesDisabled() {
        let preferences = ReaderPreferences.fixture(ageGroup: .nine, disabled: [.nine: ["volcanoes", "recycling"]])
        let prompts = preferences.enabledTopics(for: .nine).map(\.prompt)
        let expected = DefaultTopics.topics(for: .nine).filter { !["volcanoes", "recycling"].contains($0.id) }
            .map(\.prompt)
        #expect(prompts == expected)
    }

    @Test func enabledTopicsExcludesOtherGroupsCustomTopics() {
        let preferences = ReaderPreferences.fixture(ageGroup: .nine, custom: [.twelve: ["Chess"]])
        #expect(!preferences.enabledTopics(for: .nine).map(\.prompt).contains("Chess"))
        #expect(preferences.enabledTopics(for: .twelve).last?.prompt == "Chess")
    }

    @Test func enabledTopicsIgnoresUnknownDisabledIds() {
        let preferences = ReaderPreferences.fixture(ageGroup: .nine, disabled: [.nine: ["no-such-topic"]])
        #expect(preferences.enabledTopics(for: .nine).map(\.prompt) == DefaultTopics.topics(for: .nine).map(\.prompt))
    }

    /// Only possible with stale data, since the editor keeps a minimum enabled.
    @Test func enabledTopicsTopsUpFromNone() {
        let all = DefaultTopics.topics(for: .six)
        let preferences = ReaderPreferences.fixture(ageGroup: .six, disabled: [.six: Set(all.map(\.id))])
        #expect(preferences.enabledTopics(for: .six).map(\.prompt) == all.prefix(3).map(\.prompt))
    }

    /// Only possible with stale data, since the editor keeps a minimum enabled.
    @Test func enabledTopicsTopsUpBelowMinimum() {
        let all = DefaultTopics.topics(for: .six)
        let preferences = ReaderPreferences.fixture(
            ageGroup: .six,
            disabled: [.six: Set(all.dropFirst().map(\.id))],
            custom: [.six: ["Chess"]],
        )
        let expected = [all[0].prompt, "Chess", all[1].prompt]
        #expect(preferences.enabledTopics(for: .six).map(\.prompt) == expected)
    }

    @Test func enabledTopicsKeepsMinimum() {
        let all = DefaultTopics.topics(for: .six)
        let preferences = ReaderPreferences.fixture(
            ageGroup: .six,
            disabled: [.six: Set(all.map(\.id))],
            custom: [.six: ["Chess", "Origami", "Knots"]],
        )
        #expect(preferences.enabledTopics(for: .six).map(\.prompt) == ["Chess", "Origami", "Knots"])
    }

    /// `QuizViewModel.configure` relies on equal preferences giving equal settings to skip work.
    @Test func roundSettings() {
        let preferences = ReaderPreferences.fixture(ageGroup: .twelve, custom: [.twelve: ["Chess"]])
        #expect(preferences.roundSettings.ageGroup == .twelve)
        #expect(preferences.roundSettings.topics == preferences.enabledTopics(for: .twelve))
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
