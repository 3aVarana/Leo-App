import Foundation
import Observation

/// Owns the reader's preferences and the quiz, and is the only place preferences are saved.
@Observable
final class RootViewModel {
    /// `nil` until onboarding is done.
    private(set) var preferences: ReaderPreferences?
    let quiz: QuizViewModel
    var isShowingSettings = false

    private let preferencesRepository: any PreferencesRepository
    private let availabilityProvider: any ModelAvailabilityProvider
    private let topicReviews: any TopicReviewRepository

    init(
        preferences: any PreferencesRepository,
        availability: any ModelAvailabilityProvider,
        topicReviews: any TopicReviewRepository,
        quiz: QuizViewModel,
    ) {
        preferencesRepository = preferences
        availabilityProvider = availability
        self.topicReviews = topicReviews
        self.quiz = quiz
        self.preferences = preferences.load()
    }

    /// Forwarded on every access, never cached, so a view that reads it re-renders when the
    /// model becomes available.
    var availability: ModelAvailability {
        availabilityProvider.availability
    }

    /// Saves and applies `preferences`. Does nothing when they haven't changed.
    func save(_ preferences: ReaderPreferences) {
        guard preferences != self.preferences else { return }
        preferencesRepository.save(preferences)
        self.preferences = preferences
    }

    /// Prepares a round with the current preferences. The quiz keeps the round it already has
    /// when the settings are the same.
    func preferencesDidChange() {
        guard let preferences else { return }
        quiz.configure(preferences.roundSettings)
    }

    /// An editor for the first launch. Saving it ends onboarding.
    func makeOnboardingEditor() -> PreferencesEditorViewModel {
        makeEditor(draft: ReaderPreferences(ageGroup: .fifteen))
    }

    /// An editor over the current preferences. `nil` before onboarding is done.
    func makeSettingsEditor() -> PreferencesEditorViewModel? {
        preferences.map(makeEditor)
    }

    private func makeEditor(draft: ReaderPreferences) -> PreferencesEditorViewModel {
        PreferencesEditorViewModel(draft: draft, topicReviews: topicReviews) { [weak self] in
            self?.save($0)
        }
    }
}
