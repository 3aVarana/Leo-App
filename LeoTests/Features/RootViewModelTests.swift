import Foundation
@testable import Leo
import Testing

@MainActor
struct RootViewModelTests {
    private let preferences = ReaderPreferences.fixture(ageGroup: .nine, custom: [.nine: ["Chess"]])
    private let repository = PreferencesRepositorySpy()
    private let availability = StubModelAvailabilityProvider()
    private let factory = ExerciseRepositoryFactorySpy()

    private func makeRoot(factory: ExerciseRepositoryFactorySpy? = nil) -> RootViewModel {
        let factory = factory ?? self.factory
        return RootViewModel(
            preferences: repository,
            availability: availability,
            topicReviews: StubTopicReviewRepository(),
            quiz: QuizViewModel { factory.make($0) },
        )
    }

    @Test func loadsPreferencesAtInit() {
        #expect(makeRoot().preferences == nil)
        repository.stored = preferences
        #expect(makeRoot().preferences == preferences)
    }

    @Test func saveSetsAndPersists() {
        let root = makeRoot()
        root.save(preferences)
        #expect(root.preferences == preferences)
        #expect(repository.saved == [preferences])
    }

    @Test func savingEqualPreferencesDoesNotPersist() {
        repository.stored = preferences
        let root = makeRoot()
        root.save(preferences)
        #expect(repository.saved.isEmpty)
        #expect(root.preferences == preferences)
    }

    @Test func preferencesDidChangeConfiguresQuiz() {
        repository.stored = preferences
        makeRoot().preferencesDidChange()
        #expect(factory.settings == [preferences.roundSettings])
    }

    @Test func preferencesDidChangeWithoutPreferencesDoesNothing() {
        let root = makeRoot()
        root.preferencesDidChange()
        #expect(factory.settings.isEmpty)
        #expect(root.quiz.phase == .welcome)
    }

    /// Saving unchanged settings keeps the round that's already prepared.
    @Test func preferencesDidChangeWithSameSettingsKeepsRound() {
        repository.stored = preferences
        let root = makeRoot()
        root.preferencesDidChange()
        root.save(preferences)
        root.preferencesDidChange()
        #expect(factory.settings.count == 1)
    }

    @Test func availabilityFollowsProvider() {
        let root = makeRoot()
        #expect(root.availability == .available)
        availability.availability = .unavailable(.modelNotReady)
        #expect(root.availability == .unavailable(.modelNotReady))
    }
}

// MARK: - Editors

extension RootViewModelTests {
    @Test func settingsEditorStartsFromCurrentPreferences() {
        repository.stored = preferences
        let editor = makeRoot().makeSettingsEditor()
        #expect(editor?.draft == preferences)
        #expect(editor?.newTopic.isEmpty == true)
    }

    @Test func settingsEditorSaveGoesThroughRoot() throws {
        repository.stored = preferences
        let root = makeRoot()
        let editor = try #require(root.makeSettingsEditor())
        editor.draft.ageGroup = .adult
        #expect(repository.saved.isEmpty)

        editor.save()
        #expect(root.preferences == editor.draft)
        #expect(repository.saved == [editor.draft])
    }

    @Test func onboardingEditorSaveEndsOnboarding() {
        let root = makeRoot()
        let editor = root.makeOnboardingEditor()
        #expect(root.preferences == nil)

        editor.draft.ageGroup = .six
        editor.save()
        #expect(root.preferences == editor.draft)
        #expect(repository.saved == [editor.draft])
    }

    @Test func settingsEditorIsNilBeforeOnboarding() {
        #expect(makeRoot().makeSettingsEditor() == nil)
    }
}
