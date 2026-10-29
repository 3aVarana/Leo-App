import Foundation
@testable import Leo
import Testing

@MainActor
struct RootViewModelTests {
    private let preferences = ReaderPreferences.fixture(ageGroup: .nine, custom: [.nine: ["Chess"]])
    private let repository = PreferencesRepositorySpy()
    private let availability = StubModelAvailabilityProvider()
    private let factory = ExerciseRepositoryFactorySpy()

    private func makeRoot(
        factory: ExerciseRepositoryFactorySpy? = nil,
        history: RoundHistoryViewModel? = nil,
    ) -> RootViewModel {
        let factory = factory ?? self.factory
        return RootViewModel(
            preferences: repository,
            availability: availability,
            topicReviews: StubTopicReviewRepository(),
            quiz: QuizViewModel { factory.make($0) },
            history: history ?? RoundHistoryViewModel(repository: RoundHistoryRepositorySpy()),
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

    @Test func onboardingEditorStartsAtSixTexts() {
        let root = makeRoot()
        let editor = root.makeOnboardingEditor()
        #expect(editor.draft.exercisesPerRound == 6)

        editor.save()
        #expect(repository.saved.map(\.exercisesPerRound) == [6])
        #expect(root.preferences?.roundSettings.exerciseCount == 6)
    }

    @Test func onboardingEditorSavesTextsPerRound() {
        let root = makeRoot()
        let editor = root.makeOnboardingEditor()

        editor.draft.exercisesPerRound = 3
        editor.save()
        #expect(repository.saved.map(\.exercisesPerRound) == [3])
        #expect(root.preferences?.roundSettings.exerciseCount == 3)
    }

    @Test func settingsEditorIsNilBeforeOnboarding() {
        #expect(makeRoot().makeSettingsEditor() == nil)
    }
}

// MARK: - History

extension RootViewModelTests {
    @Test func preferencesDidChangeSetsHistoryAgeGroup() {
        let history = RoundHistoryViewModel(repository: RoundHistoryRepositorySpy())
        repository.stored = preferences
        let root = makeRoot(history: history)
        #expect(history.ageGroup == nil)

        root.preferencesDidChange()
        #expect(history.ageGroup == preferences.ageGroup)
    }

    /// The composition `MyApp` uses: the quiz's `onRoundFinished` goes to `history.record`, and
    /// `RootViewModel` keeps `history.ageGroup` in step, so a finished round shows up.
    @Test func finishedRoundReachesHistory() async throws {
        let history = RoundHistoryViewModel(repository: RoundHistoryRepositorySpy())
        let spy = ExerciseRepositoryFactorySpy { .ready() }
        let quiz = QuizViewModel(makeRepository: { spy.make($0) }, onRoundFinished: { history.record($0) })
        repository.stored = preferences
        let root = RootViewModel(
            preferences: repository,
            availability: availability,
            topicReviews: StubTopicReviewRepository(),
            quiz: quiz,
            history: history,
        )

        root.preferencesDidChange()
        await waitUntil { spy.latest.calls.count == RoundSettings.defaultExerciseCount }
        quiz.start()
        for _ in 0 ..< RoundSettings.defaultExerciseCount {
            let exercise = try #require(quiz.currentExercise)
            quiz.finishReading()
            quiz.select(exercise.correctIndex)
            quiz.next()
        }

        #expect(history.roundCount == 1)
    }
}
