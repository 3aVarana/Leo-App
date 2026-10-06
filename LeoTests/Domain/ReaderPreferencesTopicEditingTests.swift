import Foundation
@testable import Leo
import Testing

/// The topic editing rules on `ReaderPreferences`. Suggested topic names are compared in English,
/// the language the `Leo` test plan runs in.
@MainActor
struct ReaderPreferencesTopicEditingTests {
    private let sixIds = DefaultTopics.topics(for: .six).map(\.id)
    private let dinosaurs = DefaultTopics.topics(for: .six).first { $0.id == "dinosaurs" }!

    /// `.six` with every suggested topic off except the last `enabled`, plus `custom` topics.
    private func six(enabled: Int, custom: [String] = []) -> ReaderPreferences {
        .fixture(ageGroup: .six, disabled: [.six: Set(sixIds.dropLast(enabled))], custom: [.six: custom])
    }

    private func twentyCustomTopics() -> [String] {
        (1 ... ReaderPreferences.maximumCustomTopics).map { "Topic \($0)" }
    }

    @Test func enabledTopicCount() {
        let preferences = ReaderPreferences.fixture(
            ageGroup: .six,
            disabled: [.six: ["dinosaurs", "beach"], .nine: ["volcanoes"]],
            custom: [.six: ["Chess"], .nine: ["Origami", "Jazz"]],
        )
        #expect(preferences.enabledTopicCount(in: .six) == sixIds.count - 2 + 1)
        #expect(preferences.enabledTopicCount(in: .nine) == DefaultTopics.topics(for: .nine).count - 1 + 2)
        #expect(preferences.enabledTopicCount(in: .adult) == DefaultTopics.topics(for: .adult).count)
    }

    @Test func isAtMinimum() {
        #expect(six(enabled: 3).isAtMinimum(in: .six))
        #expect(!six(enabled: 4).isAtMinimum(in: .six))
        #expect(six(enabled: 2, custom: ["Chess"]).isAtMinimum(in: .six))
        #expect(!six(enabled: 2, custom: ["Chess", "Origami"]).isAtMinimum(in: .six))
        #expect(!six(enabled: 3).isAtMinimum(in: .nine))
    }

    @Test func matchIgnoresCaseAndAccents() {
        let preferences = ReaderPreferences.fixture(ageGroup: .six, custom: [.six: ["Música"]])
        #expect(preferences.match("DINOSAURS", in: .six) == .enabled)
        #expect(preferences.match("dinosaurs", in: .six) == .enabled)
        #expect(preferences.match("musica", in: .six) == .enabled)
        #expect(preferences.match("MÚSICA", in: .six) == .enabled)
        #expect(preferences.match("Rockets", in: .six) == nil)
        // Other groups have their own lists.
        #expect(preferences.match("Dinosaurs", in: .nine) == nil)
        #expect(preferences.match("Música", in: .nine) == nil)
    }

    @Test func matchReportsDisabledSuggestedTopic() {
        let preferences = ReaderPreferences.fixture(ageGroup: .six, disabled: [.six: ["dinosaurs"]])
        #expect(preferences.match("dinosaurs", in: .six) == .disabledDefault(id: "dinosaurs"))
        #expect(preferences.match("The beach", in: .six) == .enabled)
    }

    @Test func checkOrder() {
        // Length before duplicates.
        let shortCustom = ReaderPreferences.fixture(ageGroup: .six, custom: [.six: ["A"]])
        #expect(shortCustom.check(newTopic: "A", in: .six) == .invalidLength)

        // Duplicates before the custom topic limit.
        let full = ReaderPreferences.fixture(ageGroup: .six, custom: [.six: twentyCustomTopics()])
        #expect(full.check(newTopic: "Dinosaurs", in: .six) == .alreadyOnList)
        #expect(full.check(newTopic: "topic 7", in: .six) == .alreadyOnList)

        // Re-enabling a suggested topic before the custom topic limit.
        var fullWithDisabled = full
        fullWithDisabled.disabledDefaultTopics = [.six: ["dinosaurs"]]
        #expect(fullWithDisabled.check(newTopic: "dinosaurs", in: .six) == .reEnablesSuggested(id: "dinosaurs"))
        #expect(fullWithDisabled.check(newTopic: "Rockets", in: .six) == .tooManyCustomTopics)
    }

    @Test func checkLengthBoundaries() {
        let preferences = ReaderPreferences(ageGroup: .six)
        #expect(preferences.check(newTopic: "a", in: .six) == .invalidLength)
        #expect(preferences.check(newTopic: String(repeating: "a", count: 61), in: .six) == .invalidLength)
        #expect(preferences.check(newTopic: "ab", in: .six) == .needsReview)
        #expect(preferences.check(newTopic: String(repeating: "a", count: 60), in: .six) == .needsReview)
        #expect(ReaderPreferences.topicNameLength == 2 ... 60)
    }

    @Test func checkTooManyCustomTopics() {
        let full = ReaderPreferences.fixture(ageGroup: .six, custom: [.six: twentyCustomTopics()])
        #expect(full.check(newTopic: "Rockets", in: .six) == .tooManyCustomTopics)
        #expect(full.check(newTopic: "Rockets", in: .nine) == .needsReview)

        let almostFull = ReaderPreferences.fixture(
            ageGroup: .six,
            custom: [.six: Array(twentyCustomTopics().dropLast())],
        )
        #expect(almostFull.check(newTopic: "Rockets", in: .six) == .needsReview)
    }

    @Test func insertTopicAppendsCustom() {
        var preferences = ReaderPreferences.fixture(ageGroup: .six, custom: [.six: ["Chess"]])
        let inserted = preferences.insertTopic("Origami", in: .six)
        #expect(inserted)
        #expect(preferences.customTopics[.six]?.map(\.name) == ["Chess", "Origami"])
        #expect(preferences.customTopics[.nine] == nil)
    }

    @Test func insertTopicReEnablesSuggested() {
        var preferences = ReaderPreferences.fixture(ageGroup: .six, disabled: [.six: ["dinosaurs"]])
        let inserted = preferences.insertTopic("dinosaurs", in: .six)
        #expect(inserted)
        #expect(preferences.isEnabled(dinosaurs, in: .six))
        #expect(preferences.customTopics.isEmpty)
    }

    @Test func insertTopicRejectsEnabledDuplicate() {
        var preferences = ReaderPreferences.fixture(ageGroup: .six, custom: [.six: ["Chess"]])
        let before = preferences
        let insertedSuggested = preferences.insertTopic("DINOSAURS", in: .six)
        let insertedCustom = preferences.insertTopic("chess", in: .six)
        #expect(!insertedSuggested)
        #expect(!insertedCustom)
        #expect(preferences == before)
    }

    @Test func resetSuggestedTopicsOnlyAffectsGroup() {
        var preferences = ReaderPreferences.fixture(
            ageGroup: .six,
            disabled: [.six: ["dinosaurs", "beach"], .nine: ["volcanoes"]],
        )
        preferences.resetSuggestedTopics(in: .six)
        #expect(preferences.disabledDefaultTopics == [.nine: ["volcanoes"]])
    }

    @Test func removeCustomTopicById() throws {
        var preferences = ReaderPreferences.fixture(
            ageGroup: .six,
            custom: [.six: ["Chess", "Origami", "Jazz"], .nine: ["Chess"]],
        )
        let chess = try #require(preferences.customTopics[.six]?.first)
        preferences.removeCustomTopic(id: chess.id, in: .six)
        #expect(preferences.customTopics[.six]?.map(\.name) == ["Origami", "Jazz"])
        #expect(preferences.customTopics[.nine]?.map(\.name) == ["Chess"])
    }

    @Test func removeCustomTopicFromOtherGroupDoesNothing() throws {
        var preferences = ReaderPreferences.fixture(ageGroup: .six, custom: [.six: ["Chess"], .nine: ["Jazz"]])
        let jazz = try #require(preferences.customTopics[.nine]?.first)
        preferences.removeCustomTopic(id: jazz.id, in: .six)
        #expect(preferences.customTopics[.six]?.map(\.name) == ["Chess"])
        #expect(preferences.customTopics[.nine]?.map(\.name) == ["Jazz"])
    }

    @Test func enabledSuggestedTopicCount() {
        let preferences = ReaderPreferences.fixture(
            ageGroup: .nine,
            disabled: [.nine: ["volcanoes", "recycling"]],
            custom: [.nine: ["Chess"]],
        )
        let suggested = DefaultTopics.topics(for: .nine).count
        #expect(preferences.enabledSuggestedTopicCount(in: .nine) == suggested - 2)
        #expect(preferences.enabledTopicCount(in: .nine) == suggested - 1)
    }

    @Test func setEnabled() {
        var preferences = ReaderPreferences(ageGroup: .six)
        preferences.setEnabled(false, dinosaurs, in: .six)
        #expect(!preferences.isEnabled(dinosaurs, in: .six))
        #expect(preferences.isEnabled(dinosaurs, in: .nine))

        preferences.setEnabled(true, dinosaurs, in: .six)
        #expect(preferences.isEnabled(dinosaurs, in: .six))

        let fresh = ReaderPreferences(ageGroup: .six)
        var copy = fresh
        copy.setEnabled(true, dinosaurs, in: .six)
        #expect(copy == fresh)
    }
}
