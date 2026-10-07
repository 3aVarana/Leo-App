import Foundation
@testable import Leo
import Testing

@MainActor
struct PreferencesEditorViewModelTests {
    private struct ReviewFailed: Error {}

    private let alreadyOnList = String(localized: "That topic is already on your list.")

    private func makeEditor(
        _ draft: ReaderPreferences = ReaderPreferences(ageGroup: .nine),
        reviews: StubTopicReviewRepository = StubTopicReviewRepository(),
        onSave: @escaping (ReaderPreferences) -> Void = { _ in },
    ) -> PreferencesEditorViewModel {
        PreferencesEditorViewModel(draft: draft, topicReviews: reviews, onSave: onSave)
    }

    /// Types `text` and taps Add.
    private func add(_ text: String, to editor: PreferencesEditorViewModel) {
        editor.newTopic = text
        editor.add()
    }

    private func customTopicNames(_ editor: PreferencesEditorViewModel, in group: AgeGroup) -> [String] {
        editor.draft.customTopics[group]?.map(\.name) ?? []
    }

    private var volcanoes: DefaultTopic {
        DefaultTopics.topics(for: .nine).first { $0.id == "volcanoes" }!
    }

    @Test func startingState() {
        let draft = ReaderPreferences.fixture(ageGroup: .nine, custom: [.nine: ["Chess"]])
        let editor = makeEditor(draft)
        #expect(editor.draft == draft)
        #expect(editor.newTopic.isEmpty)
        #expect(editor.message == nil)
        #expect(!editor.isReviewing)
        #expect(!editor.canAdd)
        #expect(editor.suggestedTopics.map(\.id) == DefaultTopics.topics(for: .nine).map(\.id))
        #expect(editor.customTopics.map(\.name) == ["Chess"])
    }

    @Test func topicsFollowAgeGroup() {
        let editor = makeEditor(.fixture(ageGroup: .nine, custom: [.nine: ["Chess"], .twelve: ["Origami"]]))
        editor.draft.ageGroup = .twelve
        #expect(editor.suggestedTopics.map(\.id) == DefaultTopics.topics(for: .twelve).map(\.id))
        #expect(editor.customTopics.map(\.name) == ["Origami"])
    }
}

// MARK: - Local checks

extension PreferencesEditorViewModelTests {
    @Test(arguments: ["", "   ", " \n "])
    func addEmptyDoesNothing(_ text: String) {
        let reviews = StubTopicReviewRepository()
        let editor = makeEditor(reviews: reviews)
        add(text, to: editor)
        #expect(reviews.calls.isEmpty)
        #expect(editor.message == nil)
        #expect(editor.newTopic == text)
        #expect(!editor.canAdd)
    }

    @Test func addTrimsBeforeReview() async {
        let reviews = StubTopicReviewRepository()
        let editor = makeEditor(reviews: reviews)
        add("  rockets \n", to: editor)
        await waitUntil { reviews.calls.count == 1 }
        #expect(reviews.calls == [.init(text: "rockets", group: .nine)])
    }

    @Test(arguments: ["x", String(repeating: "x", count: 61)])
    func addInvalidLengthShowsMessage(_ text: String) {
        let reviews = StubTopicReviewRepository()
        let editor = makeEditor(reviews: reviews)
        add(text, to: editor)
        #expect(editor.message == String(localized: "Topics must be between 2 and 60 characters."))
        #expect(reviews.calls.isEmpty)
        #expect(editor.newTopic == text)
    }

    /// Covers a suggested topic and a custom topic.
    @Test(arguments: ["volcanoes", "CHESS"])
    func addEnabledDuplicateShowsMessage(_ text: String) {
        let reviews = StubTopicReviewRepository()
        let editor = makeEditor(.fixture(ageGroup: .nine, custom: [.nine: ["Chess"]]), reviews: reviews)
        add(text, to: editor)
        #expect(editor.message == alreadyOnList)
        #expect(reviews.calls.isEmpty)
        #expect(editor.newTopic == text)
    }

    @Test func addDisabledSuggestedReEnablesWithoutReview() {
        let reviews = StubTopicReviewRepository()
        let editor = makeEditor(.fixture(ageGroup: .nine, disabled: [.nine: ["volcanoes"]]), reviews: reviews)
        add("Volcanoes", to: editor)
        #expect(editor.isEnabled(volcanoes))
        #expect(editor.newTopic.isEmpty)
        #expect(editor.message == nil)
        #expect(reviews.calls.isEmpty)
        #expect(editor.customTopics.isEmpty)
    }

    @Test func addOverCustomLimitShowsMessage() {
        let reviews = StubTopicReviewRepository()
        let full = (1 ... ReaderPreferences.maximumCustomTopics).map { "Topic \($0)" }
        let editor = makeEditor(.fixture(ageGroup: .nine, custom: [.nine: full]), reviews: reviews)
        add("Rockets", to: editor)
        #expect(editor.message == String(localized: "You can have up to 20 of your own topics."))
        #expect(reviews.calls.isEmpty)
    }

    @Test func editingFieldClearsMessage() {
        let editor = makeEditor()
        add("x", to: editor)
        #expect(editor.message != nil)
        editor.newTopic = "xy"
        #expect(editor.message == nil)
    }
}

// MARK: - Reviews

extension PreferencesEditorViewModelTests {
    @Test func acceptedReviewAddsPhrase() async {
        let reviews = StubTopicReviewRepository(results: [.success(.accepted("Chess Openings"))])
        let editor = makeEditor(reviews: reviews)
        add("chess openings", to: editor)
        await waitUntil { !editor.isReviewing }
        #expect(customTopicNames(editor, in: .nine) == ["Chess Openings"])
        #expect(editor.newTopic.isEmpty)
        #expect(editor.message == nil)
    }

    @Test func acceptedPhraseAlreadyOnListShowsMessage() async {
        let reviews = StubTopicReviewRepository(results: [.success(.accepted("Dinosaurs and fossils"))])
        let editor = makeEditor(reviews: reviews)
        add("dinos", to: editor)
        await waitUntil { editor.message != nil }
        #expect(editor.message == alreadyOnList)
        #expect(editor.newTopic == "dinos")
        #expect(editor.customTopics.isEmpty)
        #expect(!editor.isReviewing)
    }

    @Test func acceptedPhraseReEnablesSuggested() async {
        let reviews = StubTopicReviewRepository(results: [.success(.accepted("Volcanoes"))])
        let editor = makeEditor(.fixture(ageGroup: .nine, disabled: [.nine: ["volcanoes"]]), reviews: reviews)
        add("lava mountains", to: editor)
        await waitUntil { !editor.isReviewing }
        #expect(editor.isEnabled(volcanoes))
        #expect(editor.customTopics.isEmpty)
        #expect(editor.newTopic.isEmpty)
    }

    @Test func rejectedReviewShowsReason() async {
        let reviews = StubTopicReviewRepository(results: [.success(.rejected("Try something gentler."))])
        let draft = ReaderPreferences.fixture(ageGroup: .nine, custom: [.nine: ["Chess"]])
        let editor = makeEditor(draft, reviews: reviews)
        add("scary stuff", to: editor)
        await waitUntil { editor.message != nil }
        #expect(editor.message == "Try something gentler.")
        #expect(editor.newTopic == "scary stuff")
        #expect(editor.draft == draft)
        #expect(!editor.isReviewing)
    }

    @Test func failedReviewShowsGenericMessage() async {
        let reviews = StubTopicReviewRepository(results: [.failure(ReviewFailed())])
        let editor = makeEditor(reviews: reviews)
        add("rockets", to: editor)
        await waitUntil { editor.message != nil }
        #expect(editor.message == String(localized: "We couldn't check that topic. Please try again."))
        #expect(editor.newTopic == "rockets")
        #expect(!editor.isReviewing)
    }

    @Test func isReviewingWhilePending() async {
        let reviews = StubTopicReviewRepository()
        let editor = makeEditor(reviews: reviews)
        add("rockets", to: editor)
        #expect(editor.isReviewing)
        #expect(!editor.canAdd)
        #expect(editor.message == nil)

        await waitUntil { reviews.waitingCount == 1 }
        reviews.resume(returning: .accepted("Rockets"))
        await waitUntil { !editor.isReviewing }
        #expect(customTopicNames(editor, in: .nine) == ["Rockets"])
    }

    @Test func addWhileReviewingIsIgnored() async {
        let reviews = StubTopicReviewRepository()
        let editor = makeEditor(reviews: reviews)
        add("rockets", to: editor)
        await waitUntil { reviews.waitingCount == 1 }
        add("comets", to: editor)
        await settle()
        #expect(reviews.calls.count == 1)
        #expect(editor.newTopic == "comets")
    }

    @Test func changingAgeGroupCancelsReview() async {
        let reviews = StubTopicReviewRepository()
        let editor = makeEditor(reviews: reviews)
        add("rockets", to: editor)
        await waitUntil { reviews.waitingCount == 1 }

        editor.draft.ageGroup = .twelve
        #expect(!editor.isReviewing)
        await waitUntil { reviews.cancelledCount == 1 }
        await settle()
        #expect(editor.draft.customTopics.isEmpty)
        #expect(editor.message == nil)
        #expect(!editor.isReviewing)
    }

    @Test func lateResultAfterCancelIsDropped() async {
        let reviews = StubTopicReviewRepository(ignoresCancellation: true)
        let editor = makeEditor(reviews: reviews)
        add("rockets", to: editor)
        await waitUntil { reviews.waitingCount == 1 }

        editor.cancelReview()
        reviews.resume(returning: .accepted("Rockets"))
        await settle()
        #expect(editor.draft.customTopics.isEmpty)
        #expect(editor.newTopic == "rockets")
        #expect(editor.message == nil)
        #expect(!editor.isReviewing)
    }

    @Test func reviewUsesGroupAtTimeOfAdd() async {
        let reviews = StubTopicReviewRepository()
        let editor = makeEditor(reviews: reviews)
        editor.draft.ageGroup = .adult
        add("rockets", to: editor)
        await waitUntil { reviews.calls.count == 1 }
        #expect(reviews.calls == [.init(text: "rockets", group: .adult)])
    }

    /// Guards the `[weak self]` capture: the review task must not keep the editor alive.
    @Test func deinitCancelsReview() async throws {
        let reviews = StubTopicReviewRepository()
        var editor: PreferencesEditorViewModel? = makeEditor(reviews: reviews)
        try add("rockets", to: #require(editor))
        await waitUntil { reviews.waitingCount == 1 }

        editor = nil
        await waitUntil { reviews.cancelledCount == 1 }
        #expect(editor == nil)
    }
}

// MARK: - Toggles, reset, delete and save

extension PreferencesEditorViewModelTests {
    @Test func toggleDisabledAtMinimum() throws {
        let ids = DefaultTopics.topics(for: .six).map(\.id)
        let editor = makeEditor(.fixture(ageGroup: .six, disabled: [.six: Set(ids.dropLast(3))]))
        let enabledTopic = try #require(DefaultTopics.topics(for: .six).last)
        let disabledTopic = try #require(DefaultTopics.topics(for: .six).first)
        #expect(editor.isAtMinimum)
        #expect(editor.isToggleDisabled(enabledTopic))
        #expect(!editor.isToggleDisabled(disabledTopic))

        editor.setEnabled(true, disabledTopic)
        #expect(!editor.isAtMinimum)
        #expect(!editor.isToggleDisabled(enabledTopic))

        editor.setEnabled(false, disabledTopic)
        #expect(editor.isAtMinimum)
    }

    @Test func resetSuggestedTopics() {
        let editor = makeEditor(.fixture(ageGroup: .nine, disabled: [.nine: ["volcanoes"], .six: ["dinosaurs"]]))
        #expect(editor.canResetSuggestedTopics)
        editor.resetSuggestedTopics()
        #expect(!editor.canResetSuggestedTopics)
        #expect(editor.isEnabled(volcanoes))
        #expect(editor.draft.disabledDefaultTopics == [.six: ["dinosaurs"]])
    }

    @Test func removeCustomTopic() throws {
        let editor = makeEditor(.fixture(ageGroup: .nine, custom: [.nine: ["Chess", "Origami"]]))
        try editor.removeCustomTopic(#require(editor.customTopics.first))
        #expect(editor.customTopics.map(\.name) == ["Origami"])
    }

    /// At the minimum the remove control is hidden; a stray call changes nothing.
    @Test func removeCustomTopicAtMinimumDoesNothing() throws {
        let ids = DefaultTopics.topics(for: .six).map(\.id)
        let editor = makeEditor(.fixture(
            ageGroup: .six,
            disabled: [.six: Set(ids.dropLast(2))],
            custom: [.six: ["Chess"]],
        ))
        #expect(editor.isAtMinimum)
        try editor.removeCustomTopic(#require(editor.customTopics.first))
        #expect(editor.customTopics.map(\.name) == ["Chess"])
    }

    @Test func counts() {
        let editor = makeEditor(.fixture(
            ageGroup: .nine,
            disabled: [.nine: ["volcanoes"], .six: ["dinosaurs"]],
            custom: [.nine: ["Chess", "Origami"]],
        ))
        let suggested = DefaultTopics.topics(for: .nine).count
        #expect(editor.enabledSuggestedCount == suggested - 1)
        #expect(editor.enabledTopicCount == suggested + 1)

        editor.draft.ageGroup = .six
        #expect(editor.enabledSuggestedCount == DefaultTopics.topics(for: .six).count - 1)
        #expect(editor.enabledTopicCount == DefaultTopics.topics(for: .six).count - 1)
    }

    @Test func saveCallsOnSaveWithDraft() {
        var saved: [ReaderPreferences] = []
        let editor = makeEditor { saved.append($0) }
        editor.draft.ageGroup = .adult
        editor.setEnabled(false, DefaultTopics.topics(for: .adult)[0])
        #expect(saved.isEmpty)

        editor.save()
        #expect(saved == [editor.draft])
        #expect(saved[0].ageGroup == .adult)
    }
}
