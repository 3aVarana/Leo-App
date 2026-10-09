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

    /// Drives the quiz through every phase: every exercise after the first fails, and so do the
    /// replacements, then a retry generates the rest.
    @Test func canShowSettings() async {
        let factory = ExerciseRepositoryFactorySpy { .scripted("S F F F F F F F F") }
        repository.stored = preferences
        let root = makeRoot(factory: factory)
        let quiz = root.quiz
        #expect(root.canShowSettings)

        root.preferencesDidChange()
        await waitUntil { factory.latest.calls.count == 9 }
        await settle()
        #expect(quiz.phase == .welcome)
        #expect(root.canShowSettings)

        quiz.start()
        #expect(quiz.phase == .answering)
        #expect(!root.canShowSettings)

        quiz.finishReading()
        quiz.select(0)
        quiz.next()
        #expect(quiz.phase == .failed)
        #expect(!root.canShowSettings)

        quiz.retry()
        #expect(quiz.phase == .loading)
        #expect(!root.canShowSettings)

        for _ in 1 ..< QuizViewModel.exerciseCount {
            await waitUntil { factory.latest.waitingCount == 1 }
            factory.latest.resume(returning: .fixture())
            await waitUntil { quiz.phase == .answering }
            #expect(!root.canShowSettings)
            quiz.finishReading()
            quiz.select(0)
            quiz.next()
        }
        #expect(quiz.phase == .finished)
        #expect(root.canShowSettings)
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
